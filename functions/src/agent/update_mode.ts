/**
 * Gardener update mode — a traditional slot-filling chatbot, not an LLM agent.
 *
 * WHY THIS EXISTS
 * Free-form "let the model figure out what the gardener meant and call the
 * right tool" is exactly where the agent was unreliable. Recording a real
 * action against T's production database is not a place for a model to
 * improvise. So the gardener now enters an explicit mode (a button), and from
 * that point the conversation is a deterministic state machine:
 *
 *   press Update ─→ ask for the update
 *                     │
 *                     ▼
 *              extract slots  ← the ONLY LLM step: free Finnish speech into
 *                     │          a fixed JSON shape. No SQL, no tool choice.
 *                     ▼
 *            all required slots present? ── no ──→ ask for the missing one
 *                     │ yes                        (plant → tappable options)
 *                     ▼
 *            hand to buildPlan/writes.ts → parameterized, whitelisted SQL
 *                     │
 *                     ▼
 *            success / error ─→ [Update another] [Done]
 *
 * The LLM never emits SQL. It emits {action_family, count, location...} and
 * the server maps that to the statements T has already reviewed. That keeps
 * the row-count caps, the operation whitelist, the audit log, and T's veto
 * over statement shapes — none of which survive if a model writes the SQL.
 *
 * ponytail: state lives in one Firestore doc per user, no session store, no
 * state-machine library. A gardener has one update conversation at a time.
 */

import { getFirestore, FieldValue } from "firebase-admin/firestore";
import { logger } from "firebase-functions/v2";
import * as dal from "./dal";
import type { LlmKeys } from "./llm";

const COLL = "agent_update_mode";
/** A half-open update conversation expires so a stale slot set can't leak into
 *  tomorrow's session and write the wrong thing. */
const TTL_MS = 15 * 60 * 1000;

export type UpdateKind = "action" | "observation";

export interface UpdateSlots {
  // identity
  plant_query?: string;
  hankintaID?: number;
  section_code?: string;
  // record_action
  action_family?: string;
  location_code?: string;
  from_location?: string;
  count?: number;
  details?: string;
  // record_observation
  condition_stars?: number;
  living_count?: number;
  size?: string;
  status?: string;
  notes?: string;
}

interface UpdateState {
  active: boolean;
  kind?: UpdateKind;
  slots: UpdateSlots;
  ts: number;
}

/** Legacy action vocabulary — from docs/notes/data_inventory.md. */
const ACTION_FAMILIES = [
  "KYLVÖ", "IT.", "KOULINTA", "IST.", "SIIRTO",
  "PISTETTY", "KUOLLUT", "POIST.", "MYYTY", "MUU",
] as const;

// ─── State ──────────────────────────────────────────────────────────────────

function ref(uid: string) {
  return getFirestore().collection(COLL).doc(uid);
}

export async function loadState(uid: string): Promise<UpdateState | null> {
  const snap = await ref(uid).get();
  if (!snap.exists) return null;
  const s = snap.data() as UpdateState;
  if (!s.active) return null;
  if (Date.now() - (s.ts ?? 0) > TTL_MS) {
    await exitUpdateMode(uid);
    return null;
  }
  return s;
}

async function saveState(uid: string, s: UpdateState): Promise<void> {
  await ref(uid).set({ ...s, ts: Date.now() }, { merge: false });
}

export async function exitUpdateMode(uid: string): Promise<void> {
  await ref(uid).set(
    { active: false, slots: {}, ts: Date.now(), closedAt: FieldValue.serverTimestamp() },
    { merge: false }
  );
}

export async function startUpdateMode(uid: string): Promise<void> {
  await saveState(uid, { active: true, slots: {}, ts: Date.now() });
}

/** Clear the slots but stay in the mode — "Update another". */
export async function resetSlots(uid: string): Promise<void> {
  await saveState(uid, { active: true, slots: {}, ts: Date.now() });
}

// ─── Localized copy ─────────────────────────────────────────────────────────

const pick = (lang: string, en: string, fi: string, sv: string) =>
  lang === "fi" ? fi : lang === "sv" ? sv : en;

export function updateModePrompt(lang: string): string {
  return pick(
    lang,
    "Update mode is on. Tell me what to record — plant, what you did, and any count or location.\n\nExample: \"Valerian in T-4.1.3 planted out, 3 kpl\"\nOr an inspection: \"Cacao in G-HA, *** 2 kpl, 2-4 m, kukkii\"",
    "Päivitystila on päällä. Kerro mitä kirjataan — kasvi, mitä teit, sekä määrä tai sijainti.\n\nEsimerkki: \"Rohtovirmajuuri T-4.1.3 istutettu, 3 kpl\"\nTai tarkastus: \"Kakao G-HA, *** 2 kpl, 2-4 m, kukkii\"",
    "Uppdateringsläge är på. Berätta vad som ska registreras — växt, vad du gjorde, samt antal eller plats.\n\nExempel: \"Läkevänderot T-4.1.3 utplanterad, 3 kpl\"\nEller en inspektion: \"Kakao G-HA, *** 2 kpl, 2-4 m, kukkii\""
  );
}

/**
 * Shown when the gardener declines a confirmation card while in update mode.
 * Deliberately asks for the CHANGE only, not the whole update again — retyping
 * a correct sentence to fix one wrong word is how people give up on a tool.
 */
export function updateDeclinedPrompt(lang: string): string {
  return pick(
    lang,
    "Not saved — nothing was written. Tell me just what needs to be different, and I'll show you the change again.",
    "Ei tallennettu — mitään ei kirjattu. Kerro vain mikä pitää muuttaa, niin näytän muutoksen uudelleen.",
    "Inte sparat — ingenting skrevs. Berätta bara vad som behöver ändras, så visar jag ändringen igen."
  );
}

export function updateModeExitMessage(lang: string): string {
  return pick(lang, "Update mode off.", "Päivitystila pois.", "Uppdateringsläge av.");
}

// ─── The one LLM step: free text → fixed JSON ───────────────────────────────

const SLOT_SYSTEM = `You convert a gardener's spoken update at Oulu Botanical Garden into JSON. You do NOT write SQL and you do NOT decide what happens next.

Output ONE JSON object, nothing else. Omit any field you are not confident about — a missing field is correct and safe; a guessed field corrupts a real record.

{
  "kind": "action" | "observation",
  "plant_query": "plant name exactly as the gardener said it",
  "section_code": "section if stated, e.g. G-HA, T-4.1.3, K-19",
  "action_family": one of ${ACTION_FAMILIES.join(" | ")},
  "location_code": "target location for IST./SIIRTO",
  "from_location": "source location for SIIRTO",
  "count": number of individuals (kpl),
  "details": "extra words the gardener used, keep their Finnish",
  "condition_stars": 1 | 2 | 3,
  "living_count": number alive,
  "size": "e.g. 2-4 m",
  "status": "e.g. kukkii",
  "notes": "free notes in the gardener's words"
}

Action vocabulary: KYLVÖ=sow, IT.=germinated, KOULINTA=prick out, IST.=plant out, SIIRTO=transfer, PISTETTY=cuttings, KUOLLUT=died, POIST.=removed, MYYTY=sold, MUU=other.
Use "observation" for a stocktake: condition stars (* poor, ** moderate, *** good), count in kpl, size, status. Use "action" for something the gardener DID.
Do not invent a plant name. If no plant is named, omit plant_query.`;

async function extractSlots(
  keys: LlmKeys,
  text: string,
  known: UpdateSlots
): Promise<{ kind?: UpdateKind; slots: UpdateSlots }> {
  const user =
    (Object.keys(known).length
      ? `ALREADY KNOWN (do not repeat unless the gardener corrects it):\n${JSON.stringify(known)}\n\n`
      : "") + `GARDENER SAID: ${text}`;

  const raw = await jsonCompletion(keys, SLOT_SYSTEM, user);
  if (!raw) return { slots: {} };

  const kind = raw.kind === "observation" ? "observation" : raw.kind === "action" ? "action" : undefined;
  const slots: UpdateSlots = {};
  const str = (v: unknown) => (typeof v === "string" && v.trim() ? v.trim() : undefined);
  const num = (v: unknown) => {
    const n = typeof v === "number" ? v : typeof v === "string" ? Number(v) : NaN;
    return Number.isFinite(n) ? n : undefined;
  };

  slots.plant_query = str(raw.plant_query);
  slots.section_code = str(raw.section_code) ? dal.normalizeSection(str(raw.section_code)!) : undefined;
  // Only accept an action from the fixed vocabulary — never a model invention.
  const af = str(raw.action_family)?.toUpperCase();
  slots.action_family = af && (ACTION_FAMILIES as readonly string[]).includes(af) ? af : undefined;
  slots.location_code = str(raw.location_code);
  slots.from_location = str(raw.from_location);
  slots.count = num(raw.count);
  slots.details = str(raw.details);
  const stars = num(raw.condition_stars);
  slots.condition_stars = stars && stars >= 1 && stars <= 3 ? Math.round(stars) : undefined;
  slots.living_count = num(raw.living_count);
  slots.size = str(raw.size);
  slots.status = str(raw.status);
  slots.notes = str(raw.notes);

  for (const k of Object.keys(slots) as (keyof UpdateSlots)[]) {
    if (slots[k] === undefined) delete slots[k];
  }
  return { kind, slots };
}

/**
 * Merge a correction over the slots already gathered.
 *
 * The one rule that matters: if the gardener names a DIFFERENT plant or a
 * different section, the previously resolved hankintaID is now wrong and must be
 * dropped so it re-resolves. Without this, correcting the plant on a declined
 * card would keep writing to the original one — a silent write to the wrong
 * plant is the worst failure this flow can produce. A tapped option
 * (`pinned`) always wins, because that is an explicit choice, not an inference.
 *
 * Pure, so it can be checked without Firestore or an LLM.
 */
export function mergeSlots(
  known: UpdateSlots,
  incoming: UpdateSlots,
  pinned?: number
): UpdateSlots {
  const namedAnotherPlant =
    !!incoming.plant_query &&
    !!known.plant_query &&
    incoming.plant_query.toLowerCase() !== known.plant_query.toLowerCase();
  const namedAnotherSection =
    !!incoming.section_code && incoming.section_code !== known.section_code;

  const merged: UpdateSlots = { ...known, ...incoming };
  if ((namedAnotherPlant || namedAnotherSection) && !pinned) {
    delete merged.hankintaID;
  }
  if (pinned) merged.hankintaID = pinned;
  return merged;
}

/** Groq JSON mode, Gemini fallback. Returns null if both fail. */
async function jsonCompletion(
  keys: LlmKeys,
  system: string,
  user: string
): Promise<Record<string, any> | null> {
  for (const model of ["llama-3.3-70b-versatile", "llama-3.1-8b-instant"]) {
    try {
      const r = await fetch("https://api.groq.com/openai/v1/chat/completions", {
        method: "POST",
        headers: { "Content-Type": "application/json", Authorization: `Bearer ${keys.groq}` },
        body: JSON.stringify({
          model,
          messages: [
            { role: "system", content: system },
            { role: "user", content: user },
          ],
          response_format: { type: "json_object" },
          temperature: 0, // slot extraction is transcription, not creativity
          max_tokens: 400,
        }),
      });
      if (r.ok) {
        const data = (await r.json()) as any;
        return JSON.parse(data.choices?.[0]?.message?.content ?? "{}");
      }
      if (r.status === 401 || r.status === 403) break;
    } catch (e) {
      logger.warn("update_mode.groq_slots_failed", { model, err: String(e) });
    }
  }
  try {
    const url = `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=${keys.gemini}`;
    const r = await fetch(url, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        system_instruction: { parts: [{ text: system }] },
        contents: [{ role: "user", parts: [{ text: user }] }],
        generationConfig: { temperature: 0, maxOutputTokens: 400, responseMimeType: "application/json" },
      }),
    });
    if (r.ok) {
      const data = (await r.json()) as any;
      const txt = (data.candidates?.[0]?.content?.parts ?? []).map((p: any) => p.text ?? "").join("");
      return JSON.parse(txt || "{}");
    }
  } catch (e) {
    logger.warn("update_mode.gemini_slots_failed", { err: String(e) });
  }
  return null;
}

// ─── The state machine ──────────────────────────────────────────────────────

export interface UpdateAsk {
  kind: "ask";
  question: string;
  /** Tappable choices; each `send_text` is what gets sent when tapped. */
  options?: { label: string; send_text: string; hankintaID?: number }[];
}
export interface UpdateReady {
  kind: "ready";
  /** Tool name the dispatcher's existing guarded write path understands. */
  tool: "record_action" | "record_observation";
  args: Record<string, unknown>;
}
export type UpdateTurn = UpdateAsk | UpdateReady;

/**
 * Advance one turn of the update conversation. Pure decision logic plus the
 * single slot-extraction call — it never writes to the garden database itself.
 */
export async function handleUpdateTurn(opts: {
  uid: string;
  text: string;
  language: string;
  keys: LlmKeys;
  /** Set when the gardener tapped a plant option. */
  pinnedHankintaID?: number;
}): Promise<UpdateTurn> {
  const lang = opts.language;
  const state = (await loadState(opts.uid)) ?? { active: true, slots: {}, ts: Date.now() };

  // 1. Merge what we already knew with whatever this message adds.
  let kind = state.kind;
  let slots: UpdateSlots = { ...state.slots };

  if (opts.pinnedHankintaID) {
    // A tapped option settles identity outright — no extraction needed for it.
    slots.hankintaID = opts.pinnedHankintaID;
  }
  if (opts.text.trim()) {
    const extracted = await extractSlots(opts.keys, opts.text, slots);
    slots = mergeSlots(slots, extracted.slots, opts.pinnedHankintaID);
    kind = kind ?? extracted.kind;
  }

  // 2. Identify the plant. This is the slot most worth being strict about:
  //    writing an action against the wrong plant is a silent data corruption.
  if (!slots.hankintaID) {
    if (!slots.plant_query) {
      await saveState(opts.uid, { active: true, kind, slots, ts: Date.now() });
      return {
        kind: "ask",
        question: pick(
          lang,
          "Which plant? Give me the name (and the section if you know it).",
          "Mikä kasvi? Kerro nimi (ja osasto jos tiedät).",
          "Vilken växt? Ange namnet (och sektionen om du vet)."
        ),
      };
    }

    let instances: dal.PlantInstance[] = [];
    try {
      instances = await dal.findPlantInstances(slots.plant_query, slots.section_code);
    } catch (e) {
      logger.warn("update_mode.find_failed", { err: String(e) });
      await saveState(opts.uid, { active: true, kind, slots, ts: Date.now() });
      return {
        kind: "ask",
        question: pick(
          lang,
          "The garden database is slow right now — say the plant name again in a moment.",
          "Puutarhan tietokanta on hidas juuri nyt — sano kasvin nimi hetken kuluttua uudelleen.",
          "Trädgårdens databas är långsam just nu — säg växtnamnet igen om en stund."
        ),
      };
    }

    if (instances.length === 0) {
      // Offer fuzzy alternatives rather than a dead end.
      let suggestions: dal.NameSuggestion[] = [];
      try {
        suggestions = await dal.suggestSimilarPlants(slots.plant_query, 4);
      } catch {
        // suggestions are a nicety, never block the turn on them
      }
      const missing = { ...slots };
      delete missing.plant_query;
      delete missing.section_code;
      await saveState(opts.uid, { active: true, kind, slots: missing, ts: Date.now() });
      return {
        kind: "ask",
        question: pick(
          lang,
          `No plant matches "${slots.plant_query}". Try the name again${suggestions.length ? " or pick one" : ""}.`,
          `Nimellä "${slots.plant_query}" ei löydy kasvia. Yritä nimeä uudelleen${suggestions.length ? " tai valitse" : ""}.`,
          `Ingen växt matchar "${slots.plant_query}". Försök med namnet igen${suggestions.length ? " eller välj en" : ""}.`
        ),
        options: suggestions.map((s) => ({
          label: s.scientific_name,
          send_text: s.scientific_name,
        })),
      };
    }

    if (instances.length > 1) {
      // Several physical plants of this species — the gardener must pick one.
      const seen = new Set<string>();
      const options: UpdateAsk["options"] = [];
      for (const i of instances) {
        const key = i.section_code ? dal.normalizeSection(i.section_code) : `ID${i.hankintaID}`;
        if (seen.has(key)) continue;
        seen.add(key);
        options.push({
          label: i.section_code
            ? `${i.section_code}${i.status ? ` (${i.status})` : ""}`
            : `#${i.hankintaID}`,
          send_text: i.section_code ?? `id ${i.hankintaID}`,
          hankintaID: i.hankintaID,
        });
      }
      if (options.length > 1) {
        await saveState(opts.uid, { active: true, kind, slots, ts: Date.now() });
        return {
          kind: "ask",
          question: pick(
            lang,
            `"${slots.plant_query}" is in ${options.length} places. Which one are you updating?`,
            `"${slots.plant_query}" on ${options.length} paikassa. Kumpaa päivität?`,
            `"${slots.plant_query}" finns på ${options.length} platser. Vilken uppdaterar du?`
          ),
          options,
        };
      }
      slots.hankintaID = options[0].hankintaID;
    } else {
      slots.hankintaID = instances[0].hankintaID;
    }
  }

  // 3. Decide which record we are writing. If the gardener gave stars or a
  //    living count it is a stocktake; if they named an action it is an action.
  if (!kind) {
    if (slots.condition_stars || slots.living_count || slots.size || slots.status) {
      kind = "observation";
    } else if (slots.action_family) {
      kind = "action";
    }
  }

  // 4. An action record is meaningless without the action.
  if (kind !== "observation" && !slots.action_family) {
    await saveState(opts.uid, { active: true, kind, slots, ts: Date.now() });
    return {
      kind: "ask",
      question: pick(
        lang,
        "What was done to it?",
        "Mitä sille tehtiin?",
        "Vad gjordes med den?"
      ),
      options: [
        { label: "KYLVÖ (sow)", send_text: "KYLVÖ" },
        { label: "IT. (germinated)", send_text: "IT." },
        { label: "KOULINTA (prick out)", send_text: "KOULINTA" },
        { label: "IST. (plant out)", send_text: "IST." },
        { label: "SIIRTO (transfer)", send_text: "SIIRTO" },
        { label: "KUOLLUT (died)", send_text: "KUOLLUT" },
      ],
    };
  }

  // 5. An observation with nothing observed is equally meaningless.
  if (kind === "observation" && !slots.condition_stars && !slots.living_count && !slots.notes) {
    await saveState(opts.uid, { active: true, kind, slots, ts: Date.now() });
    return {
      kind: "ask",
      question: pick(
        lang,
        "How is it doing? Condition, count, or a note.",
        "Missä kunnossa se on? Kunto, määrä tai huomio.",
        "Hur mår den? Skick, antal eller en notering."
      ),
      options: [
        { label: "*** good", send_text: "***" },
        { label: "** moderate", send_text: "**" },
        { label: "* poor", send_text: "*" },
      ],
    };
  }

  // 6. Every required slot is present. Hand the structured command to the
  //    existing guarded write path — which is what actually builds the SQL.
  await saveState(opts.uid, { active: true, kind, slots, ts: Date.now() });
  return kind === "observation"
    ? {
        kind: "ready",
        tool: "record_observation",
        args: {
          hankintaID: slots.hankintaID,
          condition_stars: slots.condition_stars,
          living_count: slots.living_count,
          size: slots.size,
          status: slots.status,
          notes: slots.notes ?? slots.details,
        },
      }
    : {
        kind: "ready",
        tool: "record_action",
        args: {
          hankintaID: slots.hankintaID,
          action_family: slots.action_family,
          location_code: slots.location_code,
          from_location: slots.from_location,
          count: slots.count,
          details: slots.details ?? slots.notes,
        },
      };
}

/** The [Update another] / [Done] choice shown after a write settles. */
export function followUpOptions(lang: string) {
  return {
    kind: "update_followup" as const,
    question: pick(lang, "Anything else?", "Vielä jotain?", "Något mer?"),
    options: [
      {
        label: pick(lang, "Update another", "Päivitä toinen", "Uppdatera en till"),
        send_text: pick(lang, "update another", "päivitä toinen", "uppdatera en till"),
      },
      {
        label: pick(lang, "Done", "Valmis", "Klar"),
        send_text: pick(lang, "done", "valmis", "klar"),
      },
    ],
    allow_free_text: true,
  };
}

/** Recognise the two follow-up taps (and typed equivalents). */
export function readFollowUp(text: string): "again" | "done" | null {
  const t = text.trim().toLowerCase();
  if (/^(update another|another|päivitä toinen|toinen|uppdatera en till|en till)$/.test(t)) return "again";
  if (/^(done|finished|exit|stop|valmis|lopeta|klar|sluta)$/.test(t)) return "done";
  return null;
}

// ─── Self-check ─────────────────────────────────────────────────────────────
// ponytail: covers mergeSlots only — the rest of the machine needs Firestore and
// an LLM, and this is the branch where a bug writes to the wrong plant.
// Run: `npx tsx src/agent/update_mode.ts`
if (require.main === module) {
  const assert: typeof import("assert") = require("assert");

  // Correcting the plant must drop the stale resolved id.
  assert.strictEqual(
    mergeSlots(
      { plant_query: "Valerian", hankintaID: 4421, action_family: "IST." },
      { plant_query: "Chamomile" }
    ).hankintaID,
    undefined,
    "a different plant name must invalidate the resolved id"
  );

  // Correcting only the count must NOT re-resolve the plant.
  assert.strictEqual(
    mergeSlots({ plant_query: "Valerian", hankintaID: 4421 }, { count: 3 }).hankintaID,
    4421,
    "an unrelated correction must keep the resolved plant"
  );

  // Restating the same name (different case) is not a change of plant.
  assert.strictEqual(
    mergeSlots({ plant_query: "Valerian", hankintaID: 4421 }, { plant_query: "valerian" })
      .hankintaID,
    4421,
    "the same name in another case is not a new plant"
  );

  // A narrowed section must re-resolve.
  assert.strictEqual(
    mergeSlots({ plant_query: "Valerian", hankintaID: 4421 }, { section_code: "G-HA" })
      .hankintaID,
    undefined,
    "a new section must invalidate the resolved id"
  );

  // A tapped option always wins, even alongside a new name.
  assert.strictEqual(
    mergeSlots({ plant_query: "Valerian", hankintaID: 4421 }, { plant_query: "Chamomile" }, 9999)
      .hankintaID,
    9999,
    "an explicitly tapped plant overrides inference"
  );

  // Corrections overwrite, they don't append.
  assert.strictEqual(
    mergeSlots({ action_family: "IST.", count: 3 }, { count: 5 }).count,
    5,
    "a corrected value must replace the old one"
  );

  console.log("update_mode self-check ok");
}

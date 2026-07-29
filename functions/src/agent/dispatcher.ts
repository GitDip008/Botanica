/**
 * Tool dispatcher.
 *
 * Flow:
 *   0. Update mode active? → slot-filling state machine (update_mode.ts), the
 *      LLM never chooses anything here
 *   1. Pattern-route the message (router.ts). Recognised → fixed tool calls.
 *      Unrecognised → llmTurn() picks the tool, as before.
 *   2. For each tool_call:
 *        WRITE tools  → build a pending_action (UI confirms before commit)
 *        READ tools   → execute against the DAL
 *   3. composeAnswer() rephrases the fetched rows — the LLM's only job on a
 *      read is language, never facts and never tool choice.
 */

import { randomUUID } from "node:crypto";
import { logger } from "firebase-functions/v2";
import type { Role } from "./roles";
import type { PlantCandidate } from "./resolver";
import { llmTurn, composeAnswer, type LlmKeys, type LlmToolCall } from "./llm";
import * as dal from "./dal";
import { storePending, ledgerHistory, storeIntent, loadIntent, clearIntent } from "./writes";
import { buildPlan, SafetyError, type WritePlan, type PlanChange } from "./safety";
import { routeRead } from "./router";
import * as um from "./update_mode";

export interface DispatchInput {
  uid: string;
  role: Role;
  language: "en" | "fi" | "sv";
  text: string;
  candidates: PlantCandidate[];
  keys: LlmKeys;
  /** Legacy inspector initials of the signed-in user (tarkastaja). */
  inspectorCode?: string;
  /** If the user scanned a label, the exact plant is known and unambiguous. */
  scannedHankintaID?: number;
  /** Recent conversation turns (oldest→newest) so the LLM keeps context. */
  history?: { role: "user" | "assistant"; content: string }[];
}

/** A tappable choice rendered as a button in the app. */
export interface ClarOption {
  label: string;
  /** Text sent back as the next user message when tapped. */
  send_text: string;
  /** When set, tapping pins this exact plant (sent as scanned context). */
  hankintaID?: number;
}

export interface Clarification {
  kind: "disambiguation" | "did_you_mean" | "update_ask" | "update_followup";
  question: string;
  options: ClarOption[];
  /** Whether to still allow free typing (always true here). */
  allow_free_text: boolean;
}

export interface DispatchResult {
  reply: string;
  data?: unknown;
  pending_actions?: PendingAction[];
  clarification?: Clarification;
  /** Tap-to-send follow-up prompts, contextual to this turn. */
  suggestions?: string[];
  tool_calls: ToolCallRecord[];
  llm_model: string;
}

export interface PendingAction {
  pending_id: string;
  tool: string;
  params: Record<string, unknown>;
  preview: string;
  requires_confirmation: true;
  /** The exact statement that will run, shown read-only in the card. */
  sql_display?: string;
  /** Field-by-field breakdown of what changes. */
  changes?: PlanChange[];
}

export interface ToolCallRecord {
  tool: string;
  params: Record<string, unknown>;
  result: "executed" | "pending" | "denied" | "unknown_tool";
}

const WRITE_TOOLS = new Set(["record_action", "record_observation"]);
const GARDENER_ONLY = new Set([
  "record_action",
  "record_observation",
  "query_plant_history",
  "find_overdue_inspections",
]);

export async function dispatch(input: DispatchInput): Promise<DispatchResult> {
  // ── Update mode (gardener/admin only) ──
  // An explicit mode, entered by a button, in which the conversation is a
  // slot-filling state machine rather than an LLM agent. Checked FIRST so a
  // tapped plant option routes into the machine instead of the generic
  // disambiguation path below. See update_mode.ts for why.
  if (input.role !== "visitor") {
    const umState = await um.loadState(input.uid).catch(() => null);
    if (umState) {
      const followUp = um.readFollowUp(input.text);
      if (followUp === "done") {
        await um.exitUpdateMode(input.uid);
        return {
          reply: um.updateModeExitMessage(input.language),
          tool_calls: [],
          llm_model: "update-mode",
        };
      }
      if (followUp === "again") {
        await um.resetSlots(input.uid);
        return {
          reply: um.updateModePrompt(input.language),
          tool_calls: [],
          llm_model: "update-mode",
        };
      }

      const turn = await um.handleUpdateTurn({
        uid: input.uid,
        text: input.text,
        language: input.language,
        keys: input.keys,
        pinnedHankintaID: input.scannedHankintaID,
      });

      if (turn.kind === "ask") {
        return {
          reply: turn.question,
          clarification: {
            kind: "update_ask",
            question: turn.question,
            options: turn.options ?? [],
            allow_free_text: true,
          },
          tool_calls: [],
          llm_model: "update-mode",
        };
      }

      // Slots complete → the SAME guarded write path the LLM path uses, so the
      // parameterized SQL, row-count caps and audit log all still apply.
      const outcome = await buildPendingAction({ name: turn.tool, arguments: turn.args }, input);
      if (outcome.kind === "pending") {
        await storePending(input.uid, outcome.pending);
        return {
          reply: outcome.pending.preview,
          pending_actions: [outcome.pending],
          tool_calls: [{ tool: turn.tool, params: turn.args, result: "pending" }],
          llm_model: "update-mode",
        };
      }
      if (outcome.kind === "clarify") {
        return {
          reply: outcome.clarification.question,
          clarification: outcome.clarification,
          tool_calls: [{ tool: turn.tool, params: turn.args, result: "denied" }],
          llm_model: "update-mode",
        };
      }
      // Plan couldn't be built (bad slot combination) — stay in the mode and
      // let the gardener restate rather than dropping them back to free chat.
      await um.resetSlots(input.uid);
      return {
        reply:
          input.language === "fi"
            ? "En saanut tuosta kirjausta. Kerro uudelleen: kasvi, toimenpide, määrä."
            : input.language === "sv"
              ? "Jag kunde inte registrera det. Säg igen: växt, åtgärd, antal."
              : "I couldn't turn that into a record. Say it again: plant, action, count.",
        tool_calls: [{ tool: turn.tool, params: turn.args, result: "unknown_tool" }],
        llm_model: "update-mode",
      };
    }
  }

  // ── Deterministic disambiguation completion ──
  // The user tapped a plant chip (scannedHankintaID set) and we have a stashed
  // write intent → complete THAT exact action on the chosen plant, no LLM, no
  // lost context. This is what makes the chip→card chain reliable.
  if (input.scannedHankintaID && input.role !== "visitor") {
    try {
      const intent = await loadIntent(input.uid);
      if (intent && Date.now() - intent.ts < 300_000) {
        await clearIntent(input.uid);
        const outcome = await buildPendingAction(
          { name: intent.tool, arguments: intent.args },
          input // input.scannedHankintaID pins the plant
        );
        if (outcome.kind === "pending") {
          await storePending(input.uid, outcome.pending);
          return {
            reply: outcome.pending.preview,
            pending_actions: [outcome.pending],
            tool_calls: [{ tool: intent.tool, params: intent.args, result: "pending" }],
            llm_model: "deterministic",
          };
        }
      }
    } catch (e) {
      // Flaky DB during completion → fall through to the normal LLM path.
      logger.warn("agent.deterministic_complete_failed", { err: String(e) });
    }
  }

  // ── Deterministic READ completion ──
  // A plant/section BUTTON was tapped (scannedHankintaID set, no write intent).
  // Show THAT exact plant's info directly — bypassing the LLM tool choice, which
  // substring-matches cultivars and loops. Skip only if the message is clearly a
  // status/history question (let the LLM handle those).
  if (input.scannedHankintaID) {
    const wantsMore = /attention|histor|need|next|water|record|inspect|status|when|overdue|kastel|toimenpide|tarkast/i.test(
      input.text
    );
    if (!wantsMore) {
      try {
        const details = await dal.plantDetails({ hankintaID: input.scannedHankintaID });
        if (details) {
          const safe = input.role === "visitor" ? stripForVisitor(details) : (details as any);
          const rr = [{ tool: "query_plant_details", result: safe }];
          // No-LLM fallback line so this still works when the AI is rate-limited.
          const secs = [
            ...new Set((safe.placements ?? []).map((p: any) => p.section_code).filter(Boolean)),
          ];
          const basic =
            `${safe.scientific_name}` +
            (safe.family?.latin ? `, family ${safe.family.latin}` : "") +
            (secs.length ? `. Found in section${secs.length > 1 ? "s" : ""}: ${secs.join(", ")}` : "") +
            (safe.general_notes ? `. ${safe.general_notes}` : ".");
          let composed = "";
          try {
            composed = await composeAnswer({
              keys: input.keys,
              language: input.language,
              userText: input.text,
              toolResults: rr,
            });
          } catch {
            /* AI down — use basic line */
          }
          const suggestions = buildSuggestions({
            role: input.role,
            lang: input.language,
            readResults: rr,
            hasClarification: false,
            hasPending: false,
          });
          return {
            reply: composed || basic,
            data: safe,
            suggestions,
            tool_calls: [
              { tool: "query_plant_details", params: { hankintaID: input.scannedHankintaID }, result: "executed" },
            ],
            llm_model: composed ? "deterministic-read" : "deterministic-read-basic",
          };
        }
      } catch (e) {
        logger.warn("agent.deterministic_read_failed", { err: String(e) });
      }
    }
  }

  // ── Deterministic read routing ──
  // Decide WHICH query to run by pattern, not by asking a model. Tool choice
  // was the unreliable step: the same question could resolve to find_plant,
  // query_plant_details, or an answer from memory on different days. The
  // resulting tool calls then flow through the exact same pipeline below
  // (disambiguation buttons, composeAnswer, suggestions), so the LLM still
  // does the rephrasing — it just no longer decides intent.
  //
  // Anything the router doesn't recognise falls through to llmTurn untouched,
  // so no phrasing that worked before regresses. See router.ts.
  let routed: LlmToolCall[] | null = null;
  try {
    routed = await routeToToolCalls(input);
  } catch (e) {
    logger.warn("agent.router_failed", { err: String(e) });
  }

  const turn = routed
    ? { text: "", tool_calls: routed, model: "deterministic-router" }
    : await llmTurn({
        keys: input.keys,
        role: input.role,
        language: input.language,
        text: input.text,
        candidates: input.candidates,
        history: input.history?.slice(-6), // keep recent context, save tokens
      });

  const pending: PendingAction[] = [];
  const records: ToolCallRecord[] = [];
  const readResults: { tool: string; result: unknown }[] = [];
  let clarification: Clarification | undefined;
  let dbSlow = false;
  let data: unknown;

  for (const call of turn.tool_calls) {
    // Role gate — server-side, never trust the model.
    if (GARDENER_ONLY.has(call.name) && input.role === "visitor") {
      records.push({ tool: call.name, params: call.arguments, result: "denied" });
      continue;
    }

    if (WRITE_TOOLS.has(call.name)) {
      let outcome: PendingOutcome;
      try {
        outcome = await buildPendingAction(call, input);
      } catch (e) {
        // A slow/flaky garden API must not crash the turn — degrade gracefully.
        logger.error("agent.build_pending_failed", { tool: call.name, err: String(e) });
        dbSlow = true;
        records.push({ tool: call.name, params: call.arguments, result: "unknown_tool" });
        continue;
      }
      if (outcome.kind === "pending") {
        await storePending(input.uid, outcome.pending); // survives until Save/Cancel tap
        pending.push(outcome.pending);
        records.push({ tool: call.name, params: call.arguments, result: "pending" });
      } else if (outcome.kind === "clarify") {
        clarification = clarification ?? outcome.clarification;
        records.push({ tool: call.name, params: call.arguments, result: "denied" });
      } else {
        records.push({ tool: call.name, params: call.arguments, result: "unknown_tool" });
      }
      continue;
    }

    // READ tools — real SQLite DAL (Phase 4).
    const readResult = await executeRead(call, input);
    if (readResult !== undefined) {
      data = readResult;
      readResults.push({ tool: call.name, result: readResult });
    }
    records.push({
      tool: call.name,
      params: call.arguments,
      result: readResult !== undefined ? "executed" : "unknown_tool",
    });
  }

  // A name that matched several SPECIES → "did you mean ...?" species buttons.
  if (!clarification) {
    const sc = readResults.find((r) => ((r.result as any)?.species_choices?.length ?? 0) > 0);
    if (sc) {
      const names = (sc.result as any).species_choices as string[];
      clarification = {
        kind: "did_you_mean",
        question: didYouMeanQuestion(input.language),
        options: names.map((nm) => ({ label: nm, send_text: `I am talking about ${nm}` })),
        allow_free_text: true,
      };
    }
  }

  // ANY read that matched MANY physical plants → section disambiguation buttons.
  if (!clarification) {
    const multi = readResults.find(
      (r) => ((r.result as any)?.count ?? 0) > 1 && (r.result as any)?.matches
    );
    if (multi) {
      const matches = (multi.result as any).matches as dal.PlantInstance[];
      clarification = disambiguation(matches[0].scientific_name, matches.slice(0, 8), input.language);
    }
  }

  // Any read that found nothing but produced fuzzy suggestions becomes a
  // "did you mean" clarification (buttons of the closest real names).
  if (!clarification) {
    const fp = readResults.find((r) => ((r.result as any)?.suggestions?.length ?? 0) > 0);
    if (fp) {
      const sugg = (fp.result as any).suggestions as { scientific_name: string }[];
      clarification = {
        kind: "did_you_mean",
        question: didYouMeanQuestion(input.language),
        options: sugg
          .slice(0, 4)
          .map((s) => ({ label: s.scientific_name, send_text: `I am talking about ${s.scientific_name}` })),
        allow_free_text: true,
      };
    }
  }

  // Second round-trip: read tools produced data → let the LLM compose the
  // actual answer from it. Skip when we're asking a clarification.
  let composed = "";
  if (readResults.length > 0 && !clarification) {
    composed = await composeAnswer({
      keys: input.keys,
      language: input.language,
      userText: input.text,
      toolResults: readResults,
    });
  }

  const dbSlowMsg =
    input.language === "fi"
      ? "Puutarhan tietokanta on juuri nyt hidas. Yritä hetken kuluttua uudelleen."
      : input.language === "sv"
        ? "Trädgårdens databas är långsam just nu. Försök igen om en stund."
        : "The garden database is slow right now. Please try again in a moment.";

  const reply =
    (clarification ? clarification.question : "") ||
    composed ||
    turn.text.trim() ||
    (pending.length
      ? pending.map((p) => p.preview).join("\n")
      : dbSlow
        ? dbSlowMsg
        : fallbackReply(input.language));

  const suggestions = buildSuggestions({
    role: input.role,
    lang: input.language,
    readResults,
    hasClarification: !!clarification,
    hasPending: pending.length > 0,
  });

  logger.info("agent.dispatch", {
    model: turn.model,
    toolCalls: records.length,
    pendings: pending.length,
    clarify: clarification?.kind ?? null,
  });

  return {
    reply,
    data,
    pending_actions: pending.length ? pending : undefined,
    clarification,
    suggestions,
    tool_calls: records,
    llm_model: turn.model,
  };
}

// ─── Contextual follow-up suggestions (tap-to-send quick replies) ───────────

/** Pulls the plant in focus from the reads, if any, so suggestions can name it. */
/**
 * Turn a pattern-matched intent into the tool calls the read pipeline already
 * understands. Returns null to mean "not confident — let the LLM decide", which
 * is what keeps this safe to add incrementally.
 */
async function routeToToolCalls(input: DispatchInput): Promise<LlmToolCall[] | null> {
  const route = routeRead(input.text);
  if (route.intent === "unknown") return null;

  // Staff-only intents: let visitors fall through so the LLM path's role gate
  // produces the normal refusal instead of an empty routed turn.
  const isStaff = input.role !== "visitor";

  if (route.intent === "overdue") {
    if (!isStaff) return null;
    return [
      {
        name: "find_overdue_inspections",
        arguments: {
          ...(route.days ? { days_threshold: route.days } : {}),
          ...(route.sectionCode ? { section_code: route.sectionCode } : {}),
        },
      },
    ];
  }

  if (!route.plantQuery) return null;

  // History needs a specific plant. Resolve the name first: exactly one
  // physical plant means we can answer now; several means hand the name to
  // query_plant_details, whose existing post-loop turns the matches into
  // section buttons.
  if (route.intent === "plant_history" && isStaff) {
    const instances = await dal.findPlantInstances(route.plantQuery, route.sectionCode);
    if (instances.length === 1) {
      return [
        {
          name: "query_plant_history",
          arguments: {
            hankintaID: instances[0].hankintaID,
            ...(route.days ? { days_back: route.days } : {}),
          },
        },
      ];
    }
    if (instances.length === 0) return null; // let the LLM path offer suggestions
  }

  // info / status / location / ambiguous-history all resolve through the same
  // read, which already returns placements (location) and, for staff, the
  // maintenance fields. composeAnswer receives the user's actual question, so
  // one query answers all four phrasings.
  return [
    {
      name: "query_plant_details",
      arguments: {
        name_query: route.plantQuery,
        ...(route.sectionCode ? { section_code: route.sectionCode } : {}),
      },
    },
  ];
}

function subjectName(readResults: { tool: string; result: unknown }[]): string | undefined {
  for (const r of readResults) {
    const res = r.result as any;
    if (r.tool === "query_plant_details" && res?.scientific_name) return res.scientific_name;
    if (r.tool === "find_plant" && res?.count === 1 && res?.matches?.[0]?.scientific_name) {
      return res.matches[0].scientific_name;
    }
  }
  return undefined;
}

/** Strictly-contextual quick replies. Empty when chips/a card already need a tap. */
function buildSuggestions(opts: {
  role: Role;
  lang: "en" | "fi" | "sv";
  readResults: { tool: string; result: unknown }[];
  hasClarification: boolean;
  hasPending: boolean;
}): string[] {
  if (opts.hasClarification || opts.hasPending) return []; // already actionable
  const gardener = opts.role === "gardener" || opts.role === "admin";
  const n = subjectName(opts.readResults);
  const L = opts.lang;

  const t = (en: string, fi: string, sv: string) => (L === "fi" ? fi : L === "sv" ? sv : en);

  if (n) {
    if (gardener) {
      return [
        t(`Does ${n} need attention?`, `Tarvitseeko ${n} huomiota?`, `Behöver ${n} uppmärksamhet?`),
        t(`Show ${n}'s history`, `Näytä ${n} historia`, `Visa historiken för ${n}`),
        t(`Mark ${n} watered`, `Merkitse ${n} kastelluksi`, `Markera ${n} som vattnad`),
      ];
    }
    return [
      t(`Where is ${n}?`, `Missä ${n} on?`, `Var finns ${n}?`),
      t(`What is ${n} used for?`, `Mihin ${n} käytetään?`, `Vad används ${n} till?`),
    ];
  }
  // No plant in focus → starters.
  if (gardener) {
    return [
      t("What needs attention?", "Mikä tarvitsee huomiota?", "Vad behöver uppmärksamhet?"),
      t("Find a plant", "Etsi kasvi", "Hitta en växt"),
      t("Record an action", "Kirjaa toimenpide", "Registrera en åtgärd"),
    ];
  }
  return [
    t("Find a plant", "Etsi kasvi", "Hitta en växt"),
    t("Plan a 30-minute tour", "Suunnittele 30 min kierros", "Planera en 30-min rundtur"),
  ];
}

function didYouMeanQuestion(lang: string): string {
  return lang === "fi"
    ? "En löytänyt tarkkaa osumaa. Tarkoititko jotakin näistä?"
    : lang === "sv"
      ? "Hittade ingen exakt träff. Menade du någon av dessa?"
      : "I couldn't find an exact match. Did you mean one of these?";
}

// ─── Pending-action builder ─────────────────────────────────────────────────

type PendingOutcome =
  | { kind: "pending"; pending: PendingAction }
  | { kind: "clarify"; clarification: Clarification }
  | { kind: "reject" };

/** Builds a disambiguation clarification (buttons per physical plant). */
function disambiguation(name: string, instances: dal.PlantInstance[], lang: string): Clarification {
  // One short button per DISTINCT section (e.g. "G-HA"); clean and quick to tap.
  // If a section holds several plants we keep the first; the confirmation card
  // still shows the exact plant before any write.
  const seen = new Set<string>();
  const options: ClarOption[] = [];
  for (const i of instances) {
    const key = i.section_code ? dal.normalizeSection(i.section_code) : `ID${i.hankintaID}`;
    if (seen.has(key)) continue;
    seen.add(key);
    options.push({
      label: i.section_code
        ? `${i.section_code}${i.status ? ` (${i.status})` : ""}`
        : `#${i.hankintaID}`,
      send_text: `I am talking about ${name} from section ${i.section_code ?? `id ${i.hankintaID}`}`,
      hankintaID: i.hankintaID,
    });
  }
  const n = options.length;
  const head =
    lang === "fi"
      ? `"${name}" löytyy ${n} osastosta. Mitä tarkoitat? (voit myös kirjoittaa osaston, esim. g-ha)`
      : lang === "sv"
        ? `"${name}" finns i ${n} sektioner. Vilken menar du? (du kan också skriva sektionen, t.ex. g-ha)`
        : `"${name}" is in ${n} sections. Which one? (you can also type the section, e.g. g-ha)`;
  return { kind: "disambiguation", question: head, options, allow_free_text: true };
}

async function buildPendingAction(
  call: LlmToolCall,
  input: DispatchInput
): Promise<PendingOutcome> {
  const a = { ...call.arguments };

  // ── Resolve which physical plant this write targets ──
  let hankintaID = 0;
  let verified: { taksonin_nro: number; scientific_name: string } | null = null;
  let pinned = false;

  const explicitId = Number(a.hankintaID);
  if (Number.isInteger(explicitId) && explicitId > 0) {
    hankintaID = explicitId;
  } else if (input.scannedHankintaID) {
    hankintaID = input.scannedHankintaID;
    pinned = true; // user scanned / tapped a specific plant
  }

  if (hankintaID) {
    verified = await dal.verifyPlant(hankintaID);
    if (!verified) {
      logger.warn("agent.pending_rejected_unknown_plant", { hankintaID });
      return { kind: "reject" };
    }
    if (!pinned) {
      // Unambiguous only if location-resolved candidates already narrowed this
      // taxon to exactly this plant; otherwise ask which one.
      const sameTaxon = input.candidates.filter((c) => c.taksonin_nro === verified!.taksonin_nro);
      pinned = sameTaxon.length === 1 && sameTaxon[0].hankintaID === hankintaID;
      if (!pinned) {
        const instances = await dal.plantInstances(verified.taksonin_nro);
        if (instances.length > 1) {
          await storeIntent(input.uid, { tool: call.name, args: a });
          return { kind: "clarify", clarification: disambiguation(verified.scientific_name, instances.slice(0, 8), input.language) };
        }
      }
    }
  } else {
    // No id — resolve by the name the user spoke (+ optional section).
    const nameQ = typeof a.name_query === "string" ? a.name_query.trim() : "";
    if (!nameQ) {
      logger.warn("agent.pending_rejected_no_id_or_name", { args: a });
      return { kind: "reject" };
    }
    const section = typeof a.section_code === "string" ? a.section_code : undefined;
    const instances = await dal.findPlantInstances(nameQ, section);
    if (instances.length === 0) {
      const suggestions = await dal.suggestSimilarPlants(nameQ);
      if (suggestions.length) {
        return {
          kind: "clarify",
          clarification: {
            kind: "did_you_mean",
            question: didYouMeanQuestion(input.language),
            options: suggestions.slice(0, 4).map((s) => ({ label: s.scientific_name, send_text: s.scientific_name })),
            allow_free_text: true,
          },
        };
      }
      return { kind: "reject" };
    }
    if (instances.length === 1) {
      hankintaID = instances[0].hankintaID;
      verified = { taksonin_nro: instances[0].taksonin_nro, scientific_name: instances[0].scientific_name };
      pinned = true; // the name (+ section) uniquely identified it
    } else {
      // Several physical plants → ask which, stashing the action to complete on tap.
      await storeIntent(input.uid, { tool: call.name, args: a });
      return { kind: "clarify", clarification: disambiguation(instances[0].scientific_name, instances.slice(0, 8), input.language) };
    }
  }

  const name = verified!.scientific_name;
  const date = (a.date as string) || new Date().toISOString().slice(0, 10);
  a.date = date;

  // Pre-compose the stocktake string for observations (stars + kpl + ...).
  if (call.name === "record_observation") {
    const stars = "*".repeat(Math.min(3, Math.max(1, Number(a.condition_stars) || 0)));
    const segs: string[] = [];
    if (a.condition_stars) segs.push(stars);
    if (a.living_count) segs.push(`${a.living_count} kpl`);
    if (a.size) segs.push(String(a.size));
    if (a.status) segs.push(String(a.status));
    if (a.notes) segs.push(String(a.notes));
    a.composed_stocktake = segs.join(", ");
  }

  // Build the SAFE write plan now so the user sees the exact operation + a
  // detailed diff before confirming. This validates everything; on any safety
  // failure we reject rather than show something unsafe.
  let plan: WritePlan;
  try {
    plan = buildPlan(call.name, a, {
      inspectorCode: input.inspectorCode ?? "",
      plantName: name,
      placementNro: await dal.latestPlacementNro(hankintaID),
    });
  } catch (e) {
    if (e instanceof SafetyError) {
      logger.warn("agent.plan_rejected", { tool: call.name, err: e.message });
      return { kind: "reject" };
    }
    throw e;
  }

  return {
    kind: "pending",
    pending: {
      pending_id: randomUUID(),
      tool: call.name,
      params: { ...a, _plan: plan }, // plan persisted for the confirm step
      preview: plan.summary,
      requires_confirmation: true,
      sql_display: plan.displaySql,
      changes: plan.changes,
    },
  };
}

// ─── Real reads (SQLite DAL + Firestore ledger merge) ───────────────────────

/** Fields visitors must never see, stripped from plant details server-side. */
function stripForVisitor(details: any): any {
  if (!details) return details;
  const safe = { ...details };
  if (safe.cultivation) {
    const c = { ...safe.cultivation };
    delete c.pests_and_diseases;
    delete c.toxicity;
    safe.cultivation = c;
  }
  if (Array.isArray(safe.placements)) {
    safe.placements = safe.placements.map((p: any) => {
      const q = { ...p };
      delete q.status; // plant health is staff-only
      return q;
    });
  }
  return safe;
}

async function executeRead(call: LlmToolCall, input: DispatchInput): Promise<unknown> {
  const a = call.arguments;
  try {
    switch (call.name) {
      case "query_plant_details": {
        // Resolve which plant. Prefer an explicit id (incl. a tapped button via
        // scanned context); otherwise resolve the NAME and hand ambiguity to the
        // post-loop as buttons (species choices, or sections).
        let hid = Number(a.hankintaID) || input.scannedHankintaID || 0;
        let resolvedTaxon: number | undefined;
        const nq = a.name_query as string | undefined;
        if (!hid && nq) {
          const taxa = await dal.searchTaxa(nq, 8);
          if (taxa.length === 0) {
            return { error: "Plant not found.", suggestions: await dal.suggestSimilarPlants(nq) };
          }
          // An EXACT name match resolves immediately (so tapping "Coffea arabica"
          // doesn't keep matching its own cultivars and loop forever).
          const exact = taxa.find(
            (t) => t.scientific_name.toLowerCase() === nq.trim().toLowerCase()
          );
          if (!exact && taxa.length > 1) {
            // Name matched several distinct species -> "did you mean ...?" buttons.
            return { species_choices: taxa.map((t) => t.scientific_name).slice(0, 6) };
          }
          const chosen = exact ?? taxa[0];
          resolvedTaxon = chosen.taksonin_nro;
          // Distinct PHYSICAL PLANTS (acquisitions) of this species. If there is
          // more than one, ask which — each plant can have its own status and
          // history. A single plant with several placements is NOT disambiguated
          // (that's just its location history, handled as info, not a choice).
          let instances = await dal.plantInstances(chosen.taksonin_nro);
          const wantSec = a.section_code ? dal.normalizeSection(a.section_code as string) : "";
          if (wantSec) instances = instances.filter((i) => dal.normalizeSection(i.section_code) === wantSec);
          if (instances.length > 1) {
            const vis = input.role === "visitor";
            return {
              count: instances.length,
              matches: instances.map((i) =>
                vis
                  ? { hankintaID: i.hankintaID, scientific_name: i.scientific_name, section_code: i.section_code, location_label: i.location_label }
                  : i
              ),
            };
          }
          if (instances.length >= 1) hid = instances[0].hankintaID;
        }
        const details = await dal.plantDetails({
          hankintaID: hid || undefined,
          taksonin_nro: hid ? undefined : (a.taksonin_nro as number | undefined) ?? resolvedTaxon,
          name_query: hid || resolvedTaxon ? undefined : nq,
        });
        if (!details) {
          const suggestions = nq ? await dal.suggestSimilarPlants(nq) : [];
          return { error: "Plant not found.", suggestions };
        }
        return input.role === "visitor" ? stripForVisitor(details) : details;
      }
      case "find_plant": {
        const query = String(a.name_query ?? "");
        const instances = await dal.findPlantInstances(
          query,
          a.section_code as string | undefined
        );
        const vis = input.role === "visitor";
        if (instances.length === 0) {
          // Typo tolerance: offer the closest real names as "did you mean".
          const suggestions = await dal.suggestSimilarPlants(query);
          return { count: 0, matches: [], suggestions };
        }
        return {
          count: instances.length,
          matches: instances.map((i) =>
            vis
              ? {
                  hankintaID: i.hankintaID,
                  scientific_name: i.scientific_name,
                  section_code: i.section_code,
                  location_label: i.location_label,
                }
              : i
          ),
        };
      }
      case "query_plant_history": {
        if (input.role === "visitor") return undefined; // role-gated, belt+braces
        const id = Number(a.hankintaID);
        const legacy = await dal.plantHistory(id, Number(a.days_back) || 36500);
        const agentRows = await ledgerHistory(id);
        const merged = [...agentRows, ...legacy].sort((x, y) =>
          y.date > x.date ? 1 : -1
        );
        // Grounded assessment so "what next / needs attention" is data-driven.
        const daysSince = (d?: string): number | null => {
          if (!d) return null;
          const t = Date.parse(d);
          return Number.isNaN(t) ? null : Math.floor((Date.now() - t) / 86400_000);
        };
        const lastAction = merged.find((m) => m.kind === "action");
        const lastInsp = merged.find((m) => m.kind === "inspection");
        return {
          history: merged.slice(0, 50),
          assessment: {
            has_records: merged.length > 0,
            last_action_date: lastAction?.date ?? null,
            last_inspection_date: lastInsp?.date ?? null,
            days_since_last_action: daysSince(lastAction?.date),
            days_since_last_inspection: daysSince(lastInsp?.date),
          },
        };
      }
      case "find_overdue_inspections": {
        if (input.role === "visitor") return undefined;
        return {
          overdue: await dal.overdueInspections(
            Number(a.days_threshold) || 365,
            a.section_code as string | undefined
          ),
        };
      }
      case "navigate_to_plant": {
        const id = Number(a.hankintaID);
        const details = await dal.plantDetails({ hankintaID: id });
        const placement = details?.placements?.[0];
        if (!placement) return { error: "No location on record for this plant." };
        const indoor = String(placement.section_code ?? "").startsWith("G-H");
        return {
          type: indoor ? "indoor" : "outdoor",
          section_code: placement.section_code,
          section_name: placement.section_name,
          location_label: placement.location,
        };
      }
      case "plan_tour":
        return { stops: [], note: "tour planning arrives in Phase 6" };
      default:
        return undefined;
    }
  } catch (e) {
    logger.error("agent.read_failed", { tool: call.name, err: String(e) });
    return { error: "Lookup failed — try again." };
  }
}

function fallbackReply(lang: string): string {
  switch (lang) {
    case "fi":
      return "En ymmärtänyt. Voitko tarkentaa tai skannata kasvin etiketin?";
    case "sv":
      return "Jag förstod inte. Kan du förtydliga eller skanna växtens etikett?";
    default:
      return "I didn't catch that. Could you clarify, or scan the plant's label?";
  }
}

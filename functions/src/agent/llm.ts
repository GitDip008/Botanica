/**
 * LLM layer — Groq (free) primary with tool calling, Gemini Flash fallback.
 *
 * The tool schemas here mirror agent_assets/agent_tools.json but in the
 * OpenAI function-calling format Groq expects. The system prompt encodes the
 * REAL garden conventions discovered in Phase 0:
 *   - Action vocabulary: KYLVÖ / IT. / KOULINTA / IST. / SIIRTO / KUOLLUT...
 *   - Stocktake format: stars + kpl + size + status + notes
 *   - Location prefix system: G-H*, T-x.y.z, K-n, beds n/m
 */

import { logger } from "firebase-functions/v2";
import type { Role } from "./roles";
import type { PlantCandidate } from "./resolver";

// Secrets are injected by the caller (index.ts binds them).
export interface LlmKeys {
  groq: string;
  gemini: string;
}

export interface LlmToolCall {
  name: string;
  arguments: Record<string, unknown>;
}

export interface LlmTurn {
  /** Natural-language reply (may be empty if only tool calls). */
  text: string;
  tool_calls: LlmToolCall[];
  model: string;
}

// ─── Tool schemas (OpenAI function format) ──────────────────────────────────

// NOTE on schema style:
//  - All numeric IDs are typed as STRING and coerced server-side. Groq
//    validates the model's tool calls against the schema and 400s the whole
//    request if the model emits "4421" where an integer was declared —
//    string + server-side coercion kills that failure class entirely.
//  - No `default` keys: Gemini's function-calling API rejects them.
const GARDENER_TOOLS = [
  {
    type: "function",
    function: {
      name: "record_action",
      description:
        "Log a propagation/maintenance action on a plant: sowing (KYLVÖ), germination (IT.), pricking out (KOULINTA), planting out (IST.), transfer (SIIRTO), cuttings (PISTETTY), died (KUOLLUT), removed (POIST.), sold (MYYTY), or other. Identify the plant by name_query (+ section_code if the user gave one) — you do NOT need an id. Use hankintaID only if it came from a scan or the candidate list.",
      parameters: {
        type: "object",
        properties: {
          name_query: { type: "string", description: "Plant name the user said (preferred way to identify the plant)" },
          section_code: { type: "string", description: "Section the user named, e.g. 'G-HA' or 'X-TA' — narrows which plant" },
          hankintaID: { type: "string", description: "Plant instance id, ONLY if known from a scan/candidate list, as a string e.g. '4421'" },
          action_family: {
            type: "string",
            enum: ["KYLVÖ", "IT.", "KOULINTA", "IST.", "SIIRTO", "PISTETTY", "KUOLLUT", "POIST.", "MYYTY", "MUU"],
          },
          location_code: { type: "string", description: "Target location for IST./SIIRTO, e.g. 'T-4.1.3' or 'G-HA'" },
          from_location: { type: "string", description: "Source location for SIIRTO" },
          count: { type: "string", description: "Number of individuals (kpl) if mentioned, as a string e.g. '3'" },
          details: { type: "string", description: "Any extra detail in the gardener's own words (Finnish ok)" },
          date: { type: "string", description: "ISO date YYYY-MM-DD, omit for today" },
        },
        required: ["action_family"],
      },
    },
  },
  {
    type: "function",
    function: {
      name: "record_observation",
      description:
        "Log a stocktake/inspection observation. Identify the plant by name_query (+ section_code if given) — no id needed. Format follows garden convention: condition stars (* poor / ** moderate / *** good), count in kpl, size, status (kukkii=blooming etc.), free notes.",
      parameters: {
        type: "object",
        properties: {
          name_query: { type: "string", description: "Plant name the user said (preferred way to identify the plant)" },
          section_code: { type: "string", description: "Section the user named, e.g. 'G-HA' — narrows which plant" },
          hankintaID: { type: "string", description: "Plant instance id, ONLY if known from a scan/candidate list" },
          condition_stars: { type: "string", enum: ["1", "2", "3"], description: "1=poor, 2=moderate, 3=good" },
          living_count: { type: "string", description: "How many individuals alive (kpl), as a string" },
          size: { type: "string", description: "e.g. '2-4 m' or '30 cm'" },
          status: { type: "string", description: "e.g. 'kukkii' (blooming), 'nuppu' (budding), 'siemenet'" },
          notes: { type: "string", description: "Free notes in the gardener's words" },
          date: { type: "string", description: "ISO date, omit for today" },
        },
        required: [],
      },
    },
  },
  {
    type: "function",
    function: {
      name: "query_plant_history",
      description: "Get recent actions and inspections for a plant. days_back defaults to 365 when omitted.",
      parameters: {
        type: "object",
        properties: {
          hankintaID: { type: "string" },
          days_back: { type: "string" },
        },
        required: ["hankintaID"],
      },
    },
  },
  {
    type: "function",
    function: {
      name: "find_overdue_inspections",
      description: "List plants that haven't been inspected in N days (default 365), optionally within one section.",
      parameters: {
        type: "object",
        properties: {
          days_threshold: { type: "string" },
          section_code: { type: "string" },
        },
      },
    },
  },
] as const;

// Available to everyone — the entry point for naming a plant when no QR/location
// signal is present. Returns every matching physical plant (per acquisition) so
// the SPECIFIC one can be chosen.
const SHARED_TOOLS = [
  {
    type: "function",
    function: {
      name: "find_plant",
      description:
        "Find physical plants by name. Returns one entry PER PLANT (hankintaID) with its section and location — the same species can exist as several separate plants in different sections. Use this to identify which exact plant the user means before reading history or recording anything.",
      parameters: {
        type: "object",
        properties: {
          name_query: { type: "string", description: "Scientific or common plant name spoken by the user" },
          section_code: { type: "string", description: "Optional section filter, e.g. 'G-HA' or 'T-4.1.3'" },
        },
        required: ["name_query"],
      },
    },
  },
] as const;

const VISITOR_TOOLS = [
  {
    type: "function",
    function: {
      name: "query_plant_details",
      description: "Get public information about a plant (name, family, description, uses, location).",
      parameters: {
        type: "object",
        properties: {
          hankintaID: { type: "string" },
          taksonin_nro: { type: "string" },
          name_query: { type: "string", description: "Plant name to search if no id known" },
        },
      },
    },
  },
  {
    type: "function",
    function: {
      name: "navigate_to_plant",
      description: "Where is this plant and how do I get there.",
      parameters: {
        type: "object",
        properties: { hankintaID: { type: "string" } },
        required: ["hankintaID"],
      },
    },
  },
  {
    type: "function",
    function: {
      name: "plan_tour",
      description: "Build a personalized garden tour from a time budget and interests.",
      parameters: {
        type: "object",
        properties: {
          duration_minutes: { type: "string" },
          interests: { type: "array", items: { type: "string" } },
        },
        required: ["duration_minutes"],
      },
    },
  },
] as const;

function toolsForRole(role: Role) {
  if (role === "gardener" || role === "admin") {
    return [...GARDENER_TOOLS, ...VISITOR_TOOLS, ...SHARED_TOOLS];
  }
  return [...VISITOR_TOOLS, ...SHARED_TOOLS];
}

// ─── System prompt ──────────────────────────────────────────────────────────

function systemPrompt(role: Role, language: string, candidates: PlantCandidate[]): string {
  const candidateBlock = candidates.length
    ? `CANDIDATE PLANTS (the user is near these — NEVER use a hankintaID not in this list):\n${candidates
        .map(
          (c) =>
            `- hankintaID=${c.hankintaID}: ${c.scientific_name}` +
            (c.common_name_fi ? ` (fi: ${c.common_name_fi})` : "") +
            (c.common_name_en ? ` (en: ${c.common_name_en})` : "") +
            (c.location_label ? ` @ ${c.location_label}` : "")
        )
        .join("\n")}`
    : "NO pre-resolved candidate plants (the user gave no scan/location signal). That is FINE — to record an action/observation, call record_action/record_observation with name_query set to the plant the user named. To answer a 'where/which' question, call find_plant. Never refuse for lack of an id, and never invent a hankintaID.";

  const base =
    role === "visitor"
      ? `You are the Botanica Garden Assistant for a VISITOR at Oulu Botanical Garden. Help them find plants, learn about species, plan tours. NEVER reveal maintenance history, pest issues, plant health status or staff notes. Reply in language "${language}". Be warm and brief.`
      : `You are the Botanica Garden Assistant for a GARDENER at Oulu Botanical Garden. Parse their speech into structured records. Reply in language "${language}". Be terse and precise.

GARDEN CONVENTIONS you must follow:
- Actions use legacy Finnish codes: KYLVÖ (sow), IT. (germinated), KOULINTA (prick out), IST. (plant out), SIIRTO (transfer), PISTETTY (cuttings), KUOLLUT (died), POIST. (removed), MYYTY (sold).
- Stocktake/inspection format: condition stars first (* poor, ** moderate, *** good), then count "N kpl", then size, then status words (kukkii=blooming), then free notes. Example: "*** 3 kpl, 2-4 m, kukkii, ovat liian tiheässä".
- Locations use codes: G-H? = greenhouse cells, T-x.y.z = field plots, K-n, X-*, or bed numbers like "6/ 1".
- If the gardener mentions BOTH an action and an observation in one utterance, emit BOTH tool calls.
- Counts: "kpl" = pieces/individuals, "mätäs/mät." = clump.

IDENTIFYING THE RIGHT PLANT (critical):
- Every physical plant has its own hankintaID. The SAME species can exist as MANY separate plants in different sections. An update to one must never be applied to another.
- To RECORD an action/observation: call record_action / record_observation directly, passing name_query (the plant the user said) and section_code if they named one. Do NOT call find_plant first, and do NOT ask which plant yourself — the app resolves the name and, if several plants match, shows the gardener a picker automatically. Just make the record_* call.
- Only use a hankintaID if it is already in the candidate list or came from a scan. NEVER invent one.
- Example: user says "mark Helianthus annuus as watered" → call record_action with name_query="Helianthus annuus", action_family="MUU", details="watered".

GROUNDING (strict — never invent facts):
- For "what's the latest", "what next", "does it need attention", FIRST call query_plant_history (gardener) or query_plant_details, and base every statement ONLY on the returned records.
- If the records show nothing for that plant, say plainly that the database has no records for it, THEN you may add brief GENERAL gardening guidance — but clearly label it as general advice, not from the garden's data.`;

  return `${base}\n\n${candidateBlock}\n\nCONVERSATION CONTEXT: Earlier turns are provided for reference (e.g. resolving "that one", "the X-TA one", or a plant named a moment ago). ACT ONLY on the user's LATEST message. Use history only to fill in references — never re-execute an older request, and never invent context that isn't there.\nEXCEPTION: if your OWN previous turn asked the user to choose or clarify (e.g. "which plant?" / "did you mean?"), the user's latest reply COMPLETES that original request — carry out the originally-requested action on the now-identified plant (use the hankintaID from the candidate list above). If the latest message is still ambiguous, ask again.\n\nFor any write action, your text reply must be a one-sentence summary of what will be saved (the app shows it as a confirmation card). Do not claim anything was saved yet.`;
}

// ─── Groq call ──────────────────────────────────────────────────────────────

export async function llmTurn(opts: {
  keys: LlmKeys;
  role: Role;
  language: string;
  text: string;
  candidates: PlantCandidate[];
  history?: { role: "user" | "assistant"; content: string }[];
}): Promise<LlmTurn> {
  const messages = [
    { role: "system", content: systemPrompt(opts.role, opts.language, opts.candidates) },
    ...(opts.history ?? []),
    { role: "user", content: opts.text },
  ];
  const tools = toolsForRole(opts.role);

  // 1) Groq — try the high-quality 70B first; if its DAILY token cap is hit
  //    (429) fall back to 8B-instant, which has a separate, much larger quota.
  const groqModels = ["llama-3.3-70b-versatile", "llama-3.1-8b-instant"];
  for (const model of groqModels) {
    try {
      const r = await fetch("https://api.groq.com/openai/v1/chat/completions", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${opts.keys.groq}`,
        },
        body: JSON.stringify({
          model,
          messages,
          tools,
          tool_choice: "auto",
          temperature: 0.2,
          max_tokens: 700,
        }),
      });
      if (r.ok) {
        const data = (await r.json()) as any;
        const msg = data.choices?.[0]?.message;
        return {
          text: (msg?.content as string) ?? "",
          tool_calls: parseOpenAiToolCalls(msg?.tool_calls),
          model: `groq/${model}`,
        };
      }
      logger.warn("agent.groq_http_error", {
        model,
        status: r.status,
        body: (await r.text()).slice(0, 200),
      });
      // Non-quota errors won't be fixed by switching model — stop trying Groq.
      if (r.status !== 429) break;
    } catch (e) {
      logger.warn("agent.groq_failed", { model, err: String(e) });
    }
  }

  // 2) Gemini fallback — function calling via the generateContent API
  try {
    const url = `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=${opts.keys.gemini}`;
    const r = await fetch(url, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        system_instruction: { parts: [{ text: messages[0].content }] },
        contents: messages
          .slice(1)
          .map((m) => ({ role: m.role === "assistant" ? "model" : "user", parts: [{ text: m.content }] })),
        tools: [
          {
            functionDeclarations: tools.map((t) => ({
              name: t.function.name,
              description: t.function.description,
              parameters: t.function.parameters,
            })),
          },
        ],
        generationConfig: { temperature: 0.2, maxOutputTokens: 700 },
      }),
    });
    if (!r.ok) throw new Error(`Gemini HTTP ${r.status}`);
    const data = (await r.json()) as any;
    const parts: any[] = data.candidates?.[0]?.content?.parts ?? [];
    const text = parts
      .filter((p) => typeof p.text === "string")
      .map((p) => p.text)
      .join("");
    const tool_calls: LlmToolCall[] = parts
      .filter((p) => p.functionCall)
      .map((p) => ({
        name: p.functionCall.name,
        arguments: coerceNumericArgs(p.functionCall.args ?? {}),
      }));
    return { text, tool_calls, model: "gemini-2.0-flash" };
  } catch (e) {
    logger.error("agent.gemini_failed", { err: String(e) });
    throw new Error("Both LLM providers failed.");
  }
}

/**
 * Second round-trip: given tool results, compose the final natural-language
 * answer. Plain completion, no tools — cheap and fast.
 */
export async function composeAnswer(opts: {
  keys: LlmKeys;
  language: string;
  userText: string;
  toolResults: { tool: string; result: unknown }[];
}): Promise<string> {
  const sys =
    `You are the Botanica Garden Assistant at Oulu Botanical Garden. ` +
    `The user asked a question; tools were executed and their results are below. ` +
    `Answer using ONLY this data — every fact and every care suggestion MUST be grounded in these results. Never invent dates, counts, conditions, or history. ` +
    `If the results contain an "assessment" or history, you may suggest concrete next steps, but ONLY ones justified by that data (e.g. overdue inspection, recorded status). ` +
    `If the results are empty / show no records for the plant, say clearly that the database has no records for it, THEN you may add brief general gardening guidance prefixed exactly with "General guidance (not from garden records): ". ` +
    `If several plants match (a find_plant list with more than one entry), do NOT pick one — list them by section/location and ask which the user means. ` +
    `Be concise (2-6 sentences or a short list). Reply in language "${opts.language}". Dates are ISO format. ` +
    `"kpl" means individuals/pieces. Condition stars: * poor, ** moderate, *** good.`;
  const user =
    `QUESTION: ${opts.userText}\n\nTOOL RESULTS:\n` +
    opts.toolResults
      .map((t) => `[${t.tool}]\n${JSON.stringify(t.result).slice(0, 6000)}`)
      .join("\n\n");

  // Groq first
  try {
    const r = await fetch("https://api.groq.com/openai/v1/chat/completions", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${opts.keys.groq}`,
      },
      body: JSON.stringify({
        // Fast model: this pass only summarises data we already fetched and
        // validated server-side, so the cheaper/quicker model is safe here.
        model: "llama-3.1-8b-instant",
        messages: [
          { role: "system", content: sys },
          { role: "user", content: user },
        ],
        temperature: 0.3,
        max_tokens: 500,
      }),
    });
    if (r.ok) {
      const data = (await r.json()) as any;
      const text = (data.choices?.[0]?.message?.content as string) ?? "";
      if (text.trim()) return text.trim();
    }
  } catch (e) {
    logger.warn("agent.compose_groq_failed", { err: String(e) });
  }

  // Gemini fallback
  try {
    const url = `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=${opts.keys.gemini}`;
    const r = await fetch(url, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        system_instruction: { parts: [{ text: sys }] },
        contents: [{ role: "user", parts: [{ text: user }] }],
        generationConfig: { temperature: 0.3, maxOutputTokens: 500 },
      }),
    });
    if (r.ok) {
      const data = (await r.json()) as any;
      const parts: any[] = data.candidates?.[0]?.content?.parts ?? [];
      const text = parts.map((p) => p.text ?? "").join("").trim();
      if (text) return text;
    }
  } catch (e) {
    logger.warn("agent.compose_gemini_failed", { err: String(e) });
  }
  return "";
}

function parseOpenAiToolCalls(raw: unknown): LlmToolCall[] {
  if (!Array.isArray(raw)) return [];
  const out: LlmToolCall[] = [];
  for (const tc of raw) {
    try {
      const name = tc?.function?.name;
      const args = typeof tc?.function?.arguments === "string"
        ? JSON.parse(tc.function.arguments)
        : tc?.function?.arguments ?? {};
      if (typeof name === "string") out.push({ name, arguments: coerceNumericArgs(args) });
    } catch {
      // malformed single call — skip it, keep the rest
    }
  }
  return out;
}

/**
 * Schemas declare numeric fields as strings (Groq validates the model's
 * output and 400s on type mismatch — string is the lenient choice). Here we
 * coerce them back to numbers before the dispatcher sees them.
 */
const NUMERIC_FIELDS = new Set([
  "hankintaID",
  "taksonin_nro",
  "count",
  "living_count",
  "condition_stars",
  "days_back",
  "days_threshold",
  "duration_minutes",
]);

export function coerceNumericArgs(
  args: Record<string, unknown>
): Record<string, unknown> {
  const out: Record<string, unknown> = { ...args };
  for (const key of NUMERIC_FIELDS) {
    const v = out[key];
    if (typeof v === "string" && v.trim() !== "" && !Number.isNaN(Number(v))) {
      out[key] = Number(v);
    }
  }
  return out;
}

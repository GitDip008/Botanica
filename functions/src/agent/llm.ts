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
  const cands = candidates.length
    ? `Nearby plants (use these hankintaIDs):\n${candidates
        .slice(0, 10)
        .map((c) => `- ${c.hankintaID}: ${c.scientific_name}${c.location_label ? ` @ ${c.location_label}` : ""}`)
        .join("\n")}`
    : `No nearby plants resolved — identify plants by name_query.`;

  const base =
    role === "visitor"
      ? `You are the Botanica assistant for a VISITOR at Oulu Botanical Garden. Help find plants, learn about species, plan tours. Never reveal maintenance history, health status, pests or staff notes. Reply in "${language}", warm and brief.`
      : `You are the Botanica assistant for a GARDENER at Oulu Botanical Garden. Reply in "${language}", terse and precise.
Action codes: KYLVÖ=sow, IT.=germinated, KOULINTA=prick out, IST.=plant out, SIIRTO=transfer, PISTETTY=cuttings, KUOLLUT=died, POIST.=removed, MYYTY=sold.
Stocktake: stars (*/**/***), "N kpl", size, status (kukkii=blooming), notes.
To record: call record_action/record_observation with name_query (+ section_code if said). The app resolves the name and shows a picker if several match — never ask which plant yourself.
For history / "needs attention": call query_plant_history first and use ONLY returned data; if none, say so, then optional general advice clearly labelled as general.`;

  return `${base}

${cands}

For ANY plant the user names, you MUST call a tool (query_plant_details or find_plant for questions; record_* for updates). Never say a plant does not exist, and never list a plant's locations or details, from memory — call the tool; the app turns multiple matches into buttons, so do not list options as text.
Act on the user's LATEST message; use earlier turns only to resolve references ("that one") or to complete a choice you just asked for. For writes, reply with a one-sentence summary of what will be saved; do not claim it is saved yet.`;
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
  // Each Groq model has its OWN separate daily token quota, so listing several
  // multiplies the free headroom: when one is exhausted (or emits a malformed
  // tool call), we fall through to the next. Ordered best -> lightest.
  // 2026-08-18: Groq removed every Llama model from this account overnight —
  // llama-3.3-70b-versatile and llama-3.1-8b-instant both return 404
  // "model_not_found". These are the tool-calling models the account actually
  // has. Verify with:
  //   curl -H "Authorization: Bearer $GROQ_API_KEY" \
  //        https://api.groq.com/openai/v1/models
  // before assuming a 404 here is a bug in our code.
  const groqModels = [
    "openai/gpt-oss-120b",
    "openai/gpt-oss-20b",
    "qwen/qwen3.6-27b",
  ];
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
      // Only auth errors are unfixable by switching model. Quota (429) AND the
      // occasional malformed tool-call (400 tool_use_failed) are often resolved
      // by retrying on the other model, so keep going.
      if (r.status === 401 || r.status === 403) break;
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
    `When the user asks ABOUT a plant (e.g. "tell me about X"), present its details and the section(s) it is found in as plain STATEMENTS. Do NOT ask the user to choose a location or which plant — if a real choice is needed the app shows buttons separately; your job here is just to give the information. ` +
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
        model: "openai/gpt-oss-20b",
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

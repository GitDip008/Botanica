/**
 * Deterministic intent router.
 *
 * WHY THIS EXISTS
 * Until now the LLM chose which tool to call on every turn. That is the step
 * that misfires: asked "what's the status of the Cacao", a 70B model would
 * sometimes call find_plant, sometimes query_plant_details, sometimes answer
 * from memory, and on a bad day substring-match a cultivar and loop. The data
 * layer was never the problem — tool *selection* was.
 *
 * So intent is now decided here, by pattern matching, with no model in the
 * loop. The LLM keeps the two jobs it is actually good at:
 *   1. pulling a plant name / slot values out of free-form Finnish speech
 *   2. rephrasing rows we already fetched and validated
 *
 * Anything this router does not recognise returns kind "unknown" and the
 * caller falls through to the old LLM tool-choice path, so no phrasing that
 * worked before stops working.
 *
 * ponytail: hand-written patterns over an intent-classification model. Three
 * languages x ~6 intents is a table, not a machine-learning problem. If the
 * table grows past ~40 patterns or starts contradicting itself, that is the
 * signal to revisit — not before.
 */

export type ReadIntent =
  | "plant_info"      // "tell me about X" / "what is X"
  | "plant_status"    // "how is X doing", "condition of X"
  | "plant_history"   // "history of X", "what was done to X"
  | "plant_location"  // "where is X"
  | "overdue"         // "what needs attention", "not inspected"
  | "unknown";

export interface RouteResult {
  intent: ReadIntent;
  /** Plant name extracted from the sentence, when the intent names one. */
  plantQuery?: string;
  /** Section code if the user narrowed it, e.g. "G-HA", "T-4.1.3". */
  sectionCode?: string;
  /** Day window for history / overdue intents. */
  days?: number;
}

// ─── Section codes ──────────────────────────────────────────────────────────
// Real vocabulary from docs/notes/data_inventory.md: G-H* greenhouse cells,
// T-x.y.z field plots, X-* special areas, K-n numbered areas, Z-SV.
const SECTION_RE = /\b((?:G-H[A-Z]|X-[A-Z]{2}|Z-SV|Y-O|H-O|M-L)|T-\d+(?:\.\d+){0,2}|K-\d+)\b/i;

// ─── Intent patterns ────────────────────────────────────────────────────────
// Ordered most specific first: "history of X" must beat "about X", and
// "where is X" must beat the generic info pattern.
const PATTERNS: { intent: ReadIntent; re: RegExp }[] = [
  // overdue / needs attention — no plant name involved
  {
    intent: "overdue",
    re: /\b(overdue|needs? attention|not (?:been )?inspected|un-?inspected|due for inspection|tarkastamatta|erääntyn|vaatii huomiota|behöver (?:ses över|uppmärksamhet)|ej inspekterad)\b/i,
  },
  // history — actions/inspections done to a plant
  {
    intent: "plant_history",
    re: /\b(?:histor(?:y|ia|ik)|what (?:was|has been) done|past (?:actions|records)|previous (?:actions|records)|toimenpitee|tapahtum|tidigare (?:åtgärder|händelser)|åtgärdshistorik)\b/i,
  },
  // status / condition
  {
    intent: "plant_status",
    re: /\b(?:status|condition|health|how is|how'?s|doing|alive|kunto|tila|kuinka voi|miten menee|hur (?:mår|är)|tillstånd|skick)\b/i,
  },
  // location
  {
    intent: "plant_location",
    re: /\b(?:where(?:'?s)? |locat(?:ion|ed)|find me|which section|what section|missä|sijain|osasto|var (?:finns|ligger)|vilken sektion)/i,
  },
  // general info — broadest, so last
  {
    intent: "plant_info",
    re: /\b(?:tell me about|what (?:is|are)|info(?:rmation)? (?:about|on)|describe|kerro|mikä on|tietoa|berätta|vad är|information om)\b/i,
  },
];

/**
 * Strip the question scaffolding off a sentence so what remains is the plant
 * name. `intentRe` is the pattern that classified the sentence — removing the
 * phrase it matched is what does most of the work, so the two never drift out
 * of sync the way two parallel keyword lists would.
 *
 * Deliberately conservative: if the result looks like nothing useful we return
 * undefined and let the LLM extract the name instead.
 */
function extractPlantName(text: string, intentRe: RegExp): string | undefined {
  let s = text
    // the phrase that identified the intent ("history of", "how is", ...)
    .replace(new RegExp(intentRe.source, "gi"), " ")
    // greetings and politeness
    .replace(/\b(?:hi|hey|hello|please|can you|could you|show me|kiitos|tack|visa|näytä)\b/gi, " ")
    // residual verb/preposition scaffolding left either side of the name
    .replace(/\b(?:was|were|has|have|been|done|is|are|the|of|to|on|about|for|me)\b/gi, " ")
    .replace(/\b(?:plant|kasvi|växt)\b/gi, " ")
    .replace(SECTION_RE, " ")
    .replace(/\b(?:in|from|at|section|osastossa|osasto|från|sektion)\b/gi, " ")
    .replace(/[?!.,;:]+/g, " ")
    .replace(/\s+/g, " ")
    .trim();

  // Drop a leading article the interrogative pattern left behind.
  s = s.replace(/^(?:the|a|an)\s+/i, "").trim();

  // A plant name is 1-4 words of letters (Latin binomials, Finnish compounds).
  // Anything longer is probably a sentence we mis-parsed; anything shorter than
  // 3 chars is noise.
  if (s.length < 3) return undefined;
  const words = s.split(" ").filter(Boolean);
  if (words.length > 4) return undefined;
  if (!/[a-zA-ZäöåÄÖÅ]{3}/.test(s)) return undefined;
  return s;
}

function extractDays(text: string): number | undefined {
  // "last 30 days", "viimeisen 30 päivän", "senaste 30 dagar"
  const m = text.match(/(\d{1,4})\s*(?:day|days|päiv|dag)/i);
  if (m) return Number(m[1]);
  if (/\b(?:this )?year|vuoden|år\b/i.test(text)) return 365;
  if (/\bmonth|kuukau|månad\b/i.test(text)) return 30;
  return undefined;
}

/**
 * Classify a gardener/visitor message. No LLM, no network, no I/O.
 */
export function routeRead(text: string): RouteResult {
  const t = text.trim();
  if (!t) return { intent: "unknown" };

  const sectionMatch = t.match(SECTION_RE);
  const sectionCode = sectionMatch ? sectionMatch[1].toUpperCase() : undefined;
  const days = extractDays(t);

  for (const { intent, re } of PATTERNS) {
    if (!re.test(t)) continue;
    // Overdue is the one intent that is about a set, not a named plant.
    if (intent === "overdue") return { intent, sectionCode, days };
    const plantQuery = extractPlantName(t, re);
    // A plant intent without a plant name is useless — hand it to the LLM,
    // which is better at digging a name out of a messy sentence.
    if (!plantQuery) return { intent: "unknown" };
    return { intent, plantQuery, sectionCode, days };
  }

  return { intent: "unknown" };
}

// ─── Self-check ─────────────────────────────────────────────────────────────
// ponytail: one runnable check, no test framework. `npx tsx router.ts`
if (require.main === module) {
  // Explicit type annotation required: TS only honours assertion signatures
  // when the callee's type is declared, not inferred from require().
  const assert: typeof import("assert") = require("assert");
  const cases: [string, ReadIntent, string | undefined][] = [
    ["Tell me about the Cacao", "plant_info", "Cacao"],
    ["where is the Valerian", "plant_location", "Valerian"],
    ["how is the Coffee doing", "plant_status", "Coffee"],
    ["history of Chamomile", "plant_history", "Chamomile"],
    ["what was done to the Valerian", "plant_history", "Valerian"],
    ["what needs attention", "overdue", undefined],
    ["missä on Valeriana", "plant_location", "Valeriana"],
    ["kerro Kahvista", "plant_info", "Kahvista"],
    ["var finns Kaffe", "plant_location", "Kaffe"],
    ["mark the valerian as watered", "unknown", undefined], // a write, not a read
    ["hello", "unknown", undefined],
    ["", "unknown", undefined],
  ];
  for (const [input, wantIntent, wantPlant] of cases) {
    const got = routeRead(input);
    assert.strictEqual(got.intent, wantIntent, `intent for ${JSON.stringify(input)}: got ${got.intent}`);
    if (wantPlant !== undefined) {
      assert.ok(
        got.plantQuery?.toLowerCase().includes(wantPlant.toLowerCase()),
        `plant for ${JSON.stringify(input)}: got ${JSON.stringify(got.plantQuery)}`
      );
    }
  }
  // section + day extraction
  assert.strictEqual(routeRead("where is the Cacao in G-HA").sectionCode, "G-HA");
  assert.strictEqual(routeRead("overdue inspections in T-4.1.3").sectionCode, "T-4.1.3");
  assert.strictEqual(routeRead("history of Cacao last 30 days").days, 30);
  console.log("router self-check ok");
}

/**
 * Tool dispatcher — Phase 2: real LLM (Groq + Gemini fallback).
 *
 * Flow:
 *   1. llmTurn() — Groq tool-calling round-trip with role-scoped tools
 *   2. For each tool_call:
 *        WRITE tools  → build a pending_action (UI confirms before commit)
 *        READ tools   → execute against the DAL (Phase 4 — stubbed for now)
 *   3. Compose reply text
 */

import { randomUUID } from "node:crypto";
import { logger } from "firebase-functions/v2";
import type { Role } from "./roles";
import type { PlantCandidate } from "./resolver";
import { llmTurn, composeAnswer, type LlmKeys, type LlmToolCall } from "./llm";
import * as dal from "./dal";
import { storePending, ledgerHistory } from "./writes";
import { buildPlan, SafetyError, type WritePlan, type PlanChange } from "./safety";

export interface DispatchInput {
  uid: string;
  role: Role;
  language: "en" | "fi" | "sv";
  text: string;
  candidates: PlantCandidate[];
  keys: LlmKeys;
  /** Legacy inspector initials of the signed-in user (tarkastaja). */
  inspectorCode?: string;
}

export interface DispatchResult {
  reply: string;
  data?: unknown;
  pending_actions?: PendingAction[];
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
  const turn = await llmTurn({
    keys: input.keys,
    role: input.role,
    language: input.language,
    text: input.text,
    candidates: input.candidates,
  });

  const pending: PendingAction[] = [];
  const records: ToolCallRecord[] = [];
  const readResults: { tool: string; result: unknown }[] = [];
  let data: unknown;

  for (const call of turn.tool_calls) {
    // Role gate — server-side, never trust the model.
    if (GARDENER_ONLY.has(call.name) && input.role === "visitor") {
      records.push({ tool: call.name, params: call.arguments, result: "denied" });
      continue;
    }

    if (WRITE_TOOLS.has(call.name)) {
      const p = buildPendingAction(call, input);
      if (p) {
        await storePending(input.uid, p); // survives until Save/Cancel tap
        pending.push(p);
        records.push({ tool: call.name, params: call.arguments, result: "pending" });
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

  // Second round-trip: read tools produced data → let the LLM compose the
  // actual answer from it. (Without this, the user gets a generic fallback
  // while the data sits unused.)
  let composed = "";
  if (readResults.length > 0) {
    composed = await composeAnswer({
      keys: input.keys,
      language: input.language,
      userText: input.text,
      toolResults: readResults,
    });
  }

  const reply =
    composed ||
    turn.text.trim() ||
    (pending.length
      ? pending.map((p) => p.preview).join("\n")
      : fallbackReply(input.language));

  logger.info("agent.dispatch", {
    model: turn.model,
    toolCalls: records.length,
    pendings: pending.length,
  });

  return {
    reply,
    data,
    pending_actions: pending.length ? pending : undefined,
    tool_calls: records,
    llm_model: turn.model,
  };
}

// ─── Pending-action builder ─────────────────────────────────────────────────

function buildPendingAction(
  call: LlmToolCall,
  input: DispatchInput
): PendingAction | null {
  const a = { ...call.arguments };
  const plant = input.candidates.find((c) => c.hankintaID === a.hankintaID);
  // Refuse to create a pending action for a plant outside the candidate set —
  // anti-hallucination guarantee.
  if (!plant) {
    logger.warn("agent.pending_rejected_unknown_plant", { args: a });
    return null;
  }

  const name = plant.common_name_en ?? plant.scientific_name;
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

  // Build the SAFE write plan now so the user sees the exact SQL + a detailed
  // diff before confirming. This validates everything; on any safety failure
  // we reject the pending action rather than show something unsafe.
  let plan: WritePlan;
  try {
    plan = buildPlan(call.name, a, {
      inspectorCode: input.inspectorCode ?? "",
      plantName: name,
      placementNro: dal.latestPlacementNro(plant.hankintaID),
    });
  } catch (e) {
    if (e instanceof SafetyError) {
      logger.warn("agent.plan_rejected", { tool: call.name, err: e.message });
      return null;
    }
    throw e;
  }

  return {
    pending_id: randomUUID(),
    tool: call.name,
    params: { ...a, _plan: plan }, // plan persisted for the confirm step
    preview: plan.summary,
    requires_confirmation: true,
    sql_display: plan.displaySql,
    changes: plan.changes,
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
        const details = dal.plantDetails({
          hankintaID: a.hankintaID as number | undefined,
          taksonin_nro: a.taksonin_nro as number | undefined,
          name_query: a.name_query as string | undefined,
        });
        if (!details) return { error: "Plant not found." };
        return input.role === "visitor" ? stripForVisitor(details) : details;
      }
      case "query_plant_history": {
        if (input.role === "visitor") return undefined; // role-gated, belt+braces
        const id = Number(a.hankintaID);
        const legacy = dal.plantHistory(id, Number(a.days_back) || 36500);
        const agentRows = await ledgerHistory(id);
        const merged = [...agentRows, ...legacy].sort((x, y) =>
          y.date > x.date ? 1 : -1
        );
        return { history: merged.slice(0, 50) };
      }
      case "find_overdue_inspections": {
        if (input.role === "visitor") return undefined;
        return {
          overdue: dal.overdueInspections(
            Number(a.days_threshold) || 365,
            a.section_code as string | undefined
          ),
        };
      }
      case "navigate_to_plant": {
        const id = Number(a.hankintaID);
        const details = dal.plantDetails({ hankintaID: id });
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

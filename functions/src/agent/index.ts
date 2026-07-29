// deploy-stamp: 1781990523 (app check unenforced)
/**
 * Botanica Smart Agent — Cloud Function entry point.
 *
 * Phase 2 status: real LLM (Groq tool-calling, Gemini fallback) wired in.
 * Reads are still stubbed (Phase 4 brings the SQLite DAL); writes return
 * pending_actions for UI confirmation.
 */

import { onCall, HttpsError } from "firebase-functions/v2/https";
import { defineSecret } from "firebase-functions/params";
import { logger } from "firebase-functions/v2";
import { dispatch } from "./dispatcher";
import { resolveRole, resolveInspectorCode, type Role } from "./roles";
import { resolveCandidates, type LocationContext } from "./resolver";
import { writeAuditEntry } from "./audit";
import { confirmPending, cancelPending, undoLast, logCorrection } from "./writes";
import { enforceRateLimit } from "../ratelimit";
import { GARDEN_API_USER, GARDEN_API_PASS } from "./garden_api";
import * as um from "./update_mode";

const GROQ_API_KEY = defineSecret("GROQ_API_KEY");
const GEMINI_API_KEY = defineSecret("GEMINI_API_KEY");

interface AgentRequest {
  text: string;
  context?: LocationContext;
  language?: "en" | "fi" | "sv";
  session_id: string;
  /** Present when the user tapped Edit on a pending card — the old draft is
   *  cancelled and the LLM re-parses with the correction in context. */
  correction_of?: { pending_id: string; original_preview: string };
  /** Recent conversation turns (oldest→newest) for context memory. */
  history?: { role: "user" | "assistant"; content: string }[];
}

export const agent = onCall(
  {
    cors: true,
    timeoutSeconds: 90, // headroom for T's cold-start spikes (per-call capped at 11s)
    memory: "512MiB", // more memory => more CPU => faster parallel HTTP + JSON
    // minInstances kept at 0: our cold start is minor next to T's slow API, and
    // a warm instance bills 24/7. Flip to 1 only for an active demo day.
    minInstances: 0,
    enforceAppCheck: false,
    secrets: [GROQ_API_KEY, GEMINI_API_KEY, GARDEN_API_USER, GARDEN_API_PASS],
  },
  async (req) => {
    if (!req.auth) {
      throw new HttpsError("unauthenticated", "Sign-in required to use the agent.");
    }
    const uid = req.auth.uid;
    await enforceRateLimit(uid, "agent");
    const payload = (req.data ?? {}) as AgentRequest;
    if (!payload.text || typeof payload.text !== "string") {
      throw new HttpsError("invalid-argument", "Missing `text` in request body.");
    }

    const role: Role = await resolveRole(uid);
    // Never let candidate resolution (flaky external API) crash the turn.
    let candidates: Awaited<ReturnType<typeof resolveCandidates>> = [];
    try {
      candidates = await resolveCandidates(payload.context);
    } catch (e) {
      logger.warn("agent.resolve_candidates_failed", { err: String(e) });
    }

    // Correction loop: cancel the old draft, log the correction for prompt
    // mining, and give the LLM the original to re-parse against.
    let effectiveText = payload.text;
    if (payload.correction_of?.pending_id) {
      await cancelPending(uid, payload.correction_of.pending_id);
      await logCorrection({
        uid,
        pending_id: payload.correction_of.pending_id,
        original_preview: payload.correction_of.original_preview ?? "",
        correction_text: payload.text,
      });
      effectiveText =
        `The user is CORRECTING a previous draft record.\n` +
        `PREVIOUS DRAFT: ${payload.correction_of.original_preview}\n` +
        `CORRECTION: ${payload.text}\n` +
        `Emit a NEW corrected tool call that applies the correction to the draft.`;
    }

    logger.info("agent.turn", {
      uid,
      role,
      lang: payload.language,
      session: payload.session_id,
      candidateCount: candidates.length,
      textLength: payload.text.length,
    });

    let result;
    try {
      result = await dispatch({
        uid,
        role,
        language: payload.language ?? "en",
        text: effectiveText,
        candidates,
        keys: { groq: GROQ_API_KEY.value(), gemini: GEMINI_API_KEY.value() },
        inspectorCode: (await resolveInspectorCode(uid)) ?? "",
        scannedHankintaID: payload.context?.scanned_hankintaID,
        history: payload.history,
      });
    } catch (e) {
      // Never surface a raw INTERNAL to the phone — give a SPECIFIC, retryable
      // message so the user knows whether it's the AI or the garden database.
      logger.error("agent.dispatch_failed", { err: String(e) });
      const lang = payload.language ?? "en";
      const err = String(e);
      const pick = (en: string, fi: string, sv: string) =>
        lang === "fi" ? fi : lang === "sv" ? sv : en;

      let msg: string;
      if (/LLM|providers failed/i.test(err)) {
        // Both AI models were unavailable (quota / formatting / outage).
        msg = pick(
          "The AI assistant is briefly unavailable (high demand). Please try again in a moment.",
          "Tekoälyavustaja ei ole hetkellisesti käytettävissä (ruuhkaa). Yritä hetken kuluttua uudelleen.",
          "AI-assistenten är tillfälligt otillgänglig (hög belastning). Försök igen om en stund."
        );
      } else if (/GardenApi|\/api\/|timed out|aborted|database/i.test(err)) {
        // The garden's database API was slow or down.
        msg = pick(
          "The garden database is slow or unavailable right now. Please try again in a moment.",
          "Puutarhan tietokanta on hidas tai ei käytettävissä juuri nyt. Yritä hetken kuluttua uudelleen.",
          "Trädgårdens databas är långsam eller otillgänglig just nu. Försök igen om en stund."
        );
      } else {
        msg = pick(
          "Something went wrong handling that. Please try again.",
          "Jokin meni vikaan. Yritä uudelleen.",
          "Något gick fel. Försök igen."
        );
      }
      return { reply: msg, pending_actions: [] };
    }

    await writeAuditEntry({
      uid,
      role,
      session_id: payload.session_id,
      input_text: payload.text,
      candidates_used: candidates.map((c) => c.hankintaID),
      tool_calls: result.tool_calls,
      llm_model: result.llm_model,
      reply: result.reply,
    });

    // Strip the heavy internal _plan from params before sending to the client
    // (it's persisted server-side in agent_pending). The card needs only
    // sql_display + changes, which are top-level fields.
    const clientPendings = (result.pending_actions ?? []).map((p) => ({
      pending_id: p.pending_id,
      tool: p.tool,
      preview: p.preview,
      requires_confirmation: p.requires_confirmation,
      sql_display: p.sql_display,
      changes: p.changes,
    }));

    return {
      reply: result.reply,
      data: result.data,
      pending_actions: clientPendings,
      clarification: result.clarification ?? null,
      suggestions: result.suggestions ?? [],
    };
  }
);

/**
 * agentConfirm — commits, cancels, or undoes pending actions.
 * Called by the Flutter confirmation card's Save / Cancel buttons and the
 * undo affordance.
 */
export const agentConfirm = onCall(
  {
    cors: true,
    timeoutSeconds: 30,
    memory: "256MiB",
    enforceAppCheck: false,
    secrets: [GARDEN_API_USER, GARDEN_API_PASS],
  },
  async (req) => {
    if (!req.auth) {
      throw new HttpsError("unauthenticated", "Sign-in required.");
    }
    const uid = req.auth.uid;
    await enforceRateLimit(uid, "agentConfirm");
    const { op, pending_id } = (req.data ?? {}) as {
      op?: "confirm" | "cancel" | "undo";
      pending_id?: string;
    };

    // HARD GATE: only staff (gardener/admin) may commit or undo a DB write.
    // Visitors cannot reach here through the UI, but enforce it server-side too —
    // a write to the live database must never come from a non-authority account.
    if (op === "confirm" || op === "undo") {
      const role = await resolveRole(uid);
      if (role === "visitor") {
        throw new HttpsError("permission-denied", "Only garden staff can change records.");
      }
    }

    if (op === "confirm") {
      if (!pending_id) throw new HttpsError("invalid-argument", "pending_id required.");
      const res = await confirmPending(uid, pending_id);
      // In update mode a settled write is not the end of the conversation —
      // offer [Update another] / [Done] instead of dumping the gardener back
      // into free chat. Applies to both success and failure: either way they
      // need to know what happens next.
      const lang = (req.data?.language ?? "en") as string;
      if (await um.loadState(uid).catch(() => null)) {
        await um.resetSlots(uid);
        return { ...res, clarification: um.followUpOptions(lang) };
      }
      return res;
    }
    if (op === "cancel") {
      if (!pending_id) throw new HttpsError("invalid-argument", "pending_id required.");
      await cancelPending(uid, pending_id);
      return { ok: true, message: "Cancelled." };
    }
    if (op === "undo") {
      return await undoLast(uid);
    }
    throw new HttpsError("invalid-argument", "op must be confirm | cancel | undo.");
  }
);

/**
 * agentUpdateMode — the gardener's "Update" button.
 *
 * Enters or leaves the slot-filling update conversation. Gated to garden staff
 * server-side: the button is hidden from visitors in the app, but the mode is
 * the only path that writes to T's production database, so the gate lives here
 * too and not only in the UI.
 */
export const agentUpdateMode = onCall(
  {
    cors: true,
    timeoutSeconds: 30,
    memory: "256MiB",
    enforceAppCheck: false,
  },
  async (req) => {
    if (!req.auth) throw new HttpsError("unauthenticated", "Sign-in required.");
    const uid = req.auth.uid;
    await enforceRateLimit(uid, "agentUpdateMode");

    const { op, language } = (req.data ?? {}) as {
      op?: "start" | "exit" | "status";
      language?: "en" | "fi" | "sv";
    };
    const lang = language ?? "en";

    const role = await resolveRole(uid);
    if (role === "visitor") {
      throw new HttpsError("permission-denied", "Only garden staff can record updates.");
    }

    if (op === "start") {
      await um.startUpdateMode(uid);
      return { active: true, reply: um.updateModePrompt(lang) };
    }
    if (op === "exit") {
      await um.exitUpdateMode(uid);
      return { active: false, reply: um.updateModeExitMessage(lang) };
    }
    if (op === "status") {
      return { active: (await um.loadState(uid)) !== null };
    }
    throw new HttpsError("invalid-argument", "op must be start | exit | status.");
  }
);

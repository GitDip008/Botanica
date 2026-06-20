// deploy-stamp: 1781920197
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
}

export const agent = onCall(
  {
    cors: true,
    timeoutSeconds: 60,
    memory: "256MiB",
    enforceAppCheck: true,
    secrets: [GROQ_API_KEY, GEMINI_API_KEY],
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
    const candidates = await resolveCandidates(payload.context);

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
      });
    } catch (e) {
      // Never surface a raw INTERNAL to the phone — give a retryable message.
      logger.error("agent.dispatch_failed", { err: String(e) });
      const lang = payload.language ?? "en";
      const sorry =
        lang === "fi"
          ? "Palvelussa oli hetkellinen häiriö. Yritä uudelleen."
          : lang === "sv"
            ? "Tjänsten hade ett tillfälligt fel. Försök igen."
            : "The service had a temporary hiccup. Please try again.";
      return { reply: sorry, pending_actions: [] };
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
    };
  }
);

/**
 * agentConfirm — commits, cancels, or undoes pending actions.
 * Called by the Flutter confirmation card's Save / Cancel buttons and the
 * undo affordance.
 */
export const agentConfirm = onCall(
  { cors: true, timeoutSeconds: 30, memory: "256MiB", enforceAppCheck: true },
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

    if (op === "confirm") {
      if (!pending_id) throw new HttpsError("invalid-argument", "pending_id required.");
      return await confirmPending(uid, pending_id);
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

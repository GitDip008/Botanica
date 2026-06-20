/**
 * Audit log writer.
 *
 * Every agent turn writes one row to `agent_audit_log/{auto_id}` with the
 * full provenance: user, role, transcript, candidates considered, tool calls
 * emitted, LLM model, final reply. This is what makes the system debuggable
 * and reviewable — "why did the agent log that?" has a definitive answer.
 *
 * Cheap (one Firestore write per turn). Inside the free tier well past any
 * reasonable load.
 */

import * as admin from "firebase-admin";
import { logger } from "firebase-functions/v2";
import type { Role } from "./roles";
import type { ToolCallRecord } from "./dispatcher";

export interface AuditEntry {
  uid: string;
  role: Role;
  session_id: string;
  input_text: string;
  candidates_used: number[];
  tool_calls: ToolCallRecord[];
  llm_model: string;
  reply: string;
}

export async function writeAuditEntry(entry: AuditEntry): Promise<void> {
  try {
    await admin
      .firestore()
      .collection("agent_audit_log")
      .add({
        ...entry,
        created_at: admin.firestore.FieldValue.serverTimestamp(),
      });
  } catch (err) {
    // Audit failures must NEVER break the user-facing call.
    logger.error("agent.audit_failed", { err: String(err) });
  }
}

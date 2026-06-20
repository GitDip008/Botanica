/**
 * Writes ledger + LIVE EXECUTOR.
 *
 * On confirm we ACTUALLY apply the change to the live database (SQLite in
 * Cloud Storage today; T's MySQL later) through the safety engine, then record
 * it in the Firestore ledger (`agent_writes`) for audit + undo. Every write:
 *   - runs a fixed, parameterized statement (no LLM-generated SQL),
 *   - is bounded to affect exactly 1 row (row-count guard inside a tx),
 *   - is reversible via a guarded single-row delete (undo).
 *
 * Pending actions live in `agent_pending/{pending_id}` between the LLM turn
 * and the user's Save/Cancel tap, and carry the pre-built WritePlan.
 */

import * as admin from "firebase-admin";
import { logger } from "firebase-functions/v2";
import type { PendingAction } from "./dispatcher";
import type { HistoryEntry } from "./dal";
import { executePlan, undoInsert, type WritePlan } from "./safety";
import { withWriteDb } from "./live_db";

const PENDING = "agent_pending";
const LEDGER = "agent_writes";

// ─── Pending lifecycle ──────────────────────────────────────────────────────

export async function storePending(uid: string, p: PendingAction): Promise<void> {
  await admin.firestore().collection(PENDING).doc(p.pending_id).set({
    uid,
    tool: p.tool,
    params: p.params, // includes the pre-built _plan
    preview: p.preview,
    status: "pending",
    created_at: admin.firestore.FieldValue.serverTimestamp(),
  });
}

export async function confirmPending(
  uid: string,
  pendingId: string
): Promise<{ ok: boolean; message: string }> {
  const ref = admin.firestore().collection(PENDING).doc(pendingId);
  const snap = await ref.get();
  if (!snap.exists) return { ok: false, message: "Pending action not found." };
  const data = snap.data()!;
  if (data.uid !== uid) return { ok: false, message: "Not your pending action." };
  if (data.status !== "pending") return { ok: false, message: `Already ${data.status}.` };

  const plan = (data.params as any)?._plan as WritePlan | undefined;
  if (!plan || !plan.statement) {
    return { ok: false, message: "No safe write plan attached — cannot apply." };
  }

  // APPLY to the live DB through the safety executor (row-count guarded).
  let exec;
  try {
    exec = await withWriteDb((db) => executePlan(db, plan));
  } catch (e) {
    logger.error("agent.live_write_failed", { pendingId, err: String(e) });
    return { ok: false, message: `Could not reach the database: ${String(e)}` };
  }
  if (!exec.ok) {
    return { ok: false, message: exec.message };
  }

  // Record in the ledger for audit + undo.
  await admin.firestore().collection(LEDGER).add({
    uid,
    pending_id: pendingId,
    tool: data.tool,
    preview: data.preview,
    table: plan.table,
    operation: plan.operation,
    sql_statement: plan.statement,
    sql_params: plan.params,
    sql_display: plan.displaySql,
    hankintaID: (data.params as any).hankintaID ?? null,
    inserted_pk: exec.insertedId ?? null,
    applied_to_live_db: true,
    confirmed_at: admin.firestore.FieldValue.serverTimestamp(),
  });
  await ref.update({ status: "confirmed" });
  logger.info("agent.write_applied", {
    pendingId,
    tool: data.tool,
    table: plan.table,
    rows: exec.changedRows,
  });
  return { ok: true, message: "Saved to the database." };
}

export async function cancelPending(uid: string, pendingId: string): Promise<void> {
  const ref = admin.firestore().collection(PENDING).doc(pendingId);
  const snap = await ref.get();
  if (snap.exists && snap.data()!.uid === uid) {
    await ref.update({ status: "cancelled" });
  }
}

/** Undo: reverses the most recent applied write by deleting the exact row we
 *  inserted (guarded single-row delete). INSERT-only for now — status updates
 *  aren't auto-reverted because we don't keep the prior value yet. */
export async function undoLast(uid: string): Promise<{ ok: boolean; message: string }> {
  const q = await admin
    .firestore()
    .collection(LEDGER)
    .where("uid", "==", uid)
    .limit(100)
    .get();
  const docs = q.docs
    .filter((d) => d.data().revoked !== true)
    .sort((a, b) => {
      const ta = a.data().confirmed_at?.toMillis?.() ?? 0;
      const tb = b.data().confirmed_at?.toMillis?.() ?? 0;
      return tb - ta;
    });
  if (docs.length === 0) return { ok: false, message: "Nothing to undo." };
  const doc = docs[0];
  const x = doc.data();

  if (x.operation === "insert" && x.inserted_pk) {
    const table = x.table as "toimenpide" | "tarkastusmerkinta";
    const pkCol =
      table === "toimenpide" ? "toimenpide_nro" : "tarkastusnro";
    try {
      const res = await withWriteDb((db) =>
        undoInsert(db, table, pkCol as any, Number(x.inserted_pk))
      );
      if (!res.ok) return { ok: false, message: res.message };
    } catch (e) {
      return { ok: false, message: `Could not reach the database: ${String(e)}` };
    }
  }
  await doc.ref.update({
    revoked: true,
    revoked_at: admin.firestore.FieldValue.serverTimestamp(),
  });
  return { ok: true, message: `Undone: ${x.preview}` };
}

/** Logs an Edit-tap correction for prompt improvement (Phase 7 mining). */
export async function logCorrection(entry: {
  uid: string;
  pending_id: string;
  original_preview: string;
  correction_text: string;
}): Promise<void> {
  try {
    await admin.firestore().collection("agent_corrections").add({
      ...entry,
      created_at: admin.firestore.FieldValue.serverTimestamp(),
    });
  } catch (err) {
    logger.warn("agent.correction_log_failed", { err: String(err) });
  }
}

// ─── History merge ──────────────────────────────────────────────────────────

export async function ledgerHistory(hankintaID: number): Promise<HistoryEntry[]> {
  const q = await admin
    .firestore()
    .collection(LEDGER)
    .where("hankintaID", "==", hankintaID)
    .limit(50)
    .get();
  return q.docs
    .filter((d) => d.data().revoked !== true)
    .map((d) => {
      const x = d.data();
      return {
        kind: x.tool === "record_action" ? ("action" as const) : ("inspection" as const),
        date: (x.sql_params?.[x.sql_params.length - 1] as string) ?? "",
        detail: x.preview as string,
        source: "agent" as const,
      };
    });
}

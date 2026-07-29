/**
 * Writes ledger + LIVE EXECUTOR (REST).
 *
 * On confirm we ACTUALLY apply the change to T's production database through
 * the REST API, then record it in the Firestore ledger (`agent_writes`) for
 * audit + undo. Every write:
 *   - sends a fixed, validated request built by the safety engine (no
 *     LLM-generated SQL/JSON shapes),
 *   - targets exactly one resource (POST one row / PUT one id),
 *   - is reversible: inserts via a guarded single-row DELETE, status updates by
 *     restoring the previous value with a PUT.
 *
 * Pending actions live in `agent_pending/{pending_id}` between the LLM turn and
 * the user's Save/Cancel tap, carrying the pre-built WritePlan.
 */

import * as admin from "firebase-admin";
import { logger } from "firebase-functions/v2";
import type { PendingAction } from "./dispatcher";
import type { HistoryEntry } from "./dal";
import type { WritePlan } from "./safety";
import { apiPost, apiPut, apiGetOne, GardenApiError } from "./garden_api";

const PENDING = "agent_pending";
const LEDGER = "agent_writes";
const INTENTS = "agent_intents";

// ─── Disambiguation intent (carries a write across the "which plant?" tap) ───
// When a write names a plant with several instances, we stash the action here.
// When the user taps a plant chip, we complete THAT exact action deterministically
// — no LLM, no lost context.
export async function storeIntent(
  uid: string,
  intent: { tool: string; args: Record<string, unknown> }
): Promise<void> {
  await admin.firestore().collection(INTENTS).doc(uid).set({
    tool: intent.tool,
    args: intent.args,
    ts: Date.now(),
  });
}

export async function loadIntent(
  uid: string
): Promise<{ tool: string; args: Record<string, unknown>; ts: number } | null> {
  const s = await admin.firestore().collection(INTENTS).doc(uid).get();
  if (!s.exists) return null;
  return s.data() as { tool: string; args: Record<string, unknown>; ts: number };
}

export async function clearIntent(uid: string): Promise<void> {
  await admin.firestore().collection(INTENTS).doc(uid).delete().catch(() => {});
}

interface ExecResult {
  ok: boolean;
  insertedId?: number | null;
  message: string;
}

// ─── Live executor (REST) ───────────────────────────────────────────────────

async function executePlanRest(plan: WritePlan): Promise<ExecResult> {
  // UPDATE: the API's PUT needs the whole row, so read-modify-write.
  if (plan.readModifyWrite) {
    const current = await apiGetOne<Record<string, unknown>>(plan.readModifyWrite.getPath);
    if (!current) return { ok: false, message: "The row to update no longer exists." };
    const merged = { ...current, ...plan.rest.body };
    await apiPut(plan.rest.path, merged);
    return { ok: true, message: "Updated." };
  }

  // INSERT: POST returns the created row (with its auto PK).
  const created = await apiPost<Record<string, any>>(plan.rest.path, plan.rest.body);
  const pkField =
    plan.undo?.kind === "delete" ? plan.undo.pkField : undefined;
  const insertedId = pkField ? (created?.[pkField] ?? null) : null;
  return { ok: true, insertedId, message: "Created." };
}

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
  if (!plan || !plan.rest) {
    return { ok: false, message: "No safe write plan attached — cannot apply." };
  }

  // APPLY to the live database via the REST executor.
  let exec: ExecResult;
  try {
    exec = await executePlanRest(plan);
  } catch (e) {
    const status = e instanceof GardenApiError ? e.status : 0;
    logger.error("agent.live_write_failed", { pendingId, status, err: String(e) });
    const msg =
      status === 403
        ? "The database rejected the write (permission denied for this account)."
        : `Could not reach the database: ${String(e)}`;
    return { ok: false, message: msg };
  }
  if (!exec.ok) return { ok: false, message: exec.message };

  // Record in the ledger for audit + undo.
  await admin.firestore().collection(LEDGER).add({
    uid,
    pending_id: pendingId,
    tool: data.tool,
    preview: data.preview,
    table: plan.table,
    operation: plan.operation,
    rest_method: plan.rest.method,
    rest_path: plan.rest.path,
    rest_body: plan.rest.body,
    undo: plan.undo ?? null,
    hankintaID: (data.params as any).hankintaID ?? null,
    inserted_pk: exec.insertedId ?? null,
    applied_to_live_db: true,
    confirmed_at: admin.firestore.FieldValue.serverTimestamp(),
  });
  await ref.update({ status: "confirmed" });
  logger.info("agent.write_applied", { pendingId, tool: data.tool, table: plan.table });
  return { ok: true, message: "Saved to the database." };
}

export async function cancelPending(uid: string, pendingId: string): Promise<void> {
  const ref = admin.firestore().collection(PENDING).doc(pendingId);
  const snap = await ref.get();
  if (snap.exists && snap.data()!.uid === uid) {
    await ref.update({ status: "cancelled" });
  }
}

/**
 * PERUUTETTU = "cancelled" in Finnish. Prefixed onto an annulled row's text so
 * the legacy system and any gardener reading the raw table both see it is void.
 */
const ANNUL_PREFIX = "PERUUTETTU:";
/** Text column to annul, per table. First match wins. */
const ANNUL_FIELDS = ["toimenpide", "menestymista_koskevat_havainnot", "huomautuksia"];

/** Undo: reverses the most recent applied write. Never deletes.
 *   - insert  → annul the row in place (prefix its text with PERUUTETTU:)
 *   - update  → restore the previous field value with a PUT */
export async function undoLast(uid: string): Promise<{ ok: boolean; message: string }> {
  const q = await admin.firestore().collection(LEDGER).where("uid", "==", uid).limit(100).get();
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
  const undo = x.undo as WritePlan["undo"] | undefined;

  try {
    if (undo?.kind === "delete") {
      if (!x.inserted_pk) {
        return { ok: false, message: "Can't undo: the created row's id wasn't recorded." };
      }
      // The garden's rule is that nothing is ever really deleted, so undoing an
      // insert ANNULS the row instead of removing it: the row stays, its text
      // prefixed so both the app and the legacy system read it as void. A real
      // DELETE would erase a line of the plant's history, which is exactly what
      // the append-only convention exists to prevent — and it needed a delete
      // permission on T's account that we should not be relying on either.
      const path = undo.pathTemplate.replace("{id}", String(x.inserted_pk));
      const row = await apiGetOne<Record<string, unknown>>(path);
      if (!row) {
        return { ok: false, message: "Can't undo: that record is no longer readable." };
      }
      const textField = ANNUL_FIELDS.find((f) => f in row);
      if (!textField) {
        return { ok: false, message: "Can't undo this record type automatically." };
      }
      const existing = String(row[textField] ?? "");
      if (existing.startsWith(ANNUL_PREFIX)) {
        return { ok: false, message: "That record was already cancelled." };
      }
      await apiPut(path, { ...row, [textField]: `${ANNUL_PREFIX} ${existing}`.slice(0, 500) });
    } else if (undo?.kind === "restore") {
      const current = await apiGetOne<Record<string, unknown>>(undo.path);
      if (current) {
        await apiPut(undo.path, { ...current, [undo.field]: undo.previous });
      }
    } else {
      return { ok: false, message: "This change can't be undone automatically." };
    }
  } catch (e) {
    const status = e instanceof GardenApiError ? e.status : 0;
    if (status === 403) {
      return {
        ok: false,
        message:
          "The database account can't delete rows. Ask T for delete permission, or remove it manually.",
      };
    }
    return { ok: false, message: `Could not reach the database: ${String(e)}` };
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
        date: (x.rest_body?.uus_pvm ?? x.rest_body?.uus_tarkastuspvm ?? "") as string,
        detail: x.preview as string,
        source: "agent" as const,
      };
    });
}

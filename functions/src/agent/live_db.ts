/**
 * Live writable database — Phase: real writes.
 *
 * Cloud Functions' filesystem is read-only except /tmp (ephemeral, per-
 * instance). So the single source of truth lives in Cloud Storage as
 * `agent_live/live.sqlite`. We:
 *   - seed it once from the bundled read-only snapshot if missing,
 *   - cache it in /tmp for fast reads,
 *   - for writes: serialize via a Firestore lock, pull latest, apply, push.
 *
 * Low write volume (a handful of gardener actions per day) makes the
 * download-apply-upload round-trip perfectly acceptable.
 *
 * SWAP POINT: when T ships a MySQL write API, `withWriteDb` becomes an HTTP
 * POST to that API and `getReadDb` queries it — the safety engine, plans and
 * UI stay identical.
 */

import Database from "better-sqlite3";
import * as admin from "firebase-admin";
import * as fs from "node:fs";
import * as path from "node:path";
import { logger } from "firebase-functions/v2";

// Default Firebase Storage bucket (must be enabled once in the console).
const BUCKET = "botanica-008.firebasestorage.app";
const OBJECT = "agent_live/live.sqlite";
const TMP_LIVE = "/tmp/live.sqlite";
const BUNDLED = path.join(process.cwd(), "test_database.sqlite");
const LOCK_DOC = "agent_locks/live_db";

function bucket() {
  return admin.storage().bucket(BUCKET);
}

/** Ensure the Storage object exists, seeding from the bundled snapshot once. */
async function ensureSeeded(): Promise<void> {
  const file = bucket().file(OBJECT);
  const [exists] = await file.exists();
  if (!exists) {
    logger.info("agent.live_db.seeding_from_snapshot");
    await bucket().upload(BUNDLED, { destination: OBJECT });
  }
}

/** Download the live DB to /tmp (always fresh — small file). */
async function pull(): Promise<void> {
  await ensureSeeded();
  await bucket().file(OBJECT).download({ destination: TMP_LIVE });
}

/** Upload /tmp copy back to Storage as the new source of truth. */
async function push(): Promise<void> {
  await bucket().upload(TMP_LIVE, { destination: OBJECT });
}

/**
 * Open a READ-ONLY handle to the live DB. Pulls a fresh copy each call so
 * reads reflect the latest confirmed writes. (For a low-traffic tool the
 * extra ~150ms is irrelevant; add a TTL cache later if needed.)
 */
export async function getReadDb(): Promise<Database.Database> {
  await pull();
  return new Database(TMP_LIVE, { readonly: true, fileMustExist: true });
}

/**
 * Run a write transaction against the live DB, serialized by a Firestore
 * lock so two instances can't clobber each other. The callback gets a
 * writable handle; after it returns we upload the result.
 */
export async function withWriteDb<T>(
  fn: (db: Database.Database) => T
): Promise<T> {
  const lockRef = admin.firestore().doc(LOCK_DOC);

  // Acquire a simple lock (Firestore transaction sets a held flag with TTL).
  await admin.firestore().runTransaction(async (tx) => {
    const snap = await tx.get(lockRef);
    const now = Date.now();
    const heldUntil = (snap.data()?.heldUntil as number) ?? 0;
    if (heldUntil > now) {
      throw new Error("Another write is in progress — please retry.");
    }
    tx.set(lockRef, { heldUntil: now + 30_000 }, { merge: true });
  });

  try {
    await pull();
    const db = new Database(TMP_LIVE, { fileMustExist: true });
    let result: T;
    try {
      result = fn(db);
    } finally {
      db.close();
    }
    await push();
    return result;
  } finally {
    await lockRef.set({ heldUntil: 0 }, { merge: true }).catch(() => {});
  }
}

/** Expose whether Storage-backed writes are available (for graceful degrade). */
export async function liveDbHealthy(): Promise<boolean> {
  try {
    await ensureSeeded();
    return true;
  } catch (e) {
    logger.error("agent.live_db.unhealthy", { err: String(e) });
    return false;
  }
}

/** Best-effort cleanup helper (not strictly needed; /tmp clears on cold start). */
export function clearTmp(): void {
  try {
    if (fs.existsSync(TMP_LIVE)) fs.unlinkSync(TMP_LIVE);
  } catch {
    /* ignore */
  }
}

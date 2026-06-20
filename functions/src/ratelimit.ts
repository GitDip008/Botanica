/**
 * Per-user rate limiting — fixed-window counter in Firestore.
 *
 * Every callable wraps its body in `enforceRateLimit(uid, feature, ...)`.
 * If the user exceeds the cap inside the window, we throw a
 * `resource-exhausted` HttpsError the client shows as "slow down".
 *
 * Cost: one transaction (1 read + 1 write) per call — comfortably inside the
 * Firestore free tier. The doc id is `{feature}__{uid}` so each feature has an
 * independent budget per user.
 *
 * This is defense against a real or stolen account spamming calls. App Check
 * is the separate layer that blocks scripted (non-app) callers entirely.
 */

import * as admin from "firebase-admin";
import { HttpsError } from "firebase-functions/v2/https";
import { logger } from "firebase-functions/v2";

export interface RateRule {
  /** Max calls allowed within the window. */
  limit: number;
  /** Window length in seconds. */
  windowSec: number;
}

/** Sensible default budgets per feature. Tune as real usage shows. */
export const RATE_RULES: Record<string, RateRule> = {
  agent: { limit: 30, windowSec: 60 },        // 30 agent turns / minute
  agentConfirm: { limit: 40, windowSec: 60 },  // confirms + cancels + undos
  groqChat: { limit: 40, windowSec: 60 },      // chat completions
  geminiCall: { limit: 20, windowSec: 60 },    // vision / fallback (pricier)
  plantnetIdentify: { limit: 30, windowSec: 60 }, // plant photo ID bursts
};

/**
 * Throws HttpsError("resource-exhausted") if the user is over budget for
 * `feature`. Otherwise records the call and returns. Fails OPEN on any
 * Firestore error — a limiter outage must never block legitimate use.
 */
export async function enforceRateLimit(
  uid: string,
  feature: string,
  rule: RateRule = RATE_RULES[feature] ?? { limit: 60, windowSec: 60 }
): Promise<void> {
  const ref = admin.firestore().collection("rate_limits").doc(`${feature}__${uid}`);
  const now = Date.now();

  try {
    await admin.firestore().runTransaction(async (tx) => {
      const snap = await tx.get(ref);
      const data = snap.data() as { windowStart?: number; count?: number } | undefined;

      const windowStart = data?.windowStart ?? 0;
      const count = data?.count ?? 0;
      const elapsed = now - windowStart;

      if (elapsed > rule.windowSec * 1000) {
        // New window.
        tx.set(ref, { windowStart: now, count: 1 });
        return;
      }
      if (count >= rule.limit) {
        const retryIn = Math.ceil((rule.windowSec * 1000 - elapsed) / 1000);
        throw new HttpsError(
          "resource-exhausted",
          `Too many requests — please wait ${retryIn}s and try again.`
        );
      }
      tx.update(ref, { count: count + 1 });
    });
  } catch (e) {
    if (e instanceof HttpsError) throw e; // real rate-limit rejection
    // Firestore hiccup — fail open, never block a legitimate user.
    logger.warn("ratelimit.failed_open", { feature, err: String(e) });
  }
}

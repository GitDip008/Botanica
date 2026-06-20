/**
 * Resolves a Firebase user UID into a Botanica role.
 *
 * Reads `users/{uid}` once per call (small Firestore cost). Defaults to
 * "visitor" if no role is set — which is the safest fallback because every
 * write tool requires gardener+ permission.
 */

import * as admin from "firebase-admin";

export type Role = "visitor" | "gardener" | "admin";

export async function resolveRole(uid: string): Promise<Role> {
  try {
    const snap = await admin.firestore().collection("users").doc(uid).get();
    const data = snap.data();
    const fromDoc = data?.role as Role | undefined;
    if (fromDoc === "gardener" || fromDoc === "admin") return fromDoc;
    if (data?.isAdmin === true) return "admin";
    return "visitor";
  } catch {
    return "visitor";
  }
}

/**
 * Returns the gardener's legacy initials code (the `tarkastaja` value the
 * inspection records will carry). Phase 4 will use this to auto-fill the
 * tarkastaja column. Maps to `kayttajatiedot.kayttajan_tunnus` — but the
 * mapping itself happens in the DB layer, not here.
 */
export async function resolveInspectorCode(uid: string): Promise<string | null> {
  try {
    const snap = await admin.firestore().collection("users").doc(uid).get();
    const code = snap.data()?.legacyInspectorCode as string | undefined;
    return code ?? null;
  } catch {
    return null;
  }
}

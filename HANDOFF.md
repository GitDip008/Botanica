# Botanica — Project Handoff Guide

This document explains how to transfer the Botanica app (Firebase project
`botanica-008`) to the Oulu Botanical Garden / a new developer **without
rebuilding anything**. A Firebase project is just a Google Cloud project, so
ownership moves through permissions — not by recreating the project.

> ⚠️ "The project" is actually **5 separate systems** that hand off differently.
> Transferring Firebase alone will NOT stop the original developer's bills or
> the third-party API charges. Do all five.

---

## 0. Before you start — make a shared owner account

**Do not tie ownership to one person's personal Gmail.** Staff change jobs.
Use a **shared / organisation Google account** (e.g. a Google Workspace account
like `digital@oul.botanicalgarden…`) and keep **at least two owners** for
redundancy.

The account only needs to be a Google account — any email can be turned into
one at https://accounts.google.com/signup (it does not have to be `@gmail.com`).

---

## 1. Firebase / Google Cloud project (`botanica-008`)

Everything inside the project — Firestore, Cloud Functions, Authentication,
App Check, security rules, secrets — stays exactly as-is. You only change who
has access.

1. Go to **Google Cloud Console → IAM & Admin → IAM**
   (https://console.cloud.google.com/iam-admin/iam?project=botanica-008)
2. Click **Grant access** → enter the gardeners' shared Google account
3. Assign role **Owner** → Save
4. (Later, once everything is confirmed working) remove the old developer's
   account from this list.

✅ No reconfiguration. All data, functions, and rules remain.

---

## 2. Billing account (this is what stops the bills)

The billing account is **separate** from the project and holds the original
developer's payment card. Adding someone as project Owner does **not** move
billing.

1. The gardeners create their **own** billing account (their card) at
   **Billing → Manage billing accounts → Create account**.
2. Re-link the project to it: **Billing → Account management →
   Change billing account** → pick the gardeners' new account.
3. Remove the old developer from the old billing account.

✅ Only after this does the original developer stop paying.

---

## 3. Third-party API keys (Groq, Gemini, PlantNet) — the easy-to-miss part

These keys live on the **original developer's accounts** on those services.
They do **NOT** travel with the Firebase project. Until they are replaced, the
app keeps charging the original developer's Groq/Gemini accounts.

For each service, the new developer:
1. Creates a new account (or uses the gardeners' account) and generates a key:
   - Groq: https://console.groq.com/keys
   - Gemini (Google AI Studio): https://aistudio.google.com/apikey
   - PlantNet: https://my.plantnet.org/account
2. Sets it as a Firebase secret (run inside the `functions/` directory):
   ```bash
   firebase functions:secrets:set GROQ_API_KEY
   firebase functions:secrets:set GEMINI_API_KEY
   firebase functions:secrets:set PLANTNET_API_KEY
   ```
3. Redeploys: `firebase deploy --only functions`

✅ Keys are never stored in the app or the repo — only in Secret Manager.

---

## 4. GitHub repository

Repo: https://github.com/GitDip008/Botanica

- **GitHub → Settings → Transfer ownership** to the gardeners' account/org, OR
- Add the new developer as an **Admin** collaborator.

> Note: the repo is **public** and deliberately does **not** contain:
> `google-services.json`, `firebase_options.dart`, `lib/config/api_config.dart`,
> `functions/test_database.sqlite`, or the `/resources` CAD maps. These must be
> handed over separately (see Section 6).

---

## 5. Google Play Console (only if the app is published)

If the app is published under the original developer's Play account, moving it
requires the formal **App transfer** process (+ a $25 fee for the receiving
account).

- **If not yet published:** create the Play Developer account under the
  gardeners' organisation and publish from there from the start — this avoids
  the transfer entirely.
- **If already published:** use Play Console → **Setup → App transfer**.

---

## 6. Files handed over out-of-band (not in the public repo)

Give these to the new developer directly (Drive / Teams / USB):

| File | Goes in | Needed for |
|---|---|---|
| `android/app/google-services.json` | `android/app/` | Firebase connection |
| `lib/firebase_options.dart` | `lib/` | Firebase init (or run `flutterfire configure`) |
| `lib/config/api_config.dart` | copy from `api_config.example.dart` | App config |
| `functions/test_database.sqlite` | `functions/` | Agent functions (only if deploying) |
| `/resources` (CAD maps, test DB copy) | `resources/` | Reference material |

---

## 7. App Check — every new device/dev needs registering

The app enforces App Check. Each new development machine generates its own
**debug token** on first run; until it is registered, all Firebase/agent calls
are denied.

1. Run the app once (`flutter run`)
2. Find the debug token in the logs (or via
   `adb shell run-as <package> cat .../com.google.firebase.appcheck.debug.store.*.xml`)
3. Register it: **Firebase Console → App Check → Apps → botanica_ar (android)
   → Manage debug tokens**

Release builds pass automatically via **Play Integrity** — no token needed.

---

## 8. Final handoff checklist

- [ ] Gardeners create a shared Google account (2 owners)
- [ ] Add it as **Owner** on the GCP/Firebase project (IAM)
- [ ] Gardeners create their own **billing account** → relink `botanica-008`
- [ ] New developer generates fresh **Groq / Gemini / PlantNet** keys → re-set secrets → redeploy
- [ ] Transfer the **GitHub** repo (or add new dev as admin)
- [ ] **Play Console**: publish under gardeners' account (or app transfer)
- [ ] Hand over the **out-of-band files** (Section 6)
- [ ] Register the new dev's **App Check** debug token
- [ ] Confirm the app fully works on the new setup
- [ ] **Remove the original developer** from IAM + billing

---

## Security baseline already in place (for the next developer's awareness)

- All paid API keys are server-side (Secret Manager) — none ship in the APK.
- App Check enforced on all Cloud Functions + Firestore.
- Per-user rate limiting on every callable.
- Firestore rules: per-user data isolation, admin-by-verified-email,
  privilege-escalation guard, server-only collections locked.
- Storage rules: deny-all client (agent DB is admin-SDK only).
- Agent SQL writes: parameterized, operation-whitelisted, row-count guarded,
  cannot drop the database; every write requires explicit confirmation.

See the commit history and `firestore.rules` / `storage.rules` for details.

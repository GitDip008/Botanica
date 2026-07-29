/**
 * plantsCatalogue — read-only plant catalogue for the in-app navigation module.
 *
 * The vendored BotaniNav navigation feature needs a list of plants with their
 * section so it can show the catalogue and guide the user. It must NOT call T's
 * Garden API directly from the phone: that API uses the dip_agent OAuth
 * credentials, which must never ship in the APK. So the app calls THIS callable,
 * which reuses the agent's credential-safe, cached data layer (dal.ts) on the
 * server side.
 *
 * Modes (all bounded — never sweeps the whole DB):
 *   • { search }            → plants whose taxon name matches (type-to-find)
 *   • { section }           → every plant placed in that section
 *   • { } (no args)         → a small recent slice (so the list isn't empty)
 *
 * This is READ-ONLY. Writes still go through the agent's guarded write path.
 */

import { onCall, HttpsError } from "firebase-functions/v2/https";
import { logger } from "firebase-functions/v2";
import { enforceRateLimit } from "./ratelimit";
import { GARDEN_API_USER, GARDEN_API_PASS } from "./agent/garden_api";
import { findPlantInstances, listCandidates } from "./agent/dal";

interface CataloguePlant {
  id: string;          // hankintaID (acquisition) — unique physical plant
  taxon: string;       // scientific name
  section: string;     // osaston_koodi (section code), "" if unknown
  sectionName: string; // osaston_nimi (human section label)
  status: string;      // kasvin_status, "" if unknown
}

export const plantsCatalogue = onCall(
  {
    cors: true,
    timeoutSeconds: 60, // headroom for T's cold start (per-call capped at 11s in dal)
    memory: "512MiB",
    minInstances: 0,
    enforceAppCheck: false,
    secrets: [GARDEN_API_USER, GARDEN_API_PASS],
  },
  async (req) => {
    if (!req.auth) {
      throw new HttpsError("unauthenticated", "Sign-in required to browse plants.");
    }
    await enforceRateLimit(req.auth.uid, "plantsCatalogue");

    const { search, section, limit } = (req.data ?? {}) as {
      search?: string;
      section?: string;
      limit?: number;
    };
    const cap = Math.min(Math.max(limit ?? 40, 1), 60);

    try {
      let plants: CataloguePlant[];

      if (search && search.trim().length >= 2) {
        const rows = await findPlantInstances(search.trim(), section, cap);
        plants = rows.map((i) => ({
          id: String(i.hankintaID),
          taxon: i.scientific_name,
          section: i.section_code ?? "",
          sectionName: i.location_label ?? "",
          status: i.status ?? "",
        }));
      } else {
        // Section browse, or default recent slice when no args.
        const rows = await listCandidates(
          section ? { section_code: section, limit: cap } : { limit: cap }
        );
        plants = rows.map((c) => ({
          id: String(c.hankintaID),
          taxon: c.scientific_name,
          section: c.section_code ?? "",
          sectionName: c.location_label ?? "",
          status: "",
        }));
      }

      return { plants };
    } catch (e) {
      logger.error("plantsCatalogue.failed", { err: String(e) });
      // Specific, retryable message — same spirit as the agent's classifier.
      throw new HttpsError(
        "unavailable",
        "The garden database is slow or unavailable right now. Please try again in a moment."
      );
    }
  }
);

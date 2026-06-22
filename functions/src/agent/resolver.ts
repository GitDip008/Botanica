/**
 * Plant resolver — Phase 4: real candidates from the bundled SQLite DB.
 *
 * Narrows the universe before the LLM sees a single token:
 *   1. QR/NFC scan        → exact hankintaID → list of 1
 *   2. Indoor cell tapped → plants in that greenhouse section
 *   3. Outdoor GPS        → section code → plants in that section
 *   4. No signals         → one candidate per taxon (test DB has 20 taxa,
 *                           manageable in the prompt; production will require
 *                           a location signal or name search)
 */

import { listCandidates } from "./dal";

export interface LocationContext {
  scanned_hankintaID?: number;
  indoor_cell_label?: string;
  outdoor_section_code?: string;
  gps?: { lat: number; lng: number };
}

export interface PlantCandidate {
  hankintaID: number;
  taksonin_nro: number;
  scientific_name: string;
  common_name_en?: string;
  common_name_fi?: string;
  section_code?: string;
  location_label?: string;
}

export async function resolveCandidates(
  context?: LocationContext
): Promise<PlantCandidate[]> {
  // Each resolver step is wrapped: T's API is flaky, and a candidate-resolution
  // failure must NEVER crash the turn — we just fall back to an empty set and
  // let the LLM resolve the plant by name via find_plant.
  try {
    if (context?.scanned_hankintaID) {
      const exact = await listCandidates({ hankintaID: context.scanned_hankintaID });
      if (exact.length) return exact;
    }
    // Indoor cells ARE section codes in this garden (G-HA, G-HD, ...).
    const section = context?.indoor_cell_label ?? context?.outdoor_section_code;
    if (section) {
      const inSection = await listCandidates({ section_code: section });
      if (inSection.length) return dedupeByTaxon(inSection);
    }
  } catch (_) {
    // fall through to empty
  }
  // No location/scan signal → no pre-resolved candidates. The LLM uses
  // find_plant to look up the plant by name (production DB is far too large to
  // slice generically, and doing so cost 20+ API calls per turn).
  return [];
}

function dedupeByTaxon(all: PlantCandidate[]): PlantCandidate[] {
  const seen = new Set<number>();
  const out: PlantCandidate[] = [];
  for (const c of all) {
    if (!seen.has(c.taksonin_nro)) {
      seen.add(c.taksonin_nro);
      out.push(c);
    }
  }
  return out.slice(0, 25);
}

/**
 * Data-access layer — now backed by T's production REST API (PostgreSQL).
 *
 * Replaces the bundled SQLite. Every function keeps its previous return shape
 * but is now ASYNC (REST calls). Reads fan out to a handful of endpoints and
 * are bounded with page_size caps so a single agent turn never sweeps the whole
 * DB. The production data is clean UTF-8, so fixEncoding is now mostly a
 * whitespace tidier kept for backward compatibility.
 *
 * See garden_api.ts for auth + the HTTP client.
 */

import type { PlantCandidate } from "./resolver";
import { apiList, apiGetOne } from "./garden_api";

/** Legacy latin1 mangling ('|'=ö '{'=ä '}'=å) is gone in production data, but
 *  keep the cleanup as a no-op-ish safety net + collapse stray tabs/spaces. */
export function fixEncoding(s: string | null | undefined): string {
  if (!s) return "";
  return s
    .replace(/\|/g, "ö")
    .replace(/\{/g, "ä")
    .replace(/\}/g, "å")
    .replace(/\s+/g, " ")
    .trim();
}

// Tiny per-instance cache so repeated taxon-name lookups in one turn are cheap.
const _taxonNameCache = new Map<number, string>();

async function taxonName(taksonin_nro: number): Promise<string> {
  if (_taxonNameCache.has(taksonin_nro)) return _taxonNameCache.get(taksonin_nro)!;
  const rows = await apiList<any>("/api/taksoni/", { taksonin_nro, page_size: 1 });
  const name = fixEncoding(rows[0]?.tieteellinen_nimi);
  _taxonNameCache.set(taksonin_nro, name);
  return name;
}

// ─── Candidates ─────────────────────────────────────────────────────────────

export interface CandidateFilter {
  section_code?: string;
  hankintaID?: number;
  name_query?: string;
  limit?: number;
}

export async function listCandidates(filter: CandidateFilter = {}): Promise<PlantCandidate[]> {
  const limit = Math.min(filter.limit ?? 25, 50);

  // 1. Exact acquisition lookup.
  if (filter.hankintaID) {
    const h = await apiGetOne<any>(`/api/hankintatiedot/${filter.hankintaID}`);
    if (!h) return [];
    const placements = await apiList<any>(`/api/hankintatiedot/${h.hankintaID}/osastopaikka`, { page_size: 1 });
    return [
      {
        hankintaID: h.hankintaID,
        taksonin_nro: h.taksonin_nro,
        scientific_name: await taxonName(h.taksonin_nro),
        section_code: placements[0]?.osaston_koodi ?? undefined,
        location_label: fixEncoding(placements[0]?.osaston_nimi) || undefined,
      },
    ];
  }

  // 2. Everything in a section: osastopaikka rows carry hankintaID + section.
  if (filter.section_code) {
    const rows = await apiList<any>("/api/osastopaikka/", {
      osaston_koodi: filter.section_code,
      page_size: limit,
    });
    return Promise.all(
      rows.slice(0, limit).map(async (r) => {
        const h = await apiGetOne<any>(`/api/hankintatiedot/${r.hankintaID}`);
        return {
          hankintaID: r.hankintaID,
          taksonin_nro: h?.taksonin_nro,
          scientific_name: h ? await taxonName(h.taksonin_nro) : "",
          section_code: r.osaston_koodi ?? undefined,
          location_label: fixEncoding(r.osaston_nimi) || undefined,
        } as PlantCandidate;
      })
    );
  }

  // 3. Name search → taxa → their acquisitions (parallel, flattened, capped).
  if (filter.name_query) {
    const taxa = await apiList<any>("/api/taksoni/", { search: filter.name_query, page_size: 10 });
    const perTaxon = await Promise.all(
      taxa.map(async (t) => {
        const haks = await apiList<any>(`/api/taksoni/${t.taksonin_nro}/hankintatiedot`, { page_size: 5 });
        return haks.map((h) => ({
          hankintaID: h.hankintaID,
          taksonin_nro: t.taksonin_nro,
          scientific_name: fixEncoding(t.tieteellinen_nimi),
        }));
      })
    );
    return perTaxon.flat().slice(0, limit);
  }

  // 4. No filter → a small recent slice (anti-hallucination fallback set).
  const taxa = await apiList<any>("/api/taksoni/", { page_size: Math.min(limit, 20) });
  const perTaxon = await Promise.all(
    taxa.map(async (t) => {
      const haks = await apiList<any>(`/api/taksoni/${t.taksonin_nro}/hankintatiedot`, { page_size: 1 });
      return haks[0]
        ? [{ hankintaID: haks[0].hankintaID, taksonin_nro: t.taksonin_nro, scientific_name: fixEncoding(t.tieteellinen_nimi) }]
        : [];
    })
  );
  return perTaxon.flat();
}

// ─── Plant instances (for disambiguation: same species, many physical plants) ─

export interface PlantInstance {
  hankintaID: number;
  taksonin_nro: number;
  scientific_name: string;
  section_code?: string;
  location_label?: string;
  status?: string;
}

async function enrichInstance(h: any, name: string): Promise<PlantInstance> {
  // Tolerate a flaky placement lookup — return the plant without section rather
  // than failing the whole list (T's API has transient 5xx).
  let p: any;
  try {
    const placements = await apiList<any>(`/api/hankintatiedot/${h.hankintaID}/osastopaikka`, { page_size: 1 });
    p = placements[0];
  } catch {
    p = undefined;
  }
  return {
    hankintaID: h.hankintaID,
    taksonin_nro: h.taksonin_nro,
    scientific_name: name,
    section_code: p?.osaston_koodi ?? undefined,
    location_label: fixEncoding(p?.osaston_nimi) || undefined,
    status: fixEncoding(p?.kasvin_status) || undefined,
  };
}

/** Find physical plants by name (and optional section). Returns one entry per
 *  acquisition so the gardener can pick the SPECIFIC plant they mean. */
export async function findPlantInstances(
  nameQuery: string,
  sectionCode?: string,
  limit = 8
): Promise<PlantInstance[]> {
  const taxa = await apiList<any>("/api/taksoni/", { search: nameQuery, page_size: 6 });
  // Gather raw acquisitions (cheap) WITHOUT enriching yet.
  const hakLists = await Promise.all(
    taxa.map(async (t) => {
      const haks = await apiList<any>(`/api/taksoni/${t.taksonin_nro}/hankintatiedot`, { page_size: 8 });
      return haks.map((h) => ({ h, name: fixEncoding(t.tieteellinen_nimi) }));
    })
  );
  // Cap BEFORE the (costly) per-instance section lookups so we never make more
  // calls than we'll actually show. With a section filter we enrich a bounded
  // superset, then filter.
  const raw = hakLists.flat().slice(0, sectionCode ? 25 : limit);
  const enriched = await Promise.all(raw.map((x) => enrichInstance(x.h, x.name)));
  const filtered = sectionCode ? enriched.filter((i) => i.section_code === sectionCode) : enriched;
  return filtered.slice(0, limit);
}

/** Light verification for the write path — 1-2 cached calls instead of the
 *  full plantDetails fan-out. Returns null if the id doesn't exist. */
export async function verifyPlant(
  hankintaID: number
): Promise<{ taksonin_nro: number; scientific_name: string } | null> {
  const h = await apiGetOne<any>(`/api/hankintatiedot/${hankintaID}`);
  if (!h) return null;
  return { taksonin_nro: h.taksonin_nro, scientific_name: await taxonName(h.taksonin_nro) };
}

// ─── Fuzzy "did you mean" name suggestions (typo tolerance) ─────────────────

function levenshtein(a: string, b: string): number {
  const m = a.length, n = b.length;
  if (m === 0) return n;
  if (n === 0) return m;
  let prev = Array.from({ length: n + 1 }, (_, i) => i);
  let cur = new Array(n + 1).fill(0);
  for (let i = 1; i <= m; i++) {
    cur[0] = i;
    for (let j = 1; j <= n; j++) {
      const cost = a[i - 1] === b[j - 1] ? 0 : 1;
      cur[j] = Math.min(prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + cost);
    }
    [prev, cur] = [cur, prev];
  }
  return prev[n];
}

function similarity(a: string, b: string): number {
  a = a.toLowerCase().trim();
  b = b.toLowerCase().trim();
  const maxLen = Math.max(a.length, b.length) || 1;
  return 1 - levenshtein(a, b) / maxLen;
}

export interface NameSuggestion {
  taksonin_nro: number;
  scientific_name: string;
  score: number;
}

/**
 * When an exact/substring name lookup fails (typo), suggest the closest real
 * plant names. The genus (first word) is usually typed correctly, so we pull
 * candidates by genus and a short prefix, then rank by edit distance against
 * the full query. Keeps the candidate pool tiny — never scans all 11k taxa.
 */
export async function suggestSimilarPlants(query: string, limit = 4): Promise<NameSuggestion[]> {
  const q = query.trim();
  if (q.length < 3) return [];
  const firstToken = q.split(/\s+/)[0];
  const prefix = q.slice(0, 4);

  const [byGenus, byPrefix] = await Promise.all([
    apiList<any>("/api/taksoni/", { search: firstToken, page_size: 60 }),
    firstToken.toLowerCase() === prefix.toLowerCase()
      ? Promise.resolve([])
      : apiList<any>("/api/taksoni/", { search: prefix, page_size: 40 }),
  ]);

  const pool = new Map<number, string>();
  for (const t of [...byGenus, ...byPrefix]) {
    if (t?.taksonin_nro && t.tieteellinen_nimi) pool.set(t.taksonin_nro, fixEncoding(t.tieteellinen_nimi));
  }

  const ranked = [...pool.entries()]
    .map(([taksonin_nro, scientific_name]) => ({
      taksonin_nro,
      scientific_name,
      score: similarity(scientific_name, q),
    }))
    .filter((r) => r.score >= 0.5)
    .sort((a, b) => b.score - a.score)
    .slice(0, limit);

  return ranked;
}

/** All physical plants sharing a taxon — used to detect/resolve ambiguity. */
export async function plantInstances(taksonin_nro: number, limit = 12): Promise<PlantInstance[]> {
  const name = await taxonName(taksonin_nro);
  const haks = await apiList<any>(`/api/taksoni/${taksonin_nro}/hankintatiedot`, { page_size: limit });
  return Promise.all(haks.map((h) => enrichInstance(h, name)));
}

// ─── Plant details ──────────────────────────────────────────────────────────

export async function plantDetails(opts: {
  hankintaID?: number;
  taksonin_nro?: number;
  name_query?: string;
}) {
  let taxon: any | undefined;
  let hankintaID: number | undefined = opts.hankintaID;

  if (opts.hankintaID) {
    const h = await apiGetOne<any>(`/api/hankintatiedot/${opts.hankintaID}`);
    if (h) taxon = await apiGetOne<any>(`/api/taksoni/${h.taksonin_nro}`);
  } else if (opts.taksonin_nro) {
    taxon = await apiGetOne<any>(`/api/taksoni/${opts.taksonin_nro}`);
  } else if (opts.name_query) {
    const rows = await apiList<any>("/api/taksoni/", { search: opts.name_query, page_size: 1 });
    taxon = rows[0];
  }
  if (!taxon) return null;

  const [cultRows, family, synRows, placements] = await Promise.all([
    apiList<any>(`/api/taksoni/${taxon.taksonin_nro}/taksonin_viljelytiedot`, { page_size: 1 }),
    taxon.jarjestysnumero != null
      ? apiGetOne<any>(`/api/heimo/${taxon.jarjestysnumero}`)
      : Promise.resolve(null),
    apiList<any>(`/api/taksoni/${taxon.taksonin_nro}/synonyymi`, { page_size: 5 }),
    hankintaID
      ? apiList<any>(`/api/hankintatiedot/${hankintaID}/osastopaikka`, { page_size: 10 })
      : apiList<any>(`/api/taksoni/${taxon.taksonin_nro}/hankintatiedot`, { page_size: 1 }).then(
          (haks) =>
            haks[0]
              ? apiList<any>(`/api/hankintatiedot/${haks[0].hankintaID}/osastopaikka`, { page_size: 10 })
              : []
        ),
  ]);
  const cultivation = cultRows[0];

  return {
    taksonin_nro: taxon.taksonin_nro,
    hankintaID,
    scientific_name: fixEncoding(taxon.tieteellinen_nimi),
    genus: taxon.suku,
    family: family ? { latin: fixEncoding(family.nimi), finnish: fixEncoding(family.suom_nimi) } : null,
    synonyms: synRows.map((s) => fixEncoding(s.nimi)),
    general_notes: fixEncoding(taxon.muita_tietoja),
    cultivation: cultivation
      ? {
          // Gardener-only fields — dispatcher strips for visitors.
          pests_and_diseases: fixEncoding(cultivation.kasvitaudit_ja_tuholaiset),
          substrate: fixEncoding(cultivation.erityisia_kasvualustavaatimuksia),
          light: fixEncoding(cultivation.erityisia_valovaatimuksia),
          temperature: fixEncoding(cultivation.erityisia_lampotila_tai_talvehtimisvaatimuksia),
          growth_form: fixEncoding(cultivation.kasvumuoto),
          height: fixEncoding(cultivation.korkeus),
          hardiness: fixEncoding(cultivation.ilmastollinen_kestavyys),
          toxicity: fixEncoding(cultivation.myrkyllisyys),
          other: fixEncoding(cultivation.muita_viljelytietoja),
        }
      : null,
    placements: placements.map((p) => ({
      section_code: p.osaston_koodi,
      section_name: fixEncoding(p.osaston_nimi),
      status: fixEncoding(p.kasvin_status),
      location: fixEncoding(p.osaston_nimi),
      osaston_numero: p.osaston_numero,
    })),
  };
}

// ─── History ────────────────────────────────────────────────────────────────

export interface HistoryEntry {
  kind: "action" | "inspection";
  date: string;
  detail: string;
  inspector?: string;
  source: "legacy" | "agent";
}

export async function plantHistory(hankintaID: number, daysBack = 36500): Promise<HistoryEntry[]> {
  const since = new Date(Date.now() - daysBack * 86400_000).toISOString().slice(0, 10);

  // Actions are filterable straight by hankintaID.
  const actions = await apiList<any>("/api/toimenpide/", { hankintaID, page_size: 50 });

  // Inspections live under placements: plant → osastopaikka → sijoituspaikka →
  // tarkastusmerkinta. Bounded fan-out (≤5 placements × ≤5 spots).
  const osasto = await apiList<any>(`/api/hankintatiedot/${hankintaID}/osastopaikka`, { page_size: 5 });
  const spotLists = await Promise.all(
    osasto.map((o) => apiList<any>(`/api/osastopaikka/${o.osaston_numero}/sijoituspaikka`, { page_size: 5 }))
  );
  const spots = spotLists.flat();
  const inspLists = await Promise.all(
    spots.map((s) =>
      apiList<any>(`/api/sijoituspaikka/${s.sijoituspaikan_nro}/tarkastusmerkinta`, { page_size: 20 })
    )
  );
  const inspections = inspLists.flat();

  const out: HistoryEntry[] = [
    ...actions
      .filter((a) => (a.uus_pvm ?? "") >= since || daysBack >= 36500)
      .map((a) => ({
        kind: "action" as const,
        date: a.uus_pvm ?? a.pvm ?? "",
        detail: fixEncoding(a.toimenpide),
        source: "legacy" as const,
      })),
    ...inspections
      .filter((i) => (i.uus_tarkastuspvm ?? "") >= since || daysBack >= 36500)
      .map((i) => ({
        kind: "inspection" as const,
        date: i.uus_tarkastuspvm ?? i.tarkastuspvm ?? "",
        detail:
          [
            i.elavia_yksiloita ? `${fixEncoding(i.elavia_yksiloita)} kpl` : "",
            fixEncoding(i.menestymista_koskevat_havainnot),
          ]
            .filter(Boolean)
            .join(", ") || "(no detail)",
        inspector: i.tarkastaja ?? undefined,
        source: "legacy" as const,
      })),
  ];
  out.sort((a, b) => (b.date > a.date ? 1 : -1));
  return out.slice(0, 50);
}

// ─── Overdue inspections (section-scoped to stay bounded) ───────────────────

export async function overdueInspections(daysThreshold = 365, sectionCode?: string) {
  const cutoff = new Date(Date.now() - daysThreshold * 86400_000).toISOString().slice(0, 10);
  if (!sectionCode) {
    // A garden-wide scan would sweep every plant — require a section to stay
    // within a sensible request budget.
    return [];
  }

  const rows = await apiList<any>("/api/osastopaikka/", { osaston_koodi: sectionCode, page_size: 25 });
  const out: {
    hankintaID: number;
    scientific_name: string;
    section_code: string;
    last_inspected: string | null;
  }[] = [];

  await Promise.all(
    rows.slice(0, 25).map(async (r) => {
      const spots = await apiList<any>(`/api/osastopaikka/${r.osaston_numero}/sijoituspaikka`, { page_size: 5 });
      let last = "";
      await Promise.all(
        spots.map(async (s) => {
          const insp = await apiList<any>(
            `/api/sijoituspaikka/${s.sijoituspaikan_nro}/tarkastusmerkinta`,
            { page_size: 50 }
          );
          for (const i of insp) {
            const d = i.uus_tarkastuspvm ?? "";
            if (d > last) last = d;
          }
        })
      );
      if (last === "" || last < cutoff) {
        const h = await apiGetOne<any>(`/api/hankintatiedot/${r.hankintaID}`);
        out.push({
          hankintaID: r.hankintaID,
          scientific_name: h ? await taxonName(h.taksonin_nro) : "",
          section_code: r.osaston_koodi,
          last_inspected: last || null,
        });
      }
    })
  );
  out.sort((a, b) => (a.last_inspected ?? "") < (b.last_inspected ?? "") ? -1 : 1);
  return out.slice(0, 25);
}

// ─── Section legend (the G-H*/K-*/T-* decoder) ──────────────────────────────

export async function sectionLegend(): Promise<{ code: string; name: string }[]> {
  const rows = await apiList<any>("/api/osastopaikka/", { page_size: 200 });
  const seen = new Map<string, string>();
  for (const r of rows) {
    if (r.osaston_koodi && !seen.has(r.osaston_koodi)) {
      seen.set(r.osaston_koodi, fixEncoding(r.osaston_nimi).replace(/^\S+\s*/, "").trim());
    }
  }
  return [...seen.entries()].map(([code, name]) => ({ code, name }));
}

/** Resolve the most recent sijoituspaikan_nro for a plant — needed when the
 *  agent writes a new inspection (tarkastusmerkinta FK). */
export async function latestPlacementNro(hankintaID: number): Promise<number | null> {
  const osasto = await apiList<any>(`/api/hankintatiedot/${hankintaID}/osastopaikka`, { page_size: 5 });
  const spotLists = await Promise.all(
    osasto.map((o) => apiList<any>(`/api/osastopaikka/${o.osaston_numero}/sijoituspaikka`, { page_size: 20 }))
  );
  let best: number | null = null;
  for (const s of spotLists.flat()) {
    if (best == null || s.sijoituspaikan_nro > best) best = s.sijoituspaikan_nro;
  }
  return best;
}

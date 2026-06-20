/**
 * Data-access layer — reads from T's bundled SQLite test database.
 *
 * The .sqlite file is deployed alongside the function code (548 KB). The
 * Cloud Functions filesystem is read-only, which is fine for reads; WRITES
 * go to a Firestore ledger instead (see writes.ts) holding the exact SQL
 * that will later run against the production MySQL. History queries merge
 * both sources so gardeners immediately see their own entries.
 *
 * Swap plan (Phase 10): replace this module with the production REST client.
 * The function signatures stay identical.
 */

import Database from "better-sqlite3";
import * as path from "node:path";
import type { PlantCandidate } from "./resolver";

let _db: Database.Database | null = null;

function db(): Database.Database {
  if (!_db) {
    const file = path.join(process.cwd(), "test_database.sqlite");
    _db = new Database(file, { readonly: true, fileMustExist: true });
  }
  return _db;
}

/** Legacy latin1 mangling: '|'=ö '{'=ä '}'=å — normalize when displaying. */
export function fixEncoding(s: string | null | undefined): string {
  if (!s) return "";
  return s.replace(/\|/g, "ö").replace(/\{/g, "ä").replace(/\}/g, "å");
}

// ─── Candidates ─────────────────────────────────────────────────────────────

export interface CandidateFilter {
  section_code?: string;
  hankintaID?: number;
  name_query?: string;
  limit?: number;
}

export function listCandidates(filter: CandidateFilter = {}): PlantCandidate[] {
  const limit = Math.min(filter.limit ?? 25, 50);
  const clauses: string[] = [];
  const params: Record<string, unknown> = { limit };

  if (filter.hankintaID) {
    clauses.push("h.hankintaID = :hankintaID");
    params.hankintaID = filter.hankintaID;
  }
  if (filter.section_code) {
    clauses.push("op.osaston_koodi = :section");
    params.section = filter.section_code;
  }
  if (filter.name_query) {
    clauses.push("(t.tieteellinen_nimi LIKE :q OR t.suku LIKE :q)");
    params.q = `%${filter.name_query}%`;
  }
  const where = clauses.length ? `WHERE ${clauses.join(" AND ")}` : "";

  const rows = db()
    .prepare(
      `SELECT h.hankintaID, h.taksonin_nro, t.tieteellinen_nimi,
              op.osaston_koodi,
              (SELECT sp.sijoituspaikan_nimi FROM sijoituspaikka sp
                WHERE sp.osaston_numero = op.osaston_numero
                ORDER BY sp.sijoituspaikan_nro DESC LIMIT 1) AS loc
       FROM hankintatiedot h
       JOIN taksoni t ON t.taksonin_nro = h.taksonin_nro
       LEFT JOIN osastopaikka op ON op.osaston_numero =
         (SELECT op2.osaston_numero FROM osastopaikka op2
           WHERE op2.hankintaID = h.hankintaID
           ORDER BY op2.osaston_numero DESC LIMIT 1)
       ${where}
       GROUP BY h.hankintaID
       LIMIT :limit`
    )
    .all(params) as any[];

  return rows.map((r) => ({
    hankintaID: r.hankintaID,
    taksonin_nro: r.taksonin_nro,
    scientific_name: fixEncoding(r.tieteellinen_nimi),
    section_code: r.osaston_koodi ?? undefined,
    location_label: fixEncoding(r.loc) || undefined,
  }));
}

// ─── Plant details ──────────────────────────────────────────────────────────

export function plantDetails(opts: { hankintaID?: number; taksonin_nro?: number; name_query?: string }) {
  let taxonRow: any | undefined;
  let hankintaRow: any | undefined;

  if (opts.hankintaID) {
    hankintaRow = db()
      .prepare("SELECT * FROM hankintatiedot WHERE hankintaID = ?")
      .get(opts.hankintaID);
    if (hankintaRow) {
      taxonRow = db()
        .prepare("SELECT * FROM taksoni WHERE taksonin_nro = ?")
        .get(hankintaRow.taksonin_nro);
    }
  } else if (opts.taksonin_nro) {
    taxonRow = db()
      .prepare("SELECT * FROM taksoni WHERE taksonin_nro = ?")
      .get(opts.taksonin_nro);
  } else if (opts.name_query) {
    taxonRow = db()
      .prepare("SELECT * FROM taksoni WHERE tieteellinen_nimi LIKE ? LIMIT 1")
      .get(`%${opts.name_query}%`);
  }
  if (!taxonRow) return null;

  const cultivation = db()
    .prepare("SELECT * FROM taksonin_viljelytiedot WHERE taksonin_nro = ?")
    .get(taxonRow.taksonin_nro) as any;
  const family = db()
    .prepare("SELECT nimi, suom_nimi FROM heimo WHERE jarjestysnumero = ?")
    .get(taxonRow.jarjestysnumero) as any;
  const synonyms = db()
    .prepare("SELECT nimi FROM synonyymi WHERE taksonin_nro = ? LIMIT 5")
    .all(taxonRow.taksonin_nro) as any[];
  const placements = db()
    .prepare(
      `SELECT op.osaston_koodi, op.osaston_nimi, op.kasvin_status,
              sp.sijoituspaikan_nimi
       FROM osastopaikka op
       LEFT JOIN sijoituspaikka sp ON sp.osaston_numero = op.osaston_numero
       WHERE op.hankintaID IN (
         SELECT hankintaID FROM hankintatiedot WHERE taksonin_nro = ?
       ) LIMIT 10`
    )
    .all(taxonRow.taksonin_nro) as any[];

  return {
    taksonin_nro: taxonRow.taksonin_nro,
    hankintaID: hankintaRow?.hankintaID,
    scientific_name: fixEncoding(taxonRow.tieteellinen_nimi),
    genus: taxonRow.suku,
    family: family ? { latin: family.nimi, finnish: fixEncoding(family.suom_nimi) } : null,
    synonyms: synonyms.map((s) => fixEncoding(s.nimi)),
    general_notes: fixEncoding(taxonRow.muita_tietoja),
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
      section_name: fixEncoding(p.osaston_nimi).replace(/\s+/g, " "),
      status: fixEncoding(p.kasvin_status),
      location: fixEncoding(p.sijoituspaikan_nimi),
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

export function plantHistory(hankintaID: number, daysBack = 36500): HistoryEntry[] {
  const since = new Date(Date.now() - daysBack * 86400_000)
    .toISOString()
    .slice(0, 10);

  const actions = db()
    .prepare(
      `SELECT COALESCE(uus_pvm, pvm) AS d, toimenpide AS detail
       FROM toimenpide
       WHERE hankintaID = ? AND COALESCE(uus_pvm, '') >= ?
       ORDER BY d DESC LIMIT 50`
    )
    .all(hankintaID, since) as any[];

  const inspections = db()
    .prepare(
      `SELECT COALESCE(tm.uus_tarkastuspvm, tm.tarkastuspvm) AS d,
              tm.menestymista_koskevat_havainnot AS detail,
              tm.elavia_yksiloita AS count, tm.tarkastaja
       FROM tarkastusmerkinta tm
       JOIN sijoituspaikka sp ON sp.sijoituspaikan_nro = tm.sijoituspaikan_nro
       JOIN osastopaikka op ON op.osaston_numero = sp.osaston_numero
       WHERE op.hankintaID = ? AND COALESCE(tm.uus_tarkastuspvm, '') >= ?
       ORDER BY d DESC LIMIT 50`
    )
    .all(hankintaID, since) as any[];

  const out: HistoryEntry[] = [
    ...actions.map((a) => ({
      kind: "action" as const,
      date: a.d ?? "",
      detail: fixEncoding(a.detail),
      source: "legacy" as const,
    })),
    ...inspections.map((i) => ({
      kind: "inspection" as const,
      date: i.d ?? "",
      detail:
        [i.count ? `${fixEncoding(i.count)} kpl` : "", fixEncoding(i.detail)]
          .filter(Boolean)
          .join(", ") || "(no detail)",
      inspector: i.tarkastaja ?? undefined,
      source: "legacy" as const,
    })),
  ];
  out.sort((a, b) => (b.date > a.date ? 1 : -1));
  return out;
}

// ─── Overdue inspections ────────────────────────────────────────────────────

export function overdueInspections(daysThreshold = 365, sectionCode?: string) {
  const cutoff = new Date(Date.now() - daysThreshold * 86400_000)
    .toISOString()
    .slice(0, 10);
  const rows = db()
    .prepare(
      `SELECT h.hankintaID, t.tieteellinen_nimi, op.osaston_koodi,
              MAX(COALESCE(tm.uus_tarkastuspvm, '')) AS last_seen
       FROM hankintatiedot h
       JOIN taksoni t ON t.taksonin_nro = h.taksonin_nro
       LEFT JOIN osastopaikka op ON op.hankintaID = h.hankintaID
       LEFT JOIN sijoituspaikka sp ON sp.osaston_numero = op.osaston_numero
       LEFT JOIN tarkastusmerkinta tm ON tm.sijoituspaikan_nro = sp.sijoituspaikan_nro
       WHERE (:section IS NULL OR op.osaston_koodi = :section)
       GROUP BY h.hankintaID
       HAVING last_seen = '' OR last_seen < :cutoff
       ORDER BY last_seen ASC
       LIMIT 25`
    )
    .all({ section: sectionCode ?? null, cutoff }) as any[];

  return rows.map((r) => ({
    hankintaID: r.hankintaID,
    scientific_name: fixEncoding(r.tieteellinen_nimi),
    section_code: r.osaston_koodi,
    last_inspected: r.last_seen || null,
  }));
}

// ─── Section legend (the G-H*/K-*/T-* decoder) ──────────────────────────────

export function sectionLegend(): { code: string; name: string }[] {
  const rows = db()
    .prepare("SELECT DISTINCT osaston_koodi, osaston_nimi FROM osastopaikka ORDER BY osaston_koodi")
    .all() as any[];
  return rows.map((r) => ({
    code: r.osaston_koodi,
    name: fixEncoding(r.osaston_nimi).replace(/\s+/g, " ").replace(/^\S+\s*/, "").trim(),
  }));
}

/** Resolve the most recent sijoituspaikan_nro for a plant — needed when the
 *  agent writes a new inspection (tarkastusmerkinta FK). */
export function latestPlacementNro(hankintaID: number): number | null {
  const row = db()
    .prepare(
      `SELECT sp.sijoituspaikan_nro
       FROM sijoituspaikka sp
       JOIN osastopaikka op ON op.osaston_numero = sp.osaston_numero
       WHERE op.hankintaID = ?
       ORDER BY sp.sijoituspaikan_nro DESC LIMIT 1`
    )
    .get(hankintaID) as any;
  return row?.sijoituspaikan_nro ?? null;
}

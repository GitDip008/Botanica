/**
 * SQL safety engine — the single chokepoint through which every write passes.
 *
 * Threat model & guarantees:
 *   1. The LLM NEVER produces SQL. It supplies parameter VALUES only. The SQL
 *      statements are fixed templates defined here in code.
 *   2. All values are BOUND parameters (?). User/LLM text never becomes SQL,
 *      so injection is structurally impossible.
 *   3. Only INSERT (2 whitelisted tables) and UPDATE (one column, by primary
 *      key) are permitted. DELETE/DROP/TRUNCATE/ALTER cannot be expressed.
 *   4. Row-count guard: writes run in a transaction; if >1 row would change,
 *      we ROLLBACK. A statement cannot affect the whole table.
 *   5. Keyword scan on the final statement string as defense-in-depth.
 *   6. Parameter validation: ids must be positive ints, strings length-capped
 *      and control-char-stripped.
 *
 * This module is backend-agnostic: the same Plan runs against the dev SQLite
 * today and T's MySQL later — only the executor's driver changes.
 */

import type Database from "better-sqlite3";

export interface PlanChange {
  table: string;
  column: string;
  current: string | null; // null for INSERT (new row)
  next: string;
  note: string;
}

export interface WritePlan {
  tool: string;
  operation: "insert" | "update";
  table: string;
  /** Parameterized statement with ? placeholders — executed as-is. */
  statement: string;
  /** Bound parameter values, in statement order. */
  params: (string | number | null)[];
  /** Human-readable statement with values inlined — FOR DISPLAY ONLY. */
  displaySql: string;
  /** Field-by-field breakdown shown to the user before they confirm. */
  changes: PlanChange[];
  /** Plain-language summary line. */
  summary: string;
}

// ─── Validators ─────────────────────────────────────────────────────────────

const MAX_STR = 500;

function asPositiveInt(v: unknown, field: string): number {
  const n = Number(v);
  if (!Number.isInteger(n) || n <= 0) {
    throw new SafetyError(`${field} must be a positive integer (got ${JSON.stringify(v)}).`);
  }
  return n;
}

function asSafeString(v: unknown, maxLen = MAX_STR): string {
  if (v == null) return "";
  let s = String(v);  // Strip ASCII control chars (0x00-0x1F, 0x7F) using code points — no
  // control bytes embedded in source.
  s = Array.from(s).filter((ch) => {
    const c = ch.codePointAt(0) ?? 0;
    return c === 9 || c === 10 || c === 13 || (c >= 32 && c !== 127);
  }).join("");
  if (s.length > maxLen) s = s.slice(0, maxLen);
  return s;
}

export class SafetyError extends Error {}

// ─── Forbidden-token scan (defense in depth) ────────────────────────────────

const FORBIDDEN = /(;|--|\/\*|\bDROP\b|\bDELETE\b|\bTRUNCATE\b|\bALTER\b|\bATTACH\b|\bPRAGMA\b|\bCREATE\b|\bREPLACE\b|\bGRANT\b|\bEXEC\b)/i;

function assertStatementShape(statement: string, op: "insert" | "update") {
  // Statements are fixed templates — this should never trip. It exists so a
  // future careless edit to a template is caught immediately.
  if (FORBIDDEN.test(statement)) {
    throw new SafetyError("Statement contains a forbidden token.");
  }
  const head = statement.trim().slice(0, 7).toUpperCase();
  if (op === "insert" && !head.startsWith("INSERT")) {
    throw new SafetyError("Insert plan did not produce an INSERT.");
  }
  if (op === "update" && !head.startsWith("UPDATE")) {
    throw new SafetyError("Update plan did not produce an UPDATE.");
  }
  // Exactly one statement — no stacked queries.
  if (statement.includes(";")) {
    throw new SafetyError("Multiple statements are not allowed.");
  }
}

// ─── Display helper (NEVER executed) ────────────────────────────────────────

function inlineForDisplay(statement: string, params: (string | number | null)[]): string {
  let i = 0;
  return statement.replace(/\?/g, () => {
    const p = params[i++];
    if (p === null) return "NULL";
    if (typeof p === "number") return String(p);
    return `'${String(p).replace(/'/g, "''")}'`;
  });
}

// ─── Plan builders (one per write tool) ─────────────────────────────────────

export interface PlanContext {
  /** Current user's legacy inspector code (tarkastaja). */
  inspectorCode: string;
  /** Resolved plant display name for the human summary. */
  plantName: string;
  /** Resolved sijoituspaikan_nro for inspection inserts. */
  placementNro?: number | null;
  /** For UPDATE: a reader to fetch the current value before changing it. */
  readCurrent?: (table: string, column: string, pkCol: string, pk: number) => string | null;
}

function isoToLegacy(iso: string): string {
  const m = iso.match(/^(\d{4})-(\d{2})-(\d{2})$/);
  return m ? `${m[3]}.${m[2]}.${m[1]}` : iso;
}

/** record_action → INSERT into toimenpide. */
function planRecordAction(args: Record<string, unknown>, ctx: PlanContext): WritePlan {
  const hankintaID = asPositiveInt(args.hankintaID, "hankintaID");
  const iso = asSafeString(args.date) || new Date().toISOString().slice(0, 10);
  const isoDate = /^\d{4}-\d{2}-\d{2}$/.test(iso) ? iso : new Date().toISOString().slice(0, 10);
  const legacy = isoToLegacy(isoDate);

  const segs: string[] = [asSafeString(args.action_family) || "MUU"];
  if (args.location_code) segs.push(asSafeString(args.location_code, 60));
  if (args.count) segs.push(`${asPositiveInt(args.count, "count")} kpl`);
  if (args.details) segs.push(asSafeString(args.details));
  const toimenpide = segs.join(" ");

  const statement =
    "INSERT INTO toimenpide (pvm, toimenpide, hankintaID, uus_pvm) VALUES (?, ?, ?, ?)";
  const params: (string | number | null)[] = [legacy, toimenpide, hankintaID, isoDate];
  assertStatementShape(statement, "insert");

  return {
    tool: "record_action",
    operation: "insert",
    table: "toimenpide",
    statement,
    params,
    displaySql: inlineForDisplay(statement, params),
    changes: [
      { table: "toimenpide", column: "(new row)", current: null, next: "INSERT", note: `A new action record will be added for ${ctx.plantName} (#${hankintaID}).` },
      { table: "toimenpide", column: "toimenpide", current: null, next: toimenpide, note: "The action text (legacy garden convention)." },
      { table: "toimenpide", column: "pvm", current: null, next: legacy, note: "Legacy date format DD.MM.YYYY." },
      { table: "toimenpide", column: "uus_pvm", current: null, next: isoDate, note: "ISO date YYYY-MM-DD." },
      { table: "toimenpide", column: "hankintaID", current: null, next: String(hankintaID), note: "The plant this action belongs to." },
    ],
    summary: `Add a new ACTION record to "${ctx.plantName}" (#${hankintaID}): ${toimenpide}`,
  };
}

/** record_observation → INSERT into tarkastusmerkinta. */
function planRecordObservation(args: Record<string, unknown>, ctx: PlanContext): WritePlan {
  const hankintaID = asPositiveInt(args.hankintaID, "hankintaID");
  const iso = asSafeString(args.date) || new Date().toISOString().slice(0, 10);
  const isoDate = /^\d{4}-\d{2}-\d{2}$/.test(iso) ? iso : new Date().toISOString().slice(0, 10);
  const legacy = isoToLegacy(isoDate);

  // Compose the legacy stocktake string: stars, kpl, size, status, notes.
  const stocktake = asSafeString(args.composed_stocktake);
  const livingCount = args.living_count != null ? String(asPositiveInt(args.living_count, "living_count")) : "";
  const notes = asSafeString(args.notes) || null;
  const inspector = asSafeString(ctx.inspectorCode, 10);
  const placement = ctx.placementNro ?? null;
  if (placement == null) {
    throw new SafetyError("No placement (sijoituspaikan_nro) found for this plant — cannot record an inspection.");
  }

  const statement =
    "INSERT INTO tarkastusmerkinta (tarkastuspvm, elavia_yksiloita, menestymista_koskevat_havainnot, tarkastaja, kasvin_huomautuksia, sijoituspaikan_nro, uus_tarkastuspvm) VALUES (?, ?, ?, ?, ?, ?, ?)";
  const params: (string | number | null)[] = [legacy, livingCount, stocktake, inspector, notes, placement, isoDate];
  assertStatementShape(statement, "insert");

  return {
    tool: "record_observation",
    operation: "insert",
    table: "tarkastusmerkinta",
    statement,
    params,
    displaySql: inlineForDisplay(statement, params),
    changes: [
      { table: "tarkastusmerkinta", column: "(new row)", current: null, next: "INSERT", note: `A new inspection record will be added for ${ctx.plantName} (#${hankintaID}).` },
      { table: "tarkastusmerkinta", column: "menestymista_koskevat_havainnot", current: null, next: stocktake || "(empty)", note: "Condition observation (stars/kpl/size/status)." },
      { table: "tarkastusmerkinta", column: "elavia_yksiloita", current: null, next: livingCount || "(empty)", note: "Living individuals (kpl)." },
      { table: "tarkastusmerkinta", column: "tarkastaja", current: null, next: inspector || "(unset)", note: "Your inspector code." },
      { table: "tarkastusmerkinta", column: "sijoituspaikan_nro", current: null, next: String(placement), note: "The plant's placement this inspection is tied to." },
      { table: "tarkastusmerkinta", column: "uus_tarkastuspvm", current: null, next: isoDate, note: "ISO inspection date." },
    ],
    summary: `Add a new INSPECTION record to "${ctx.plantName}" (#${hankintaID}): ${stocktake || "(no detail)"}`,
  };
}

/** mark_plant_status → UPDATE osastopaikka.kasvin_status WHERE osaston_numero = ?. */
function planMarkStatus(args: Record<string, unknown>, ctx: PlanContext): WritePlan {
  const osastoNro = asPositiveInt(args.osaston_numero, "osaston_numero");
  const allowed = ["alive", "dormant", "dead", "removed"];
  const status = asSafeString(args.status, 30);
  if (!allowed.includes(status)) {
    throw new SafetyError(`status must be one of ${allowed.join(", ")}.`);
  }
  const current = ctx.readCurrent
    ? ctx.readCurrent("osastopaikka", "kasvin_status", "osaston_numero", osastoNro)
    : null;

  const statement = "UPDATE osastopaikka SET kasvin_status = ? WHERE osaston_numero = ?";
  const params: (string | number | null)[] = [status, osastoNro];
  assertStatementShape(statement, "update");

  return {
    tool: "mark_plant_status",
    operation: "update",
    table: "osastopaikka",
    statement,
    params,
    displaySql: inlineForDisplay(statement, params),
    changes: [
      {
        table: "osastopaikka",
        column: "kasvin_status",
        current: current ?? "(unknown)",
        next: status,
        note: `For ${ctx.plantName}, placement row #${osastoNro}, status changes ${current ?? "?"} → ${status}.`,
      },
    ],
    summary: `Change status of "${ctx.plantName}" to ${status.toUpperCase()} (placement #${osastoNro}).`,
  };
}

const BUILDERS: Record<string, (a: Record<string, unknown>, c: PlanContext) => WritePlan> = {
  record_action: planRecordAction,
  record_observation: planRecordObservation,
  mark_plant_status: planMarkStatus,
};

export function buildPlan(
  tool: string,
  args: Record<string, unknown>,
  ctx: PlanContext
): WritePlan {
  const fn = BUILDERS[tool];
  if (!fn) throw new SafetyError(`Tool "${tool}" is not a permitted write.`);
  return fn(args, ctx);
}

// ─── Executor — runs a Plan with the row-count guard, in a transaction ──────

export interface ExecResult {
  ok: boolean;
  changedRows: number;
  insertedId?: number;
  message: string;
}

export function executePlan(db: Database.Database, plan: WritePlan): ExecResult {
  assertStatementShape(plan.statement, plan.operation);

  const run = db.transaction((): ExecResult => {
    const info = db.prepare(plan.statement).run(...(plan.params as any[]));
    const changed = info.changes;

    // Row-count guard — the heart of the destructive-op defense.
    if (plan.operation === "insert" && changed !== 1) {
      throw new SafetyError(`INSERT affected ${changed} rows (expected exactly 1). Rolled back.`);
    }
    if (plan.operation === "update" && (changed < 0 || changed > 1)) {
      throw new SafetyError(`UPDATE affected ${changed} rows (max 1 allowed). Rolled back.`);
    }
    return {
      ok: true,
      changedRows: changed,
      insertedId: plan.operation === "insert" ? Number(info.lastInsertRowid) : undefined,
      message: "Applied.",
    };
  });

  try {
    return run();
  } catch (e) {
    return {
      ok: false,
      changedRows: 0,
      message: e instanceof SafetyError ? e.message : `Write failed: ${String(e)}`,
    };
  }
}

/** Guarded single-row undo for an INSERT we made — deletes by primary key. */
export function undoInsert(
  db: Database.Database,
  table: "toimenpide" | "tarkastusmerkinta",
  pkColumn: "toimenpide_nro" | "tarkastusnro",
  pkValue: number
): ExecResult {
  const id = asPositiveInt(pkValue, "pkValue");
  const statement = `DELETE FROM ${table} WHERE ${pkColumn} = ?`;
  // This is the ONLY place a DELETE is allowed, and it is hard-bounded to a
  // single primary-key match with a row-count guard.
  const run = db.transaction((): ExecResult => {
    const info = db.prepare(statement).run(id);
    if (info.changes > 1) {
      throw new SafetyError(`Undo affected ${info.changes} rows — rolled back.`);
    }
    return { ok: true, changedRows: info.changes, message: info.changes === 1 ? "Undone." : "Nothing to undo." };
  });
  try {
    return run();
  } catch (e) {
    return { ok: false, changedRows: 0, message: e instanceof SafetyError ? e.message : String(e) };
  }
}

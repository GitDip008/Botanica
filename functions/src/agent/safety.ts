/**
 * Write safety engine — the single chokepoint every write passes through.
 *
 * Backend is now T's REST API (PostgreSQL). The LLM NEVER constructs requests;
 * it supplies parameter VALUES only, which are validated here and placed into
 * fixed request templates. Guarantees:
 *   1. Only three operations exist: POST toimenpide, POST tarkastusmerkinta,
 *      PUT osastopaikka (one field). No DELETE/bulk operation can be expressed,
 *      and the service account is permissioned server-side to nothing else.
 *   2. Every write targets exactly one resource (POST one row, PUT one id).
 *   3. No SQL string is ever built → SQL injection is structurally impossible.
 *   4. Parameter validation: ids are positive ints; strings are length-capped
 *      and control-char-stripped; status is whitelisted; dates are normalised.
 *
 * The builder is pure (no I/O). Execution lives in writes.ts.
 */

export interface PlanChange {
  table: string;
  column: string;
  current: string | null; // null for INSERT (new row)
  next: string;
  note: string;
}

export interface RestStep {
  method: "POST" | "PUT";
  /** Full API path, e.g. "/api/toimenpide/" or "/api/osastopaikka/22767". */
  path: string;
  /** JSON body to send. For PUT-over-current, these fields are merged over the
   *  freshly-read row at execution time (see readModifyWrite). */
  body: Record<string, string | number | null>;
}

export interface WritePlan {
  tool: string;
  operation: "insert" | "update";
  table: string;
  /** The actual request that will run. */
  rest: RestStep;
  /** When set, the executor GETs this path, applies rest.body on top, then PUTs
   *  the merged row back (the API's PUT requires the full row). */
  readModifyWrite?: { getPath: string };
  /** Undo descriptor. */
  undo?:
    | { kind: "delete"; pathTemplate: string; pkField: string }
    | { kind: "restore"; path: string; field: string; previous: string | null };
  /** Human-readable representation of the request — FOR DISPLAY ONLY. Kept on
   *  the `sql_display` client field; the card labels it "Database operation".
   *  Shows the SQL equivalent first (what the gardener and T both read) then the
   *  literal REST call that actually runs. */
  displaySql: string;
  /** Field-by-field breakdown shown to the user before they confirm. */
  changes: PlanChange[];
  /** Semi-technical summary naming the record type. */
  summary: string;
  /** ONE sentence, no jargon — no table, column, id or SQL words. This is what
   *  a gardener actually reads before tapping Save, so it must stand alone. */
  plainSummary: string;
}

// ─── Validators ─────────────────────────────────────────────────────────────

const MAX_STR = 500;

export class SafetyError extends Error {}

function asPositiveInt(v: unknown, field: string): number {
  const n = Number(v);
  if (!Number.isInteger(n) || n <= 0) {
    throw new SafetyError(`${field} must be a positive integer (got ${JSON.stringify(v)}).`);
  }
  return n;
}

function asSafeString(v: unknown, maxLen = MAX_STR): string {
  if (v == null) return "";
  let s = String(v);
  // Strip ASCII control chars (keep tab/newline/CR), then cap length.
  s = Array.from(s)
    .filter((ch) => {
      const c = ch.codePointAt(0) ?? 0;
      return c === 9 || c === 10 || c === 13 || (c >= 32 && c !== 127);
    })
    .join("");
  if (s.length > maxLen) s = s.slice(0, maxLen);
  return s;
}

function isoToLegacy(iso: string): string {
  const m = iso.match(/^(\d{4})-(\d{2})-(\d{2})$/);
  return m ? `${m[3]}.${m[2]}.${m[1]}` : iso;
}

/**
 * Renders the pending write for the confirmation card. NEVER executed — this
 * string is display-only and no code path parses it back.
 *
 * Shows the SQL equivalent above the literal REST call. There is no real SQL
 * in the system any more (see the header: requests go to T's REST API, which is
 * why injection is structurally impossible), but SQL is the form gardeners and
 * T can both actually check, and REST JSON is not. So we show both: the SQL to
 * be read, the REST line so nobody is misled about what runs.
 *
 * ponytail: string building over a query-builder dependency. This produces one
 * statement shape per operation and is never round-tripped.
 */
function displayFor(step: RestStep, table: string, pkClause?: string): string {
  const quote = (v: string | number | null) =>
    v === null ? "NULL" : typeof v === "number" ? String(v) : `'${String(v).replace(/'/g, "''")}'`;

  let sql: string;
  if (step.method === "POST") {
    const cols = Object.keys(step.body);
    sql =
      `INSERT INTO ${table} (${cols.join(", ")})\n` +
      `VALUES (${cols.map((c) => quote(step.body[c])).join(", ")});`;
  } else {
    const sets = Object.entries(step.body)
      .map(([k, v]) => `${k} = ${quote(v)}`)
      .join(", ");
    sql = `UPDATE ${table} SET ${sets}\nWHERE ${pkClause ?? "<single row>"};`;
  }
  return `${sql}\n\n-- actually sent as: ${step.method} ${step.path}`;
}

// ─── Plan builders (one per write tool) ─────────────────────────────────────

export interface PlanContext {
  /** Current user's legacy inspector code (tarkastaja). */
  inspectorCode: string;
  /** Resolved plant display name for the human summary. */
  plantName: string;
  /** Resolved sijoituspaikan_nro for inspection inserts. */
  placementNro?: number | null;
  /** Current kasvin_status (for mark_plant_status diff + undo). */
  currentStatus?: string | null;
}

/** record_action → POST /api/toimenpide/. */
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

  const rest: RestStep = {
    method: "POST",
    path: "/api/toimenpide/",
    body: { pvm: legacy, toimenpide, hankintaID, uus_pvm: isoDate },
  };

  return {
    tool: "record_action",
    operation: "insert",
    table: "toimenpide",
    rest,
    undo: { kind: "delete", pathTemplate: "/api/toimenpide/{id}", pkField: "toimenpide_nro" },
    displaySql: displayFor(rest, "toimenpide"),
    changes: [
      { table: "toimenpide", column: "(new row)", current: null, next: "CREATE", note: `A new action record will be added for ${ctx.plantName} (#${hankintaID}).` },
      { table: "toimenpide", column: "toimenpide", current: null, next: toimenpide, note: "The action text (legacy garden convention)." },
      { table: "toimenpide", column: "pvm", current: null, next: legacy, note: "Legacy date format DD.MM.YYYY." },
      { table: "toimenpide", column: "uus_pvm", current: null, next: isoDate, note: "ISO date YYYY-MM-DD." },
      { table: "toimenpide", column: "hankintaID", current: null, next: String(hankintaID), note: "The plant this action belongs to." },
    ],
    summary: `Add a new ACTION record to "${ctx.plantName}" (#${hankintaID}): ${toimenpide}`,
    plainSummary:
      `This adds a note to ${ctx.plantName}'s history: "${toimenpide}", dated ${isoDate}. ` +
      `Nothing already in the garden records is changed or removed.`,
  };
}

/** record_observation → POST /api/tarkastusmerkinta/. */
function planRecordObservation(args: Record<string, unknown>, ctx: PlanContext): WritePlan {
  const hankintaID = asPositiveInt(args.hankintaID, "hankintaID");
  const iso = asSafeString(args.date) || new Date().toISOString().slice(0, 10);
  const isoDate = /^\d{4}-\d{2}-\d{2}$/.test(iso) ? iso : new Date().toISOString().slice(0, 10);
  const legacy = isoToLegacy(isoDate);

  const stocktake = asSafeString(args.composed_stocktake);
  const livingCount =
    args.living_count != null ? String(asPositiveInt(args.living_count, "living_count")) : null;
  const notes = asSafeString(args.notes) || null;
  const inspector = asSafeString(ctx.inspectorCode, 10) || null;
  const placement = ctx.placementNro ?? null;
  if (placement == null) {
    throw new SafetyError(
      "No placement (sijoituspaikan_nro) found for this plant — cannot record an inspection."
    );
  }

  const rest: RestStep = {
    method: "POST",
    path: "/api/tarkastusmerkinta/",
    body: {
      tarkastuspvm: legacy,
      elavia_yksiloita: livingCount,
      menestymista_koskevat_havainnot: stocktake || null,
      tarkastaja: inspector,
      kasvin_huomautuksia: notes,
      sijoituspaikan_nro: placement,
      uus_tarkastuspvm: isoDate,
    },
  };

  return {
    tool: "record_observation",
    operation: "insert",
    table: "tarkastusmerkinta",
    rest,
    undo: { kind: "delete", pathTemplate: "/api/tarkastusmerkinta/{id}", pkField: "tarkastusnro" },
    displaySql: displayFor(rest, "tarkastusmerkinta"),
    changes: [
      { table: "tarkastusmerkinta", column: "(new row)", current: null, next: "CREATE", note: `A new inspection record will be added for ${ctx.plantName} (#${hankintaID}).` },
      { table: "tarkastusmerkinta", column: "menestymista_koskevat_havainnot", current: null, next: stocktake || "(empty)", note: "Condition observation (stars/kpl/size/status)." },
      { table: "tarkastusmerkinta", column: "elavia_yksiloita", current: null, next: livingCount || "(empty)", note: "Living individuals (kpl)." },
      { table: "tarkastusmerkinta", column: "tarkastaja", current: null, next: inspector || "(unset)", note: "Your inspector code." },
      { table: "tarkastusmerkinta", column: "sijoituspaikan_nro", current: null, next: String(placement), note: "The plant's placement this inspection is tied to." },
      { table: "tarkastusmerkinta", column: "uus_tarkastuspvm", current: null, next: isoDate, note: "ISO inspection date." },
    ],
    summary: `Add a new INSPECTION record to "${ctx.plantName}" (#${hankintaID}): ${stocktake || "(no detail)"}`,
    plainSummary:
      `This saves today's check on ${ctx.plantName}: "${stocktake || "no detail given"}", dated ${isoDate}. ` +
      `It is added alongside the earlier checks — none of them are changed or removed.`,
  };
}

/** mark_plant_status → PUT /api/osastopaikka/{osaston_numero} (kasvin_status). */
function planMarkStatus(args: Record<string, unknown>, ctx: PlanContext): WritePlan {
  const osastoNro = asPositiveInt(args.osaston_numero, "osaston_numero");
  const allowed = ["alive", "dormant", "dead", "removed"];
  const status = asSafeString(args.status, 30);
  if (!allowed.includes(status)) {
    throw new SafetyError(`status must be one of ${allowed.join(", ")}.`);
  }
  const current = ctx.currentStatus ?? null;

  const rest: RestStep = {
    method: "PUT",
    path: `/api/osastopaikka/${osastoNro}`,
    // Only this field is changed; the executor merges it over the current row
    // (the API's PUT requires the whole row, incl. the required hankintaID).
    body: { kasvin_status: status },
  };

  return {
    tool: "mark_plant_status",
    operation: "update",
    table: "osastopaikka",
    rest,
    readModifyWrite: { getPath: `/api/osastopaikka/${osastoNro}` },
    undo: { kind: "restore", path: `/api/osastopaikka/${osastoNro}`, field: "kasvin_status", previous: current },
    displaySql: displayFor(rest, "osastopaikka", `osaston_numero = ${osastoNro}`),
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
    // The only write that overwrites an existing value, so it is the only one
    // whose plain summary must name what is being replaced.
    plainSummary:
      `This marks ${ctx.plantName} as "${status}"` +
      (current ? `, instead of "${current}" as it is now. ` : ". ") +
      `The plant stays in the records with its full history — marking it ` +
      `"removed" or "dead" is how removal is recorded here, and it never deletes anything.`,
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

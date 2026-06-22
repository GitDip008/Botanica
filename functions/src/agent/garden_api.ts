/**
 * Garden Information System — production REST client.
 *
 * Replaces the bundled SQLite (dal.ts) and the GCS write-DB (live_db.ts) with
 * T's FastAPI service (PostgreSQL-backed). Auth is OAuth2 password flow:
 * we exchange the service-account username/password for a bearer token and
 * cache it in memory between calls (tokens are re-fetched on 401).
 *
 * Credentials come from Firebase secrets GARDEN_API_USER / GARDEN_API_PASS —
 * they are NEVER hard-coded or shipped in the app.
 *
 * Safety note: the service account is permissioned by T to read all tables,
 * CREATE only `toimenpide` + `tarkastusmerkinta`, and UPDATE only
 * `osastopaikka`. Any other write is rejected server-side — the API itself is
 * now the strongest guard against destructive operations.
 */

import { defineSecret } from "firebase-functions/params";
import { logger } from "firebase-functions/v2";

export const GARDEN_API_USER = defineSecret("GARDEN_API_USER");
export const GARDEN_API_PASS = defineSecret("GARDEN_API_PASS");

const BASE = "https://web-database-six.vercel.app";

// ─── Token cache (per warm instance) ────────────────────────────────────────
let _token: string | null = null;
let _tokenExpiry = 0; // epoch ms

async function fetchToken(): Promise<string> {
  const body = new URLSearchParams();
  body.set("username", GARDEN_API_USER.value());
  body.set("password", GARDEN_API_PASS.value());

  const res = await fetch(`${BASE}/api/auth/token`, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: body.toString(),
  });
  if (!res.ok) {
    const txt = await res.text().catch(() => "");
    throw new GardenApiError(
      `Auth failed (${res.status}). Check GARDEN_API_USER/PASS secrets. ${txt.slice(0, 120)}`,
      res.status
    );
  }
  const json = (await res.json()) as { access_token?: string; expires_in?: number };
  if (!json.access_token) throw new GardenApiError("Auth response had no access_token.", 500);
  _token = json.access_token;
  // Default to 25 min if the API doesn't say; refresh a minute early.
  const ttl = (json.expires_in ?? 1800) * 1000;
  _tokenExpiry = Date.now() + ttl - 60_000;
  return _token;
}

async function token(): Promise<string> {
  if (_token && Date.now() < _tokenExpiry) return _token;
  return fetchToken();
}

export class GardenApiError extends Error {
  status: number;
  constructor(message: string, status: number) {
    super(message);
    this.status = status;
  }
}

// ─── Core request (auto re-auths once on 401) ───────────────────────────────
async function request<T>(
  method: "GET" | "POST" | "PUT" | "DELETE",
  path: string,
  opts: { query?: Record<string, string | number | undefined>; body?: unknown; retried?: boolean } = {}
): Promise<T> {
  let url = `${BASE}${path}`;
  if (opts.query) {
    const qs = new URLSearchParams();
    for (const [k, v] of Object.entries(opts.query)) {
      if (v !== undefined && v !== null && v !== "") qs.set(k, String(v));
    }
    const s = qs.toString();
    if (s) url += `?${s}`;
  }

  const headers: Record<string, string> = { Authorization: `Bearer ${await token()}` };
  if (opts.body !== undefined) headers["Content-Type"] = "application/json";

  // Bound each call so one slow cold-start can't consume the whole turn budget.
  // On abort we treat it like a transient 5xx (GET retries once below).
  const ctrl = new AbortController();
  const timer = setTimeout(() => ctrl.abort(), 11_000);
  let res: Response;
  try {
    res = await fetch(url, {
      method,
      headers,
      body: opts.body !== undefined ? JSON.stringify(opts.body) : undefined,
      signal: ctrl.signal,
    });
  } catch (e) {
    clearTimeout(timer);
    if (method === "GET" && !opts.retried) {
      return request<T>(method, path, { ...opts, retried: true });
    }
    throw new GardenApiError(`${method} ${path} timed out or failed: ${String(e)}`, 504);
  }
  clearTimeout(timer);

  // Token expired/revoked → refresh once and retry.
  if (res.status === 401 && !opts.retried) {
    _token = null;
    return request<T>(method, path, { ...opts, retried: true });
  }
  // T's API has flaky cold starts (transient 5xx). Retry a GET once after a
  // short pause — never retry writes (not idempotent).
  if (res.status >= 500 && method === "GET" && !opts.retried) {
    await new Promise((r) => setTimeout(r, 600));
    return request<T>(method, path, { ...opts, retried: true });
  }
  if (!res.ok) {
    const txt = await res.text().catch(() => "");
    throw new GardenApiError(
      `${method} ${path} → ${res.status}. ${txt.slice(0, 200)}`,
      res.status
    );
  }
  if (res.status === 204) return undefined as T;
  return (await res.json()) as T;
}

// ─── GET cache (per warm instance, short TTL) ───────────────────────────────
// Reads dominate agent latency. A small TTL cache makes repeated lookups in a
// turn (and re-searching the same plant) instant, without serving stale data
// for long. Writes bypass it and clear it (see apiPost/apiPut/apiDelete).
const CACHE_TTL_MS = 45_000;
const _cache = new Map<string, { exp: number; data: unknown }>();

function cacheGet<T>(key: string): T | undefined {
  const hit = _cache.get(key);
  if (hit && hit.exp > Date.now()) return hit.data as T;
  if (hit) _cache.delete(key);
  return undefined;
}
function cacheSet(key: string, data: unknown): void {
  if (_cache.size > 800) _cache.clear(); // simple cap
  _cache.set(key, { exp: Date.now() + CACHE_TTL_MS, data });
}
/** Drop the read cache after any write so the next read reflects the change. */
export function clearReadCache(): void {
  _cache.clear();
}

// ─── Public helpers ─────────────────────────────────────────────────────────

/** List endpoints return { items: [...] } (paginated). Returns the items. */
export async function apiList<T = any>(
  path: string,
  query: Record<string, string | number | undefined> = {}
): Promise<T[]> {
  const key = `L:${path}?${JSON.stringify(query)}`;
  const cached = cacheGet<T[]>(key);
  if (cached) return cached;
  const out = await request<{ items?: T[] } | T[]>("GET", path, { query });
  const items = Array.isArray(out) ? out : out.items ?? [];
  cacheSet(key, items);
  return items;
}

/** Single-resource GET. Returns null on 404. */
export async function apiGetOne<T = any>(
  path: string,
  query: Record<string, string | number | undefined> = {}
): Promise<T | null> {
  const key = `O:${path}?${JSON.stringify(query)}`;
  const cached = cacheGet<T | null>(key);
  if (cached !== undefined) return cached;
  try {
    const data = await request<T>("GET", path, { query });
    cacheSet(key, data);
    return data;
  } catch (e) {
    if (e instanceof GardenApiError && e.status === 404) {
      cacheSet(key, null);
      return null;
    }
    throw e;
  }
}

export async function apiPost<T = any>(path: string, body: unknown): Promise<T> {
  const r = await request<T>("POST", path, { body });
  clearReadCache();
  return r;
}

export async function apiPut<T = any>(path: string, body: unknown): Promise<T> {
  const r = await request<T>("PUT", path, { body });
  clearReadCache();
  return r;
}

/** DELETE — used only by the guarded single-row undo. May throw GardenApiError
 *  with status 403 if the service account lacks delete permission. */
export async function apiDelete(path: string): Promise<void> {
  await request<void>("DELETE", path, {});
  clearReadCache();
}

/** Cheap connectivity/auth probe for diagnostics. */
export async function apiWhoAmI(): Promise<{ username?: string; role_name?: string }> {
  try {
    return await request("GET", "/api/auth/users/me");
  } catch (e) {
    logger.error("garden_api.whoami_failed", { err: String(e) });
    throw e;
  }
}

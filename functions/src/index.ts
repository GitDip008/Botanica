// deploy-stamp: 1781990523 (app check unenforced for sideloaded/GitHub distribution)
/**
 * Botanica Cloud Functions
 * ------------------------
 * 1. onPublicEventApproved   FCM push when an admin approves a public event
 * 2. scrapeHolidayHours      Twice-yearly scrape of oulu.fi for holiday hours
 *                            On failure, writes scrapeError so the admin
 *                            panel shows an alert and asks the admin to edit.
 */
import { onDocumentUpdated } from "firebase-functions/v2/firestore";
import { onSchedule } from "firebase-functions/v2/scheduler";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { defineSecret } from "firebase-functions/params";
import { logger, setGlobalOptions } from "firebase-functions/v2";
import * as admin from "firebase-admin";

admin.initializeApp();
setGlobalOptions({ region: "europe-north1" });

// Smart Agent (see functions/src/agent/)
export { agent, agentConfirm, agentUpdateMode } from "./agent";
export { plantsCatalogue } from "./catalogue";
import { enforceRateLimit } from "./ratelimit";
import { apiList, GARDEN_API_USER, GARDEN_API_PASS } from "./agent/garden_api";

// ─── Secrets (set with: firebase functions:secrets:set GROQ_API_KEY) ─────────
const GROQ_API_KEY = defineSecret("GROQ_API_KEY");
const PLANTNET_API_KEY = defineSecret("PLANTNET_API_KEY");
const GEMINI_API_KEY = defineSecret("GEMINI_API_KEY");

// ─── Keep T's garden API warm ────────────────────────────────────────────────
// T's API (Vercel) cold-starts in 5-25s after idle, which is the agent's main
// source of lag. A light authenticated ping every 5 minutes keeps the serverless
// function AND its DB connection warm, so real user requests stay fast.
// Region europe-west1 because Cloud Scheduler is not available in europe-north1.
export const keepGardenApiWarm = onSchedule(
  {
    schedule: "*/5 * * * *",
    region: "europe-west1",
    secrets: [GARDEN_API_USER, GARDEN_API_PASS],
    timeoutSeconds: 30,
    memory: "256MiB",
  },
  async () => {
    try {
      const t0 = Date.now();
      await apiList("/api/taksoni/", { page_size: 1 }); // tiny authed read warms auth + DB
      logger.info("garden_api.warm_ok", { ms: Date.now() - t0 });
    } catch (e) {
      // A failed ping is harmless — the next one runs in 5 minutes.
      logger.warn("garden_api.warm_failed", { err: String(e) });
    }
  }
);

// ─── 1. FCM push on public event approval ────────────────────────────────────
export const onPublicEventApproved = onDocumentUpdated(
  "events/{eventId}",
  async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();
    if (!before || !after) return;

    const justApproved =
      before.status !== "approved" && after.status === "approved";
    const isPublic = after.isPublic === true;
    if (!justApproved || !isPublic) return;

    const name = (after.name as string) ?? "New event";
    const dateIso = after.date as string | undefined;
    const startTime = (after.startTime as string) ?? "";
    let dateLabel = "";
    if (dateIso) {
      try {
        const d = new Date(dateIso);
        dateLabel = d.toLocaleDateString("en-GB", {
          weekday: "short",
          day: "numeric",
          month: "short",
        });
      } catch {
        dateLabel = dateIso;
      }
    }
    const body = [dateLabel, startTime].filter(Boolean).join(" · ");

    const message: admin.messaging.Message = {
      topic: "public_events",
      notification: {
        title: `🌿 New event at the garden: ${name}`,
        body: body || (after.description as string) || "Tap for details",
      },
      data: {
        eventId: event.params.eventId,
        type: "public_event",
      },
      android: {
        priority: "high",
        notification: { channelId: "public_events" },
      },
    };

    try {
      const id = await admin.messaging().send(message);
      logger.info(`Public event notification sent: ${id}`);
    } catch (e) {
      logger.error("Failed to send notification", e);
    }
  }
);

// ─── 2. Twice-yearly holiday-hours scrape ────────────────────────────────────
//
// Schedule explained:
//   - "0 3 1 1,7 *"  = at 03:00 on the 1st of January AND the 1st of July
//   - Time zone: Helsinki (matches the garden)
//
// If the scrape parses fewer than 3 entries, OR fails entirely, we write a
// `scrapeError` field to /config/holiday_hours so the admin panel shows a
// banner asking staff to update manually.
//
export const scrapeHolidayHours = onSchedule(
  // Cloud Scheduler has no europe-north1; pin to europe-west1 like scrapeOuluEvents.
  { schedule: "0 3 1 1,7 *", timeZone: "Europe/Helsinki", region: "europe-west1" },
  async () => {
    const doc = admin.firestore().doc("config/holiday_hours");
    try {
      const res = await fetch(
        "https://www.oulu.fi/en/university/botanical-garden"
      );
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      const html = await res.text();
      const entries = parseHolidayHours(html);
      if (entries.length < 3) {
        throw new Error(`Only parsed ${entries.length} entries`);
      }
      await doc.set(
        {
          entries,
          lastUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
          lastUpdateSource: "auto",
          scrapeError: null,
        },
        { merge: true }
      );
      logger.info(`Scraped ${entries.length} holiday entries`);
    } catch (e: any) {
      logger.error("Holiday scrape failed", e);
      await doc.set(
        {
          scrapeError: String(e?.message ?? e),
          scrapeErrorAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true }
      );
    }
  }
);

/**
 * Parses oulu.fi's holiday-hours block into entries.
 * Looks for lines like:
 *   "Good Friday 3rd April closed"
 *   "Sat 4th April 10 -16"
 */
function parseHolidayHours(html: string): { label: string; hours: string }[] {
  // Strip HTML tags, normalise whitespace
  const text = html
    .replace(/<[^>]+>/g, "\n")
    .replace(/&nbsp;/g, " ")
    .replace(/&amp;/g, "&");

  const lines = text
    .split("\n")
    .map((l) => l.trim())
    .filter((l) => l.length > 0);

  const out: { label: string; hours: string }[] = [];
  const closedRe = /\bclosed\b/i;
  const rangeRe = /(\d{1,2})(?::(\d{2}))?\s*[-–—]\s*(\d{1,2})(?::(\d{2}))?/;
  const monthRe =
    /(january|february|march|april|may|june|july|august|september|october|november|december|jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)/i;

  for (const line of lines) {
    // Must mention a month — otherwise it's not a holiday row
    if (!monthRe.test(line)) continue;

    if (closedRe.test(line)) {
      const label = line.replace(closedRe, "").trim().replace(/\s+/g, " ");
      if (label) out.push({ label, hours: "Closed" });
      continue;
    }
    const m = line.match(rangeRe);
    if (m) {
      const start = `${m[1]}${m[2] ? ":" + m[2] : ""}`;
      const end = `${m[3]}${m[4] ? ":" + m[4] : ""}`;
      const hours = `${start} – ${end}`;
      const label = line.substring(0, m.index!).trim().replace(/\s+/g, " ");
      if (label) out.push({ label, hours });
    }
  }
  return out;
}

// ─── 3. Groq chat proxy ──────────────────────────────────────────────────────
// Replaces direct Flutter → Groq calls so the API key never ships in the APK.
// Client just calls `httpsCallable('groqChat')` with messages + model.
export const groqChat = onCall(
  { secrets: [GROQ_API_KEY], cors: true, timeoutSeconds: 60, enforceAppCheck: false },
  async (req) => {
    if (!req.auth) {
      throw new HttpsError("unauthenticated", "Sign-in required.");
    }
    await enforceRateLimit(req.auth.uid, "groqChat");
    const { messages, model, temperature, maxTokens } = (req.data ?? {}) as {
      messages?: { role: string; content: string }[];
      model?: string;
      temperature?: number;
      maxTokens?: number;
    };
    if (!Array.isArray(messages) || messages.length === 0) {
      throw new HttpsError("invalid-argument", "messages required.");
    }
    // Never pass the client's model id straight through. Installed APKs carry
    // whatever model was current when they were built, and on 2026-08-18 Groq
    // removed every Llama model — so every phone in the field was asking for a
    // model that 404s. Honour the client's choice only if it is one we know
    // still exists; otherwise silently use the current default. This fixes
    // already-installed apps without shipping an update.
    const ALLOWED_MODELS = new Set([
      "openai/gpt-oss-120b",
      "openai/gpt-oss-20b",
      "qwen/qwen3.6-27b",
    ]);
    const chosen = model && ALLOWED_MODELS.has(model) ? model : "openai/gpt-oss-20b";
    if (model && !ALLOWED_MODELS.has(model)) {
      logger.warn("groqChat.stale_client_model", { requested: model, used: chosen });
    }
    const resp = await fetch("https://api.groq.com/openai/v1/chat/completions", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${GROQ_API_KEY.value()}`,
      },
      body: JSON.stringify({
        model: chosen,
        messages,
        temperature: temperature ?? 0.7,
        // gpt-oss models emit `reasoning` before `content` and both draw on
        // max_tokens, so a caller's modest budget produced an EMPTY reply with
        // finish_reason "length" — blank plant summaries, blank search results.
        // Floor the budget and keep reasoning short.
        max_tokens: Math.max(maxTokens ?? 600, 1200),
        ...(chosen.startsWith("openai/gpt-oss") ? { reasoning_effort: "low" } : {}),
      }),
    });
    if (resp.status === 429) {
      throw new HttpsError("resource-exhausted", "Rate limited — try again.");
    }
    if (!resp.ok) {
      const body = await resp.text();
      logger.error(`Groq ${resp.status}: ${body}`);
      throw new HttpsError("internal", `Chat error (${resp.status}).`);
    }
    const data = (await resp.json()) as { choices?: { message?: { content?: string } }[] };
    const reply = data.choices?.[0]?.message?.content ?? "";
    return { reply };
  }
);

// ─── 4. Gemini proxy (text + vision) ─────────────────────────────────────────
// Client calls `httpsCallable('geminiCall')` with:
//   { prompt: string, model?: string, imageBase64?: string, mimeType?: string }
// If imageBase64 is supplied, sends a multimodal request (vision).
export const geminiCall = onCall(
  {
    secrets: [GEMINI_API_KEY],
    cors: true,
    timeoutSeconds: 60,
    memory: "512MiB", // image payloads can be a few MB
    enforceAppCheck: false,
  },
  async (req) => {
    if (!req.auth) {
      throw new HttpsError("unauthenticated", "Sign-in required.");
    }
    await enforceRateLimit(req.auth.uid, "geminiCall");
    const { prompt, model, imageBase64, mimeType } = (req.data ?? {}) as {
      prompt?: string;
      model?: string;
      imageBase64?: string;
      mimeType?: string;
    };
    if (!prompt || typeof prompt !== "string") {
      throw new HttpsError("invalid-argument", "prompt required.");
    }
    const m = model ?? "gemini-2.0-flash";
    const url = `https://generativelanguage.googleapis.com/v1beta/models/${m}:generateContent?key=${GEMINI_API_KEY.value()}`;

    const parts: any[] = [];
    if (imageBase64) {
      parts.push({
        inlineData: {
          mimeType: mimeType ?? "image/jpeg",
          data: imageBase64,
        },
      });
    }
    parts.push({ text: prompt });

    const resp = await fetch(url, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ contents: [{ parts }] }),
    });
    if (!resp.ok) {
      const body = await resp.text();
      logger.error(`Gemini ${resp.status}: ${body}`);
      throw new HttpsError("internal", `Gemini error (${resp.status}).`);
    }
    const data = (await resp.json()) as {
      candidates?: { content?: { parts?: { text?: string }[] } }[];
    };
    const reply =
      data.candidates?.[0]?.content?.parts?.map((p) => p.text ?? "").join("") ?? "";
    return { reply };
  }
);

// ─── 5. Daily Oulu events scrape ─────────────────────────────────────────────
// Pulls https://www.oulu.fi/en/events every 24h, parses event cards, and
// upserts them as approved+public events in Firestore. Each event gets a
// stable ID derived from its source URL so re-runs don't create duplicates.
//
// Runs in europe-west1 because Cloud Scheduler doesn't support europe-north1.
// Cost: ~30 invocations/month — well inside the free tier.
export const scrapeOuluEvents = onSchedule(
  {
    schedule: "every 24 hours",
    timeZone: "Europe/Helsinki",
    region: "europe-west1",
    memory: "512MiB",
    timeoutSeconds: 120,
  },
  async () => {
    const sourcePage = "https://www.oulu.fi/en/events";
    try {
      const res = await fetch(sourcePage);
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      const html = await res.text();
      const events = parseOuluEvents(html);
      if (events.length === 0) {
        logger.warn("scrapeOuluEvents: parsed 0 events — page layout may have changed");
        return;
      }
      const db = admin.firestore();
      const batch = db.batch();
      const now = new Date().toISOString();
      for (const e of events) {
        const id = `oulu-${hashId(e.sourceUrl)}`;
        const ref = db.collection("events").doc(id);
        batch.set(
          ref,
          {
            id,
            userId: "scraper",
            userName: "Oulu University Events",
            userEmail: "events@oulu.fi",
            name: e.title,
            description: e.description || "See full details on oulu.fi",
            attendees: 0,
            date: e.dateIso,
            time: e.timeLabel,
            startTime: e.startTime || "",
            endTime: e.endTime || "",
            spaceRequirements: e.location || "",
            status: "approved",
            createdAt: now,
            isPublic: true,
            capacity: 0,
            rsvpUserIds: [],
            sourceUrl: e.sourceUrl,
            source: "oulu-events-scrape",
            lastScrapedAt: now,
          },
          { merge: true }
        );
      }
      await batch.commit();
      logger.info(`scrapeOuluEvents: upserted ${events.length} events`);
    } catch (err) {
      logger.error("scrapeOuluEvents failed", err);
    }
  }
);

// ── Helpers ──────────────────────────────────────────────────────────────────

type ScrapedEvent = {
  title: string;
  sourceUrl: string;
  dateIso: string;
  timeLabel: string;
  startTime?: string;
  endTime?: string;
  description?: string;
  location?: string;
};

// Cheap stable hash for doc IDs derived from URLs.
function hashId(s: string): string {
  let h = 0;
  for (let i = 0; i < s.length; i++) {
    h = (h * 31 + s.charCodeAt(i)) | 0;
  }
  return Math.abs(h).toString(36);
}

// Defensive HTML parser. Looks for <a href="/en/events/..."> anchors as the
// primary anchor point — every event tile on oulu.fi has one. Around each
// anchor we look for a nearby <time datetime="..."> tag for the date and
// reasonable surrounding text for title + description.
function parseOuluEvents(html: string): ScrapedEvent[] {
  const events: ScrapedEvent[] = [];
  const seen = new Set<string>();

  // Find event-page anchors
  const anchorRe = /<a\s+[^>]*href="(\/en\/events\/[^"#?]+)"[^>]*>([\s\S]*?)<\/a>/gi;
  let m: RegExpExecArray | null;
  while ((m = anchorRe.exec(html)) !== null) {
    const href = m[1];
    if (seen.has(href)) continue;
    seen.add(href);

    const sourceUrl = `https://www.oulu.fi${href}`;
    // Title = strip tags from anchor inner HTML
    const title = stripTags(m[2]).trim();
    if (!title || title.length < 4) continue;

    // Find a <time datetime="..."> within ~3000 chars after the anchor
    const lookAhead = html.slice(m.index, m.index + 3000);
    const timeMatch = lookAhead.match(/<time[^>]+datetime="([^"]+)"/i);
    let dateIso = "";
    let timeLabel = "";
    let startTime = "";
    let endTime = "";
    if (timeMatch) {
      const dt = new Date(timeMatch[1]);
      if (!isNaN(dt.getTime())) {
        dateIso = dt.toISOString();
        const hh = String(dt.getUTCHours()).padStart(2, "0");
        const mm = String(dt.getUTCMinutes()).padStart(2, "0");
        startTime = `${hh}:${mm}`;
        timeLabel = startTime;
      }
    }
    // Fallback — skip events without a date
    if (!dateIso) continue;

    // Skip past events (anything older than today)
    if (new Date(dateIso).getTime() < Date.now() - 24 * 60 * 60 * 1000) continue;

    events.push({
      title,
      sourceUrl,
      dateIso,
      timeLabel,
      startTime,
      endTime,
      description: "",
    });
    if (events.length >= 30) break; // safety cap
  }
  return events;
}

function stripTags(s: string): string {
  return s
    .replace(/<[^>]+>/g, " ")
    .replace(/&nbsp;/g, " ")
    .replace(/&amp;/g, "&")
    .replace(/&#39;/g, "'")
    .replace(/&quot;/g, '"')
    .replace(/\s+/g, " ")
    .trim();
}

// ─── 6. PlantNet identification proxy ────────────────────────────────────────
// Keeps the PlantNet API key server-side. The app sends base64 image bytes;
// we forward to PlantNet with the secret key and return the raw results.
export const plantnetIdentify = onCall(
  {
    secrets: [PLANTNET_API_KEY],
    cors: true,
    timeoutSeconds: 40,
    memory: "512MiB", // image payloads
    enforceAppCheck: false,
  },
  async (req) => {
    if (!req.auth) {
      throw new HttpsError("unauthenticated", "Sign-in required.");
    }
    await enforceRateLimit(req.auth.uid, "plantnetIdentify");
    const { imageBase64, organs, lang } = (req.data ?? {}) as {
      imageBase64?: string;
      organs?: string;
      lang?: string;
    };
    if (!imageBase64) {
      throw new HttpsError("invalid-argument", "imageBase64 required.");
    }

    const url =
      `https://my-api.plantnet.org/v2/identify/all` +
      `?api-key=${PLANTNET_API_KEY.value()}&lang=${lang ?? "en"}`;

    // Build multipart form-data with the image + organ hint.
    const form = new FormData();
    const bytes = Buffer.from(imageBase64, "base64");
    form.append("images", new Blob([bytes], { type: "image/jpeg" }), "plant.jpg");
    form.append("organs", organs ?? "auto");

    const resp = await fetch(url, { method: "POST", body: form as any });

    if (resp.status === 404) {
      return { notFound: true };
    }
    if (!resp.ok) {
      const body = await resp.text();
      logger.error(`PlantNet ${resp.status}: ${body.slice(0, 300)}`);
      throw new HttpsError("internal", `PlantNet error (${resp.status}).`);
    }
    const data = (await resp.json()) as unknown;
    return { data };
  }
);

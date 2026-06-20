# Botanica Smart Agent — Full Implementation Plan

A single, sequenced plan covering everything: data work, agent build, navigation,
voice, confirmation flow, memory, launch. Solo build, parallelizable where possible.

---

## Phase 0 — Discovery week (3 days, do this NOW)

**Goal: know exactly what the data looks like before writing real code.**

| Day | Task | Output |
|---|---|---|
| 1 | Install DB Browser for SQLite. Open T's `test_database.sqlite`. Browse every table | A mental map of the data |
| 1 | Run `SELECT sijoituspaikan_nimi, COUNT(*) FROM sijoituspaikka GROUP BY 1 ORDER BY 2 DESC` | The complete indoor location vocabulary (~30–80 codes) |
| 1 | Run `SELECT toimenpide, COUNT(*) FROM toimenpide GROUP BY 1 ORDER BY 2 DESC LIMIT 50` | The action-code vocabulary (`ko`, `la`, `le`, etc.) |
| 2 | Sit with the head gardener (or the printed greenhouse map). Map each `sijoituspaikan_nimi` → floor-plan cell label | `indoor_translation.json` |
| 2 | Map each action code → human meaning. Build `action_codes.json` | `action_codes.json` |
| 3 | Write the 1-page **Agent Tools Spec** (`agent_tools.json`) listing all 12 tools with SQL templates | Single source of truth |
| 3 | Reply to T thanking him + asking nothing new | Goodwill banked |

**End of week 1:** you know what's possible, what's not, and you have all the vocabularies the agent needs hardcoded.

---

## Phase 1 — Foundation (Week 2)

**Goal: end-to-end mock pipeline. Real Flutter UI talking to a stub Cloud Function with hardcoded responses.**

### Cloud Function side
1. Create `functions/src/agent.ts` — single entry point `httpsCallable("agent")`
2. Auth check (Firebase Auth required)
3. Role lookup from Firestore `users/{uid}.role`
4. Tool registry — fixed catalog of 12 tools, each role-gated
5. Stub responses — return mocked plant data, mocked confirmation cards
6. Audit log every call to Firestore `audit_log/{auto_id}`

### Flutter side
7. New `AgentScreen` widget — chat thread + mic button + text input
8. New `agent_service.dart` — calls `httpsCallable("agent")`, manages pending actions
9. **Pending-action confirmation card** widget — title, summary, [Edit][Cancel][Save] buttons
10. Hardcode 3 test conversations (gardener fertilizes, visitor asks about Coffee, admin checks overdue) to validate the UI

**End of week 2:** working demo with fake data. Clear demo to T, navigation team, and anyone watching.

---

## Phase 2 — Real LLM with tool calling (Week 3)

**Goal: replace stub responses with Groq + Gemini fallback.**

11. Wire `groqChat` with `tools:[]` parameter (Groq's OpenAI-compatible API supports it)
12. System prompt builder — injects: user role, recent session memory (stub for now), available tools
13. Tool-call parser — extracts JSON tool calls from Groq response, validates against catalog
14. Retry-with-Gemini layer — if Groq fails or returns malformed JSON, fall back to Gemini Flash
15. Build the **plant resolver** — input: text + current GPS/cell context → output: list of 5-20 candidate plants. Bypasses LLM hallucination.
16. Pass candidate list into LLM context: "Here are the 8 plants near you, pick from these only"

**End of week 3:** the LLM actually understands gardener intent and picks the right tool — but still on SQLite.

---

## Phase 3 — Voice in, voice out (Week 4)

**Goal: hands-free operation. Critical for gardeners holding muddy gloves.**

17. Spin up Whisper container on Cloud Run (free tier). Docker image: `onerahmet/openai-whisper-asr-webservice` with `small` model
18. Flutter: add `flutter_sound` for recording. Push-to-talk button, not always-listening.
19. Audio uploaded to Cloud Run → Whisper transcribes → returns text + confidence
20. Pass `lang: "fi"` hint based on user's app language setting
21. Add `flutter_tts` for spoken-back confirmations: "I'll save: fertilized Valerian with compost. Confirm?"
22. **Offline queue** — failed STT or LLM calls cached in local SQLite. Background isolate retries when network returns.

**End of week 4:** Gardener can voice-record an update, hear it spoken back, confirm verbally. No more typing on a wet phone.

---

## Phase 4 — Real database integration (Week 5)

**Goal: agent reads and writes the actual SQLite test database.**

23. Cloud Function reads SQLite file via `better-sqlite3` (or host it as a tiny REST API for cleaner separation)
24. Implement READ tools first — `query_plant_details`, `query_plant_history`, `find_overdue_inspections`, `whats_blooming_now`, `find_nearby_plants`
25. **Always read from `uus_tarkastuspvm` / `uus_pvm` ISO columns**, never the legacy ones
26. Implement WRITE tools — `record_action`, `record_observation`, `update_cultivation_info`
27. **Always write to BOTH old and new date columns** to keep the legacy system happy (`pvm` in `DD.MM.YYYY`, `uus_pvm` in `YYYY-MM-DD`)
28. Auto-fill `tarkastaja` from logged-in user's `kayttajan_tunnus`
29. **Soft-delete pattern** — writes set `is_active=true`. Add `undo_last_action` tool that flips it to false. Nightly hard-delete after 24h.
30. Cache all 41 `lista_*` tables in memory on Cloud Function cold start
31. Full audit logging: every write captures user, transcript, LLM JSON, DB row IDs

**End of week 5:** real data flowing both directions. Test with 20 voice commands per role.

---

## Phase 5 — Indoor + outdoor navigation (Week 6)

**Goal: visitor and gardener can find any plant on the map.**

### Outdoor (GPS-based)
32. Open geojson.io, search "Oulu Botanical Garden", trace 20 biggest sections as polygons. Tag each with `osaston_koodi`
33. Save as `assets/maps/garden.geojson`, bundle in app
34. Flutter `MapScreen` with `flutter_map` + OSM tiles + section polygons overlay
35. Point-in-polygon: GPS → current `osaston_koodi`
36. **Outdoor route** — section centroid to section centroid, drawn as polyline. Not turn-by-turn, just "go to that area."

### Indoor (tap-based)
37. Save Romeo + Julia floor plan screenshots as `assets/maps/romeo.png`, `assets/maps/julia.png`
38. Use the `indoor_translation.json` from Phase 0
39. Flutter `IndoorMapScreen` — image + invisible tappable rectangles for each cell
40. Visitor taps "I'm in A8" → app stores current cell
41. Visitor picks a plant → agent returns DB code (e.g. `G-HA`) → JSON translates → `A8` → highlight on floor plan

### Unified agent tool
42. Add `navigate_to_plant(hankintaID)` tool:
    - Returns `{ type: "outdoor", section_code, route_geojson }` or
    - Returns `{ type: "indoor", floorplan, cell_label }`
43. Agent screen has "show me" button on every plant reference. Tap → opens the right map view.

**End of week 6:** "Where is the Cacao?" → indoor floor plan opens, A12 highlighted. "Where is the Valerian?" → outdoor map opens, route to Medicinal section drawn.

---

## Phase 6 — Tour planning (Week 7)

**Goal: visitor says "I have 30 minutes and like medicinal plants" — agent builds a real ordered tour.**

44. Tag ~50 "highlight" plants — either via a new `taksoni.is_highlight` flag (ask T to add the column or do it in your SQLite copy) or hardcode the list of `taksonin_nro`s
45. Build `find_highlight_plants(themes[], lang, limit)` tool — joins taksoni + viljelytiedot + sections for ~10 candidates
46. Build `compute_walking_route(start, visits[], budget_minutes)`:
    - Greedy seed: nearest unvisited highlight from current location
    - 2-opt local search: try swapping pairs, keep improvements
    - Hard cap on total time
47. Wire into agent: `plan_tour(duration, interests, language)` calls both
48. Format output as ordered list with section + cell names: "1. Valerian — Medicinal section (3 min walk, 2 min stop)"
49. Tap each tour stop → opens the navigation view for that plant

**End of week 7:** working tour generator. Visitors can leave with a personalized route.

---

## Phase 7 — Memory + intelligence (Week 8)

**Goal: agent feels like it actually remembers.**

50. Short-term: keep last 5 turns of conversation in session context, inject every LLM call
51. Long-term: at end of each session, summarize what was logged → embed with Gemini `text-embedding-004` → store in Firestore `memory/{uid}/{auto_id}`
52. On new session, retrieve top-3 semantically relevant memories → inject into system prompt
53. **Correction log** — every "Edit" tap saves the original LLM output + the corrected version. Becomes future few-shot examples.
54. **Proactive nudges** — Cloud Scheduler runs nightly: "5 days ago you reported aphids on plant 4421. Did you treat it?" → push notification
55. Admin screen: review correction log, promote frequent corrections into permanent prompt rules

**End of week 8:** agent says "you logged aphids on the Chamomile last Tuesday — any update?" Gardeners feel heard.

---

## Phase 8 — Visitor data filtering (Week 9 — partial week)

**Goal: visitors never see maintenance data.**

56. Every READ tool runs role check in Cloud Function
57. If role == 'visitor', strip sensitive fields from response BEFORE returning:
    - `tarkastusmerkinta.*` — all inspection data
    - `toimenpide.*` — all maintenance actions
    - `taksonin_viljelytiedot.kasvitaudit_ja_tuholaiset` — pests
    - `taksonin_viljelytiedot.haitallisuus`, `myrkyllisyys` — toxicity
    - `osastopaikka.kasvin_status` — health status
    - All `huomautuksia` and `lisatiedot` free-text fields
58. Add **integration tests** — query same plant as gardener vs visitor, diff the responses, confirm no leakage

**End of week 9 (Tue):** rock-solid permission boundary, server-side enforced.

---

## Phase 9 — Polish + pilot (Week 9 Wed–Friday)

59. Build admin dashboard — recent audit entries, correction log, agent error rate, daily active users
60. Build undo UI — "Last action: fertilized Valerian. Undo?"
61. Handle 5 specific failure UX paths (LLM timeout, malformed JSON, STT garbage, DB write fails, network drops)
62. Run pilot with 2 gardeners for 3 days. Log every issue.

---

## Phase 10 — Production cutover (Week 10)

63. Get T to provide live REST credentials for production write access
64. Swap SQLite driver for REST client. Same SQL templates, different transport.
65. Review every WRITE tool's SQL with T. He gets veto power on any of them.
66. Soft launch to gardener team. Two-week burn-in. Watch audit log + correction rate.

---

## Parallel work — outdoor map asset

While Phases 2-7 run, fit this in whenever:
- **Friday afternoons:** trace one outdoor section on geojson.io. By week 6 you have 20 sections. By launch you have ~30.

---

## Critical dependencies / blockers

| Dependency | Phase | Owner | Action if delayed |
|---|---|---|---|
| `sijoituspaikan_nimi` vocabulary | Phase 0 | You | Run query yourself, no waiting |
| Action code dictionary | Phase 0 | You + head gardener | One coffee meeting |
| Floor plan → cell translation | Phase 0 | You + head gardener | Same coffee meeting |
| Whisper Cloud Run instance | Phase 3 | You | Docker, 30 min |
| Outdoor section polygons | Phase 5 | You (geojson.io) | Friday afternoon work |
| Highlight plants list | Phase 6 | You + curator OR auto-pick from `kasvin_kayttotarkoitus` | Default to auto-pick |
| Production REST access | Phase 10 | T | Build everything on SQLite, swap at the end |

**Notice: zero dependencies that can't be self-served or worked around.** You're not blocked by anyone.

---

## Time budget summary

| Weeks | Work |
|---|---|
| 1 | Discovery + vocabularies + tool spec |
| 2 | Mock pipeline end-to-end |
| 3 | Real LLM with tool calling |
| 4 | Voice in + voice out + offline |
| 5 | Real DB integration on SQLite |
| 6 | Navigation (outdoor + indoor) |
| 7 | Tour planning |
| 8 | Memory + learning |
| 9 | Permission filtering + polish |
| 10 | Pilot + production cutover |

**Total: 10 weeks solo to a working pilot.** 12 weeks to production launch with burn-in.

---

## Day 1 action list

1. **9:00–11:00** — Open the SQLite file. Run the two distinct-value queries. Save results as plain text in `notes/data_inventory.md`.
2. **11:00–12:00** — Skim the 20 plants' inspection history. Read 50 real `tarkastusmerkinta.menestymista_koskevat_havainnot` entries. You'll know the actual vocabulary gardeners use.
3. **Lunch with the head gardener** — bring the floor plan printout + the action codes list. 30 minutes of "what does `ko` mean?" gives you the entire vocabulary.
4. **14:00–17:00** — Write `agent_tools.json`. ~15 tools, ~3 hours of careful writing. This single file unblocks everything else.
5. **17:00** — Send T a one-line message: "Got it, building. Will share progress in two weeks."

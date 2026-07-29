# Botanica — Project Map & Plan

Reconstructed 2026-07-30 from the repo (commits, `docs/`, `agent_assets/`, code)
after the Claude Code chat history was lost. This file is the current state of
record; `README.md` describes the pre-agent app and is out of date.

---

## 1. What this is

An AI companion app for the **Oulu Botanical Garden**. Winner of Growth Hack '26
(IKAPO + University of Oulu). Flutter/Android, Firebase backend, destined to be
handed over to the garden itself (`HANDOFF.md`).

It grew in three layers, in this order:

| Layer | What | Commits | State |
|---|---|---|---|
| **A. Visitor app** | plant ID, chat, trails, hunt, map, events, reports, admin panel, EN/FI/SV | `69224d0`, `6cd72ed` | shipped, 1.0.0 |
| **B. Smart agent** | LLM + tool-calling over the garden's live production database | `f0f9c43`, `0c099f9` | working against live API |
| **C. Wayfinding** | indoor + outdoor plant navigation | partly committed, partly not | **three competing implementations** |

Layers A and B are coherent. Layer C is the problem.

---

## 2. Timeline

```
2026-05-09  Flutter project created
2026-05-30  69224d0  Major feature update
2026-06-02  6cd72ed  Release 1.0.0 — real Oulu events, server-side API keys, translations
2026-06-10  docs/plan.md written — the 10-phase agent plan
2026-06-12  docs/notes/data_inventory.md — Phase 0 discovery done
2026-06-16  docs/navigation_graph.md + agent_assets/navigation_graph.json
2026-06-20  f0f9c43  Smart AI agent + navigation + security hardening
2026-06-22  0c099f9  Agent → live garden REST API, role control    ← LAST COMMIT
2026-07-09  last file edit (3rd navigation stack)                  ← WORK STOPS
2026-07-28  PC / Claude crash, ~/.claude wiped, transcripts lost
2026-07-30  this reconstruction
```

Uncommitted since 2026-07-09: **18 files, ~2093 insertions.** Nothing is on a
branch. A stray `git checkout` deletes it.

---

## 3. Architecture map

```
┌─ FLUTTER APP (lib/, ~25 000 lines Dart) ──────────────────────────────┐
│                                                                       │
│  main.dart  ──ProviderScope(riverpod)──> BotanicaApp(provider)         │
│      │       └─ only there to host layer C impl #1                     │
│      ▼                                                                 │
│  auth_gate → main_nav_screen (4 tabs) → home_screen                    │
│                                                                        │
│  A. VISITOR FEATURES            B. AGENT              C. WAYFINDING    │
│  camera_screen                  screens/agent/        ┌──────────────┐ │
│  plant_result_screen              agent_screen (958)  │ #1 lib/nav../│ │
│  search_screen                  services/agent/       │  3352 lines  │ │
│  trail_screen (1047)              agent_service       │  riverpod+BLE│ │
│  plant_hunt_screen (887)                              ├──────────────┤ │
│  soundscape_screen                                    │ #2 nav_graph │ │
│  bloom_screen                                         │  682 lines A*│ │
│  report_screen (930)                                  ├──────────────┤ │
│  events_screen                                        │ #3 graph_data│ │
│  chat_history / continuation                          │  1490 lines A*│ │
│  admin_panel + admin_user_list                        └──────────────┘ │
│  profile / paywall / settings / about / schedule                       │
│                                                                        │
│  i18n/app_strings.dart (1739) — every string, EN/FI/SV                  │
└───────────────────────────┬───────────────────────────────────────────┘
                            │ httpsCallable
┌───────────────────────────▼───────────────────────────────────────────┐
│ CLOUD FUNCTIONS (functions/src, ~3600 lines TS)                       │
│                                                                       │
│  index.ts ── agent, plantsCatalogue, keepGardenApiWarm, + app callables│
│  ratelimit.ts ── per-user limits on every callable                    │
│  catalogue.ts ── NEW, read-only plant list for the nav module          │
│                                                                       │
│  agent/                                                               │
│    index.ts ─────── entry, auth + App Check + rate limit              │
│    roles.ts ─────── visitor | gardener | admin                        │
│    llm.ts ───────── Groq Llama 70B → 8B → Gemini fallback chain        │
│    dispatcher.ts ── tool registry + role gating (731 lines, the core)  │
│    resolver.ts ──── name/GPS → candidate plants (anti-hallucination)   │
│    dal.ts ───────── data access, OAuth token cache, GET cache, retry   │
│    garden_api.ts ── T's production REST client                         │
│    writes.ts ────── parameterized, whitelisted, row-count guarded      │
│    safety.ts ────── confirmation gates, soft-delete, undo              │
│    audit.ts ─────── every call logged to Firestore                     │
└───────────────────────────┬───────────────────────────────────────────┘
                            │ OAuth2 (dip_agent) — credentials server-side only
┌───────────────────────────▼───────────────────────────────────────────┐
│ T's GARDEN INFORMATION SYSTEM (production, external, not ours)        │
│ Finnish schema: taksoni, osastopaikka, toimenpide, tarkastusmerkinta… │
└───────────────────────────────────────────────────────────────────────┘

Also: Firebase Auth · Firestore (EU) · Secret Manager (Groq/Gemini/PlantNet keys)
      PlantNet · Gemini · Groq · OpenRouteService · Wikipedia · OSM tiles
```

### Key vocabularies (`agent_assets/`)

| File | What it pins down |
|---|---|
| `agent_tools.json` | the ~15 agent tools + SQL templates — single source of truth |
| `action_codes.json` | 37 legacy actions: KYLVÖ → IT. → KOULINTA → IST. → SIIRTO → KUOLLUT |
| `indoor_translation.json` | `G-H*` codes → greenhouse floor-plan cells (partly unconfirmed) |
| `navigation_graph.json` | seed nodes/edges for the unified A* graph |

Data quirks that bite (`docs/notes/data_inventory.md`): Latin-1 mangling
(`|`=ö, `{`=ä, `}`=å), condition stars embedded in location strings (`10/***`),
dual date columns (write **both** `pvm` DD.MM.YYYY and `uus_pvm` ISO), and
inspector initials ≠ usernames.

---

> **Update 2026-07-30** — Sections 4 and 5 below are superseded. Navigation was
> consolidated onto Phuc's implementation (`8d5a47e`) and the agent's LLM
> boundary was rewritten (`afa197e`). Section 7 records the result.

## 4. The one real problem: three navigation stacks (RESOLVED)

All three are reachable in the shipped UI. A visitor can find a plant three
different ways, with three different UX languages.

| # | Files | Lines | Entry point | Approach |
|---|---|---|---|---|
| 1 | `lib/navigation/**` (untracked) | 3352 | home → "Find a Plant" | vendored BotaniNav: riverpod, **BLE beacons**, compass, geojson |
| 2 | `services/navigation/nav_graph.dart` + `screens/navigation/navigation_view.dart` | 682 | agent → "show me" | the documented unified A* graph |
| 3 | `models/graph_data.dart` + `models/a_star_algorithm.dart` + `screens/navigation_screen.dart` | 1490 | home → "Navigating Map" | Phuc's A* over CAD nodes |

`screens/map_screen.dart` (491 lines) lost its home-screen link but still lives
in `main_nav_screen.dart` tab 2 — so there is arguably a fourth map surface.

**#2 is the design of record** (`docs/navigation_graph.md`): one graph, `door`
nodes carrying both a lat/lng and a floor-plan pixel, A* across the
indoor/outdoor boundary. That design explicitly rejected BLE beacons and
Wi-Fi fingerprinting as MazeMap's licensing problem — yet #1 reintroduces
beacons, and its UUIDs are still a `TODO` in `lib/navigation/config/env.dart`.
No hardware has been provisioned.

Cost of leaving it: ~5500 lines of navigation code for one feature, three
codebases to keep translated and role-gated, and `ProviderScope` bolted over
the whole app to serve one of them.

---

## 5. Plan

### Phase 1 — stop the bleeding (do first, ~30 min)

1. `git add -A && git commit` the WIP on a branch. It is three weeks of work
   with zero protection. Message it honestly as WIP.
2. `flutter analyze` + `cd functions && npm run build`. Nothing has been
   compiled since the crash; know whether the tree is even green.
3. Register this machine's App Check debug token (`HANDOFF.md` §7) — otherwise
   every agent call is denied and you'll misread it as a code bug.

### Phase 2 — decide navigation (the fork in the road)

Pick one canonical stack, delete the other two, keep one map surface. Ladder
order, laziest first:

- **Keep #2** (the documented A* graph, 682 lines). Move #3's CAD node data
  into `navigation_graph.json` and #1's plant-catalogue list screen into the
  existing screens. Delete `lib/navigation/**` → drops `flutter_riverpod`,
  `equatable`, `flutter_blue_plus`, `sensors_plus`, the `ProviderScope`
  wrapper, and the unprovisioned beacon dependency. Net: ~4000 lines deleted.
- **Keep #3** if its CAD-derived greenhouse geometry is materially better than
  the hand-seeded graph — but then fold it *into* `nav_graph.dart`'s node/edge
  model rather than keeping a parallel one, and still delete #1.
- **Keep #1** only if BLE beacons are actually being funded and installed.
  Nothing in the repo suggests they are.

Recommendation: **keep #2, harvest from #3, delete #1.** It is the documented
design, it is the smallest, and it needs no hardware. Run `/plan-eng-review`
on the consolidation before touching code — `CLAUDE.md` already routes
nav↔live-DB architecture work there.

### Phase 3 — close the human dependencies

Neither is a coding task, both block finished features:

- One meeting with the head gardener: `G-H*` → floor-plan cells, and the
  meaning of `Z-SV`, `Y-O`, `H-O`, `M-L`, `K-19`, `X-TA`, `X-KO`, `X-KK`.
  Unblocks two locked-open decisions and indoor navigation accuracy.
- Curator: the ~50 highlight plants. Unblocks tour planning (`plan.md` Phase 6).

### Phase 4 — resume the agent plan

`docs/plan.md` phases 1–5, 8, 10 are done or in progress. Outstanding:

- **Phase 3 — voice.** `speech_to_text` and `flutter_tts` are in `pubspec.yaml`;
  Whisper on Cloud Run and the offline retry queue are not built. This is the
  feature the gardeners actually asked for (muddy gloves, wet phone).
- **Phase 6 — tour planning.** Blocked on the curator above.
- **Phase 7 — memory.** Conversation memory exists (last 15 turns). Long-term
  embedded memory, the correction log, and proactive nudges do not.
- **Phase 9 — pilot.** Never run. Two gardeners, three days.

### Phase 5 — before handover

- Re-enable **App Check** enforcement at store launch. It is off for sideloaded
  distribution while the agent reads and writes live production data — the
  trust boundary is currently open. Run `/cso` before touching that path.
- Rewrite `README.md`: its project-structure section predates `lib/navigation/`,
  `lib/screens/agent/`, and the whole `functions/` backend.
- Walk `HANDOFF.md` §8 checklist. The billing-account step is the one that
  actually stops you paying for the garden's app.

---

## 6. Known debt

| Where | What |
|---|---|
| `lib/navigation/config/env.dart:9` | beacon UUIDs are a `TODO`; no hardware provisioned |
| `lib/data/plant_index.dart:110` | `ponytail:` hand-rolled CSV loader over adding a csv package — has a self-check (`dart run`) |
| `README.md` | describes the pre-agent, pre-navigation app |
| `api_spec.tmp.json` (455 KB) | temp file committed to the working tree |
| whole app | no test coverage beyond `test/`; agent write paths are guarded but unverified by tests |
| `main.dart` | two state-management systems (provider + riverpod) for one feature |

---

## 7. What changed on 2026-07-30

### Navigation consolidated (`8d5a47e`)

Phuc is actively developing on `origin/feature/navigation` — he pushed
`e26017f` on 2026-07-15, after local work stopped. `main` was running his
2026-07-02 code. His latest is now in, including `finger_print_algorithm.dart`
(RSSI positioning), `beacons_service`, `ble_permission`, `plants.dart`, the
9-component refactor of `navigation_screen`, and the five AutoCAD `.lsp`
extractors that generate `graph_data`'s coordinates.

**Never merge his branch.** Two dev shortcuts on it must not reach `main`:

| File | What it does |
|---|---|
| `lib/screens/auth/auth_gate.dart` | replaces `LoginScreen` with a hardcoded 200-node nav harness — disables authentication |
| `.firebaserc` | repoints `default` to `botanica-c885c`, his own Firebase project |

Cherry-pick paths instead:
`git checkout origin/feature/navigation -- lib/models/... lib/screens/navigation_screen/ ...`

Deleted: `lib/navigation/**` (3352 lines — a vendored copy of
`resources/from_navteam`, duplicating Phuc's indoor nav with beacon UUIDs that
were never provisioned), `plant_index.dart`, `plant_tags_bar.dart`,
`api_spec.tmp.json`, and `flutter_riverpod` / `equatable` / `sensors_plus`.

`lib/services/navigation/nav_graph.dart` was **kept** — it is outdoor GPS with
door nodes and serves the agent's "show me", while Phuc's graph is indoor CAD
coordinates. Different spaces, not duplicates.

Recoverable from `wip/pre-cleanup-2026-07-30` / `3bf6ebc`.

### Agent LLM boundary rewritten (`afa197e`)

The unreliable step was tool **choice**, not the data layer. With 8 tool
schemas the model answered "what's the status of the Cacao" by calling
`find_plant`, `query_plant_details`, or from memory on different days.

The LLM is now confined to two jobs:

1. free-form speech → fixed JSON slots (`update_mode.ts`, temperature 0)
2. rephrasing rows already fetched and validated (`llm.ts` `composeAnswer`)

```
READS   text ─→ router.ts (patterns, EN/FI/SV, no model)
                  ├─ recognised   → fixed tool calls → existing read pipeline
                  └─ unrecognised → llmTurn(), exactly as before (no regression)

WRITES  [Update] button ─→ update_mode.ts slot-filling state machine
                              missing plant     → asks back
                              several matches   → tappable section options
                              missing action    → legacy vocabulary buttons
                              complete          → buildPendingAction (guarded SQL)
                              settled           → [Update another] [Done]
```

The LLM does **not** emit SQL. It emits `{action_family, count, location_code,
...}` and the server builds the statement, so parameterized queries, the
operation whitelist, row-count caps, the audit log, and T's veto over statement
shapes all survive. `action_family` is accepted only if it appears in the
hardcoded legacy vocabulary.

New: `functions/src/agent/router.ts`, `functions/src/agent/update_mode.ts`,
`agentUpdateMode` callable (gardener-gated server-side), an `agent_update_mode`
deny-all Firestore rule, and a gardener-only Update/Done button in the agent app
bar whose eligibility comes from a server probe rather than a client role copy.

Router self-check: `cd functions && npx tsx src/agent/router.ts`

### Verification

| Check | Result |
|---|---|
| `flutter analyze` | 0 errors, 4 warnings (595 issues → 114, all info) |
| `functions` `tsc` | clean |
| Net lines | −1574 (cleanup) then +1100 (agent rework) |

`analysis_options.yaml` now excludes `resources/**`, which was contributing 481
phantom errors from the nav team's original unbuilt drop.

### Still outstanding

- **Not run on a device.** Update mode and the router are compile-verified only;
  the slot extraction and the disambiguation loop need a real gardener session.
- Rewrite `README.md` — it predates the agent, the navigation module, and
  `functions/` entirely. `../botanica_knowledge_base.md` has the same problem.
- Tell Phuc his `auth_gate.dart` and `.firebaserc` changes are on the branch.
- The human dependencies in section 5 (head gardener's `G-H*` mapping, the
  curator's highlight plants) are unchanged and still block indoor accuracy and
  tour planning.
- Voice (`plan.md` Phase 3) still unbuilt: `speech_to_text` and `flutter_tts`
  are declared, Whisper on Cloud Run and the offline retry queue are not.

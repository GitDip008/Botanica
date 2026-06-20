# Data Inventory — Phase 0 results (filled 2026-06)

Source: T's `test_database.sqlite` + Phuc/Tuomas stocktake format example.

---

## Query 1 — location vocabulary (76 distinct values)

**Verdict: structured prefix system, NOT a clean grid — but mappable.**

| Prefix | Meaning | Examples |
|---|---|---|
| `G-H*` | Greenhouse cells | G-HA, G-HL, G-HO, G-HF, G-HJ, G-HZ, G-HD, G-HK, G-HT |
| `T-x.y.z` | Field plot coordinates | T-1.5.2, T-2.3.2, T-4.1.3 |
| `X-*` | Special areas (X-TUTK. = research) | X-TA, X-KO, X-KK |
| `K-n` | Numbered K-areas | K-19, K-8, K-11 |
| `Z-SV` | Biggest single location (38 rows) — likely seed storage? | Z-SV |
| `n/ m` | Outdoor bed/position | 6/ 1, 5/ 1, 11/a, 15/ 2 |
| freeform | Legacy text incl. mangled encoding | marjapenkki 392, kylv\|s, AULA/ 1 |

**Gotchas:**
- Condition stars embedded in location strings: `10/***`, `14/*` — strip when parsing
- Latin1 mangling: `|`=ö, `{`=ä, `}`=å
- Decision: **section-level navigation + raw-code display as fallback.** Ask head gardener for G-H* → floor-plan cell mapping.

---

## Query 2 — action vocabulary (37 distinct values)

**Verdict: propagation lifecycle, NOT maintenance actions.** The garden tracks:
`KYLVÖ` (sow) → `IT./ITÄNYT` (germinated) → `KOULINTA` (prick out) → `IST. <loc>` (plant out) → `SIIRTO <from> <to>` (transfer) → `KUOLLUT`/`POIST.`/`MYYTY` (end states)

Conventions:
- Location code appended to action: `IST. T-4.1.3/ 4 kpl`
- Counts use `kpl` (pieces) and `MÄTÄS`/`MÄT.` (clumps)
- Case-insensitive variants everywhere (KYLVÖ / ky. / KY.)

Full mapping → `agent_assets/action_codes.json`

---

## Query 3 + 4 — inspectors vs users

22 distinct inspector initials. Only 9 user accounts. **Initials ≠ usernames** — probable mappings:
- RH → rhiltune (Ritva)
- MS → mas (Mirja Siuruainen)
- MH → mhyvarin (Marko Hyvärinen)
- TK → tpkauppi (Tuomas Kauppila)?

**Decision:** store `legacyInspectorCode` per user in Firestore. Ask once on first write.
Many historical initials (PP, JK, ER, VH…) belong to past staff — no need to map those.

---

## Query 5 + Phuc — observation format

**The stocktake convention (from Tuomas via Phuc):**

```
*** 3 kpl, 2-4 m, kukkii, ovat liian tiheässä, yksi huonompi
└┬┘ └──┬──┘ └─┬─┘ └─┬──┘ └────────────┬───────────────────┘
stars  count  size  status            free notes
```

- `*` = poor, `**` = moderate, `***` = good
- Count in `kpl`, size in m/cm, status words (kukkii = blooming)
- Real data confirms: most entries are bare stars (`***`), terse Finnish ("siirto Romeoon", "HÄVITETTY, MADOT!", "ei itänyt")

**Agent rule:** parse speech → compose record in this exact format. Keep gardener's words for notes.

---

## Locked decisions

- [x] **Date strategy:** read+write `uus_*` ISO columns; also write legacy `DD.MM.YYYY` columns for compatibility
- [x] **Inspector ID:** `users/{uid}.legacyInspectorCode`, ask-once-and-save
- [x] **Indoor positioning:** section-level + G-H* code mapping (pending gardener confirmation)
- [x] **Action vocabulary:** follow legacy conventions (KYLVÖ/IST./SIIRTO...), location appended
- [x] **Observation format:** stocktake convention (stars, kpl, size, status, notes)
- [ ] **Highlight plants:** still needs curator input (Phase 6)
- [ ] **G-H* → floor-plan cells:** needs head-gardener meeting

## Remaining questions for the gardener (one short meeting)

1. What do these location codes mean: `Z-SV`, `Y-O`, `H-O`, `M-L`, `K-19`, `X-TA`, `X-KO`, `X-KK`?
2. Which floor-plan cell is each `G-H*` code (G-HA, G-HD, G-HF, G-HJ, G-HK, G-HL, G-HO, G-HT, G-HZ)?
3. Confirm star convention: `*` poor / `**` moderate / `***` good?
4. What does `PISTETTY` mean exactly — cuttings?

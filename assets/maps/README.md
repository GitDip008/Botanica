# assets/maps

Only artefacts the **app actually loads** belong here. Everything in this
directory ships inside the APK on every visitor's phone.

## Expected contents

Floor-plan images, one PNG per greenhouse floor plan:

```
assets/maps/romeo.png
assets/maps/julia.png
```

`lib/screens/navigation/navigation_view.dart` loads these by name
(`assets/maps/${segment.floorplan}.png`) when a route crosses a door node and
the view switches from the outdoor map to the indoor plan.

**These PNGs do not exist yet**, so that rendering path has never run. Exporting
them from the greenhouse CAD is what turns it on — see below.

## Where the source drawings went

The CAD and PDF originals are **not** in this folder and must not be put back.
They live in `/resources/cad/` (gitignored, handed over out-of-band per
`HANDOFF.md` §6). They were bundled here until 2026-08-24, costing ~12 MB of
APK for files no code ever opened.

| File | What it is |
|---|---|
| `romeo julia dwg260630 romeo ja julia_02.dwg` | greenhouse CAD — the source for the PNGs above |
| `greenhouse pdf 260630 romeo ja julia 1.200 A4.pdf` | same plan, 1:200 on A4 |
| `outdoor area map dwg 260703B kartta.dwg` | outdoor garden CAD |
| `outdoor area map pdf 260703B kartta 1.2000 A4.pdf` | same, 1:2000 on A4 |
| `Section_Layer_{1,2,3}.geojson` | CAD geometry export (polylines), 7 MB, unused |

The greenhouse cell labels extracted from that CAD — 37 rooms, `A1`–`A17`,
`B1`–`B6`, `D1`–`D10`, `E1`–`E7`, `F1`–`F4` — were kept, because they are small
and they are vocabulary rather than geometry. They now live at
`agent_assets/greenhouse_cells.geojson` alongside the other code vocabularies.

## Exporting the floor-plan PNGs

Needs a tool that reads DWG (AutoCAD, BricsCAD, ODA File Converter, or the
1:200 PDF at sufficient resolution).

1. Export the plan as PNG at a **known, recorded scale** — the pixel-to-metre
   ratio has to be written down, because `navigation_view` positions the route
   line in pixel space.
2. Keep the same origin and orientation as `lib/models/graph_data.dart`, whose
   node coordinates came from this drawing via the `*.lsp` extractors. A PNG
   that does not share the graph's frame will draw routes in the wrong place.
3. Drop the file in here and re-add it to `pubspec.yaml`.

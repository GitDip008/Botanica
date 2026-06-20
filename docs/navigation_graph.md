# Unified Navigation Graph — door-to-door routing

The one piece of MazeMap's architecture worth copying: **a single routable
graph that spans outdoor sections AND indoor greenhouse cells**, joined by
*door nodes*. With this, "route me to the Coffee plant" works seamlessly from
the main gate → across the garden → through the Aula door → into Romeo cell A8,
even though GPS dies the moment you step inside.

---

## The core idea

Everything the visitor can stand on or walk through is a **node**. Everything
walkable between two nodes is an **edge** with a distance. Routing = A* over
this graph. No GPS required for the routing itself — GPS (outdoor) or a tapped
cell (indoor) only tells us *which node the user is currently at*.

```
  [Main gate]──12m──[Path junction 1]──30m──[Medicinal L-O]
        │                   │
       8m                  20m
        │                   │
   [Café]            [Aula door] ←── the magic node: in BOTH graphs
                            │
                          indoor
                            │
                     [Romeo cell A8]──[Romeo cell A12]──[Romeo cell B6]
```

The **Aula door** node is what MazeMap calls a "vertical connector" (they use
it for stairs/elevators between floors). For us it connects the *outdoor*
graph to the *indoor* greenhouse graph. That single shared node makes
door-to-door routing fall out of plain A* for free.

---

## Node types

| type | where it comes from | positioned by |
|---|---|---|
| `section` | one per garden section (`osaston_koodi`) | GPS polygon centroid (outdoor) or floor-plan cell (indoor) |
| `junction` | path intersections, forks, dead-ends | surveyed lat/lng (outdoor) or pixel point (indoor) |
| `door` | greenhouse + building entrances | the threshold — has BOTH a lat/lng and a floor-plan pixel |
| `poi` | café, WC, info desk, gate | lat/lng |

A node knows whether it's `outdoor` or which `floorplan` it lives on. A `door`
node is special: it carries both an outdoor lat/lng and an indoor pixel, so it
appears in both coordinate systems.

## Edge

```
{ from, to, meters, accessible, kind }
```
- `meters` — walking distance (the A* cost)
- `accessible` — true if wheelchair/stroller friendly (no stairs/steps)
- `kind` — `path` | `door` | `indoor`

Edges are **undirected** (walkable both ways); the loader adds both directions.

---

## How the three positioning modes feed the same router

| Situation | How we find the user's start node |
|---|---|
| Outdoor, GPS on | point-in-polygon → current `section` node, or nearest `junction` |
| Indoor greenhouse | the cell the user tapped → that `section`/cell node |
| Scanned a plant QR | the plant's `osaston_koodi` → that section node |

Target node = the section/cell the requested plant lives in (from
`osastopaikka.osaston_koodi`). Then `aStar(start, target)` returns the path,
and the UI draws it: a polyline on the outdoor map, then a highlighted line on
the greenhouse floor-plan once the route crosses a door.

---

## Why this beats a flat section list

- **Door-to-door**: routes correctly cross the indoor/outdoor boundary.
- **Accessible routing**: filter edges by `accessible` when the visitor needs
  step-free paths — exactly MazeMap's "avoid stairs" toggle.
- **Multi-segment rendering**: the path naturally splits at door nodes, so the
  app knows when to switch from the OSM map view to the floor-plan view.
- **One algorithm**: A* over one graph. No special-casing indoor vs outdoor.

---

## Building it (one-time, ~half a day with the garden map)

1. **Outdoor sections** → trace polygons on geojson.io, take each centroid as a
   `section` node. (You already need this for GPS positioning.)
2. **Paths** → walk the garden once, drop a `junction` node at every fork, and
   record `edge`s between adjacent junctions/sections with rough distances
   (pace them, ±5 m is fine).
3. **Doors** → mark each greenhouse entrance as a `door` node; give it the
   outdoor lat/lng AND the matching pixel on the floor-plan image.
4. **Indoor cells** → each greenhouse cell (A1…F8) becomes a `section` node on
   its floor-plan; connect adjacent cells with short `indoor` edges; connect
   the entrance cell to the `door` node.

The starter file `agent_assets/navigation_graph.json` is pre-seeded with your
real section codes and the greenhouse structure — you only need to fill in the
coordinates and confirm the path connections with the gardener.

---

## What you do NOT need (and MazeMap charges for)

- ❌ Wi-Fi fingerprinting / BLE beacons — tap-to-locate replaces indoor
  positioning entirely.
- ❌ Hosted vector-tile servers — OSM tiles (outdoor) + a PNG (indoor) are free.
- ❌ Their CMS — the JSON file IS your editor.
- ❌ A per-year license — this is ~150 lines of Dart you own forever.

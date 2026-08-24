// lib/data/greenhouse_cells.dart
//
// The 37 greenhouse planting cells, extracted from the garden's Romeo/Julia
// CAD drawing (resources/cad/romeo julia dwg260630 romeo ja julia_02.dwg).
//
// These share the SAME coordinate frame as lib/models/graph_data.dart — both
// came out of that drawing — which is what makes them usable as A* endpoints
// without any transform. Verified 2026-08-24: cell labels span
// x -166.9..-124.2, Phuc's 212 path nodes span -165.8..-124.8, and his
// corridors run through the cell clusters.
//
// House assignment comes from that same check: blocks A and B sit in the
// upper-right cluster (Romeo), blocks D, E and F in the lower-left (Julia).
//
// ponytail: parsed from the geojson at runtime rather than code-generated into
// a Dart literal — it is 6 KB read once, and keeping the CAD export as the
// single source of truth means a re-export cannot silently disagree with code.

// Deliberately imports nothing from Flutter: keeping this file pure is what
// lets its self-check run under plain `dart run`. Asset loading lives in the
// widget that needs it.
import 'dart:convert';

/// Which greenhouse a cell belongs to.
enum Greenhouse { romeo, julia }

extension GreenhouseLabel on Greenhouse {
  String get label => this == Greenhouse.romeo ? 'Romeo' : 'Julia';
}

class GreenhouseCell {
  /// Cell label as drawn on the plan, e.g. "A12", "D5".
  final String name;

  /// CAD coordinates, same frame as graph_data.dart's PathNode.
  final double x;
  final double y;

  final Greenhouse house;

  const GreenhouseCell({
    required this.name,
    required this.x,
    required this.y,
    required this.house,
  });

  /// Letter block the cell belongs to ("A", "B", "D", "E", "F").
  String get block => RegExp(r'^[A-Z]+').firstMatch(name)?.group(0) ?? '';

  @override
  String toString() => '$name (${house.label})';
}

/// Blocks A and B are Romeo; D, E and F are Julia.
///
/// An unknown block defaults to Romeo rather than throwing: a future CAD
/// re-export that adds a block should degrade to a usable cell, not crash the
/// navigation screen. The assertion in the self-check covers the known set.
Greenhouse _houseForBlock(String block) {
  switch (block) {
    case 'A':
    case 'B':
      return Greenhouse.romeo;
    case 'D':
    case 'E':
    case 'F':
      return Greenhouse.julia;
    default:
      return Greenhouse.romeo;
  }
}

/// Pure parser — kept separate from asset loading so it can be checked without
/// a Flutter binding.
List<GreenhouseCell> parseGreenhouseCells(String geojson) {
  final root = jsonDecode(geojson) as Map<String, dynamic>;
  final features = (root['features'] as List?) ?? const [];
  final out = <GreenhouseCell>[];

  for (final f in features) {
    if (f is! Map) continue;
    final props = f['properties'];
    final geom = f['geometry'];
    if (props is! Map || geom is! Map) continue;

    final name = props['RoomName'];
    final coords = geom['coordinates'];
    // Point geometry only; anything else in the layer is not a cell label.
    if (name is! String || name.trim().isEmpty) continue;
    if (geom['type'] != 'Point' || coords is! List || coords.length < 2) continue;

    final x = (coords[0] as num).toDouble();
    final y = (coords[1] as num).toDouble();
    final block = RegExp(r'^[A-Z]+').firstMatch(name.trim())?.group(0) ?? '';

    out.add(GreenhouseCell(
      name: name.trim(),
      x: x,
      y: y,
      house: _houseForBlock(block),
    ));
  }

  // Sort by block then numerically — "A2" must come before "A10", which a
  // plain string sort gets wrong and which visitors notice immediately.
  out.sort((a, b) {
    final c = a.block.compareTo(b.block);
    if (c != 0) return c;
    int num(String s) => int.tryParse(s.replaceAll(RegExp(r'^[A-Z]+'), '')) ?? 0;
    return num(a.name).compareTo(num(b.name));
  });
  return out;
}

/// Asset path the cells are parsed from. The caller loads it — see
/// [parseGreenhouseCells].
const greenhouseCellsAsset = 'agent_assets/greenhouse_cells.geojson';

/// Cells belonging to one greenhouse, in plan order.
List<GreenhouseCell> cellsIn(List<GreenhouseCell> all, Greenhouse house) =>
    all.where((c) => c.house == house).toList();

/// Case-insensitive lookup by label. Returns null when there is no such cell.
GreenhouseCell? findCell(List<GreenhouseCell> all, String name) {
  final q = name.trim().toUpperCase();
  for (final c in all) {
    if (c.name.toUpperCase() == q) return c;
  }
  return null;
}

// ─── Self-check ─────────────────────────────────────────────────────────────
// ponytail: one runnable check on the parsing and ordering, which is the part
// that can silently go wrong. Run: `dart run lib/data/greenhouse_cells.dart`
void main() {
  const sample = '''
  {"type":"FeatureCollection","features":[
    {"type":"Feature","properties":{"RoomName":"A10"},"geometry":{"type":"Point","coordinates":[-135.0,15.5]}},
    {"type":"Feature","properties":{"RoomName":"A2"},"geometry":{"type":"Point","coordinates":[-138.6,16.0]}},
    {"type":"Feature","properties":{"RoomName":"E5"},"geometry":{"type":"Point","coordinates":[-164.0,-12.2]}},
    {"type":"Feature","properties":{"RoomName":"B1"},"geometry":{"type":"Point","coordinates":[-130.7,11.1]}},
    {"type":"Feature","properties":{"RoomName":""},"geometry":{"type":"Point","coordinates":[0,0]}},
    {"type":"Feature","properties":{"Layer":"Imported"},"geometry":{"type":"MultiLineString","coordinates":[]}}
  ]}''';

  final cells = parseGreenhouseCells(sample);

  // Unlabelled points and non-Point geometry are not cells.
  assert(cells.length == 4, 'expected 4 cells, got ${cells.length}');

  // Numeric ordering within a block: A2 before A10.
  assert(cells[0].name == 'A2', 'first should be A2, got ${cells[0].name}');
  assert(cells[1].name == 'A10', 'second should be A10, got ${cells[1].name}');

  // House assignment follows the surveyed clusters.
  assert(findCell(cells, 'A2')!.house == Greenhouse.romeo);
  assert(findCell(cells, 'B1')!.house == Greenhouse.romeo);
  assert(findCell(cells, 'E5')!.house == Greenhouse.julia);

  // Coordinates survive the round trip unchanged — these become A* endpoints,
  // so a swapped or rounded value would route to the wrong place.
  final a2 = findCell(cells, 'A2')!;
  assert(a2.x == -138.6 && a2.y == 16.0, 'A2 coords wrong: ${a2.x},${a2.y}');

  // Lookup is case-insensitive and tolerant of stray whitespace.
  assert(findCell(cells, ' e5 ') != null);
  assert(findCell(cells, 'Z9') == null);

  assert(cellsIn(cells, Greenhouse.julia).length == 1);

  // ignore: avoid_print
  print('greenhouse_cells self-check ok (${cells.length} cells parsed)');
}

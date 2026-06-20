import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/services.dart' show rootBundle;

/// One node in the unified navigation graph. Outdoor nodes carry lat/lng;
/// indoor nodes carry a floorplan + pixel; door nodes carry both.
class NavNode {
  final String id;
  final String type; // section | junction | door | poi
  final String? code; // osaston_koodi for section nodes
  final String label;
  final String area; // outdoor | indoor | door
  final String? theme;
  final double? lat;
  final double? lng;
  final String? floorplan; // romeo | julia
  final List<double>? px; // [x, y] pixel on the floor plan

  const NavNode({
    required this.id,
    required this.type,
    required this.label,
    required this.area,
    this.code,
    this.theme,
    this.lat,
    this.lng,
    this.floorplan,
    this.px,
  });

  bool get isIndoor => area == 'indoor';
  bool get isDoor => area == 'door';

  factory NavNode.fromJson(Map<String, dynamic> j) => NavNode(
        id: j['id'] as String,
        type: j['type'] as String,
        code: j['code'] as String?,
        label: (j['label'] as String?) ?? (j['id'] as String),
        area: (j['area'] as String?) ?? 'outdoor',
        theme: j['theme'] as String?,
        lat: (j['lat'] as num?)?.toDouble(),
        lng: (j['lng'] as num?)?.toDouble(),
        floorplan: j['floorplan'] as String?,
        px: (j['px'] as List?)?.map((e) => (e as num).toDouble()).toList(),
      );
}

class NavEdge {
  final String from;
  final String to;
  final double meters;
  final bool accessible;
  final String kind; // path | door | indoor

  const NavEdge({
    required this.from,
    required this.to,
    required this.meters,
    required this.accessible,
    required this.kind,
  });

  factory NavEdge.fromJson(Map<String, dynamic> j) => NavEdge(
        from: j['from'] as String,
        to: j['to'] as String,
        meters: (j['meters'] as num).toDouble(),
        accessible: (j['accessible'] as bool?) ?? true,
        kind: (j['kind'] as String?) ?? 'path',
      );
}

/// A computed route: the ordered nodes, total distance, and the segments
/// split at every indoor/outdoor boundary so the UI knows when to switch
/// between the map view and a floor-plan view.
class NavRoute {
  final List<NavNode> nodes;
  final double totalMeters;
  final List<NavSegment> segments;

  const NavRoute({
    required this.nodes,
    required this.totalMeters,
    required this.segments,
  });

  bool get isEmpty => nodes.isEmpty;
  int get walkMinutes => (totalMeters / 75).ceil(); // ~75 m/min strolling
}

/// A contiguous stretch of the route in one coordinate system.
class NavSegment {
  final String area; // outdoor | indoor
  final String? floorplan;
  final List<NavNode> nodes;
  const NavSegment({required this.area, this.floorplan, required this.nodes});
}

/// Loads the graph and runs A* over it. MazeMap-style door-to-door routing
/// in ~150 lines, free.
class NavGraph {
  final Map<String, NavNode> _nodes;
  final Map<String, List<NavEdge>> _adj; // node id -> outgoing edges

  NavGraph._(this._nodes, this._adj);

  NavNode? node(String id) => _nodes[id];
  Iterable<NavNode> get nodes => _nodes.values;

  /// Find the section/cell node for a garden section code (osaston_koodi).
  NavNode? nodeForSection(String code) {
    for (final n in _nodes.values) {
      if (n.code == code) return n;
    }
    return null;
  }

  static Future<NavGraph> load([
    String asset = 'agent_assets/navigation_graph.json',
  ]) async {
    final raw = await rootBundle.loadString(asset);
    final data = jsonDecode(raw) as Map<String, dynamic>;

    final nodes = <String, NavNode>{};
    for (final n in (data['nodes'] as List)) {
      final node = NavNode.fromJson(Map<String, dynamic>.from(n as Map));
      nodes[node.id] = node;
    }

    final adj = <String, List<NavEdge>>{};
    void addDir(NavEdge e) => (adj[e.from] ??= []).add(e);
    for (final raw in (data['edges'] as List)) {
      final e = NavEdge.fromJson(Map<String, dynamic>.from(raw as Map));
      addDir(e);
      // Undirected — add the reverse direction too.
      addDir(NavEdge(
          from: e.to, to: e.from, meters: e.meters, accessible: e.accessible, kind: e.kind));
    }
    return NavGraph._(nodes, adj);
  }

  /// A* shortest path from [startId] to [goalId]. When [accessibleOnly] is
  /// true, edges with accessible=false (stairs/rough ground) are skipped —
  /// MazeMap's "avoid stairs" toggle.
  NavRoute route(String startId, String goalId, {bool accessibleOnly = false}) {
    if (!_nodes.containsKey(startId) || !_nodes.containsKey(goalId)) {
      return const NavRoute(nodes: [], totalMeters: 0, segments: []);
    }
    if (startId == goalId) {
      final n = _nodes[startId]!;
      return NavRoute(
        nodes: [n],
        totalMeters: 0,
        segments: [NavSegment(area: n.area, floorplan: n.floorplan, nodes: [n])],
      );
    }

    final open = <String>{startId};
    final cameFrom = <String, String>{};
    final g = <String, double>{startId: 0};
    final f = <String, double>{startId: _heuristic(startId, goalId)};

    while (open.isNotEmpty) {
      // node in open with lowest f
      String current = open.first;
      double best = f[current] ?? double.infinity;
      for (final id in open) {
        final v = f[id] ?? double.infinity;
        if (v < best) {
          best = v;
          current = id;
        }
      }
      if (current == goalId) {
        return _reconstruct(cameFrom, current, g[goalId] ?? 0);
      }
      open.remove(current);

      for (final e in (_adj[current] ?? const <NavEdge>[])) {
        if (accessibleOnly && !e.accessible) continue;
        final tentative = (g[current] ?? double.infinity) + e.meters;
        if (tentative < (g[e.to] ?? double.infinity)) {
          cameFrom[e.to] = current;
          g[e.to] = tentative;
          f[e.to] = tentative + _heuristic(e.to, goalId);
          open.add(e.to);
        }
      }
    }
    return const NavRoute(nodes: [], totalMeters: 0, segments: []); // unreachable
  }

  // ── helpers ────────────────────────────────────────────────────────────

  NavRoute _reconstruct(Map<String, String> cameFrom, String goal, double total) {
    final path = <String>[goal];
    var cur = goal;
    while (cameFrom.containsKey(cur)) {
      cur = cameFrom[cur]!;
      path.insert(0, cur);
    }
    final nodes = path.map((id) => _nodes[id]!).toList();
    return NavRoute(nodes: nodes, totalMeters: total, segments: _segment(nodes));
  }

  /// Split the path into contiguous outdoor / indoor segments so the UI knows
  /// when to swap views. Door nodes belong to the segment on each side.
  List<NavSegment> _segment(List<NavNode> nodes) {
    final segs = <NavSegment>[];
    var buf = <NavNode>[];
    String? curArea;
    String? curFloor;

    String effArea(NavNode n) => n.isDoor ? (curArea ?? 'outdoor') : (n.isIndoor ? 'indoor' : 'outdoor');

    for (final n in nodes) {
      final area = n.isDoor ? (curArea ?? effArea(n)) : (n.isIndoor ? 'indoor' : 'outdoor');
      final floor = n.isIndoor ? n.floorplan : (n.isDoor ? n.floorplan : null);
      if (curArea == null) {
        curArea = area;
        curFloor = floor;
        buf.add(n);
      } else if (area == curArea && (area != 'indoor' || floor == curFloor)) {
        buf.add(n);
      } else {
        // boundary — door node bridges both segments
        buf.add(n);
        segs.add(NavSegment(area: curArea, floorplan: curFloor, nodes: List.of(buf)));
        buf = [n];
        curArea = area;
        curFloor = floor;
      }
    }
    if (buf.isNotEmpty) {
      segs.add(NavSegment(area: curArea ?? 'outdoor', floorplan: curFloor, nodes: buf));
    }
    return segs;
  }

  /// Straight-line distance estimate for A*. Uses metres for outdoor (haversine)
  /// and a rough pixel→metre scale indoors. Admissible enough for this scale.
  double _heuristic(String a, String b) {
    final na = _nodes[a]!, nb = _nodes[b]!;
    if (na.lat != null && nb.lat != null) {
      return _haversine(na.lat!, na.lng!, nb.lat!, nb.lng!);
    }
    if (na.px != null && nb.px != null && na.floorplan == nb.floorplan) {
      final dx = na.px![0] - nb.px![0];
      final dy = na.px![1] - nb.px![1];
      return math.sqrt(dx * dx + dy * dy) * 0.02; // ~50 px per metre
    }
    return 0; // cross-system: lean on edge costs (A* still correct)
  }

  double _haversine(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371000.0;
    final dLat = _rad(lat2 - lat1);
    final dLon = _rad(lon2 - lon1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_rad(lat1)) * math.cos(_rad(lat2)) *
            math.sin(dLon / 2) * math.sin(dLon / 2);
    return r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  double _rad(double d) => d * math.pi / 180;
}

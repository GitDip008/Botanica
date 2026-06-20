import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../services/navigation/nav_graph.dart';

/// Renders a computed [NavRoute] door-to-door, MazeMap-style:
///   • outdoor segments → polyline on an OSM map
///   • indoor segments  → highlighted cells on the greenhouse floor-plan
///   • a step-by-step direction list at the bottom that always works
///
/// Open it with [NavigationView.show] from anywhere (e.g. the agent's
/// "Show me" button or the map screen).
class NavigationView extends StatefulWidget {
  final NavRoute route;
  final String destinationLabel;

  const NavigationView({
    super.key,
    required this.route,
    required this.destinationLabel,
  });

  static Future<void> show(
    BuildContext context, {
    required NavRoute route,
    required String destinationLabel,
  }) {
    return Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            NavigationView(route: route, destinationLabel: destinationLabel),
      ),
    );
  }

  @override
  State<NavigationView> createState() => _NavigationViewState();
}

class _NavigationViewState extends State<NavigationView> {
  int _activeSegment = 0;

  @override
  Widget build(BuildContext context) {
    final route = widget.route;
    final segments = route.segments;
    if (route.isEmpty || segments.isEmpty) {
      return _emptyScaffold();
    }
    _activeSegment = _activeSegment.clamp(0, segments.length - 1);
    final seg = segments[_activeSegment];

    return Scaffold(
      backgroundColor: const Color(0xFF0A1A0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D1F14),
        title: Text('To: ${widget.destinationLabel}',
            overflow: TextOverflow.ellipsis),
        elevation: 0,
      ),
      body: Column(
        children: [
          // ── Distance / time banner ──
          Container(
            width: double.infinity,
            color: const Color(0xFF1A2E1E),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(children: [
              const Icon(Icons.directions_walk_rounded,
                  color: Color(0xFF66BB6A), size: 20),
              const SizedBox(width: 8),
              Text(
                '${route.totalMeters.round()} m  ·  ~${route.walkMinutes} min',
                style: const TextStyle(
                    color: Color(0xFFE8F5E9),
                    fontSize: 15,
                    fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              Text('Leg ${_activeSegment + 1}/${segments.length}',
                  style: const TextStyle(color: Color(0xFF81C784), fontSize: 12)),
            ]),
          ),

          // ── Active segment view (map OR floor-plan) ──
          Expanded(
            child: seg.area == 'indoor'
                ? _IndoorSegment(segment: seg)
                : _OutdoorSegment(segment: seg),
          ),

          // ── Segment switcher (only when the route crosses a boundary) ──
          if (segments.length > 1)
            Container(
              color: const Color(0xFF0D1F14),
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              child: Row(children: [
                _legButton(
                  enabled: _activeSegment > 0,
                  icon: Icons.chevron_left_rounded,
                  label: 'Previous leg',
                  onTap: () => setState(() => _activeSegment--),
                ),
                const Spacer(),
                Text(
                  seg.area == 'indoor'
                      ? '🏠 Inside ${_floorName(seg.floorplan)}'
                      : '🌳 Outdoors',
                  style: const TextStyle(
                      color: Color(0xFFE8F5E9),
                      fontSize: 13,
                      fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                _legButton(
                  enabled: _activeSegment < segments.length - 1,
                  icon: Icons.chevron_right_rounded,
                  label: 'Next leg',
                  trailing: true,
                  onTap: () => setState(() => _activeSegment++),
                ),
              ]),
            ),

          // ── Step list ──
          _StepList(route: route),
        ],
      ),
    );
  }

  Widget _legButton({
    required bool enabled,
    required IconData icon,
    required String label,
    bool trailing = false,
    required VoidCallback onTap,
  }) {
    final color = enabled ? const Color(0xFF66BB6A) : const Color(0xFF2A4A2F);
    return TextButton.icon(
      onPressed: enabled ? onTap : null,
      icon: trailing ? const SizedBox.shrink() : Icon(icon, color: color, size: 20),
      label: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(label, style: TextStyle(color: color, fontSize: 12)),
        if (trailing) Icon(icon, color: color, size: 20),
      ]),
    );
  }

  String _floorName(String? f) =>
      f == 'romeo' ? 'Romeo greenhouse' : f == 'julia' ? 'Julia greenhouse' : 'greenhouse';

  Scaffold _emptyScaffold() => Scaffold(
        backgroundColor: const Color(0xFF0A1A0F),
        appBar: AppBar(
          backgroundColor: const Color(0xFF0D1F14),
          title: const Text('Directions'),
        ),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Text(
              "I couldn't find a route to that plant. It may not be mapped yet — ask a gardener for help finding it.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF81C784), fontSize: 15, height: 1.5),
            ),
          ),
        ),
      );
}

// ─── Outdoor segment: OSM map + polyline + start/end markers ────────────────

class _OutdoorSegment extends StatelessWidget {
  final NavSegment segment;
  const _OutdoorSegment({required this.segment});

  @override
  Widget build(BuildContext context) {
    final pts = segment.nodes
        .where((n) => n.lat != null && n.lng != null)
        .map((n) => LatLng(n.lat!, n.lng!))
        .toList();
    if (pts.isEmpty) {
      return const Center(
        child: Text('Outdoor leg — coordinates not set yet',
            style: TextStyle(color: Color(0xFF81C784))),
      );
    }
    final center = pts[pts.length ~/ 2];

    return FlutterMap(
      options: MapOptions(initialCenter: center, initialZoom: 17.5, minZoom: 14, maxZoom: 20),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.example.botanica_ar',
        ),
        if (pts.length > 1)
          PolylineLayer(polylines: [
            Polyline(
              points: pts,
              strokeWidth: 5,
              color: const Color(0xFF2E7D32),
              borderStrokeWidth: 2,
              borderColor: Colors.white,
            ),
          ]),
        MarkerLayer(markers: [
          // start
          Marker(
            point: pts.first,
            width: 40,
            height: 40,
            child: const _PinDot(color: Color(0xFF64B5F6), icon: Icons.my_location_rounded),
          ),
          // end of this leg
          Marker(
            point: pts.last,
            width: 40,
            height: 40,
            child: const _PinDot(color: Color(0xFFE65100), icon: Icons.place_rounded),
          ),
        ]),
      ],
    );
  }
}

class _PinDot extends StatelessWidget {
  final Color color;
  final IconData icon;
  const _PinDot({required this.color, required this.icon});

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      );
}

// ─── Indoor segment: floor-plan image + highlighted cells ───────────────────

class _IndoorSegment extends StatelessWidget {
  final NavSegment segment;
  const _IndoorSegment({required this.segment});

  @override
  Widget build(BuildContext context) {
    final asset = 'assets/maps/${segment.floorplan}.png';
    final cells = segment.nodes.where((n) => n.px != null).toList();

    return LayoutBuilder(builder: (context, box) {
      return Container(
        color: const Color(0xFF0F2018),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Floor-plan image if present; otherwise a graceful placeholder.
            Image.asset(
              asset,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => _PlanPlaceholder(cells: cells),
            ),
            // Highlight dots over cells. We scale pixel coords assuming the
            // source image is laid out in a 1500×1500 space (see the JSON).
            ...cells.asMap().entries.map((e) {
              final i = e.key;
              final n = e.value;
              final isLast = i == cells.length - 1;
              // Map the 1500-space px into the visible box, BoxFit.contain.
              final scale = (box.maxWidth / 1500).clamp(0.0, box.maxHeight / 1500);
              final left = n.px![0] * scale;
              final top = n.px![1] * scale;
              return Positioned(
                left: left - 14,
                top: top - 14,
                child: _CellDot(
                  number: i + 1,
                  highlight: isLast,
                  label: n.label,
                ),
              );
            }),
          ],
        ),
      );
    });
  }
}

class _CellDot extends StatelessWidget {
  final int number;
  final bool highlight;
  final String label;
  const _CellDot({required this.number, required this.highlight, required this.label});

  @override
  Widget build(BuildContext context) {
    final color = highlight ? const Color(0xFFE65100) : const Color(0xFF2E7D32);
    return Tooltip(
      message: label,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: [
            BoxShadow(color: color.withOpacity(0.5), blurRadius: 6, spreadRadius: 1),
          ],
        ),
        alignment: Alignment.center,
        child: Text('$number',
            style: const TextStyle(
                color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
      ),
    );
  }
}

/// Shown when the floor-plan PNG hasn't been added yet — the route still works
/// as a labeled cell sequence.
class _PlanPlaceholder extends StatelessWidget {
  final List<NavNode> cells;
  const _PlanPlaceholder({required this.cells});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.meeting_room_outlined, color: Color(0xFF4A7A50), size: 56),
            const SizedBox(height: 12),
            const Text('Greenhouse floor-plan image not added yet.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF81C784), fontSize: 14)),
            const SizedBox(height: 16),
            ...cells.asMap().entries.map((e) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Text('${e.key + 1}.  ${e.value.label}',
                      style: const TextStyle(color: Color(0xFFE8F5E9), fontSize: 14)),
                )),
          ],
        ),
      ),
    );
  }
}

// ─── Step-by-step direction list ────────────────────────────────────────────

class _StepList extends StatelessWidget {
  final NavRoute route;
  const _StepList({required this.route});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxHeight: 150),
      decoration: const BoxDecoration(
        color: Color(0xFF0D1F14),
        border: Border(top: BorderSide(color: Color(0xFF1E3D24))),
      ),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: route.nodes.length,
        itemBuilder: (_, i) {
          final n = route.nodes[i];
          final isLast = i == route.nodes.length - 1;
          final isDoor = n.isDoor;
          return ListTile(
            dense: true,
            visualDensity: VisualDensity.compact,
            leading: Icon(
              isLast
                  ? Icons.place_rounded
                  : isDoor
                      ? Icons.door_front_door_rounded
                      : i == 0
                          ? Icons.my_location_rounded
                          : Icons.arrow_downward_rounded,
              color: isLast
                  ? const Color(0xFFE65100)
                  : isDoor
                      ? const Color(0xFFFFB300)
                      : const Color(0xFF66BB6A),
              size: 18,
            ),
            title: Text(
              isLast ? 'Arrive: ${n.label}' : n.label,
              style: TextStyle(
                color: const Color(0xFFE8F5E9),
                fontSize: 13,
                fontWeight: isLast || i == 0 ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
            subtitle: isDoor
                ? const Text('Enter the greenhouse here',
                    style: TextStyle(color: Color(0xFFFFD54F), fontSize: 11))
                : null,
          );
        },
      ),
    );
  }
}

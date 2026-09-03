// lib/screens/trail_screen.dart
//
// Themed walks through the garden, built from the garden's own plant records.
//
// What this replaces: three hand-written trails whose plants were real but
// whose coordinates and turn-by-turn directions were invented — "walk 150 m,
// turn left at the wooden sign" against a LatLng nobody had surveyed. It
// showed a map with a blue dot that meant nothing, and none of it changed when
// the plant data did.
//
// This screen carries no map and no coordinates on purpose. The garden has no
// surveyed positions for its outdoor sections, and an honest section name
// ("Tropical house") beats a confident pin in the wrong place. When real
// coordinates exist — the contest already records them per photo — a map can
// be added without any of this being rewritten.

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../data/plant_index.dart';
import '../data/trails.dart';
import '../services/usage_tracking_service.dart';

const _bg = Color(0xFF0A1A0F);
const _surface = Color(0xFF111F16);
const _border = Color(0xFF2A4A2F);
const _green = Color(0xFF4CAF50);
const _textPri = Color(0xFFE8F5E9);
const _textDim = Color(0xFF6E8A72);

class TrailScreen extends StatefulWidget {
  const TrailScreen({super.key});

  @override
  State<TrailScreen> createState() => _TrailScreenState();
}

class _TrailScreenState extends State<TrailScreen> {
  List<Trail> _trails = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    UsageTrackingService.instance.log(UsageTrackingService.featureTrails);
    _build();
  }

  Future<void> _build() async {
    await PlantIndex.instance.ready();
    if (!mounted) return;
    setState(() {
      _trails = buildTrails(
        PlantIndex.instance.all,
        labelFor: PlantIndex.instance.sectionLabel,
      );
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D1F14),
        elevation: 0,
        title: const Text('Garden trails',
            style: TextStyle(color: _textPri, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Color(0xFF66BB6A)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _green))
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                const Text(
                  'Pick a theme and walk it. Every stop is a plant the garden '
                  'records in that section, described in the garden’s own '
                  'words.',
                  style: TextStyle(
                      color: Color(0xFF9CCC9F), fontSize: 13.5, height: 1.5),
                ),
                const SizedBox(height: 18),
                for (var i = 0; i < _trails.length; i++)
                  _TrailCard(trail: _trails[i], index: i),
              ],
            ),
    );
  }
}

class _TrailCard extends StatelessWidget {
  const _TrailCard({required this.trail, required this.index});
  final Trail trail;
  final int index;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => TrailDetailScreen(trail: trail)),
          ),
          child: Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _border),
            ),
            child: Row(
              children: [
                Text(trail.emoji, style: const TextStyle(fontSize: 28)),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(trail.title,
                          style: const TextStyle(
                              color: _textPri,
                              fontSize: 16,
                              fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text(trail.subtitle,
                          style: const TextStyle(
                              color: Color(0xFF9CCC9F),
                              fontSize: 12.5,
                              height: 1.35)),
                      const SizedBox(height: 6),
                      Text(
                        '${trail.stops.length} plants · '
                        '${trail.sections.length} sections · '
                        '~${trail.minutes} min',
                        style: const TextStyle(color: _textDim, fontSize: 11.5),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: Color(0xFF4A7A50)),
              ],
            ),
          ),
        ),
      ),
    ).animate().slideY(
        begin: 0.1, duration: 300.ms, delay: (40 * index).ms, curve: Curves.easeOut);
  }
}

/// The walk itself: section by section, with each plant to find under it.
///
/// Ticking a plant off is deliberately local and unsaved. It is a walk, not a
/// competition — the Plant Hunt is next door for that — and nobody should
/// worry about a half-finished trail following them around.
class TrailDetailScreen extends StatefulWidget {
  const TrailDetailScreen({super.key, required this.trail});
  final Trail trail;

  @override
  State<TrailDetailScreen> createState() => _TrailDetailScreenState();
}

class _TrailDetailScreenState extends State<TrailDetailScreen> {
  final _found = <String>{};

  @override
  Widget build(BuildContext context) {
    final t = widget.trail;

    // Group the stops by section so the list reads as a walk rather than a
    // list of plants in no particular place.
    final grouped = <String, List<TrailStop>>{};
    for (final s in t.stops) {
      grouped.putIfAbsent(s.sectionLabel, () => []).add(s);
    }

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D1F14),
        elevation: 0,
        title: Text('${t.emoji}  ${t.title}',
            style: const TextStyle(color: _textPri, fontSize: 17)),
        iconTheme: const IconThemeData(color: Color(0xFF66BB6A)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          Text(t.subtitle,
              style: const TextStyle(
                  color: Color(0xFF9CCC9F), fontSize: 13.5, height: 1.5)),
          const SizedBox(height: 12),
          _Progress(found: _found.length, total: t.stops.length),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _border),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.route_rounded, size: 15, color: _green),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Your route: ${t.sections.join("  →  ")}',
                    style: const TextStyle(
                        color: Color(0xFFCFE8D2), fontSize: 12.5, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          for (final entry in grouped.entries) ...[
            Row(
              children: [
                Icon(
                  entry.value.first.isIndoors
                      ? Icons.holiday_village_rounded
                      : Icons.park_rounded,
                  size: 15,
                  color: _green,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(entry.key.toUpperCase(),
                      style: const TextStyle(
                          color: _green,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1)),
                ),
                Text(
                  '${entry.value.length} · '
                  '${entry.value.first.isIndoors ? "indoors" : "outdoors"}',
                  style: const TextStyle(color: _textDim, fontSize: 11.5),
                ),
              ],
            ),
            // The garden's own name for the same place — what is printed on
            // the sign the visitor is looking for.
            if ((entry.value.first.sectionRoom ?? '').isNotEmpty &&
                entry.value.first.sectionRoom!.toUpperCase() !=
                    entry.key.toUpperCase())
              Padding(
                padding: const EdgeInsets.only(left: 21, top: 2),
                child: Text(
                  'signed “${entry.value.first.sectionRoom}”',
                  style: const TextStyle(
                      color: Color(0xFF4A7A50),
                      fontSize: 11,
                      fontStyle: FontStyle.italic),
                ),
              ),
            const SizedBox(height: 8),
            for (final stop in entry.value)
              _StopTile(
                stop: stop,
                found: _found.contains(stop.scientificName),
                onToggle: () => setState(() {
                  if (!_found.remove(stop.scientificName)) {
                    _found.add(stop.scientificName);
                  }
                }),
              ),
            const SizedBox(height: 18),
          ],
          const SizedBox(height: 4),
          const Text(
            'Sections are where the garden’s records place each plant. Ask at '
            'the info desk if you cannot find one — plants do get moved.',
            style: TextStyle(color: Color(0xFF4A7A50), fontSize: 11.5, height: 1.4),
          ),
        ],
      ),
    );
  }
}

class _Progress extends StatelessWidget {
  const _Progress({required this.found, required this.total});
  final int found;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: total == 0 ? 0 : found / total,
              minHeight: 7,
              backgroundColor: const Color(0xFF13301A),
              valueColor: const AlwaysStoppedAnimation(Colors.greenAccent),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text('$found / $total found',
            style: const TextStyle(color: Color(0xFF9CCC9F), fontSize: 12)),
      ],
    );
  }
}

class _StopTile extends StatelessWidget {
  const _StopTile({
    required this.stop,
    required this.found,
    required this.onToggle,
  });

  final TrailStop stop;
  final bool found;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onToggle,
          child: Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: found ? const Color(0xFF16301D) : _surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: found ? const Color(0xFF66BB6A) : _border),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  found
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked,
                  size: 19,
                  color: found ? Colors.greenAccent : const Color(0xFF4A7A50),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(stop.displayName,
                          style: TextStyle(
                              color: _textPri,
                              fontSize: 14.5,
                              fontWeight: FontWeight.w600,
                              decoration: found
                                  ? TextDecoration.lineThrough
                                  : TextDecoration.none,
                              decorationColor: const Color(0xFF66BB6A))),
                      Text(
                        [
                          stop.scientificName,
                          if (stop.finnishName?.isNotEmpty ?? false)
                            stop.finnishName!,
                        ].join('  ·  '),
                        style: const TextStyle(
                            color: _textDim,
                            fontSize: 11.5,
                            fontStyle: FontStyle.italic),
                      ),
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          const Icon(Icons.place_outlined,
                              size: 12, color: Color(0xFF81C784)),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(stop.locationLine,
                                style: const TextStyle(
                                    color: Color(0xFF81C784), fontSize: 11.5)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      // The garden's own words about this plant.
                      Text(stop.why,
                          style: const TextStyle(
                              color: Color(0xFFCFE8D2),
                              fontSize: 12.5,
                              height: 1.45)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

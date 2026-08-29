// lib/screens/tour_screen.dart
//
// Self-guided tour planner — docs/plan.md Phase 6.
//
// That phase was blocked on "a curated highlight-plant list from the curator".
// It turned out to already exist, in the garden's own spreadsheet: 380 plants
// carrying 18 themed tags with hand-written English and Finnish descriptions,
// of which 169 are flagged "Keep it = y". This screen is that list, made usable.
//
// Ordering is by SECTION, not by walking distance. Only 58 of the 380 rows have
// coordinates, so a nearest-neighbour route would be precise for a sixth of the
// plants and invented for the rest. Grouping by section gives a visitor a real
// walking order — finish one area before moving to the next — without implying
// metre-accurate routing we cannot deliver.
//
// ponytail: filter + group + sort over the existing index. No solver, no new
// data file, no backend call. Upgrade to a real 2-opt route when every plant
// has a coordinate, not before.

import 'package:flutter/material.dart';
import '../data/plant_index.dart';
import '../services/language_service.dart';
import '../widgets/plant_tags_bar.dart';

/// Rough minutes spent standing at one plant. Walking between sections is on
/// top of this; both are estimates shown as "about", never as a promise.
const int _minutesPerStop = 3;

class TourScreen extends StatefulWidget {
  const TourScreen({super.key});

  @override
  State<TourScreen> createState() => _TourScreenState();
}

class _TourScreenState extends State<TourScreen> {
  final Set<String> _themes = {};
  int _budget = 30;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    PlantIndex.instance.ready().then((_) {
      if (mounted) setState(() => _ready = true);
    });
  }

  bool get _isFinnish => LanguageService.instance.current.code == 'fi';

  /// Plants matching the chosen themes, grouped by section, capped to the time
  /// budget. Returns section label -> plants in that section.
  Map<String, List<PlantFacts>> _plan() {
    final idx = PlantIndex.instance;
    final matches = <PlantFacts>[];

    for (final p in idx.all) {
      if (p.tags.isEmpty) continue;
      // No theme chosen = "anything interesting", so every tagged plant counts.
      if (_themes.isNotEmpty && !_themes.any(p.tags.containsKey)) continue;
      matches.add(p);
    }

    // Stable, meaningful order: richer entries first (more tags = more to say),
    // then alphabetical so the same choices always produce the same tour.
    matches.sort((a, b) {
      final c = b.tags.length.compareTo(a.tags.length);
      return c != 0 ? c : a.scientificName.compareTo(b.scientificName);
    });

    final maxStops = (_budget / _minutesPerStop).floor().clamp(1, 40);
    final chosen = matches.take(maxStops).toList();

    final grouped = <String, List<PlantFacts>>{};
    for (final p in chosen) {
      final label = idx.sectionLabel(p.sectionCode, preferEnglish: !_isFinnish);
      grouped.putIfAbsent(label.isEmpty ? '—' : label, () => []).add(p);
    }
    // Largest sections first — spend the visitor's time where the density is.
    final keys = grouped.keys.toList()
      ..sort((a, b) => grouped[b]!.length.compareTo(grouped[a]!.length));
    return {for (final k in keys) k: grouped[k]!};
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A1A0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D1F14),
        elevation: 0,
        title: Text(_isFinnish ? 'Suunnittele kierros' : 'Plan a tour'),
      ),
      body: !_ready
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _sectionLabel(_isFinnish ? 'Paljonko aikaa?' : 'How much time?'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final m in [15, 30, 45, 60, 90])
                      ChoiceChip(
                        label: Text('$m min'),
                        selected: _budget == m,
                        onSelected: (_) => setState(() => _budget = m),
                        labelStyle: TextStyle(
                          color: _budget == m
                              ? const Color(0xFF0A1A0F)
                              : const Color(0xFFE8F5E9),
                          fontWeight: FontWeight.w600,
                        ),
                        selectedColor: const Color(0xFF81C784),
                        backgroundColor: const Color(0xFF1B4020),
                        side: const BorderSide(color: Color(0xFF2E7D32)),
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                _sectionLabel(_isFinnish
                    ? 'Mikä kiinnostaa? (valinnainen)'
                    : 'What interests you? (optional)'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final t in kPlantTags)
                      FilterChip(
                        label: Text(t),
                        selected: _themes.contains(t),
                        onSelected: (on) => setState(
                            () => on ? _themes.add(t) : _themes.remove(t)),
                        labelStyle: TextStyle(
                          color: _themes.contains(t)
                              ? const Color(0xFF0A1A0F)
                              : const Color(0xFFE8F5E9),
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                        selectedColor: const Color(0xFF81C784),
                        backgroundColor: const Color(0xFF13301A),
                        side: const BorderSide(color: Color(0xFF2E7D32)),
                        showCheckmark: false,
                      ),
                  ],
                ),
                const SizedBox(height: 24),
                ..._buildPlan(),
                const SizedBox(height: 32),
              ],
            ),
    );
  }

  List<Widget> _buildPlan() {
    final plan = _plan();
    final total = plan.values.fold<int>(0, (a, b) => a + b.length);

    if (total == 0) {
      return [
        Text(
          _isFinnish
              ? 'Ei kasveja näillä valinnoilla. Kokeile vähemmän teemoja.'
              : 'No plants match those choices. Try fewer themes.',
          style: const TextStyle(color: Color(0xFF9CCC9F)),
        ),
      ];
    }

    return [
      Row(
        children: [
          const Icon(Icons.route_rounded, color: Color(0xFF81C784), size: 20),
          const SizedBox(width: 8),
          Text(
            _isFinnish
                ? '$total kasvia, ${plan.length} osastoa · noin ${total * _minutesPerStop} min'
                : '$total plants across ${plan.length} areas · about ${total * _minutesPerStop} min',
            style: const TextStyle(
              color: Color(0xFFE8F5E9),
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
      const SizedBox(height: 4),
      Text(
        _isFinnish
            ? 'Kierros on ryhmitelty osastoittain — käy yksi alue kerrallaan.'
            : 'Grouped by area — finish one before moving to the next.',
        style: const TextStyle(color: Color(0xFF6E8A72), fontSize: 12),
      ),
      const SizedBox(height: 16),
      for (final entry in plan.entries) ...[
        Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF13301A),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              const Icon(Icons.place_rounded, size: 16, color: Color(0xFF81C784)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  entry.key,
                  style: const TextStyle(
                    color: Color(0xFFE8F5E9),
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
              Text(
                '${entry.value.length}',
                style: const TextStyle(color: Color(0xFF81C784), fontSize: 13),
              ),
            ],
          ),
        ),
        for (final p in entry.value) _stop(p),
        const SizedBox(height: 14),
      ],
    ];
  }

  Widget _stop(PlantFacts p) {
    final common = _isFinnish
        ? (p.finnishName ?? p.englishName)
        : (p.englishName ?? p.finnishName);
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            p.scientificName,
            style: const TextStyle(
              color: Color(0xFFE8F5E9),
              fontSize: 14.5,
              fontStyle: FontStyle.italic,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (common != null && common.isNotEmpty)
            Text(common,
                style: const TextStyle(color: Color(0xFF9CCC9F), fontSize: 12.5)),
          PlantTagsBar(scientificName: p.scientificName),
        ],
      ),
    );
  }

  Widget _sectionLabel(String t) => Text(
        t.toUpperCase(),
        style: const TextStyle(
          color: Color(0xFF81C784),
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      );
}

// lib/screens/plants_screen.dart
//
// "Know your plants" — a browsable view of the garden's own plant records.
//
// Backed entirely by the two bundled CSVs (lib/data/plant_index.dart): 11,489
// plants with their identity and section, of which 380 carry curated tags and
// hand-written descriptions. No network call is involved, so this works with no
// signal anywhere in the garden — which is most of the greenhouses.
//
// Replaces the earlier tour-planner screen. Theme filtering survived from it,
// because "show me the edible ones" is the same question whether the visitor is
// planning a route or just browsing.
//
// ponytail: filter + group over the in-memory index. The full list is only
// rendered lazily by ListView, so no paging machinery for 11k rows.

import 'package:flutter/material.dart';
import '../data/plant_index.dart';
import '../services/language_service.dart';
import '../widgets/plant_tags_bar.dart';

class PlantsScreen extends StatefulWidget {
  const PlantsScreen({super.key});

  @override
  State<PlantsScreen> createState() => _PlantsScreenState();
}

class _PlantsScreenState extends State<PlantsScreen> {
  final Set<String> _themes = {};
  String _query = '';
  bool _onlyCurated = true;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    PlantIndex.instance.ready().then((_) {
      if (mounted) setState(() => _ready = true);
    });
  }

  bool get _isFinnish => LanguageService.instance.current.code == 'fi';

  List<PlantFacts> _results() {
    final q = _query.trim().toLowerCase();
    final out = <PlantFacts>[];

    for (final p in PlantIndex.instance.all) {
      // Curated-only is the default: 380 plants with real descriptions beats
      // 11k bare names for someone browsing rather than looking one up.
      if (_onlyCurated && p.tags.isEmpty) continue;
      if (_themes.isNotEmpty && !_themes.any(p.tags.containsKey)) continue;

      if (q.isNotEmpty) {
        final hay = [
          p.scientificName,
          p.englishName ?? '',
          p.finnishName ?? '',
          p.sectionCode ?? '',
        ].join(' ').toLowerCase();
        if (!hay.contains(q)) continue;
      }
      out.add(p);
    }

    out.sort((a, b) {
      // Richer entries first when browsing; plain alphabetical when searching,
      // because then the user has a specific plant in mind.
      if (q.isEmpty) {
        final c = b.tags.length.compareTo(a.tags.length);
        if (c != 0) return c;
      }
      return a.scientificName.compareTo(b.scientificName);
    });
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final results = _ready ? _results() : const <PlantFacts>[];

    return Scaffold(
      backgroundColor: const Color(0xFF0A1A0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D1F14),
        elevation: 0,
        title: Text(_isFinnish ? 'Tunne kasvit' : 'Know your plants'),
      ),
      body: !_ready
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: TextField(
                    style: const TextStyle(color: Color(0xFFE8F5E9)),
                    onChanged: (v) => setState(() => _query = v),
                    decoration: InputDecoration(
                      hintText: _isFinnish
                          ? 'Hae nimellä tai osastolla'
                          : 'Search by name or section',
                      hintStyle: const TextStyle(color: Color(0xFF6E8A72)),
                      prefixIcon:
                          const Icon(Icons.search, color: Color(0xFF81C784)),
                      filled: true,
                      fillColor: const Color(0xFF13301A),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                      isDense: true,
                    ),
                  ),
                ),
                SizedBox(
                  height: 46,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      FilterChip(
                        label: Text(_isFinnish ? 'Vain kuvatut' : 'Described only'),
                        selected: _onlyCurated,
                        onSelected: (v) => setState(() => _onlyCurated = v),
                        labelStyle: TextStyle(
                          color: _onlyCurated
                              ? const Color(0xFF0A1A0F)
                              : const Color(0xFFE8F5E9),
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                        selectedColor: const Color(0xFFFFB74D),
                        backgroundColor: const Color(0xFF13301A),
                        side: const BorderSide(color: Color(0xFF2E7D32)),
                        showCheckmark: false,
                      ),
                      const SizedBox(width: 8),
                      for (final t in kPlantTags) ...[
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
                        const SizedBox(width: 8),
                      ],
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _isFinnish
                          ? '${results.length} kasvia'
                          : '${results.length} plants',
                      style: const TextStyle(
                          color: Color(0xFF6E8A72), fontSize: 12),
                    ),
                  ),
                ),
                Expanded(
                  child: results.isEmpty
                      ? Center(
                          child: Text(
                            _isFinnish
                                ? 'Ei osumia.'
                                : 'Nothing matches those filters.',
                            style: const TextStyle(color: Color(0xFF9CCC9F)),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                          itemCount: results.length,
                          itemBuilder: (_, i) => _PlantRow(
                            facts: results[i],
                            isFinnish: _isFinnish,
                            onTap: () => _showDetail(results[i]),
                          ),
                        ),
                ),
              ],
            ),
    );
  }

  void _showDetail(PlantFacts p) {
    final idx = PlantIndex.instance;
    final common =
        _isFinnish ? (p.finnishName ?? p.englishName) : (p.englishName ?? p.finnishName);
    final section = idx.sectionLabel(p.sectionCode, preferEnglish: !_isFinnish);
    final finnishSection = idx.sectionFinnishName(p.sectionCode);

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0D1F14),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.8,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p.scientificName,
                  style: const TextStyle(
                    color: Color(0xFFE8F5E9),
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                if (common != null && common.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(common,
                        style: const TextStyle(
                            color: Color(0xFF9CCC9F), fontSize: 14)),
                  ),
                const SizedBox(height: 14),
                if (section.isNotEmpty)
                  _row(Icons.place_rounded, _isFinnish ? 'Osasto' : 'Area',
                      section +
                          (finnishSection != null &&
                                  finnishSection.toLowerCase() !=
                                      section.toLowerCase()
                              ? '  ·  $finnishSection'
                              : '') +
                          (p.sectionCode != null ? '  (${p.sectionCode})' : '')),
                if (p.englishName != null && p.englishName!.isNotEmpty)
                  _row(Icons.language_rounded, 'English', p.englishName!),
                if (p.finnishName != null && p.finnishName!.isNotEmpty)
                  _row(Icons.translate_rounded, 'Suomi', p.finnishName!),
                if (p.count != null && p.count!.isNotEmpty)
                  _row(Icons.numbers_rounded,
                      _isFinnish ? 'Määrä' : 'Count', p.count!),
                if (p.hankintaID != null)
                  _row(Icons.tag_rounded,
                      _isFinnish ? 'Tunniste' : 'Record id', p.hankintaID!),
                if (p.tags.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    (_isFinnish ? 'Mikä tekee siitä erityisen' : 'What makes it notable')
                        .toUpperCase(),
                    style: const TextStyle(
                      color: Color(0xFF81C784),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
                  ),
                  PlantTagsBar(scientificName: p.scientificName),
                  const SizedBox(height: 8),
                  for (final t in p.tags.keys)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(t,
                              style: const TextStyle(
                                  color: Color(0xFFFFD54F),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700)),
                          Text(
                            (_isFinnish ? p.tagsFi[t] : null) ?? p.tags[t] ?? '',
                            style: const TextStyle(
                                color: Color(0xFFCFE8D2),
                                fontSize: 13.5,
                                height: 1.45),
                          ),
                        ],
                      ),
                    ),
                ] else
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(
                      _isFinnish
                          ? 'Tälle kasville ei ole vielä kuvausta puutarhan aineistossa.'
                          : "The garden's records carry no description for this plant yet.",
                      style: const TextStyle(
                          color: Color(0xFF6E8A72), fontSize: 13),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _row(IconData icon, String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 16, color: const Color(0xFF81C784)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label.toUpperCase(),
                      style: const TextStyle(
                          color: Color(0xFF6E8A72),
                          fontSize: 10,
                          letterSpacing: 1.1,
                          fontWeight: FontWeight.w700)),
                  Text(value,
                      style: const TextStyle(
                          color: Color(0xFFE8F5E9), fontSize: 13.5)),
                ],
              ),
            ),
          ],
        ),
      );
}

class _PlantRow extends StatelessWidget {
  const _PlantRow({
    required this.facts,
    required this.isFinnish,
    required this.onTap,
  });

  final PlantFacts facts;
  final bool isFinnish;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final common = isFinnish
        ? (facts.finnishName ?? facts.englishName)
        : (facts.englishName ?? facts.finnishName);
    final section = PlantIndex.instance
        .sectionLabel(facts.sectionCode, preferEnglish: !isFinnish);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF111F16),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFF2A4A2F)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    facts.scientificName,
                    style: const TextStyle(
                      color: Color(0xFFE8F5E9),
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  if (common != null && common.isNotEmpty)
                    Text(common,
                        style: const TextStyle(
                            color: Color(0xFF9CCC9F), fontSize: 12.5)),
                  if (section.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Text(section,
                          style: const TextStyle(
                              color: Color(0xFF4A7A50), fontSize: 11.5)),
                    ),
                ],
              ),
            ),
            if (facts.isDangerous)
              const Padding(
                padding: EdgeInsets.only(right: 6),
                child: Icon(Icons.warning_amber_rounded,
                    size: 18, color: Color(0xFFEF5350)),
              ),
            if (facts.tags.isNotEmpty)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF1B4020),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('${facts.tags.length}',
                    style: const TextStyle(
                        color: Color(0xFF81C784),
                        fontSize: 11,
                        fontWeight: FontWeight.w700)),
              ),
            const Icon(Icons.chevron_right, color: Color(0xFF4A7A50)),
          ],
        ),
      ),
    );
  }
}

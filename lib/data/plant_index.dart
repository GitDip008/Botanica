// lib/data/plant_index.dart
//
// Static, bundled plant index built from two CSV assets:
//   • plant_report  (11k rows) — every plant's identity + section, keyed by
//     hankintaID / taksonin_nro. Lets the app resolve a plant's name and
//     location INSTANTLY with no network, so the slow garden API is only needed
//     for live data (inspections, actions, updates).
//   • Data (380 rows)          — curated tags + descriptions + EN/FI names.
//
// Loaded once, lazily, on first use.

import 'package:flutter/services.dart' show rootBundle;

const _tagFile =
    'assets/data/Plant_data_combined_previous_sources(Data).csv';
const _indexFile =
    'assets/data/Plant_data_combined_previous_sources(plant_report 1).csv';

/// The 18 curated tag columns, in CSV order (col 10..27 of the tag file).
const List<String> kPlantTags = [
  'Aromatic', 'Crop', 'Edible', 'Endangered', 'Exotic', 'Flowering',
  'Fragrant', 'Fruit-bearing', 'Historical', 'House plant', 'Medicinal',
  'Native', 'Pollinator', 'Resilient', 'Dangerous', 'Seasonal', 'Striking',
  'Unique',
];

class PlantFacts {
  PlantFacts(this.scientificName);
  final String scientificName;
  String? englishName;
  String? finnishName;
  String? sectionCode; // e.g. "G-HA" (before the tab)
  String? sectionRoom; // e.g. "TROOPPINEN HUONE" (after the tab)
  String? hankintaID;
  String? taksonNro;
  String? count;

  /// tag name -> curated "why" description (English). Only present tags are keys.
  final Map<String, String> tags = {};

  /// Same tags, Finnish descriptions (baked into the CSV). May be a subset.
  final Map<String, String> tagsFi = {};

  bool get isDangerous => tags.containsKey('Dangerous');
}

class PlantIndex {
  PlantIndex._();
  static final PlantIndex instance = PlantIndex._();

  final Map<String, PlantFacts> _byName = {}; // normalised sci name -> facts
  Future<void>? _loading;

  /// Normalise a scientific name for matching: lowercase, collapse whitespace.
  static String norm(String s) => s.toLowerCase().trim().replaceAll(RegExp(r'\s+'), ' ');

  Future<void> ready() => _loading ??= _load();

  PlantFacts? factsFor(String scientificName) => _byName[norm(scientificName)];

  /// Every plant in the index (call after [ready]).
  Iterable<PlantFacts> get all => _byName.values;

  Future<void> _load() async {
    // Index file first (identity + section for all plants).
    final indexRows = parseCsv(await rootBundle.loadString(_indexFile));
    for (final r in indexRows.skip(1)) {
      if (r.isEmpty || r[0].trim().isEmpty) continue;
      final f = _byName.putIfAbsent(norm(r[0]), () => PlantFacts(r[0].trim()));
      f.englishName ??= _clean(_at(r, 1));
      f.finnishName ??= _clean(_at(r, 2));
      _applySection(f, _at(r, 3));
      f.hankintaID ??= _clean(_at(r, 4));
      f.taksonNro ??= _clean(_at(r, 5));
    }

    // Tag file (adds curated tags + names for the highlighted subset).
    final tagRows = parseCsv(await rootBundle.loadString(_tagFile));
    for (final r in tagRows.skip(1)) {
      if (r.isEmpty || r[0].trim().isEmpty) continue;
      final f = _byName.putIfAbsent(norm(r[0]), () => PlantFacts(r[0].trim()));
      f.englishName ??= _clean(_at(r, 2));
      f.finnishName ??= _clean(_at(r, 3));
      _applySection(f, _at(r, 4));
      f.count ??= _clean(_at(r, 7));
      for (var i = 0; i < kPlantTags.length; i++) {
        final desc = _at(r, 10 + i).trim(); // EN cols 10..27
        if (desc.isNotEmpty) f.tags[kPlantTags[i]] = desc;
        final descFi = _at(r, 29 + i).trim(); // FI cols 29..46
        if (descFi.isNotEmpty) f.tagsFi[kPlantTags[i]] = descFi;
      }
    }
  }

  // Section cells look like "G-HA \t TROOPPINEN HUONE"; split on the tab.
  void _applySection(PlantFacts f, String raw) {
    final s = raw.trim();
    if (s.isEmpty || s == '#N/A' || f.sectionCode != null) return;
    final parts = s.split('\t');
    f.sectionCode = parts[0].trim();
    if (parts.length > 1) f.sectionRoom = parts.sublist(1).join(' ').trim();
  }

  static String _at(List<String> r, int i) => i < r.length ? r[i] : '';
  static String? _clean(String s) => s.trim().isEmpty ? null : s.trim();
}

/// Minimal RFC-4180 CSV parser: handles quoted fields, embedded commas, and
/// doubled quotes. Enough for these two files; no dependency needed.
/// ponytail: hand-rolled over adding a csv package for one loader.
List<List<String>> parseCsv(String input) {
  final rows = <List<String>>[];
  var field = StringBuffer();
  var row = <String>[];
  var inQuotes = false;
  for (var i = 0; i < input.length; i++) {
    final c = input[i];
    if (inQuotes) {
      if (c == '"') {
        if (i + 1 < input.length && input[i + 1] == '"') {
          field.write('"');
          i++;
        } else {
          inQuotes = false;
        }
      } else {
        field.write(c);
      }
    } else if (c == '"') {
      inQuotes = true;
    } else if (c == ',') {
      row.add(field.toString());
      field = StringBuffer();
    } else if (c == '\n' || c == '\r') {
      if (c == '\r' && i + 1 < input.length && input[i + 1] == '\n') i++;
      row.add(field.toString());
      field = StringBuffer();
      rows.add(row);
      row = <String>[];
    } else {
      field.write(c);
    }
  }
  if (field.isNotEmpty || row.isNotEmpty) {
    row.add(field.toString());
    rows.add(row);
  }
  return rows;
}

/// ponytail self-check: run `dart run lib/data/plant_index.dart`.
void main() {
  final rows = parseCsv('a,b,"c,d","e""f"\n1,2,3,4\n');
  assert(rows.length == 2, 'row count');
  assert(rows[0][2] == 'c,d', 'embedded comma');
  assert(rows[0][3] == 'e"f', 'doubled quote');
  assert(rows[1][0] == '1', 'second row');
  assert(PlantIndex.norm('  Coffea   ARABICA ') == 'coffea arabica', 'norm');
  // ignore: avoid_print
  print('plant_index self-check ok');
}

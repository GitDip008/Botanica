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

import 'encoding_fix.dart';

export 'encoding_fix.dart' show fixMojibake;

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

/// English glosses for the greenhouse zones — the only section codes a visitor
/// is routinely shown, since those are the rooms they walk through.
///
/// Derived from the Finnish names in the data (decoded 2026-08-24). Everything
/// else falls back to the garden's own name, which is the right default: we
/// adopted their vocabulary rather than inventing a parallel one.
const Map<String, String> kGreenhouseZoneEn = {
  'G-HA': 'Tropical house',
  'G-HB': 'Summer-rain zone',
  'G-HC': 'Ferns',
  'G-HD': 'Mediterranean zone',
  'G-HE': 'Temperate zone',
  'G-HF': 'Succulents',
  'G-HJ': 'Grow-on house',
  'G-HK': 'Teaching & trial house',
  'G-HL': 'Propagation house',
  'G-HO': 'Greenhouse section',
  'G-HT': 'Terrarium',
  'G-HZ': 'Elsewhere in the building',
};

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

  /// Facts for a scientific name.
  ///
  /// Falls back to a cultivar when the exact species is absent. The garden's
  /// spreadsheet records cultivars — "Coffea arabica 'Nana'" — while PlantNet
  /// and the live database return the species, "Coffea arabica". Without this,
  /// identifying a coffee plant finds no tags at all despite the garden holding
  /// three tagged coffee cultivars.
  ///
  /// Deliberately one-directional and prefix-anchored: a query for the species
  /// may match a cultivar of it, never the reverse, and never a merely similar
  /// name. "Rubus" must not resolve to "Rubus chamaemorus".
  PlantFacts? factsFor(String scientificName) {
    final q = norm(scientificName);
    if (q.isEmpty) return null;
    final exact = _byName[q];
    if (exact != null) return exact;

    // The remainder must be an infraspecific marker, not another word. A
    // cultivar reads "<species> 'Name'" or "<species> subsp. x"; a plain extra
    // word means a DIFFERENT taxon — "Rubus" must not resolve to "Rubus
    // chamaemorus", or cloudberry facts get attached to every bramble.
    final prefix = '$q ';
    PlantFacts? best;
    for (final entry in _byName.entries) {
      if (!entry.key.startsWith(prefix)) continue;
      final rest = entry.key.substring(prefix.length);
      if (!_infraspecific.hasMatch(rest)) continue;
      // Prefer whichever cultivar actually carries curated tags.
      if (best == null || (best.tags.isEmpty && entry.value.tags.isNotEmpty)) {
        best = entry.value;
      }
    }
    return best;
  }

  /// Markers that make the remainder a variant of the queried taxon rather than
  /// a different one: a cultivar in quotes, or an infraspecific rank.
  ///
  /// Hybrid markers (× / "x ") are deliberately absent. "Rubus x castoreus" is
  /// its own taxon, not a variant of Rubus, so treating it as a fallback for a
  /// genus query would attach one hybrid's facts to the whole genus.
  static final RegExp _infraspecific =
      RegExp(r"""^(['‘’“"]|subsp\.|ssp\.|var\.|cv\.|f\.|forma\b)""");

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

  /// Every section code seen in the data, mapped to its garden name.
  /// 188 entries — the full location vocabulary, including the 12 greenhouse
  /// zones that `agent_assets/indoor_translation.json` still lists as TODO.
  final Map<String, String> _sectionNames = {};

  /// Human label for a section code, e.g. "G-HA" -> "Tropical house".
  ///
  /// Prefers a visitor-friendly English gloss where one exists, otherwise the
  /// garden's own Finnish name from the data, otherwise the bare code. Never
  /// returns null so callers can drop it straight into a sentence.
  String sectionLabel(String? code, {bool preferEnglish = true}) {
    final c = (code ?? '').trim().toUpperCase();
    if (c.isEmpty) return '';
    if (preferEnglish) {
      final en = kGreenhouseZoneEn[c];
      if (en != null) return en;
    }
    return _sectionNames[c] ?? c;
  }

  /// The garden's own name for a code, untranslated. Null when unknown.
  String? sectionFinnishName(String? code) =>
      _sectionNames[(code ?? '').trim().toUpperCase()];

  /// All known section codes, sorted.
  List<String> get sectionCodes => _sectionNames.keys.toList()..sort();

  // Section cells look like "G-HA \t TROOPPINEN HUONE"; split on the tab.
  void _applySection(PlantFacts f, String raw) {
    final s = fixMojibake(raw).trim();
    if (s.isEmpty || s == '#N/A') return;
    final parts = s.split('\t');
    final code = parts[0].trim().toUpperCase();
    final room = parts.length > 1 ? parts.sublist(1).join(' ').trim() : '';

    // Register the vocabulary even when this plant already has a section, so
    // one pass over the data yields the complete code list.
    if (code.isNotEmpty && room.isNotEmpty) {
      _sectionNames.putIfAbsent(code, () => room);
    }
    if (f.sectionCode != null) return;
    f.sectionCode = code;
    if (room.isNotEmpty) f.sectionRoom = room;
  }

  static String _at(List<String> r, int i) => i < r.length ? r[i] : '';
  static String? _clean(String s) {
    final t = fixMojibake(s).trim();
    return t.isEmpty ? null : t;
  }
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


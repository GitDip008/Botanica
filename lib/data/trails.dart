// lib/data/trails.dart
//
// Themed walking trails, generated from the garden's own plant records.
//
// The trails this replaces were hand-written: real plants, but invented GPS
// coordinates and invented turn-by-turn directions ("walk 150 m, turn left at
// the wooden sign"). Neither survived contact with the actual garden, and
// nothing regenerated when the plant data changed.
//
// These are built from the 287 curated plants that carry both a tag and a real
// section code. Every stop is a plant the garden records as being in that
// section, described in the garden's own words. Nothing here is invented.
//
// Positions are deliberately section-level — "Tropical house", "Medicinal &
// Economic Section" — not coordinates. The garden has no surveyed lat/lng for
// its outdoor sections yet, and a made-up coordinate is worse than an honest
// section name: it sends people to the wrong place with false confidence.
//
// No Flutter imports, so the shaping is testable on its own.

import 'plant_index.dart';

/// One plant to find, and why it is worth finding.
class TrailStop {
  const TrailStop({
    required this.scientificName,
    required this.displayName,
    required this.sectionCode,
    required this.sectionLabel,
    required this.why,
    this.finnishName,
  });

  final String scientificName;

  /// English common name where the garden has one, otherwise the botanical
  /// name — the label a visitor reads first.
  final String displayName;
  final String? finnishName;

  final String sectionCode;
  final String sectionLabel;

  /// The garden's own curated note for this plant under this theme. This is
  /// why the stop is on the trail, and it is why nothing here needed writing.
  final String why;
}

/// A themed walk: a tag, and the plants carrying it, grouped by section.
class Trail {
  const Trail({
    required this.tag,
    required this.title,
    required this.subtitle,
    required this.emoji,
    required this.stops,
  });

  final String tag;
  final String title;
  final String subtitle;
  final String emoji;
  final List<TrailStop> stops;

  /// Sections visited, in walking order, without repeats.
  List<String> get sections {
    final seen = <String>[];
    for (final s in stops) {
      if (seen.isEmpty || seen.last != s.sectionLabel) {
        if (!seen.contains(s.sectionLabel)) seen.add(s.sectionLabel);
      }
    }
    return seen;
  }

  /// Rough walking time. Two minutes to find and read each plant, four more
  /// for each move between sections — paced for a visitor reading labels, not
  /// for a measured route the garden has never surveyed.
  int get minutes => stops.length * 2 + (sections.length - 1) * 4;
}

/// The themes worth walking, in the order they are offered.
///
/// Chosen from what the data actually supports: every one of these has at
/// least nine curated plants carrying both the tag and a section. Tags with
/// only a handful of plants ("Endangered", 3) make a disappointing walk and
/// are left out rather than padded.
const kTrailThemes = <String, List<String>>{
  // tag: [emoji, title, subtitle]
  'Edible': [
    '🍎',
    'Good enough to eat',
    'Plants people have grown for food, from staples to oddities.',
  ],
  'Dangerous': [
    '☠️',
    'Look, do not touch',
    'Beautiful, ordinary-looking, and best admired from a step back.',
  ],
  'Historical': [
    '📜',
    'Plants with a past',
    'Species that changed trade, medicine or the way people live.',
  ],
  'Fragrant': [
    '🌸',
    'Follow your nose',
    'Lean in close. These are the ones worth smelling.',
  ],
  'Medicinal': [
    '💊',
    'The garden pharmacy',
    'Plants that treated people long before pharmacies existed.',
  ],
  'Striking': [
    '✨',
    'Hard to walk past',
    'The shapes, colours and sheer size that stop people mid-path.',
  ],
  'Pollinator': [
    '🐝',
    'Built for insects',
    'Flowers shaped by, and for, whatever comes to visit them.',
  ],
  'Native': [
    '🇫🇮',
    'Finnish by nature',
    'What grows here without anybody planting it.',
  ],
  'Crop': [
    '🌾',
    'From field to table',
    'The species farming is built on, growing where you can see them.',
  ],
  'Fruit-bearing': [
    '🍇',
    'Fruit hunters',
    'Look up, and underneath — the fruit is not always where you expect.',
  ],
};

/// Greenhouse zones first, then outdoor sections.
///
/// Not a route — the garden has no surveyed paths — but an order that keeps a
/// walk from bouncing between the greenhouses and the far end of the grounds.
/// Everything under one roof is done together before stepping outside.
int _sectionRank(String code) {
  final c = code.trim().toUpperCase();
  if (c.startsWith('G-')) return 0; // under glass
  if (c.startsWith('L-') || c.startsWith('H-')) return 1; // fenced beds
  if (c.startsWith('S-')) return 2; // systematic
  if (c.startsWith('R-')) return 3; // arboretum
  return 4; // the rest of the grounds
}

/// The most stops a trail offers.
///
/// A hundred-stop "House plant" trail is a database dump, not a walk.
const kMaxTrailStops = 10;

/// The most sections one trail sends a visitor to.
///
/// Without this the spread picks one plant from each of a dozen sections, and
/// the walk becomes an hour of crossing the garden to look at a single plant
/// at a time. Concentrating on the richest few sections turns the same data
/// into a walk somebody would actually finish.
const kMaxTrailSections = 4;

/// Some section cells in the garden's data separate code from room name with a
/// space rather than a tab, so the same place arrives as both 'G-HA' and
/// 'G-HA TROOPPINEN HUONE'. Left alone they become two stops in two different
/// "sections" of the same trail.
String canonicalSectionCode(String raw) {
  final s = raw.trim().toUpperCase();
  final i = s.indexOf(' ');
  final head = i == -1 ? s : s.substring(0, i);
  // Only treat the first token as a code when it looks like one; free-text
  // names such as 'BEHIND ANNUALS' must stay whole.
  final looksLikeCode = RegExp(r'^[A-Z]-[A-Z0-9.]+$').hasMatch(head);
  return looksLikeCode ? head : s;
}

/// Builds every trail the data supports.
///
/// [minStops] drops themes too thin to be worth walking rather than padding
/// them out with plants that do not carry the tag.
List<Trail> buildTrails(Iterable<PlantFacts> plants,
    {String Function(String?)? labelFor, int minStops = 5}) {
  final label = labelFor ?? (c) => c ?? '';
  final out = <Trail>[];

  kTrailThemes.forEach((tag, meta) {
    final tagged = <TrailStop>[];
    for (final p in plants) {
      final why = p.tags[tag];
      final code = canonicalSectionCode(p.sectionCode ?? '');
      // Both are required: a plant with no section cannot be walked to, and a
      // plant with no curated note has nothing to say when you get there.
      if (why == null || why.trim().isEmpty || code.isEmpty) continue;
      tagged.add(TrailStop(
        scientificName: p.scientificName,
        displayName: (p.englishName?.trim().isNotEmpty ?? false)
            ? p.englishName!.trim()
            : p.scientificName,
        finnishName: p.finnishName,
        sectionCode: code,
        sectionLabel: label(code).isEmpty ? code : label(code),
        why: why.trim(),
      ));
    }
    if (tagged.length < minStops) return;

    // Group by section so the walk is section by section, and keep sections in
    // a stable order. Alphabetical within a section keeps the list from
    // reshuffling between app launches.
    tagged.sort((a, b) {
      final r = _sectionRank(a.sectionCode).compareTo(_sectionRank(b.sectionCode));
      if (r != 0) return r;
      final c = a.sectionCode.compareTo(b.sectionCode);
      return c != 0 ? c : a.displayName.compareTo(b.displayName);
    });

    final stops = _pickWalkableStops(tagged);

    out.add(Trail(
      tag: tag,
      emoji: meta[0],
      title: meta[1],
      subtitle: meta[2],
      stops: stops,
    ));
  });

  return out;
}

/// Chooses a walk out of everything carrying the tag.
///
/// Two competing pulls: enough stops to be worth doing, few enough sections
/// that the walk is not mostly walking. So it takes the richest few sections
/// and fills from those, rather than one plant from everywhere.
List<TrailStop> _pickWalkableStops(List<TrailStop> sorted) {
  final bySection = <String, List<TrailStop>>{};
  for (final s in sorted) {
    bySection.putIfAbsent(s.sectionCode, () => []).add(s);
  }

  // Richest sections first, ties broken by code so the choice is stable
  // between launches rather than depending on map iteration order.
  final codes = bySection.keys.toList()
    ..sort((a, b) {
      final c = bySection[b]!.length.compareTo(bySection[a]!.length);
      return c != 0 ? c : a.compareTo(b);
    });
  final chosen = codes.take(kMaxTrailSections).toList()
    ..sort((a, b) {
      final r = _sectionRank(a).compareTo(_sectionRank(b));
      return r != 0 ? r : a.compareTo(b);
    });

  // Round-robin within the chosen sections so no single section fills the
  // whole trail, then regroup so the walk still runs section by section.
  final picked = <TrailStop>[];
  var round = 0;
  while (picked.length < kMaxTrailStops) {
    var added = false;
    for (final code in chosen) {
      final list = bySection[code]!;
      if (round < list.length) {
        picked.add(list[round]);
        added = true;
        if (picked.length == kMaxTrailStops) break;
      }
    }
    if (!added) break;
    round++;
  }

  picked.sort((a, b) {
    final r = _sectionRank(a.sectionCode).compareTo(_sectionRank(b.sectionCode));
    if (r != 0) return r;
    final c = a.sectionCode.compareTo(b.sectionCode);
    return c != 0 ? c : a.displayName.compareTo(b.displayName);
  });
  return picked;
}

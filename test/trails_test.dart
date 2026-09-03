// test/trails_test.dart
//
// Trails are generated from the garden's plant records rather than written by
// hand, so the failures worth guarding are about shape, not content: a walk
// that crosses the whole garden for one plant at a time, a stop with nothing
// to say when you arrive, or the same place appearing twice under two names.

import 'package:botanica_ar/data/plant_index.dart';
import 'package:botanica_ar/data/trails.dart';
import 'package:flutter_test/flutter_test.dart';

PlantFacts _plant(
  String sci, {
  String? section,
  String? english,
  Map<String, String> tags = const {},
}) {
  final p = PlantFacts(sci);
  p.sectionCode = section;
  p.englishName = english;
  tags.forEach((k, v) => p.tags[k] = v);
  return p;
}

/// Enough tagged plants to clear the minimum, spread over [sections].
List<PlantFacts> _many(String tag, int n, List<String> sections) => [
      for (var i = 0; i < n; i++)
        _plant('Genus species$i',
            section: sections[i % sections.length],
            english: 'Plant $i',
            tags: {tag: 'Why plant $i is on this trail.'}),
    ];

void main() {
  group('section codes', () {
    test('a code split by a space is the same place as the bare code', () {
      // The garden's data uses a tab in most rows and a space in 44 of them.
      // Left alone, "G-HA" and "G-HA TROOPPINEN HUONE" become two sections of
      // the same trail — which is exactly what happened first time.
      expect(canonicalSectionCode('G-HA TROOPPINEN HUONE'), 'G-HA');
      expect(canonicalSectionCode('g-ha'), 'G-HA');
      expect(canonicalSectionCode('  G-HA  '), 'G-HA');
    });

    test('a free-text section name is left whole', () {
      // "BEHIND ANNUALS" must not become "BEHIND".
      expect(canonicalSectionCode('Behind annuals'), 'BEHIND ANNUALS');
      expect(canonicalSectionCode('First room of Julia'), 'FIRST ROOM OF JULIA');
    });

    test('codes with digits and dots survive', () {
      expect(canonicalSectionCode('T-1.5.2 KALKKINIITYT'), 'T-1.5.2');
    });
  });

  group('what makes it onto a trail', () {
    test('a plant with no section is left out', () {
      // It cannot be walked to.
      final trails = buildTrails([
        ..._many('Edible', 6, ['G-HA']),
        _plant('Nowhere plantus',
            section: null, tags: {'Edible': 'No section.'}),
      ]);
      final stops = trails.single.stops.map((s) => s.scientificName);
      expect(stops, isNot(contains('Nowhere plantus')));
    });

    test('a plant with no curated note is left out', () {
      // It would have nothing to say when you got there.
      final trails = buildTrails([
        ..._many('Edible', 6, ['G-HA']),
        _plant('Silent plantus', section: 'G-HA', tags: {'Edible': '   '}),
      ]);
      final stops = trails.single.stops.map((s) => s.scientificName);
      expect(stops, isNot(contains('Silent plantus')));
    });

    test('a theme too thin to walk is dropped, not padded', () {
      // Three plants is not a trail. Better no trail than a disappointing one.
      final trails = buildTrails(_many('Edible', 3, ['G-HA']));
      expect(trails, isEmpty);
    });

    test('the botanical name stands in when there is no common name', () {
      final trails = buildTrails([
        for (var i = 0; i < 6; i++)
          _plant('Botanicus nameonly$i',
              section: 'G-HA', tags: {'Edible': 'Note $i'}),
      ]);
      expect(trails.single.stops.first.displayName,
          startsWith('Botanicus nameonly'));
    });
  });

  group('the walk is walkable', () {
    test('a huge theme is capped instead of dumping the database', () {
      final trails = buildTrails(_many('Edible', 100, ['G-HA', 'G-HB']));
      expect(trails.single.stops.length, lessThanOrEqualTo(kMaxTrailStops));
    });

    test('a trail never sends you to more sections than the cap', () {
      // The bug this replaces: 12 stops across 12 sections, one plant each,
      // an hour of walking between single plants.
      final sections = ['G-HA', 'G-HB', 'G-HC', 'G-HD', 'S-O', 'R-O', 'L-O'];
      final trails = buildTrails(_many('Edible', 60, sections));
      expect(trails.single.sections.length,
          lessThanOrEqualTo(kMaxTrailSections));
    });

    test('stops are grouped so each section is visited once', () {
      final trails = buildTrails(_many('Edible', 40, ['G-HA', 'G-HB', 'S-O']));
      final order = trails.single.stops.map((s) => s.sectionLabel).toList();
      // Once a section is left, it is never returned to.
      final seen = <String>{};
      String? current;
      for (final label in order) {
        if (label != current) {
          expect(seen.contains(label), isFalse,
              reason: 'returned to $label after leaving it');
          seen.add(label);
          current = label;
        }
      }
    });

    test('greenhouse sections come before outdoor ones', () {
      // Everything under one roof gets done before stepping outside.
      final trails = buildTrails(_many('Edible', 40, ['R-O', 'G-HA']));
      final first = trails.single.stops.first.sectionCode;
      expect(first, startsWith('G-'));
    });

    test('the same data always produces the same trail', () {
      // Order must not depend on map iteration, or the walk reshuffles between
      // app launches and a half-finished trail stops matching.
      final plants = _many('Edible', 40, ['G-HA', 'G-HB', 'S-O']);
      final a = buildTrails(plants).single.stops.map((s) => s.scientificName);
      final b = buildTrails(plants).single.stops.map((s) => s.scientificName);
      expect(a, orderedEquals(b));
    });
  });

  group('estimated time', () {
    test('counts both the looking and the walking between sections', () {
      final trails = buildTrails(_many('Edible', 8, ['G-HA', 'G-HB']));
      final t = trails.single;
      expect(t.minutes, t.stops.length * 2 + (t.sections.length - 1) * 4);
      expect(t.minutes, greaterThan(0));
    });
  });

  group('against the real garden data', () {
    setUpAll(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      await PlantIndex.instance.ready();
    });

    test('the real records produce several walkable trails', () {
      final trails = buildTrails(PlantIndex.instance.all,
          labelFor: PlantIndex.instance.sectionLabel);
      expect(trails.length, greaterThanOrEqualTo(5),
          reason: 'the curated CSV should support at least five themes');
      for (final t in trails) {
        expect(t.stops.length, greaterThanOrEqualTo(5), reason: t.title);
        expect(t.stops.length, lessThanOrEqualTo(kMaxTrailStops), reason: t.title);
        expect(t.sections.length, lessThanOrEqualTo(kMaxTrailSections),
            reason: t.title);
        // Nothing invented: every stop carries a real note and a real place.
        for (final s in t.stops) {
          expect(s.why.trim(), isNotEmpty);
          expect(s.sectionLabel.trim(), isNotEmpty);
        }
      }
    });

    test('a trail never lists the same plant twice', () {
      final trails = buildTrails(PlantIndex.instance.all,
          labelFor: PlantIndex.instance.sectionLabel);
      for (final t in trails) {
        final names = t.stops.map((s) => s.scientificName).toList();
        expect(names.toSet().length, names.length, reason: t.title);
      }
    });
  });
}

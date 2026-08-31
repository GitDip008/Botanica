// test/data_test.dart
//
// The data layer: encoding repair, the plant index, greenhouse cells.
//
// These cover the failures that are SILENT — a corrupted Finnish string, a
// section that resolves to the wrong name, a cell that lands in the wrong
// greenhouse. None of those throw; they just quietly produce wrong output, and
// some of them can reach the garden's records.

import 'dart:io';

import 'package:botanica_ar/data/greenhouse_cells.dart';
import 'package:botanica_ar/data/plant_index.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('encoding repair', () {
    test('fixes the double-encoding in the garden CSV exports', () {
      expect(fixMojibake('TALVISAT. L. VÃ„LIMEREN ILMASTOALUE'),
          'TALVISAT. L. VÄLIMEREN ILMASTOALUE');
      expect(fixMojibake('KESÃ„SATEIDEN ALUE'), 'KESÄSATEIDEN ALUE');
      expect(fixMojibake('HYÃ–TYKASVI OSASTO'), 'HYÖTYKASVI OSASTO');
      expect(fixMojibake('LÃ„Ã„KEKASVI OSASTO'), 'LÄÄKEKASVI OSASTO');
    });

    test('leaves correct text untouched', () {
      expect(fixMojibake('KESÄSATEIDEN ALUE'), 'KESÄSATEIDEN ALUE');
      expect(fixMojibake('TROOPPINEN HUONE'), 'TROOPPINEN HUONE');
      expect(fixMojibake('Rukoushelmi'), 'Rukoushelmi');
      expect(fixMojibake(''), '');
    });

    test('does not mangle a legitimate lone Ã', () {
      // Reversing it alone yields an incomplete UTF-8 sequence, so the original
      // must survive. Getting this wrong corrupts real plant names.
      expect(fixMojibake('Ã'), 'Ã');
    });

    test('is idempotent', () {
      final once = fixMojibake('KESÃ„SATEIDEN ALUE');
      expect(fixMojibake(once), once);
    });
  });

  group('greenhouse cells', () {
    late List<GreenhouseCell> cells;

    setUpAll(() {
      final raw =
          File('agent_assets/greenhouse_cells.geojson').readAsStringSync();
      cells = parseGreenhouseCells(raw);
    });

    test('parses all 37 surveyed cells', () {
      expect(cells.length, 37);
    });

    test('splits Romeo and Julia as surveyed', () {
      // Blocks A+B sit in the upper-right cluster, D+E+F lower-left. Verified
      // against Phuc's node graph, which shares this coordinate frame.
      expect(cellsIn(cells, Greenhouse.romeo).length, 19);
      expect(cellsIn(cells, Greenhouse.julia).length, 18);
    });

    test('orders numerically inside a block, not lexically', () {
      final romeo = cellsIn(cells, Greenhouse.romeo).map((c) => c.name).toList();
      expect(romeo.indexOf('A2'), lessThan(romeo.indexOf('A10')));
    });

    test('lookup is case-insensitive and tolerates whitespace', () {
      expect(findCell(cells, ' a12 ')?.name, 'A12');
      expect(findCell(cells, 'A12')?.name, 'A12');
      expect(findCell(cells, 'ZZ99'), isNull);
    });

    test('coordinates share the navigation graph frame', () {
      // If these drift, routes draw in the wrong place while still "working".
      for (final c in cells) {
        expect(c.x, inInclusiveRange(-170, -120));
        expect(c.y, inInclusiveRange(-15, 22));
      }
    });
  });

  group('plant index', () {
    setUpAll(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      await PlantIndex.instance.ready();
    });

    test('loads both CSVs', () {
      // 11,489 CSV rows collapse to ~5,000 DISTINCT scientific names — the same
      // species is acquired many times over, one row per acquisition. The index
      // is keyed by name, so this counts species and not rows.
      expect(PlantIndex.instance.all.length, greaterThan(4500));
    });

    test('contains plants that exist in the live database', () {
      // Guards against a silent parse failure that leaves the index populated
      // but wrong — every one of these is real in the garden's records.
      for (final name in [
        'Theobroma cacao',
        'Valeriana officinalis',
        'Rubus chamaemorus',
      ]) {
        expect(PlantIndex.instance.factsFor(name), isNotNull,
            reason: '$name missing from the index');
      }
    });

    test('a species query resolves to one of its cultivars', () {
      // The spreadsheet holds "Coffea arabica 'Nana'" and friends, but never
      // the bare species — while PlantNet and the live database return the
      // species. Without the fallback, identifying a coffee plant finds no
      // tags despite the garden holding three tagged coffee cultivars.
      final coffee = PlantIndex.instance.factsFor('Coffea arabica');
      expect(coffee, isNotNull);
      expect(coffee!.scientificName, startsWith('Coffea arabica'));
    });

    test('the cultivar fallback does not match a bare genus', () {
      // "Rubus" resolving to "Rubus chamaemorus" would attach cloudberry facts
      // to any bramble — confidently wrong is worse than empty.
      final genusOnly = PlantIndex.instance.factsFor('Rubus');
      expect(
        genusOnly == null || genusOnly.scientificName.toLowerCase() == 'rubus',
        isTrue,
        reason: 'a genus query must not resolve to a species',
      );
    });

    test('resolves the full section vocabulary', () {
      expect(PlantIndex.instance.sectionCodes.length, greaterThan(150));
    });

    test('section names survive the encoding repair', () {
      // The bug this guards: "KESÄSATEIDEN" arriving as "KESÃ„SATEIDEN".
      final names = PlantIndex.instance.sectionCodes
          .map((c) => PlantIndex.instance.sectionFinnishName(c) ?? '')
          .join(' ');
      expect(names.contains('Ã'), isFalse,
          reason: 'mojibake leaked into section names');
      expect(names, contains('Ä'));
    });

    test('greenhouse zones get an English gloss, others keep Finnish', () {
      expect(PlantIndex.instance.sectionLabel('G-HA'), 'Tropical house');
      expect(PlantIndex.instance.sectionLabel('G-HF'), 'Succulents');
      // Not a greenhouse zone: the garden's own name is the right answer.
      final arboretum = PlantIndex.instance.sectionLabel('R-O');
      expect(arboretum.toUpperCase(), contains('ARBORETUM'));
    });

    test('sectionLabel never returns null-ish for unknown input', () {
      expect(PlantIndex.instance.sectionLabel(null), '');
      expect(PlantIndex.instance.sectionLabel('NOPE-1'), 'NOPE-1');
    });

    test('curated plants carry tag descriptions in both languages', () {
      final tagged =
          PlantIndex.instance.all.where((p) => p.tags.isNotEmpty).toList();
      expect(tagged.length, greaterThan(300));
      // Every tag key must be one we know how to render.
      for (final p in tagged.take(50)) {
        for (final k in p.tags.keys) {
          expect(kPlantTags, contains(k));
        }
      }
    });

    test('name lookup is normalised', () {
      final any = PlantIndex.instance.all.first.scientificName;
      expect(PlantIndex.instance.factsFor(any.toUpperCase()), isNotNull);
      expect(PlantIndex.instance.factsFor('  ${any.toLowerCase()}  '),
          isNotNull);
    });
  });
}

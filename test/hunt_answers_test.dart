// test/hunt_answers_test.dart
//
// Judging typed Plant Hunt answers.
//
// Two failures matter and they pull against each other: rejecting a visitor
// who is standing at the right tag and typed it slightly wrong, and accepting
// someone who typed a different plant. Every case below is one or the other.

import 'package:botanica_ar/data/hunt_answers.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  List<String> of(String key) => kHuntAccepted[key]!;

  group('the tag text itself', () {
    // Exactly what is stamped on the garden's metal labels, which is what a
    // visitor is copying from.
    final tags = {
      'cacao': ['kaakaopuu', 'Theobroma cacao'],
      'monstera': ['jättipeikonlehti', 'Monstera deliciosa'],
      'kultapallo': ['kultapallo', 'Rudbeckia laciniata'],
      'grape': ['tarhaviiniköynnös', 'Vitis vinifera subsp. vinifera'],
      'mustard': ['keltasinappi', 'Sinapis alba'],
    };

    tags.forEach((key, names) {
      for (final name in names) {
        test('"$name" solves $key outright', () {
          final s = scoreAnswer(name, of(key));
          expect(s.points, 100);
          expect(s.isCorrect, isTrue);
        });
      }
    });
  });

  group('everyday names', () {
    final everyday = {
      'cacao': ['cocoa', 'chocolate tree', 'cacao'],
      'monstera': ['monstera', 'swiss cheese plant'],
      'kultapallo': ['golden glow', 'coneflower'],
      'grape': ['grape', 'grapevine', 'rypäle'],
      'mustard': ['mustard', 'white mustard', 'sinappi'],
    };

    everyday.forEach((key, names) {
      for (final name in names) {
        test('"$name" counts for $key', () {
          expect(scoreAnswer(name, of(key)).isCorrect, isTrue);
        });
      }
    });
  });

  group('near misses still find the plant', () {
    final typos = {
      'monstera': ['monstra deliciosa', 'monstera deliciosia', 'jattipeikonlehti'],
      'cacao': ['theobroma cacoa', 'kaakaopu'],
      'grape': ['vitis vinifera', 'tarhaviinikoynnos', 'grapes'],
      'mustard': ['sinapsis alba', 'keltasinapi'],
      'kultapallo': ['rudbekia laciniata', 'kultapalo'],
    };

    typos.forEach((key, names) {
      for (final name in names) {
        test('"$name" is accepted for $key', () {
          expect(scoreAnswer(name, of(key)).isCorrect, isTrue,
              reason: 'scored ${scoreAnswer(name, of(key)).points}');
        });
      }
    });
  });

  group('a different plant is never accepted', () {
    // The one that would ruin the hunt: answers that belong to another quest.
    final keys = kHuntAccepted.keys.toList();
    for (final answerKey in keys) {
      for (final questKey in keys) {
        if (answerKey == questKey) continue;
        test('$answerKey answers do not solve $questKey', () {
          for (final name in of(answerKey)) {
            final s = scoreAnswer(name, of(questKey));
            expect(s.isCorrect, isFalse,
                reason: '"$name" scored ${s.points} against $questKey');
          }
        });
      }
    }
  });

  group('junk', () {
    test('empty and whitespace score nothing', () {
      expect(scoreAnswer('', of('cacao')).points, 0);
      expect(scoreAnswer('   ', of('cacao')).points, 0);
    });

    test('a single letter cannot match by containment', () {
      for (final key in kHuntAccepted.keys) {
        expect(scoreAnswer('a', of(key)).isCorrect, isFalse);
        expect(scoreAnswer('the', of(key)).isCorrect, isFalse);
      }
    });

    test('an unrelated word is rejected', () {
      expect(scoreAnswer('bicycle', of('grape')).isCorrect, isFalse);
      expect(scoreAnswer('oak tree', of('cacao')).isCorrect, isFalse);
    });
  });

  group('scoring separates confidence', () {
    test('a clean answer outscores a rough one', () {
      final clean = scoreAnswer('Monstera deliciosa', of('monstera')).points;
      final rough = scoreAnswer('monstra deliciosia', of('monstera')).points;
      expect(clean, 100);
      expect(rough, lessThan(clean));
      expect(rough, greaterThanOrEqualTo(68));
    });

    test('a rough answer is flagged as approximate, a clean one is not', () {
      expect(scoreAnswer('monstra deliciosia', of('monstera')).isApproximate,
          isTrue);
      expect(
          scoreAnswer('Monstera deliciosa', of('monstera')).isApproximate,
          isFalse);
    });

    test('points never exceed the per-quest maximum the rules allow', () {
      // firestore.rules caps a five-quest total at 500.
      for (final key in kHuntAccepted.keys) {
        for (final name in of(key)) {
          expect(scoreAnswer(name, of(key)).points, lessThanOrEqualTo(100));
        }
      }
    });
  });

  group('normalisation', () {
    test('accents, case and punctuation do not matter', () {
      expect(normalizeAnswer('Jättipeikonlehti!'), 'jattipeikonlehti');
      expect(normalizeAnswer('Tarhaviiniköynnös'), 'tarhaviinikoynnos');
      expect(normalizeAnswer('  Cut-Leaf   Coneflower '),
          'cut leaf coneflower');
    });

    test('a Finnish name typed on an English keyboard still matches', () {
      expect(scoreAnswer('jattipeikonlehti', of('monstera')).points, 100);
      expect(scoreAnswer('tarhaviinikoynnos', of('grape')).points, 100);
    });
  });

  group('edit distance', () {
    test('behaves like Levenshtein on known pairs', () {
      expect(editDistance('kitten', 'sitting'), 3);
      expect(editDistance('', 'abc'), 3);
      expect(editDistance('abc', 'abc'), 0);
    });
  });
}

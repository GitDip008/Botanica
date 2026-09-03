// test/hunt_answers_test.dart
//
// Judging typed Plant Hunt answers.
//
// Two failures matter and they pull against each other: rejecting a visitor
// who is standing at the right tag and typed it slightly wrong, and accepting
// someone who typed a different plant. Every case below is one or the other.

import 'package:botanica_ar/data/hunt_answers.dart';
import 'package:botanica_ar/screens/plant_hunt_screen.dart';
import 'package:botanica_ar/services/hunt_score_service.dart';
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


  group('photo check', () {
    PhotoVerdict check(String sci, String fam, String key,
            {bool isPlant = true}) =>
        checkPhotoPlant(
          isPlant: isPlant,
          detectedScientific: sci,
          detectedFamily: fam,
          targetScientific: {
            'cacao': 'Theobroma cacao',
            'monstera': 'Monstera deliciosa',
            'kultapallo': 'Rudbeckia laciniata',
            'grape': 'Vitis vinifera',
            'mustard': 'Sinapis alba',
          }[key]!,
          targetFamilies: kHuntFamilies[key]!,
        );

    test('the exact species passes', () {
      expect(check('Theobroma cacao', 'Malvaceae', 'cacao'),
          PhotoVerdict.accepted);
      expect(check('Sinapis alba', 'Brassicaceae', 'mustard'),
          PhotoVerdict.accepted);
    });

    test('a neighbouring species of the same genus passes', () {
      // PlantNet routinely returns a sibling species for the same specimen.
      expect(check('Monstera adansonii', 'Araceae', 'monstera'),
          PhotoVerdict.accepted);
      expect(check('Rudbeckia hirta', 'Asteraceae', 'kultapallo'),
          PhotoVerdict.accepted);
    });

    test('a different plant of the same family passes', () {
      expect(check('Brassica napus', 'Brassicaceae', 'mustard'),
          PhotoVerdict.accepted);
    });

    test('the old family name on the garden tag still passes', () {
      // The cacao tag reads Sterculiaceae; identifiers say Malvaceae. Both
      // have to work or every correct cacao photo would be rejected.
      expect(check('Theobroma bicolor', 'Sterculiaceae', 'cacao'),
          PhotoVerdict.accepted);
      expect(check('Herrania nitida', 'Malvaceae', 'cacao'),
          PhotoVerdict.accepted);
      expect(check('Rudbeckia laciniata', 'Compositae', 'kultapallo'),
          PhotoVerdict.accepted);
    });

    test('a plant from another family is rejected', () {
      expect(check('Monstera deliciosa', 'Araceae', 'mustard'),
          PhotoVerdict.wrongPlant);
      expect(check('Vitis vinifera', 'Vitaceae', 'cacao'),
          PhotoVerdict.wrongPlant);
      expect(check('Quercus robur', 'Fagaceae', 'grape'),
          PhotoVerdict.wrongPlant);
    });

    test('a photo of something that is not a plant is rejected', () {
      expect(check('Unknown', 'N/A', 'grape', isPlant: false),
          PhotoVerdict.notAPlant);
      expect(check('', '', 'grape', isPlant: true), PhotoVerdict.notAPlant);
      expect(check('Unknown', 'N/A', 'grape'), PhotoVerdict.notAPlant);
    });

    test('an unplaceable plant is inconclusive, not a wrong answer', () {
      // Distinct from wrongPlant on purpose: the visitor may well be standing
      // at the right plant, and the message tells them to retake rather than
      // to go and look somewhere else.
      expect(check('Something obscure', 'N/A', 'grape'),
          PhotoVerdict.inconclusive);
      expect(check('Something obscure', '', 'grape'),
          PhotoVerdict.inconclusive);
    });

    test('family matching ignores case and stray punctuation', () {
      expect(check('Vitis riparia', 'vitaceae', 'grape'),
          PhotoVerdict.accepted);
      expect(check('Vitis riparia', ' Vitaceae ', 'grape'),
          PhotoVerdict.accepted);
    });
  });


  group('leaderboard ranking', () {
    int rank(int solved, int total) => HuntScore.rankOf(solved, total);

    test('more plants found always outranks more points', () {
      // The whole point of the change: someone who found four plants with
      // hints beats someone who found three cleanly.
      expect(rank(4, 100), greaterThan(rank(3, 300)));
      expect(rank(1, 0), greaterThan(rank(0, 500)));
    });

    test('points break a tie between equal hunters', () {
      expect(rank(3, 240), greaterThan(rank(3, 239)));
      expect(rank(5, 500), greaterThan(rank(5, 499)));
    });

    test('a perfect run cannot collide with the tier above it', () {
      // The multiplier only works while a total can never reach it.
      expect(rank(4, 500), lessThan(rank(5, 0)));
    });

    test('ranks are ordered the same as (solved, points) would be', () {
      final runs = [
        [0, 0], [1, 23], [1, 100], [2, 50], [3, 300], [4, 100], [5, 500],
      ];
      final ranks = runs.map((r) => rank(r[0], r[1])).toList();
      final sorted = [...ranks]..sort();
      expect(ranks, sorted, reason: 'rank must rise with (solved, points)');
    });
  });

  _pointsTests();

  group('edit distance', () {
    test('behaves like Levenshtein on known pairs', () {
      expect(editDistance('kitten', 'sitting'), 3);
      expect(editDistance('', 'abc'), 3);
      expect(editDistance('abc', 'abc'), 0);
    });
  });
}

// ─── Points ───────────────────────────────────────────────────────────────────

void _pointsTests() {
  group('quest points', () {
    test('a clean answer with no hints banks the full score', () {
      expect(
        questPoints(
            answerScore: 100,
            usedLocationHint: false,
            usedPhotoHint: false,
            answerRevealed: false),
        100,
      );
    });

    test('each hint costs what the rules say it costs', () {
      expect(
        questPoints(
            answerScore: 100,
            usedLocationHint: true,
            usedPhotoHint: false,
            answerRevealed: false),
        100 - kLocationHintCost,
      );
      expect(
        questPoints(
            answerScore: 100,
            usedLocationHint: false,
            usedPhotoHint: true,
            answerRevealed: false),
        100 - kPhotoHintCost,
      );
      expect(
        questPoints(
            answerScore: 100,
            usedLocationHint: true,
            usedPhotoHint: true,
            answerRevealed: false),
        100 - kLocationHintCost - kPhotoHintCost,
      );
    });

    test('the photo hint costs more than the location hint', () {
      // Seeing the plant is most of the puzzle; knowing the greenhouse is not.
      expect(kPhotoHintCost, greaterThan(kLocationHintCost));
    });

    test('an unconfirmed photo is the cheapest way through, by choice', () {
      // This reverses an earlier deliberate rule. The garden decided a refusal
      // is usually the identifier's failing rather than the visitor's, so the
      // hatch is priced as a nuisance rather than a penalty. The check still
      // has teeth from the gate around it: never for an empty frame, never
      // before a second rejected photo.
      expect(kUncheckedPhotoCost, lessThan(kLocationHintCost));
      expect(kUncheckedPhotoCost, lessThan(kPhotoHintCost));
    });

    test('a waived unconfirmed-photo cost deducts nothing', () {
      // Kultapallo: a garden cultivar among lookalike yellow composites that
      // the identifier regularly misreads. Charging for the app's blind spot
      // would be charging the visitor for our problem.
      expect(
        questPoints(
            answerScore: 100,
            usedLocationHint: false,
            usedPhotoHint: false,
            answerRevealed: false,
            uncheckedPhoto: true,
            uncheckedPhotoCost: 0),
        100,
      );
    });

    test('the waiver does not leak into the hint costs', () {
      expect(
        questPoints(
            answerScore: 100,
            usedLocationHint: true,
            usedPhotoHint: true,
            answerRevealed: false,
            uncheckedPhoto: true,
            uncheckedPhotoCost: 0),
        100 - kLocationHintCost - kPhotoHintCost,
      );
    });

    test('skipping the photo check costs what the rules say', () {
      expect(
        questPoints(
            answerScore: 100,
            usedLocationHint: false,
            usedPhotoHint: false,
            answerRevealed: false,
            uncheckedPhoto: true),
        100 - kUncheckedPhotoCost,
      );
    });

    test('a found plant always banks something, whatever it cost', () {
      // Worst case anyone can reach: the lowest answer that still counts,
      // with both hints and an unconfirmed photo. The costs are tuned to stay
      // under it, so finding a plant is never worth nothing.
      expect(kLocationHintCost + kPhotoHintCost + kUncheckedPhotoCost,
          lessThan(68));
      expect(
        questPoints(
            answerScore: 68,
            usedLocationHint: true,
            usedPhotoHint: true,
            answerRevealed: false,
            uncheckedPhoto: true),
        greaterThan(0),
      );
    });

    test('the clamp still guards against a negative total', () {
      // firestore.rules rejects one, so this must hold even if the costs are
      // retuned past the answer score later.
      expect(
        questPoints(
            answerScore: 0,
            usedLocationHint: true,
            usedPhotoHint: true,
            answerRevealed: false,
            uncheckedPhoto: true),
        0,
      );
    });

    test('finding the plant is never worth nothing', () {
      // Worst case a visitor can actually reach: the lowest score that still
      // counts as correct (68), with both hints bought. No floor is needed for
      // this to stay positive, and the panel says so rather than promising a
      // minimum that never applies.
      final worst = questPoints(
          answerScore: 68,
          usedLocationHint: true,
          usedPhotoHint: true,
          answerRevealed: false);
      expect(worst, 68 - kLocationHintCost - kPhotoHintCost);
      expect(worst, greaterThan(0));
    });

    test('points can never go negative, whatever the costs become', () {
      // firestore.rules rejects a negative total outright.
      expect(
        questPoints(
            answerScore: 0,
            usedLocationHint: true,
            usedPhotoHint: true,
            answerRevealed: false),
        0,
      );
    });

    test('being told the answer banks nothing, hints or not', () {
      expect(
        questPoints(
            answerScore: 100,
            usedLocationHint: false,
            usedPhotoHint: false,
            answerRevealed: true),
        0,
      );
      expect(
        questPoints(
            answerScore: 100,
            usedLocationHint: true,
            usedPhotoHint: true,
            answerRevealed: true),
        0,
      );
    });

    test('a perfect run stays inside the cap the rules enforce', () {
      // firestore.rules rejects a total above 500.
      const quests = 5;
      expect(kMaxQuestPoints * quests, lessThanOrEqualTo(500));
    });
  });
}

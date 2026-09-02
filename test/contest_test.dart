// test/contest_test.dart
//
// Contest rules that must hold regardless of what the UI does.
//
// The leaderboard decides a prize, so the two properties worth guarding are
// that one person cannot inflate a plant's score, and that ranking counts
// people rather than opinions.

import 'package:botanica_ar/models/contest.dart';
import 'package:botanica_ar/services/contest_service.dart';
import 'package:flutter_test/flutter_test.dart';

ContestEntry _entry({
  required String uid,
  required String plant,
  String contest = 'c1',
  Map<String, int>? ratings,
  String? team,
  double? lat,
  double? lng,
  bool fromIndex = true,
}) {
  final key = ContestEntry.keyFor(plant);
  return ContestEntry(
    id: ContestEntry.docId(contest, uid, key),
    contestId: contest,
    uid: uid,
    displayName: uid,
    plantKey: key,
    plantName: plant,
    plantSection: 'Tropical house',
    ratings: ratings ?? const {'cute_creepy': 0},
    createdAt: DateTime(2026, 9, 1),
    teamId: team,
    teamName: team,
    lat: lat,
    lng: lng,
    fromIndex: fromIndex,
  );
}

void main() {
  group('entry identity', () {
    test('document id is deterministic per contest, person and plant', () {
      final a = _entry(uid: 'u1', plant: 'Theobroma cacao');
      final b = _entry(uid: 'u1', plant: 'theobroma  CACAO');
      // Same person, same plant, different capitalisation and spacing: the id
      // must collide so the second submission overwrites rather than adds.
      expect(a.id, b.id);
    });

    test('different people on the same plant get different ids', () {
      expect(_entry(uid: 'u1', plant: 'Aloe vera').id,
          isNot(_entry(uid: 'u2', plant: 'Aloe vera').id));
    });

    test('plant keys are slugged safely', () {
      expect(ContestEntry.keyFor('  Coffea   arabica '), 'coffea-arabica');
      expect(ContestEntry.keyFor("Rubus chamaemorus (punahilla)"),
          'rubus-chamaemorus-punahilla-');
    });
  });

  group('leaderboard', () {
    test('ranks by number of distinct people', () {
      final rows = ContestService.rank([
        _entry(uid: 'a', plant: 'Cacao'),
        _entry(uid: 'b', plant: 'Cacao'),
        _entry(uid: 'c', plant: 'Cacao'),
        _entry(uid: 'a', plant: 'Aloe'),
        _entry(uid: 'b', plant: 'Aloe'),
      ]);
      expect(rows.first.plantName, 'Cacao');
      expect(rows.first.votes, 3);
      expect(rows[1].votes, 2);
    });

    test('one person cannot vote a plant up twice', () {
      // Two entries from the same uid on the same plant — possible if a stale
      // client writes twice — must still count once.
      final rows = ContestService.rank([
        _entry(uid: 'a', plant: 'Cacao'),
        _entry(uid: 'a', plant: 'Cacao'),
        _entry(uid: 'b', plant: 'Cacao'),
      ]);
      expect(rows.single.votes, 2);
    });

    test('extreme opinions do not outrank more people', () {
      // There are no right answers, so a strong slider must not beat a count.
      final rows = ContestService.rank([
        _entry(uid: 'a', plant: 'Loud', ratings: {'cute_creepy': 5}),
        _entry(uid: 'b', plant: 'Quiet', ratings: {'cute_creepy': 0}),
        _entry(uid: 'c', plant: 'Quiet', ratings: {'cute_creepy': 0}),
      ]);
      expect(rows.first.plantName, 'Quiet');
    });

    test('ties break alphabetically so the order does not jitter', () {
      final first = ContestService.rank([
        _entry(uid: 'a', plant: 'Zebra plant'),
        _entry(uid: 'b', plant: 'Apple mint'),
      ]);
      final second = ContestService.rank([
        _entry(uid: 'b', plant: 'Apple mint'),
        _entry(uid: 'a', plant: 'Zebra plant'),
      ]);
      expect(first.map((r) => r.plantName).toList(),
          second.map((r) => r.plantName).toList());
      expect(first.first.plantName, 'Apple mint');
    });

    test('averages the scales across everyone who picked the plant', () {
      final rows = ContestService.rank([
        _entry(uid: 'a', plant: 'Cacao', ratings: {'cute_creepy': 4}),
        _entry(uid: 'b', plant: 'Cacao', ratings: {'cute_creepy': -2}),
      ]);
      expect(rows.single.averageFor('cute_creepy'), 1.0);
      expect(rows.single.averageFor('not_an_axis'), isNull);
    });

    test('records who voted, so a prize can be resolved', () {
      final rows = ContestService.rank([
        _entry(uid: 'a', plant: 'Cacao'),
        _entry(uid: 'b', plant: 'Cacao'),
      ]);
      expect(rows.single.voterUids, {'a', 'b'});
    });

    test('empty input yields an empty board, not a crash', () {
      expect(ContestService.rank(const []), isEmpty);
    });

    test('names the pickers and their teams', () {
      final rows = ContestService.rank([
        _entry(uid: 'a', plant: 'Cacao', team: 'Ferns'),
        _entry(uid: 'b', plant: 'Cacao'),
      ]);
      expect(rows.single.pickers.map((p) => p.label).toList(),
          ['a · Ferns', 'b']);
      expect(rows.single.teamNames, {'Ferns'});
    });

    test('a duplicate from one person does not duplicate them as a picker', () {
      final rows = ContestService.rank([
        _entry(uid: 'a', plant: 'Cacao'),
        _entry(uid: 'a', plant: 'Cacao'),
      ]);
      expect(rows.single.pickers, hasLength(1));
    });
  });

  group('leaderboard by scale', () {
    List<String> names(List<LeaderboardRow> rows) =>
        rows.map((r) => r.plantName).toList();

    test('ranks toward either end of one scale', () {
      final entries = [
        _entry(uid: 'a', plant: 'Cute one', ratings: {'cute_creepy': -4}),
        _entry(uid: 'b', plant: 'Creepy one', ratings: {'cute_creepy': 5}),
        _entry(uid: 'c', plant: 'Middling', ratings: {'cute_creepy': 0}),
      ];
      expect(names(ContestService.rankByAxis(entries, 'cute_creepy')),
          ['Creepy one', 'Middling', 'Cute one']);
      expect(
        names(ContestService.rankByAxis(entries, 'cute_creepy',
            towardRight: false)),
        ['Cute one', 'Middling', 'Creepy one'],
      );
    });

    test('drops plants nobody rated on that scale', () {
      // "Not rated" must not render as "dead centre" — they mean different
      // things and would otherwise be indistinguishable at 0.0.
      final rows = ContestService.rankByAxis([
        _entry(uid: 'a', plant: 'Rated', ratings: {'cute_creepy': 2}),
        _entry(uid: 'b', plant: 'Unrated', ratings: {'other_axis': 5}),
      ], 'cute_creepy');
      expect(names(rows), ['Rated']);
    });

    test('equal averages put the better-attested plant first', () {
      final rows = ContestService.rankByAxis([
        _entry(uid: 'a', plant: 'One voice', ratings: {'cute_creepy': 3}),
        _entry(uid: 'b', plant: 'Many voices', ratings: {'cute_creepy': 3}),
        _entry(uid: 'c', plant: 'Many voices', ratings: {'cute_creepy': 3}),
      ], 'cute_creepy');
      expect(names(rows), ['Many voices', 'One voice']);
    });

    test('averages, not extremes, decide the order', () {
      // Two moderate ratings must beat one extreme one.
      final rows = ContestService.rankByAxis([
        _entry(uid: 'a', plant: 'Spiky', ratings: {'cute_creepy': 5}),
        _entry(uid: 'b', plant: 'Steady', ratings: {'cute_creepy': 1}),
        _entry(uid: 'c', plant: 'Steady', ratings: {'cute_creepy': 1}),
      ], 'cute_creepy');
      expect(names(rows), ['Spiky', 'Steady']);
    });
  });

  group('submission record', () {
    test('location is optional and round-trips through the map', () {
      final withGps = _entry(uid: 'a', plant: 'Cacao', lat: 65.06, lng: 25.47);
      expect(withGps.hasLocation, isTrue);
      expect(withGps.toMap()['lat'], 65.06);
      expect(withGps.mapsUrl, contains('65.06,25.47'));

      final without = _entry(uid: 'a', plant: 'Cacao');
      expect(without.hasLocation, isFalse);
      expect(without.mapsUrl, isNull);
      // Firestore rejects explicit nulls in a merge-free set, so an entry with
      // no fix must simply omit the keys.
      expect(without.toMap().containsKey('lat'), isFalse);
    });

    test('free-typed plants are flagged so the gaps can be counted', () {
      final typed = _entry(uid: 'a', plant: 'Big spiky one', fromIndex: false);
      final picked = _entry(uid: 'b', plant: 'Aloe vera');
      final missing =
          [typed, picked].where((e) => !e.fromIndex).map((e) => e.plantName);
      expect(missing, ['Big spiky one']);
      expect(typed.toMap()['fromIndex'], isFalse);
    });
  });

  group('contest window', () {
    Contest make({
      required bool active,
      required DateTime start,
      required DateTime end,
    }) =>
        Contest(
          id: 'c1',
          title: 't',
          subtitle: '',
          intro: '',
          steps: const [],
          axes: const [],
          startsAt: start,
          endsAt: end,
          active: active,
        );

    final now = DateTime.now();

    test('live only when switched on AND inside the window', () {
      expect(
        make(
          active: true,
          start: now.subtract(const Duration(days: 1)),
          end: now.add(const Duration(days: 1)),
        ).isLive,
        isTrue,
      );
    });

    test('an expired contest hides itself even if left switched on', () {
      // The belt-and-braces guard: forgetting to flip `active` must not leave
      // an event running past its end.
      final c = make(
        active: true,
        start: now.subtract(const Duration(days: 5)),
        end: now.subtract(const Duration(days: 1)),
      );
      expect(c.isLive, isFalse);
      expect(c.hasEnded, isTrue);
    });

    test('switching off hides a contest still inside its window', () {
      expect(
        make(
          active: false,
          start: now.subtract(const Duration(days: 1)),
          end: now.add(const Duration(days: 1)),
        ).isLive,
        isFalse,
      );
    });

    test('a future contest is not live yet', () {
      expect(
        make(
          active: true,
          start: now.add(const Duration(days: 1)),
          end: now.add(const Duration(days: 2)),
        ).isLive,
        isFalse,
      );
    });
  });
}

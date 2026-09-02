// lib/services/hunt_score_service.dart
//
// Plant Hunt scores and leaderboard.
//
// One document per person, id = uid, so a second run replaces the first rather
// than stacking up entries. Only an improvement is written: a visitor who
// replays and does worse keeps their best score, which is what anyone expects
// of a high-score table.
//
// ponytail: no Cloud Function, no aggregation, no pagination. A day's event
// produces a few hundred documents and the board shows ten of them.

import 'package:cloud_firestore/cloud_firestore.dart';

class HuntScore {
  const HuntScore({
    required this.uid,
    required this.displayName,
    required this.total,
    required this.solved,
    required this.updatedAt,
  });

  final String uid;
  final String displayName;

  /// Sum of the per-quest points, so a confident answer beats a rough one even
  /// when both found the plant.
  final int total;

  /// How many of the quests were solved. This is what the board ranks on:
  /// finding four plants beats finding three, however many points the three
  /// scored, because the hunt is about finding plants.
  final int solved;
  final DateTime updatedAt;

  /// Quests first, points as the tiebreak, folded into one sortable number.
  ///
  /// Firestore cannot order by two fields without a composite index, and one
  /// derived value needs no index at all. A total can never reach 1000, so
  /// `solved * 1000 + total` orders exactly as (solved, total) would.
  static int rankOf(int solved, int total) => solved * 1000 + total;

  int get rank => rankOf(solved, total);

  factory HuntScore.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? {};
    return HuntScore(
      uid: d.id,
      displayName: (m['displayName'] ?? 'Visitor') as String,
      total: (m['total'] as num?)?.toInt() ?? 0,
      solved: (m['solved'] as num?)?.toInt() ?? 0,
      updatedAt: (m['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

class HuntScoreService {
  HuntScoreService._();
  static final HuntScoreService instance = HuntScoreService._();

  static const _col = 'hunt_scores';

  FirebaseFirestore get _db => FirebaseFirestore.instance;

  /// Saves a finished run, keeping whichever attempt scored higher.
  ///
  /// Failure is swallowed on purpose: a visitor who has just walked the whole
  /// garden should not be shown a database error at the moment they earn their
  /// badge. The badge itself is awarded locally and does not depend on this.
  Future<void> submit({
    required String uid,
    required String displayName,
    required int total,
    required int solved,
  }) async {
    try {
      final ref = _db.collection(_col).doc(uid);
      await _db.runTransaction((tx) async {
        final cur = await tx.get(ref);
        // Compared on rank, not points: a run that found more plants is the
        // better run even if it scored fewer points buying hints along the way.
        final best = (cur.data()?['rank'] as num?)?.toInt() ?? -1;
        final rank = HuntScore.rankOf(solved, total);
        if (rank <= best) return; // an earlier run stands
        tx.set(ref, {
          'uid': uid,
          'displayName': displayName.isEmpty ? 'Visitor' : displayName,
          'total': total,
          'solved': solved,
          'rank': rank,
          'updatedAt': Timestamp.now(),
        });
      });
    } catch (_) {
      // Offline in a greenhouse is normal; the run still counted for them.
    }
  }

  /// The board: most plants found first, points breaking ties.
  Stream<List<HuntScore>> watchTop({int limit = 20}) => _db
      .collection(_col)
      .orderBy('rank', descending: true)
      .limit(limit)
      .snapshots()
      .map((s) => s.docs.map(HuntScore.fromDoc).toList());
}

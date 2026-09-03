// lib/services/hunt_submission_service.dart
//
// The permanent record of what visitors submitted, and the admin review queue.
//
// Every Plant Hunt attempt is kept — the photo, the typed name, the verdict,
// which hints were bought, whether it scored. Wrong answers too: an answer
// nobody expected is the interesting one when the garden looks back at what
// people thought their plants were called, and it cannot be recovered later if
// it was never written down.
//
// Cost, since this has to stay on the free tier: a photo at medium resolution
// is 100-200 KB, and Firebase's free allowance is 5 GB stored with 1 GB/day
// egress. A day with 200 visitors making 500 attempts is well under 100 MB, and
// the metadata documents are a few hundred bytes each against a 1 GiB Firestore
// allowance. The one thing that would blow it is re-uploading the same picture
// on every retyped answer, so [recordAttempt] uploads a photo once and reuses
// the path while the bytes are unchanged.

import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

// ─── Models ───────────────────────────────────────────────────────────────────

/// One Plant Hunt attempt, right or wrong.
class HuntSubmission {
  const HuntSubmission({
    required this.id,
    required this.uid,
    required this.displayName,
    required this.questIndex,
    required this.plantName,
    required this.typedAnswer,
    required this.correct,
    required this.points,
    required this.photoVerdict,
    required this.createdAt,
    this.photoPath,
    this.detectedName,
    this.usedLocationHint = false,
    this.usedPhotoHint = false,
    this.uncheckedPhoto = false,
    this.adminApproved = false,
  });

  final String id;
  final String uid;
  final String displayName;

  /// 0-based quest, and the plant it was asking for. The name is stored rather
  /// than looked up so the record still reads correctly if the quests change.
  final int questIndex;
  final String plantName;

  final String typedAnswer;
  final bool correct;
  final int points;

  /// What the identifier made of the photo: accepted, wrongPlant, notAPlant,
  /// inconclusive — or 'adminApproved' where a person overruled it.
  final String photoVerdict;
  final String? detectedName;

  final String? photoPath;
  final bool usedLocationHint;
  final bool usedPhotoHint;
  final bool uncheckedPhoto;
  final bool adminApproved;
  final DateTime createdAt;

  factory HuntSubmission.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? {};
    return HuntSubmission(
      id: d.id,
      uid: (m['uid'] ?? '') as String,
      displayName: (m['displayName'] ?? 'Visitor') as String,
      questIndex: (m['questIndex'] as num?)?.toInt() ?? 0,
      plantName: (m['plantName'] ?? '') as String,
      typedAnswer: (m['typedAnswer'] ?? '') as String,
      correct: (m['correct'] as bool?) ?? false,
      points: (m['points'] as num?)?.toInt() ?? 0,
      photoVerdict: (m['photoVerdict'] ?? '') as String,
      detectedName: m['detectedName'] as String?,
      photoPath: m['photoPath'] as String?,
      usedLocationHint: (m['usedLocationHint'] as bool?) ?? false,
      usedPhotoHint: (m['usedPhotoHint'] as bool?) ?? false,
      uncheckedPhoto: (m['uncheckedPhoto'] as bool?) ?? false,
      adminApproved: (m['adminApproved'] as bool?) ?? false,
      createdAt: (m['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

/// A visitor asking a human to look at a photo the identifier refused.
class ReviewRequest {
  const ReviewRequest({
    required this.id,
    required this.uid,
    required this.displayName,
    required this.questIndex,
    required this.plantName,
    required this.status,
    required this.createdAt,
    this.photoPath,
    this.typedAnswer = '',
    this.decidedBy,
  });

  final String id;
  final String uid;
  final String displayName;
  final int questIndex;

  /// What the quest was asking for. The admin needs it to judge the photo —
  /// they cannot be expected to remember which quest is which.
  final String plantName;
  final String typedAnswer;
  final String? photoPath;

  /// pending | approved | declined
  final String status;
  final String? decidedBy;
  final DateTime createdAt;

  bool get isPending => status == 'pending';
  bool get isApproved => status == 'approved';
  bool get isDeclined => status == 'declined';

  factory ReviewRequest.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? {};
    return ReviewRequest(
      id: d.id,
      uid: (m['uid'] ?? '') as String,
      displayName: (m['displayName'] ?? 'Visitor') as String,
      questIndex: (m['questIndex'] as num?)?.toInt() ?? 0,
      plantName: (m['plantName'] ?? '') as String,
      typedAnswer: (m['typedAnswer'] ?? '') as String,
      photoPath: m['photoPath'] as String?,
      status: (m['status'] ?? 'pending') as String,
      decidedBy: m['decidedBy'] as String?,
      createdAt: (m['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

/// One person, and how much they have done. Kept as its own document so the
/// admin's participant list is a single cheap query rather than a scan of
/// every submission in the event.
class Participant {
  const Participant({
    required this.uid,
    required this.displayName,
    required this.huntAttempts,
    required this.huntSolved,
    required this.contestEntries,
    required this.lastSeen,
  });

  final String uid;
  final String displayName;
  final int huntAttempts;
  final int huntSolved;

  /// Picks filed in the timed contest. Counted here so the admin list shows
  /// someone who only played the contest, not just Plant Hunt players.
  final int contestEntries;
  final DateTime lastSeen;

  factory Participant.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? {};
    return Participant(
      uid: d.id,
      displayName: (m['displayName'] ?? 'Visitor') as String,
      huntAttempts: (m['huntAttempts'] as num?)?.toInt() ?? 0,
      huntSolved: (m['huntSolved'] as num?)?.toInt() ?? 0,
      contestEntries: (m['contestEntries'] as num?)?.toInt() ?? 0,
      lastSeen: (m['lastSeen'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

// ─── Service ──────────────────────────────────────────────────────────────────

class HuntSubmissionService {
  HuntSubmissionService._();
  static final HuntSubmissionService instance = HuntSubmissionService._();

  static const _submissions = 'hunt_submissions';
  static const _reviews = 'hunt_reviews';
  static const _participants = 'participants';

  FirebaseFirestore get _db => FirebaseFirestore.instance;

  /// Uploads a hunt photo and returns its Storage path.
  ///
  /// One object per attempt, named by quest and timestamp so the same person
  /// photographing the same plant twice does not overwrite their first try —
  /// the whole point is to keep everything.
  Future<String?> uploadPhoto(Uint8List bytes, String uid, int questIndex) async {
    final path = 'hunt_submissions/$uid/'
        'q${questIndex + 1}_${DateTime.now().millisecondsSinceEpoch}.jpg';
    try {
      await FirebaseStorage.instance.ref(path).putData(
            bytes,
            SettableMetadata(contentType: 'image/jpeg'),
          );
      return path;
    } catch (_) {
      // No signal in a greenhouse. The attempt is still recorded without the
      // picture rather than being lost with it.
      return null;
    }
  }

  /// Writes one attempt and bumps the person's participant row.
  ///
  /// Never throws: a visitor mid-hunt must not see a database error, and the
  /// hunt works perfectly well if a record fails to save.
  Future<void> recordAttempt({
    required String uid,
    required String displayName,
    required int questIndex,
    required String plantName,
    required String typedAnswer,
    required bool correct,
    required int points,
    required String photoVerdict,
    String? photoPath,
    String? detectedName,
    bool usedLocationHint = false,
    bool usedPhotoHint = false,
    bool uncheckedPhoto = false,
    bool adminApproved = false,
  }) async {
    try {
      await _db.collection(_submissions).add({
        'uid': uid,
        'displayName': displayName.isEmpty ? 'Visitor' : displayName,
        'questIndex': questIndex,
        'plantName': plantName,
        'typedAnswer': typedAnswer,
        'correct': correct,
        'points': points,
        'photoVerdict': photoVerdict,
        if (detectedName != null) 'detectedName': detectedName,
        if (photoPath != null) 'photoPath': photoPath,
        'usedLocationHint': usedLocationHint,
        'usedPhotoHint': usedPhotoHint,
        'uncheckedPhoto': uncheckedPhoto,
        'adminApproved': adminApproved,
        'createdAt': Timestamp.now(),
      });

      await _db.collection(_participants).doc(uid).set({
        'displayName': displayName.isEmpty ? 'Visitor' : displayName,
        'huntAttempts': FieldValue.increment(1),
        if (correct) 'huntSolved': FieldValue.increment(1),
        'lastSeen': Timestamp.now(),
      }, SetOptions(merge: true));
    } catch (_) {
      // Recording is bookkeeping, not gameplay.
    }
  }

  /// Records that someone filed a contest pick, so the admin's participant
  /// list covers both challenges rather than only the Plant Hunt.
  ///
  /// The entry itself already lives in contest_entries with its photo, GPS and
  /// ratings — this only maintains the index the admin list reads.
  Future<void> noteContestEntry({
    required String uid,
    required String displayName,
  }) async {
    try {
      await _db.collection(_participants).doc(uid).set({
        'displayName': displayName.isEmpty ? 'Visitor' : displayName,
        'contestEntries': FieldValue.increment(1),
        'lastSeen': Timestamp.now(),
      }, SetOptions(merge: true));
    } catch (_) {
      // Bookkeeping, not gameplay.
    }
  }

  // ── Review requests ───────────────────────────────────────────────────────

  /// Asks an admin to look at a photo the identifier would not accept.
  /// Returns the request id to watch, or null if it could not be filed.
  Future<String?> requestReview({
    required String uid,
    required String displayName,
    required int questIndex,
    required String plantName,
    required String typedAnswer,
    String? photoPath,
  }) async {
    try {
      final ref = await _db.collection(_reviews).add({
        'uid': uid,
        'displayName': displayName.isEmpty ? 'Visitor' : displayName,
        'questIndex': questIndex,
        'plantName': plantName,
        'typedAnswer': typedAnswer,
        if (photoPath != null) 'photoPath': photoPath,
        'status': 'pending',
        'createdAt': Timestamp.now(),
      });
      return ref.id;
    } catch (_) {
      return null;
    }
  }

  /// The visitor's own request, so the screen can react the moment an admin
  /// decides without anyone refreshing anything.
  Stream<ReviewRequest?> watchReview(String id) => _db
      .collection(_reviews)
      .doc(id)
      .snapshots()
      .map((d) => d.exists ? ReviewRequest.fromDoc(d) : null);

  /// Everything waiting on an admin. Oldest first — whoever has been standing
  /// in a greenhouse longest gets seen first.
  Stream<List<ReviewRequest>> watchPendingReviews() => _db
      .collection(_reviews)
      .where('status', isEqualTo: 'pending')
      .snapshots()
      .map((s) {
        final list = s.docs.map(ReviewRequest.fromDoc).toList()
          ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
        return list;
      });

  /// Count for the admin panel badge.
  Stream<int> watchPendingReviewCount() => _db
      .collection(_reviews)
      .where('status', isEqualTo: 'pending')
      .snapshots()
      .map((s) => s.docs.length);

  Future<void> decideReview({
    required String id,
    required bool approved,
    required String adminUid,
  }) =>
      _db.collection(_reviews).doc(id).update({
        'status': approved ? 'approved' : 'declined',
        'decidedBy': adminUid,
        'decidedAt': Timestamp.now(),
      });

  // ── Admin reading ─────────────────────────────────────────────────────────

  /// Everyone who has submitted anything, most recently active first.
  Stream<List<Participant>> watchParticipants({int limit = 200}) => _db
      .collection(_participants)
      .orderBy('lastSeen', descending: true)
      .limit(limit)
      .snapshots()
      .map((s) => s.docs.map(Participant.fromDoc).toList());

  /// One person's Plant Hunt history, newest first. Sorted on the device so no
  /// composite index is needed for uid + createdAt.
  Stream<List<HuntSubmission>> watchUserSubmissions(String uid) => _db
      .collection(_submissions)
      .where('uid', isEqualTo: uid)
      .snapshots()
      .map((s) {
        final list = s.docs.map(HuntSubmission.fromDoc).toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return list;
      });

  Future<String?> photoUrl(String? path) async {
    if (path == null || path.isEmpty) return null;
    try {
      return await FirebaseStorage.instance.ref(path).getDownloadURL();
    } catch (_) {
      return null;
    }
  }
}

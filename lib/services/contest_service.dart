// lib/services/contest_service.dart
//
// Firestore + Storage access for visitor contests.
//
// Deliberately thin: one live contest at a time, entries aggregated on the
// device rather than by a Cloud Function. A single-day event produces a few
// hundred entry documents, which is nothing to fold in memory — a scheduled
// aggregator would be more moving parts for a leaderboard nobody will ever
// scroll past the top ten of.
//
// ponytail: no aggregation function, no cached counters, no pagination. Revisit
// only if a contest ever runs long enough to produce thousands of entries.

import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../models/contest.dart';

class ContestService {
  ContestService._();
  static final ContestService instance = ContestService._();

  static const _configDoc = 'config/contest';
  static const _entries = 'contest_entries';
  static const _teams = 'contest_teams';

  FirebaseFirestore get _db => FirebaseFirestore.instance;

  // ── Contest config ────────────────────────────────────────────────────────

  /// The current contest, or null when none is configured.
  /// Streamed so ending the contest removes it from the UI without a restart.
  Stream<Contest?> watchContest() => _db
      .doc(_configDoc)
      .snapshots()
      .map((d) => d.exists ? Contest.fromDoc(d) : null);

  Future<Contest?> fetchContest() async {
    final d = await _db.doc(_configDoc).get();
    return d.exists ? Contest.fromDoc(d) : null;
  }

  // ── Entries ───────────────────────────────────────────────────────────────

  /// All entries for a contest. Drives the leaderboard.
  ///
  /// Entry documents are world-readable — they hold a plant name, a display
  /// name and slider values. The PHOTO is not in here; it is a Storage object
  /// readable only by its owner.
  Stream<List<ContestEntry>> watchEntries(String contestId) => _db
      .collection(_entries)
      .where('contestId', isEqualTo: contestId)
      .snapshots()
      .map((s) => s.docs.map(ContestEntry.fromDoc).toList());

  Stream<List<ContestEntry>> watchMyEntries(String contestId, String uid) => _db
      .collection(_entries)
      .where('contestId', isEqualTo: contestId)
      .where('uid', isEqualTo: uid)
      .snapshots()
      .map((s) => s.docs.map(ContestEntry.fromDoc).toList());

  /// True when this person has already voted on this plant.
  Future<bool> hasEntered(String contestId, String uid, String plantKey) async {
    final d = await _db
        .collection(_entries)
        .doc(ContestEntry.docId(contestId, uid, plantKey))
        .get();
    return d.exists;
  }

  /// Saves an entry. The document id is derived from contest + user + plant, so
  /// a second submission for the same plant overwrites the first rather than
  /// inflating that plant's score.
  Future<void> submitEntry(ContestEntry entry, {File? photo}) async {
    String? photoPath;
    if (photo != null) {
      photoPath = 'contests/${entry.contestId}/${entry.uid}/${entry.plantKey}.jpg';
      try {
        await FirebaseStorage.instance.ref(photoPath).putFile(
              photo,
              SettableMetadata(contentType: 'image/jpeg'),
            );
      } catch (_) {
        // A failed upload must not cost the visitor their vote — the photo is
        // a keepsake, the rating is the entry. Save without it.
        photoPath = null;
      }
    }

    final withPhoto = ContestEntry(
      id: entry.id,
      contestId: entry.contestId,
      uid: entry.uid,
      displayName: entry.displayName,
      plantKey: entry.plantKey,
      plantName: entry.plantName,
      plantSection: entry.plantSection,
      ratings: entry.ratings,
      createdAt: entry.createdAt,
      teamId: entry.teamId,
      teamName: entry.teamName,
      photoPath: photoPath,
    );

    await _db.collection(_entries).doc(entry.id).set(withPhoto.toMap());
  }

  /// Download URL for an entry photo. Only resolves for the owner — Storage
  /// rules reject anyone else, which is what keeps the contest free of a public
  /// photo gallery.
  Future<String?> photoUrl(String? path) async {
    if (path == null || path.isEmpty) return null;
    try {
      return await FirebaseStorage.instance.ref(path).getDownloadURL();
    } catch (_) {
      return null;
    }
  }

  // ── Teams ─────────────────────────────────────────────────────────────────

  Stream<List<ContestTeam>> watchTeams(String contestId) => _db
      .collection(_teams)
      .where('contestId', isEqualTo: contestId)
      .snapshots()
      .map((s) => s.docs.map(ContestTeam.fromDoc).toList());

  Future<ContestTeam?> myTeam(String contestId, String uid) async {
    final s = await _db
        .collection(_teams)
        .where('contestId', isEqualTo: contestId)
        .where('memberUids', arrayContains: uid)
        .limit(1)
        .get();
    return s.docs.isEmpty ? null : ContestTeam.fromDoc(s.docs.first);
  }

  Future<String> createTeam({
    required String contestId,
    required String name,
    required String uid,
    required String displayName,
  }) async {
    final ref = _db.collection(_teams).doc();
    await ref.set({
      'contestId': contestId,
      'name': name.trim(),
      'createdBy': uid,
      'memberUids': [uid],
      'memberNames': [displayName],
      'createdAt': Timestamp.now(),
    });
    return ref.id;
  }

  /// Joins an existing team. Uses arrayUnion so two people tapping at once
  /// cannot overwrite each other's membership.
  Future<void> joinTeam({
    required String teamId,
    required String uid,
    required String displayName,
  }) async {
    await _db.collection(_teams).doc(teamId).update({
      'memberUids': FieldValue.arrayUnion([uid]),
      'memberNames': FieldValue.arrayUnion([displayName]),
    });
  }

  Future<void> leaveTeam({
    required String teamId,
    required String uid,
    required String displayName,
  }) async {
    await _db.collection(_teams).doc(teamId).update({
      'memberUids': FieldValue.arrayRemove([uid]),
      'memberNames': FieldValue.arrayRemove([displayName]),
    });
  }

  // ── Leaderboard ───────────────────────────────────────────────────────────

  /// Folds entries into ranked plants, most-picked first.
  static List<LeaderboardRow> rank(List<ContestEntry> entries) {
    final rows = <String, LeaderboardRow>{};
    for (final e in entries) {
      if (e.plantKey.isEmpty) continue;
      rows
          .putIfAbsent(
            e.plantKey,
            () => LeaderboardRow(
              plantKey: e.plantKey,
              plantName: e.plantName,
              plantSection: e.plantSection,
            ),
          )
          .add(e);
    }
    final list = rows.values.toList();
    list.sort((a, b) {
      final c = b.votes.compareTo(a.votes);
      // Alphabetical tiebreak keeps the order stable between refreshes, so a
      // plant does not appear to move around while the count is unchanged.
      return c != 0 ? c : a.plantName.compareTo(b.plantName);
    });
    return list;
  }
}

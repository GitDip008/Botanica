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

import 'dart:typed_data';

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

  /// Every pick one person has made, across any contest. Sorted on the device
  /// so no composite index is needed for uid + createdAt.
  Stream<List<ContestEntry>> watchEntriesByUser(String uid) => _db
      .collection(_entries)
      .where('uid', isEqualTo: uid)
      .snapshots()
      .map((s) {
        final list = s.docs.map(ContestEntry.fromDoc).toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return list;
      });

  /// True when this person has already voted on this plant.
  Future<bool> hasEntered(String contestId, String uid, String plantKey) async {
    final d = await _db
        .collection(_entries)
        .doc(ContestEntry.docId(contestId, uid, plantKey))
        .get();
    return d.exists;
  }

  /// Name of the team-mate who already claimed this plant, or null if nobody
  /// has. The deterministic document id stops one PERSON entering a plant
  /// twice; this stops a team farming the same plant through its members.
  ///
  /// Queried by plantKey and filtered in memory: a plant has a handful of
  /// entries, so this avoids a three-field composite index for one check.
  Future<String?> teamMateWhoPicked({
    required String contestId,
    required String teamId,
    required String plantKey,
    required String exceptUid,
  }) async {
    final s = await _db
        .collection(_entries)
        .where('contestId', isEqualTo: contestId)
        .where('plantKey', isEqualTo: plantKey)
        .get();
    for (final d in s.docs) {
      final e = ContestEntry.fromDoc(d);
      if (e.teamId == teamId && e.uid != exceptUid) {
        return e.displayName.isEmpty ? 'a team-mate' : e.displayName;
      }
    }
    return null;
  }

  /// Saves an entry. The document id is derived from contest + user + plant, so
  /// a second submission for the same plant overwrites the first rather than
  /// inflating that plant's score.
  /// Photo bytes rather than a File: the same code then runs on web, where
  /// dart:io File does not exist.
  ///
  /// Returns null on success, or a description of why the photo could not be
  /// uploaded. The entry is saved either way — a failed upload must not cost
  /// the visitor their vote, the photo is a keepsake and the rating is the
  /// entry — but the failure is reported rather than swallowed, because a
  /// silently missing photo looks identical to a broken app.
  Future<String?> submitEntry(ContestEntry entry, {Uint8List? photo}) async {
    String? photoPath;
    String? photoError;
    if (photo != null) {
      photoPath = 'contests/${entry.contestId}/${entry.uid}/${entry.plantKey}.jpg';
      try {
        await FirebaseStorage.instance.ref(photoPath).putData(
              photo,
              SettableMetadata(contentType: 'image/jpeg'),
            );
      } catch (e) {
        photoPath = null;
        photoError = '$e';
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
      lat: entry.lat,
      lng: entry.lng,
      fromIndex: entry.fromIndex,
    );

    await _db.collection(_entries).doc(entry.id).set(withPhoto.toMap());
    return photoError;
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

  /// The same plants ranked by where the crowd put them on ONE scale.
  ///
  /// [towardRight] picks which end of the scale leads, so a single axis gives
  /// both boards a visitor would want — the cutest and the creepiest — without
  /// doubling the number of tabs.
  ///
  /// Plants nobody rated on this axis are dropped rather than shown at zero:
  /// "not rated" and "dead centre" are different things and must not look the
  /// same. Ties fall back to the number of people, so where two plants sit at
  /// the same average the better-attested one leads.
  static List<LeaderboardRow> rankByAxis(
    List<ContestEntry> entries,
    String axisKey, {
    bool towardRight = true,
  }) {
    final rows = rank(entries)
        .where((r) => r.averageFor(axisKey) != null)
        .toList();
    rows.sort((a, b) {
      final av = a.averageFor(axisKey)!;
      final bv = b.averageFor(axisKey)!;
      final c = towardRight ? bv.compareTo(av) : av.compareTo(bv);
      if (c != 0) return c;
      final v = b.votes.compareTo(a.votes);
      return v != 0 ? v : a.plantName.compareTo(b.plantName);
    });
    return rows;
  }
}

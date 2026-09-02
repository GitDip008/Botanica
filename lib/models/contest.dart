// lib/models/contest.dart
//
// Time-boxed visitor contests. The whole contest — title, rules, the slider
// axes, the dates — lives in one Firestore document, so an event can be
// launched, edited or ended without shipping an app update. That matters here:
// the first contest runs for a single day and has to disappear cleanly
// afterwards.

import 'package:cloud_firestore/cloud_firestore.dart';

/// One slider axis, e.g. "Cute ↔ Creepy".
class ContestAxis {
  const ContestAxis({required this.key, required this.left, required this.right});

  /// Stable id stored on entries. Renaming the labels must not orphan votes.
  final String key;
  final String left;
  final String right;

  factory ContestAxis.fromMap(Map<String, dynamic> m) => ContestAxis(
        key: (m['key'] ?? '') as String,
        left: (m['left'] ?? '') as String,
        right: (m['right'] ?? '') as String,
      );
}

class Contest {
  const Contest({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.intro,
    required this.steps,
    required this.axes,
    required this.startsAt,
    required this.endsAt,
    required this.active,
    this.prizeNote = '',
  });

  final String id;
  final String title;
  final String subtitle;
  final String intro;
  final List<String> steps;
  final List<ContestAxis> axes;
  final DateTime startsAt;
  final DateTime endsAt;

  /// Master switch. Flipping this false hides the contest everywhere, which is
  /// how the event gets torn down without a release.
  final bool active;
  final String prizeNote;

  /// Visible only while switched on AND inside its window — belt and braces, so
  /// forgetting to flip the switch still ends the contest on time.
  bool get isLive {
    final now = DateTime.now();
    return active && now.isAfter(startsAt) && now.isBefore(endsAt);
  }

  bool get hasEnded => DateTime.now().isAfter(endsAt);

  factory Contest.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? {};
    return Contest(
      id: d.id,
      title: (m['title'] ?? '') as String,
      subtitle: (m['subtitle'] ?? '') as String,
      intro: (m['intro'] ?? '') as String,
      steps: ((m['steps'] as List?) ?? const []).map((e) => '$e').toList(),
      axes: ((m['axes'] as List?) ?? const [])
          .map((e) => ContestAxis.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList(),
      startsAt: (m['startsAt'] as Timestamp?)?.toDate() ?? DateTime(2000),
      endsAt: (m['endsAt'] as Timestamp?)?.toDate() ?? DateTime(2000),
      active: (m['active'] as bool?) ?? false,
      prizeNote: (m['prizeNote'] ?? '') as String,
    );
  }
}

/// One person's vote on one plant. The document id is deterministic —
/// `${contestId}__${uid}__${plantKey}` — which is what enforces "one entry per
/// plant per person" at the database level rather than by hoping the UI behaves.
class ContestEntry {
  const ContestEntry({
    required this.id,
    required this.contestId,
    required this.uid,
    required this.displayName,
    required this.plantKey,
    required this.plantName,
    required this.plantSection,
    required this.ratings,
    required this.createdAt,
    this.teamId,
    this.teamName,
    this.photoPath,
    this.lat,
    this.lng,
    this.fromIndex = true,
  });

  final String id;
  final String contestId;
  final String uid;
  final String displayName;

  /// Normalised plant name — the leaderboard groups on this.
  final String plantKey;
  final String plantName;
  final String plantSection;

  /// axis key -> -5..5, 0 being dead centre.
  final Map<String, int> ratings;
  final DateTime createdAt;
  final String? teamId;
  final String? teamName;

  /// Storage object path. The bytes are readable only by this uid; nothing in
  /// the app shows another visitor's photo.
  final String? photoPath;

  /// Where the photo was taken. Null when location was refused or unavailable —
  /// an entry is never blocked on it.
  final double? lat;
  final double? lng;

  /// False when the visitor typed a name that is not in the garden's index.
  /// Counting these tells the curator which plants the records are missing.
  final bool fromIndex;

  bool get hasLocation => lat != null && lng != null;

  /// Opens the capture spot in any maps app.
  String? get mapsUrl => hasLocation
      ? 'https://www.google.com/maps/search/?api=1&query=$lat,$lng'
      : null;

  static String docId(String contestId, String uid, String plantKey) =>
      '${contestId}__${uid}__$plantKey';

  static String keyFor(String plantName) =>
      plantName.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-');

  Map<String, dynamic> toMap() => {
        'contestId': contestId,
        'uid': uid,
        'displayName': displayName,
        'plantKey': plantKey,
        'plantName': plantName,
        'plantSection': plantSection,
        'ratings': ratings,
        'createdAt': Timestamp.fromDate(createdAt),
        if (teamId != null) 'teamId': teamId,
        if (teamName != null) 'teamName': teamName,
        if (photoPath != null) 'photoPath': photoPath,
        if (lat != null) 'lat': lat,
        if (lng != null) 'lng': lng,
        'fromIndex': fromIndex,
      };

  factory ContestEntry.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? {};
    return ContestEntry(
      id: d.id,
      contestId: (m['contestId'] ?? '') as String,
      uid: (m['uid'] ?? '') as String,
      displayName: (m['displayName'] ?? '') as String,
      plantKey: (m['plantKey'] ?? '') as String,
      plantName: (m['plantName'] ?? '') as String,
      plantSection: (m['plantSection'] ?? '') as String,
      ratings: Map<String, int>.from(
          (m['ratings'] as Map?)?.map((k, v) => MapEntry('$k', (v as num).toInt())) ?? {}),
      createdAt: (m['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      teamId: m['teamId'] as String?,
      teamName: m['teamName'] as String?,
      photoPath: m['photoPath'] as String?,
      lat: (m['lat'] as num?)?.toDouble(),
      lng: (m['lng'] as num?)?.toDouble(),
      // Entries written before this field existed came from the picker.
      fromIndex: (m['fromIndex'] as bool?) ?? true,
    );
  }
}

/// A team someone created that others can join from the open-teams list.
class ContestTeam {
  const ContestTeam({
    required this.id,
    required this.contestId,
    required this.name,
    required this.createdBy,
    required this.memberUids,
    required this.memberNames,
    required this.createdAt,
  });

  final String id;
  final String contestId;
  final String name;
  final String createdBy;
  final List<String> memberUids;
  final List<String> memberNames;
  final DateTime createdAt;

  int get size => memberUids.length;

  factory ContestTeam.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? {};
    return ContestTeam(
      id: d.id,
      contestId: (m['contestId'] ?? '') as String,
      name: (m['name'] ?? '') as String,
      createdBy: (m['createdBy'] ?? '') as String,
      memberUids: ((m['memberUids'] as List?) ?? const []).map((e) => '$e').toList(),
      memberNames: ((m['memberNames'] as List?) ?? const []).map((e) => '$e').toList(),
      createdAt: (m['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

/// One person (and their team, if any) who picked a plant.
class Picker {
  const Picker({
    required this.uid,
    required this.name,
    required this.at,
    this.teamName,
  });

  final String uid;
  final String name;
  final String? teamName;
  final DateTime at;

  String get label => teamName == null ? name : '$name · $teamName';
}

/// One row of the leaderboard: a plant and how many people picked it.
///
/// Rank is the number of DISTINCT people who entered that plant, which is what
/// "most scores" was defined to mean. The slider values are deliberately not
/// part of the ranking — there are no right answers, so an extreme vote must
/// not outweigh a moderate one.
class LeaderboardRow {
  LeaderboardRow({
    required this.plantKey,
    required this.plantName,
    required this.plantSection,
  });

  final String plantKey;
  final String plantName;
  final String plantSection;
  int votes = 0;

  /// Everyone who picked this plant — used to resolve the prize afterwards.
  final Set<String> voterUids = {};

  /// Who picked it, in the order they did, so the prize for a top plant can be
  /// handed to the right person or team without digging through Firestore.
  final List<Picker> pickers = [];

  /// Distinct team names among the pickers, blank for solo players.
  Set<String> get teamNames =>
      pickers.map((p) => p.teamName).whereType<String>().toSet();

  /// Mean position per axis, for the "how people saw it" bar.
  final Map<String, List<int>> _byAxis = {};

  void add(ContestEntry e) {
    if (!voterUids.add(e.uid)) return; // one entry per person per plant
    votes++;
    pickers.add(Picker(
      uid: e.uid,
      name: e.displayName.isEmpty ? 'Visitor' : e.displayName,
      teamName: e.teamName,
      at: e.createdAt,
    ));
    e.ratings.forEach((k, v) => _byAxis.putIfAbsent(k, () => []).add(v));
  }

  /// Average slider position for an axis, or null when nobody rated it.
  double? averageFor(String axisKey) {
    final vals = _byAxis[axisKey];
    if (vals == null || vals.isEmpty) return null;
    return vals.reduce((a, b) => a + b) / vals.length;
  }
}

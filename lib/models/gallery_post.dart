// lib/models/gallery_post.dart
//
// A visitor's photo from their walk round the garden — a caption, optionally a
// plant, and a choice of who can see it.
//
// The storage decision is the interesting part. A PRIVATE post never leaves the
// phone: the image sits in the app's own directory and only the person who took
// it can ever see it, so it costs nothing to host and cannot leak. Publishing is
// what triggers the upload, so cloud cost scales with shared content rather than
// with everything anyone ever snapped.
//
// The trade that buys: a private post depends on the file still being on the
// device. Clear the app's data and it is gone. That is the right bargain for a
// visit diary, and the UI says so rather than pretending otherwise.

import 'package:cloud_firestore/cloud_firestore.dart';

enum PostVisibility { private, public }

class GalleryPost {
  const GalleryPost({
    required this.id,
    required this.uid,
    required this.displayName,
    required this.caption,
    required this.visibility,
    required this.createdAt,
    this.plantName,
    this.localPath,
    this.photoPath,
    this.reactionCount = 0,
    this.reactedUids = const [],
    this.hidden = false,
  });

  final String id;
  final String uid;
  final String displayName;
  final String caption;
  final String? plantName;
  final PostVisibility visibility;
  final DateTime createdAt;

  /// Where the image lives on THIS device. Set for every post the owner made;
  /// null when reading someone else's public post.
  final String? localPath;

  /// Storage object path. Only set once published — a private post has none.
  final String? photoPath;

  final int reactionCount;
  final List<String> reactedUids;

  /// Set by an admin on a reported post. Hidden posts drop out of the feed but
  /// are never destroyed, so a moderation call can be reversed.
  final bool hidden;

  bool get isPublic => visibility == PostVisibility.public;

  GalleryPost copyWith({
    String? caption,
    PostVisibility? visibility,
    String? photoPath,
    String? localPath,
    int? reactionCount,
    List<String>? reactedUids,
  }) =>
      GalleryPost(
        id: id,
        uid: uid,
        displayName: displayName,
        caption: caption ?? this.caption,
        plantName: plantName,
        visibility: visibility ?? this.visibility,
        createdAt: createdAt,
        localPath: localPath ?? this.localPath,
        photoPath: photoPath ?? this.photoPath,
        reactionCount: reactionCount ?? this.reactionCount,
        reactedUids: reactedUids ?? this.reactedUids,
        hidden: hidden,
      );

  // ── Firestore (public posts only) ────────────────────────────────────────

  Map<String, dynamic> toFirestore() => {
        'uid': uid,
        'displayName': displayName,
        'caption': caption,
        if (plantName != null) 'plantName': plantName,
        'visibility': 'public',
        'createdAt': Timestamp.fromDate(createdAt),
        if (photoPath != null) 'photoPath': photoPath,
        'reactionCount': reactionCount,
        'reactedUids': reactedUids,
        'hidden': hidden,
      };

  factory GalleryPost.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? {};
    return GalleryPost(
      id: d.id,
      uid: (m['uid'] ?? '') as String,
      displayName: (m['displayName'] ?? 'Visitor') as String,
      caption: (m['caption'] ?? '') as String,
      plantName: m['plantName'] as String?,
      visibility: PostVisibility.public,
      createdAt: (m['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      photoPath: m['photoPath'] as String?,
      reactionCount: (m['reactionCount'] as num?)?.toInt() ?? 0,
      reactedUids:
          ((m['reactedUids'] as List?) ?? const []).map((e) => '$e').toList(),
      hidden: (m['hidden'] as bool?) ?? false,
    );
  }

  // ── Local JSON (every post the owner made, private or public) ────────────

  Map<String, dynamic> toJson() => {
        'id': id,
        'uid': uid,
        'displayName': displayName,
        'caption': caption,
        'plantName': plantName,
        'visibility': visibility.name,
        'createdAt': createdAt.toIso8601String(),
        'localPath': localPath,
        'photoPath': photoPath,
      };

  factory GalleryPost.fromJson(Map<String, dynamic> j) => GalleryPost(
        id: (j['id'] ?? '') as String,
        uid: (j['uid'] ?? '') as String,
        displayName: (j['displayName'] ?? 'Visitor') as String,
        caption: (j['caption'] ?? '') as String,
        plantName: j['plantName'] as String?,
        visibility: (j['visibility'] == 'public')
            ? PostVisibility.public
            : PostVisibility.private,
        createdAt:
            DateTime.tryParse('${j['createdAt']}') ?? DateTime.now(),
        localPath: j['localPath'] as String?,
        photoPath: j['photoPath'] as String?,
      );
}

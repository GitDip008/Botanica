// lib/services/gallery_service.dart
//
// Visitor photo gallery. Two storage tiers, chosen so cost tracks what is
// actually shared:
//
//   PRIVATE  — image copied into the app's own directory, metadata in
//              SharedPreferences. Never uploaded, never costs anything, never
//              visible to anyone else.
//   PUBLIC   — the image is uploaded at the moment of publishing, and a
//              Firestore document makes it visible in the feed.
//
// Publishing later is supported and costs nothing extra: the upload simply
// happens then instead of at capture. The one requirement is that the local
// file still exists, which is why unpublishable posts are reported rather than
// silently failing.
//
// ponytail: no separate thumbnail pipeline. Captures are ~150 KB at medium
// resolution, so a 20-post page is ~3 MB — comfortably inside the free daily
// egress, and cheaper than adding an image-processing dependency. Revisit if
// posts ever get large or the feed gets long.

import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/gallery_post.dart';

class GalleryService {
  GalleryService._();
  static final GalleryService instance = GalleryService._();

  static const _posts = 'gallery_posts';
  static const _reports = 'gallery_reports';
  static const _prefsKey = 'gallery_local_posts_v1';

  FirebaseFirestore get _db => FirebaseFirestore.instance;

  // ── Local (the owner's own record of every post) ─────────────────────────

  Future<Directory> _photoDir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/gallery');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  /// Where a private photo lives for this platform.
  ///
  /// On Android it is the app's own directory — free, offline, never uploaded.
  /// The browser has no such directory (path_provider throws on web), and
  /// localStorage is far too small for photographs, so on web a private photo
  /// goes to Storage under a path only its owner can read. It costs ~150 KB of
  /// storage per photo, which is the price of the feature existing at all for
  /// iPhone visitors who cannot install the app.
  static String privateStoragePath(String uid, String postId) =>
      'gallery_private/$uid/$postId.jpg';

  /// Copies a camera capture somewhere durable and returns a handle to it.
  ///
  /// Android: an absolute file path. Web: the Storage path it was uploaded to,
  /// prefixed so [isRemoteHandle] can tell the two apart.
  Future<String> persistPhoto(File source, String postId, {String? uid}) async {
    if (kIsWeb) {
      final path = privateStoragePath(uid ?? 'anon', postId);
      await FirebaseStorage.instance.ref(path).putFile(
            source,
            SettableMetadata(contentType: 'image/jpeg'),
          );
      return '$_remotePrefix$path';
    }
    final dir = await _photoDir();
    final dest = File('${dir.path}/$postId.jpg');
    await source.copy(dest.path);
    return dest.path;
  }

  /// Marks a handle as living in Storage rather than on disk.
  static const _remotePrefix = 'remote:';

  static bool isRemoteHandle(String? handle) =>
      handle != null && handle.startsWith(_remotePrefix);

  static String remotePathOf(String handle) =>
      handle.substring(_remotePrefix.length);

  /// Resolves a private photo for display, whichever platform stored it.
  Future<String?> privatePhotoUrl(String? handle) async {
    if (handle == null) return null;
    if (!isRemoteHandle(handle)) return null; // a local file; caller uses File()
    return photoUrl(remotePathOf(handle));
  }

  Future<List<GalleryPost>> loadLocal() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
      final posts = list.map(GalleryPost.fromJson).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return posts;
    } catch (_) {
      return []; // corrupt store must not brick the screen
    }
  }

  Future<void> _saveLocal(List<GalleryPost> posts) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _prefsKey, jsonEncode(posts.map((p) => p.toJson()).toList()));
  }

  Future<void> upsertLocal(GalleryPost post) async {
    final all = await loadLocal();
    final i = all.indexWhere((p) => p.id == post.id);
    if (i >= 0) {
      all[i] = post;
    } else {
      all.insert(0, post);
    }
    await _saveLocal(all);
  }

  /// Removes a post from this device. A published post is also withdrawn from
  /// the feed and its uploaded file deleted — this is the visitor's own content,
  /// so unlike the garden's records they may take it back.
  Future<void> deleteLocal(GalleryPost post) async {
    if (post.isPublic) {
      await unpublish(post);
    }
    final handle = post.localPath;
    if (handle != null) {
      if (isRemoteHandle(handle)) {
        try {
          await FirebaseStorage.instance.ref(remotePathOf(handle)).delete();
        } catch (_) {
          // Already gone; nothing is reachable without the local record anyway.
        }
      } else {
        final f = File(handle);
        if (await f.exists()) await f.delete();
      }
    }
    final all = await loadLocal()
      ..removeWhere((p) => p.id == post.id);
    await _saveLocal(all);
  }

  // ── Publishing ───────────────────────────────────────────────────────────

  /// Uploads the image and writes the feed document. Returns the updated post.
  ///
  /// Throws [StateError] when the local file is gone — a post captured on a
  /// device whose app data was cleared cannot be published, and the caller
  /// shows that plainly instead of failing without explanation.
  Future<GalleryPost> publish(GalleryPost post) async {
    final handle = post.localPath;
    if (handle == null) throw StateError('photo-missing');

    final storagePath = 'gallery/${post.uid}/${post.id}.jpg';

    if (isRemoteHandle(handle)) {
      // Web: the image is already in Storage under the private path. Copy the
      // bytes across rather than asking the browser to re-upload something it
      // no longer holds in memory.
      final bytes =
          await FirebaseStorage.instance.ref(remotePathOf(handle)).getData();
      if (bytes == null) throw StateError('photo-missing');
      await FirebaseStorage.instance.ref(storagePath).putData(
            bytes,
            SettableMetadata(contentType: 'image/jpeg'),
          );
    } else {
      if (!await File(handle).exists()) throw StateError('photo-missing');
      await FirebaseStorage.instance.ref(storagePath).putFile(
            File(handle),
            SettableMetadata(contentType: 'image/jpeg'),
          );
    }

    final published = post.copyWith(
      visibility: PostVisibility.public,
      photoPath: storagePath,
    );
    await _db.collection(_posts).doc(post.id).set(published.toFirestore());
    await upsertLocal(published);
    return published;
  }

  /// Takes a post back out of the feed and deletes the uploaded image, so an
  /// unpublished post stops costing storage as well as stopping being visible.
  Future<GalleryPost> unpublish(GalleryPost post) async {
    try {
      await _db.collection(_posts).doc(post.id).delete();
    } catch (_) {
      // Already gone, or offline — the local flag below is what the owner sees.
    }
    if (post.photoPath != null) {
      try {
        await FirebaseStorage.instance.ref(post.photoPath!).delete();
      } catch (_) {
        // Nothing readable remains without the Firestore doc; a stray object is
        // a cent, not a leak.
      }
    }
    final reverted = GalleryPost(
      id: post.id,
      uid: post.uid,
      displayName: post.displayName,
      caption: post.caption,
      plantName: post.plantName,
      visibility: PostVisibility.private,
      createdAt: post.createdAt,
      localPath: post.localPath,
    );
    await upsertLocal(reverted);
    return reverted;
  }

  // ── Public feed ──────────────────────────────────────────────────────────

  /// Newest first, capped. Hidden posts are filtered on the client because a
  /// composite index on (hidden, createdAt) is not worth provisioning for a
  /// feed this size.
  Stream<List<GalleryPost>> watchFeed({int limit = 60}) => _db
      .collection(_posts)
      .orderBy('createdAt', descending: true)
      .limit(limit)
      .snapshots()
      .map((s) =>
          s.docs.map(GalleryPost.fromDoc).where((p) => !p.hidden).toList());

  Future<String?> photoUrl(String? storagePath) async {
    if (storagePath == null || storagePath.isEmpty) return null;
    try {
      return await FirebaseStorage.instance.ref(storagePath).getDownloadURL();
    } catch (_) {
      return null;
    }
  }

  /// Toggles this user's reaction. arrayUnion/arrayRemove plus an increment so
  /// two people reacting at once cannot clobber each other's count.
  Future<void> toggleReaction(GalleryPost post, String uid) async {
    final has = post.reactedUids.contains(uid);
    await _db.collection(_posts).doc(post.id).update({
      'reactedUids':
          has ? FieldValue.arrayRemove([uid]) : FieldValue.arrayUnion([uid]),
      'reactionCount': FieldValue.increment(has ? -1 : 1),
    });
  }

  /// Files a report for an admin to review. Reporting never removes anything by
  /// itself — one tap from a stranger must not be able to take a post down.
  Future<void> report(GalleryPost post, String byUid, String reason) async {
    await _db.collection(_reports).add({
      'postId': post.id,
      'postUid': post.uid,
      'reportedBy': byUid,
      'reason': reason,
      'createdAt': Timestamp.now(),
      'resolved': false,
    });
  }

  // ── Moderation (admin only; rules enforce it server-side too) ────────────

  /// Open reports, oldest first — the queue is worked front to back.
  Stream<List<GalleryReport>> watchOpenReports() => _db
      .collection(_reports)
      .where('resolved', isEqualTo: false)
      .snapshots()
      .map((s) {
        final list = s.docs.map(GalleryReport.fromDoc).toList()
          ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
        return list;
      });

  /// Count of open reports, for the badge on the admin panel.
  Stream<int> watchOpenReportCount() => _db
      .collection(_reports)
      .where('resolved', isEqualTo: false)
      .snapshots()
      .map((s) => s.docs.length);

  Future<GalleryPost?> fetchPost(String postId) async {
    final d = await _db.collection(_posts).doc(postId).get();
    return d.exists ? GalleryPost.fromDoc(d) : null;
  }

  /// Hides or restores a post. Hiding drops it from the feed but destroys
  /// nothing, so a moderation call can be reversed — the same reasoning that
  /// keeps the garden's own records append-only.
  Future<void> setHidden(String postId, bool hidden) =>
      _db.collection(_posts).doc(postId).update({'hidden': hidden});

  /// Removes a post outright. Reserved for content that must not sit in the
  /// database at all; hiding is the usual answer.
  Future<void> adminDeletePost(GalleryPost post) async {
    await _db.collection(_posts).doc(post.id).delete();
    if (post.photoPath != null) {
      try {
        await FirebaseStorage.instance.ref(post.photoPath!).delete();
      } catch (_) {
        // The document is gone, so nothing is reachable either way.
      }
    }
  }

  Future<void> resolveReport(String reportId, String outcome) =>
      _db.collection(_reports).doc(reportId).update({
        'resolved': true,
        'outcome': outcome,
        'resolvedAt': Timestamp.now(),
      });
}

/// A visitor's report of a public post, awaiting an admin decision.
class GalleryReport {
  const GalleryReport({
    required this.id,
    required this.postId,
    required this.postUid,
    required this.reportedBy,
    required this.reason,
    required this.createdAt,
  });

  final String id;
  final String postId;
  final String postUid;
  final String reportedBy;
  final String reason;
  final DateTime createdAt;

  factory GalleryReport.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? {};
    return GalleryReport(
      id: d.id,
      postId: (m['postId'] ?? '') as String,
      postUid: (m['postUid'] ?? '') as String,
      reportedBy: (m['reportedBy'] ?? '') as String,
      reason: (m['reason'] ?? '') as String,
      createdAt: (m['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

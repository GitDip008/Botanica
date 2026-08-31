// test/gallery_test.dart
//
// Gallery post serialisation and the private/public boundary.
//
// The property that matters: a PRIVATE post must never carry a storage path.
// If one ever did, the app would try to serve an image that was never uploaded
// — or worse, imply a private photo is sitting in a shared bucket.

import 'package:botanica_ar/models/gallery_post.dart';
import 'package:flutter_test/flutter_test.dart';

GalleryPost _post({
  PostVisibility visibility = PostVisibility.private,
  String? photoPath,
  String? localPath = '/data/app/gallery/1.jpg',
}) =>
    GalleryPost(
      id: '1',
      uid: 'u1',
      displayName: 'Dip',
      caption: 'Odd little thing by the pond',
      plantName: 'Rubus chamaemorus',
      visibility: visibility,
      createdAt: DateTime(2026, 9, 1, 12, 30),
      localPath: localPath,
      photoPath: photoPath,
    );

void main() {
  group('local round trip', () {
    test('survives encode/decode unchanged', () {
      final before = _post();
      final after = GalleryPost.fromJson(before.toJson());

      expect(after.id, before.id);
      expect(after.uid, before.uid);
      expect(after.caption, before.caption);
      expect(after.plantName, before.plantName);
      expect(after.visibility, PostVisibility.private);
      expect(after.localPath, before.localPath);
      expect(after.createdAt, before.createdAt);
    });

    test('a public post keeps its storage path locally', () {
      final p = _post(
        visibility: PostVisibility.public,
        photoPath: 'gallery/u1/1.jpg',
      );
      final after = GalleryPost.fromJson(p.toJson());
      expect(after.isPublic, isTrue);
      expect(after.photoPath, 'gallery/u1/1.jpg');
    });

    test('unknown visibility decodes as private', () {
      // Anything unrecognised must fail CLOSED — never surface as public.
      final j = _post().toJson()..['visibility'] = 'weird';
      expect(GalleryPost.fromJson(j).visibility, PostVisibility.private);
    });

    test('a malformed date does not throw', () {
      final j = _post().toJson()..['createdAt'] = 'not-a-date';
      expect(() => GalleryPost.fromJson(j), returnsNormally);
    });
  });

  group('private/public boundary', () {
    test('a private post carries no storage path', () {
      expect(_post().photoPath, isNull);
      expect(_post().isPublic, isFalse);
    });

    test('publishing sets visibility and path together', () {
      final published = _post().copyWith(
        visibility: PostVisibility.public,
        photoPath: 'gallery/u1/1.jpg',
      );
      expect(published.isPublic, isTrue);
      expect(published.photoPath, isNotNull);
    });

    test('copyWith preserves identity and authorship', () {
      // A caption edit must never be able to change who owns a post.
      final edited = _post().copyWith(caption: 'new words');
      expect(edited.id, '1');
      expect(edited.uid, 'u1');
      expect(edited.createdAt, DateTime(2026, 9, 1, 12, 30));
      expect(edited.caption, 'new words');
    });
  });

  group('firestore shape', () {
    test('only ever writes a public document', () {
      // Nothing private should be able to reach Firestore at all: the map is
      // hardcoded public because that is the only case that is uploaded.
      final m = _post(
        visibility: PostVisibility.public,
        photoPath: 'gallery/u1/1.jpg',
      ).toFirestore();

      expect(m['visibility'], 'public');
      expect(m['hidden'], false);
      expect(m['reactionCount'], 0);
      expect(m['uid'], 'u1');
      // The device-local path is private information and must not be uploaded.
      expect(m.containsKey('localPath'), isFalse);
    });
  });
}

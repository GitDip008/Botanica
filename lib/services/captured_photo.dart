// lib/services/captured_photo.dart
//
// A photo the visitor just took, usable on both Android and the web.
//
// `dart:io`'s File cannot be constructed in a browser — it throws
// "UnsupportedOperation: _Namespace", which is what broke plant identification
// and the garden diary on the web build. The camera plugin hands back an XFile
// whose `path` is a real filesystem path on Android and a blob URL on web, so
// the only thing safe to use on both is its BYTES.
//
// Everything downstream (upload, identify, display) wants bytes anyway, so this
// carries them and keeps the path only where a native file is genuinely needed.

import 'dart:io' show File;
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class CapturedPhoto {
  const CapturedPhoto({required this.bytes, this.path});

  /// Image bytes. Always present, on every platform.
  final Uint8List bytes;

  /// Native filesystem path. Null on web, where no such thing exists.
  final String? path;

  static Future<CapturedPhoto> fromXFile(XFile x) async {
    final bytes = await x.readAsBytes();
    return CapturedPhoto(bytes: bytes, path: kIsWeb ? null : x.path);
  }

  /// A `File` for the APIs that still require one. Null on web — callers must
  /// fall back to [bytes] rather than assume this exists.
  File? get file => path == null ? null : File(path!);

  int get sizeBytes => bytes.lengthInBytes;
}

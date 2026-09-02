// lib/services/camera_utils.dart
//
// Camera selection helpers shared by every screen that takes a photo.
//
// `availableCameras().first` is NOT the back camera on many Android devices —
// the order is whatever the platform reports, and on several phones the front
// camera comes first. Every capture screen in the app was using `.first`, so
// visitors got a selfie camera pointed at themselves when trying to photograph
// a plant.

import 'package:camera/camera.dart';

/// The camera a plant photo should start with: rear-facing if the device has
/// one, otherwise whatever exists.
CameraDescription preferredCamera(List<CameraDescription> cameras) {
  for (final c in cameras) {
    if (c.lensDirection == CameraLensDirection.back) return c;
  }
  return cameras.first;
}

/// The next camera to switch to, cycling through what the device actually has.
/// Returns null when there is nothing to switch to, so callers can hide the
/// toggle rather than showing a button that does nothing.
CameraDescription? nextCamera(
  List<CameraDescription> cameras,
  CameraDescription current,
) {
  if (cameras.length < 2) return null;
  final i = cameras.indexWhere((c) =>
      c.name == current.name && c.lensDirection == current.lensDirection);
  return cameras[(i + 1) % cameras.length];
}

/// Whether a switch control is worth showing at all.
bool hasMultipleCameras(List<CameraDescription> cameras) => cameras.length > 1;

/// Icon hint for the camera currently in use.
bool isFront(CameraDescription c) =>
    c.lensDirection == CameraLensDirection.front;

/// The next whole-number zoom level one press away, clamped to what the device
/// actually supports. [direction] is +1 to zoom in, -1 to zoom out.
///
/// Whole steps rather than a fraction of the reported range: phones report
/// maximum zoom anywhere from 4× to 100×, so stepping by "one eighth of the
/// range" moved barely at all on one device and jumped uselessly far on
/// another. A press now means 1×, 2×, 3×, … everywhere.
///
/// The epsilon matters after a pinch: at 2.0 exactly, `ceil(2.0) - 1` is 1 as
/// wanted, but at 2.0000001 it would be 2 — the level already showing, so the
/// button would look broken.
double nextZoom(double current, int direction, double min, double max) {
  const e = 0.001;
  final next = direction > 0
      ? (current + e).floorToDouble() + 1
      : (current - e).ceilToDouble() - 1;
  return next.clamp(min, max);
}

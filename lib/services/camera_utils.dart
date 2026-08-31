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

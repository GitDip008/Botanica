// lib/providers/navigation_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../models/navigation_state.dart';
import '../services/compass_service.dart';
import 'plant_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// GPS position
// ─────────────────────────────────────────────────────────────────────────────

final gpsPositionProvider = StreamProvider<Position>((ref) {
  return Geolocator.getPositionStream(
    locationSettings: const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5,
    ),
  );
});

// ─────────────────────────────────────────────────────────────────────────────
// Compass heading
// ─────────────────────────────────────────────────────────────────────────────

final compassServiceProvider = Provider<CompassService>((ref) {
  final svc = CompassService();
  svc.startListening();
  ref.onDispose(svc.dispose);
  return svc;
});

final compassHeadingProvider = StreamProvider<double>((ref) {
  return ref.watch(compassServiceProvider).headingStream;
});

// ─────────────────────────────────────────────────────────────────────────────
// Navigation state — computed ON-DEVICE from GPS + destination.
//
// The original BotaniNav received this over a WebSocket from the backend's
// server-side trilateration. Inside Botanica we compute bearing/distance/arrival
// locally with geolocator, so navigation needs no live backend connection.
// (Indoor positioning is handled separately by the BLE nearest-beacon service.)
// ─────────────────────────────────────────────────────────────────────────────

/// Distance (metres) under which the user is considered to have arrived.
const double _arrivalRadiusM = 5;

final navigationStateProvider =
    Provider.family<AsyncValue<NavigationState>, String>((ref, plantId) {
  final gpsAsync = ref.watch(gpsPositionProvider);
  final plant = ref.watch(plantByIdProvider(plantId));

  return gpsAsync.whenData((pos) {
    if (plant == null || !plant.hasGpsCoords) {
      return NavigationState.loading;
    }
    final destLat = plant.gpsLat!;
    final destLng = plant.gpsLng!;

    final distance = Geolocator.distanceBetween(
        pos.latitude, pos.longitude, destLat, destLng);
    final rawBearing = Geolocator.bearingBetween(
        pos.latitude, pos.longitude, destLat, destLng);
    final bearing = (rawBearing + 360) % 360;

    final arrived = distance <= _arrivalRadiusM;
    // Hot/cold: 1.0 right on top, fading to 0.0 at ~100 m away.
    final hotCold = (1 - distance / 100).clamp(0.0, 1.0).toDouble();

    final hint = arrived
        ? 'You have arrived'
        : distance < 15
            ? 'Almost there'
            : distance < 50
                ? 'Getting warmer'
                : 'Head toward the marker';

    return NavigationState(
      bearing: bearing,
      distanceMetres: distance,
      hotColdScore: hotCold,
      hint: hint,
      waypointIndex: 0,
      arrived: arrived,
    );
  });
});

// ─────────────────────────────────────────────────────────────────────────────
// Arrow angle — bearing minus compass heading
// ─────────────────────────────────────────────────────────────────────────────

final arrowAngleProvider = Provider.family<double, String>((ref, plantId) {
  final navAsync = ref.watch(navigationStateProvider(plantId));
  final headingAsync = ref.watch(compassHeadingProvider);

  final bearing = navAsync.whenOrNull(data: (s) => s.bearing) ?? 0.0;
  final heading = headingAsync.whenOrNull(data: (h) => h) ?? 0.0;

  return (bearing - heading + 360) % 360;
});
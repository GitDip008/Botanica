// lib/navigation/config/env.dart
//
// Static configuration for the navigation module. Plant data comes from
// Botanica's own backend (the plantsCatalogue callable), so no API base lives
// here. These values are non-sensitive.

abstract final class Env {
  // ── BLE Beacon UUIDs ───────────────────────────────────────────────────────
  // TODO: replace with the real provisioned beacon UUIDs (humidity-resistant ID
  // beacons). One per greenhouse zone; the nearest-beacon service maps the
  // strongest signal to the current indoor section.
  static const List<String> beaconUuids = [
    '00000000-0000-0000-0000-000000000001',
    '00000000-0000-0000-0000-000000000002',
  ];
}

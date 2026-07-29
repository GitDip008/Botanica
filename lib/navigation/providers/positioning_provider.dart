// lib/navigation/providers/positioning_provider.dart
//
// Nearest-beacon indoor positioning. Scans BLE, keeps only the known PhytoSense
// nodes (beacon_map.dart), and reports the section of whichever node is
// strongest — that is "you are here". No math, no network; the whole thing is
// dormant (returns null) until kBeaconToSection is filled with real node ids.
//
// Upgrade path: swap _strongest for the trilateration / fused solver once the
// beacon team shares their algorithm + node coordinates.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import '../config/beacon_map.dart';
import '../services/ble_service.dart';

/// Owns the scanner. Requests BLE permission, starts scanning, cleans up.
/// autoDispose so scanning stops the moment the floor plan is closed.
final bleServiceProvider = Provider.autoDispose<BleService>((ref) {
  final svc = BleService();
  () async {
    await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
    ].request();
    await svc.startScanning();
  }();
  ref.onDispose(svc.dispose);
  return svc;
});

/// Raw { beaconId → rssi } snapshots from the scanner.
final beaconScanProvider = StreamProvider.autoDispose<BeaconRssiMap>((ref) {
  return ref.watch(bleServiceProvider).rssiStream;
});

/// The room label the user is currently in (strongest known node), or null when
/// no known node is in range (also the state until real node ids are provided).
final currentSectionProvider = Provider.autoDispose<String?>((ref) {
  final scan = ref.watch(beaconScanProvider).whenOrNull(data: (m) => m);
  if (scan == null || scan.isEmpty) return null;
  return _strongest(scan);
});

/// Pick the known beacon with the highest RSSI (closest) and return its section.
String? _strongest(BeaconRssiMap scan) {
  String? bestSection;
  int bestRssi = -1000;
  scan.forEach((id, rssi) {
    final section = kBeaconToSection[id];
    if (section != null && rssi > bestRssi) {
      bestRssi = rssi;
      bestSection = section;
    }
  });
  return bestSection;
}

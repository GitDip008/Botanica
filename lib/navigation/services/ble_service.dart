// lib/navigation/services/ble_service.dart
//
// Scans for BLE advertising packets and exposes a stream of { beaconId → rssi }
// maps. The positioning layer keeps only the IDs it recognises (the PhytoSense
// ESP32 nodes, see beacon_map.dart) and picks the strongest as the current spot.
//
// We scan ALL advertisers (no service-UUID filter) so this works whatever format
// the nodes advertise in (iBeacon / Eddystone / custom); matching is done by
// device id downstream. Once the node advertising format is confirmed, a
// withServices filter can be added to save battery.

import 'dart:async';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

typedef BeaconRssiMap = Map<String, int>;

class BleService {
  final _controller = StreamController<BeaconRssiMap>.broadcast();
  StreamSubscription<List<ScanResult>>? _scanSubscription;

  /// Stream of beacon-ID → RSSI snapshots, emitted every scan cycle.
  Stream<BeaconRssiMap> get rssiStream => _controller.stream;

  Future<void> startScanning() async {
    final isOn = await FlutterBluePlus.isSupported;
    if (!isOn) {
      _controller.addError(Exception('BLE not supported on this device.'));
      return;
    }

    await FlutterBluePlus.startScan(continuousUpdates: true);

    _scanSubscription = FlutterBluePlus.scanResults.listen(
      (results) {
        final snapshot = <String, int>{};
        for (final result in results) {
          snapshot[result.device.remoteId.str] = result.rssi;
        }
        if (!_controller.isClosed) _controller.add(snapshot);
      },
      onError: (Object e) {
        if (!_controller.isClosed) _controller.addError(e);
      },
    );
  }

  Future<void> dispose() async {
    await FlutterBluePlus.stopScan();
    await _scanSubscription?.cancel();
    await _controller.close();
  }
}

import 'dart:async';

import 'package:botanica_ar/services/ble_permission.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class BeaconScanner {
  final BlePermissionManager _permissionManager = BlePermissionManager();
  StreamSubscription<List<ScanResult>>? _subscription;

  Future<bool> startScan({
    required Function(String beaconId, int rssi) onBeaconFound,
  }) async {
    final hasPermission = await _permissionManager.requestPermissions();
    if (!hasPermission) {
      return false; // để UI xử lý hiển thị thông báo / dẫn vào Settings
    }

    if (await FlutterBluePlus.adapterState.first != BluetoothAdapterState.on) {
      return false;
    }

    FlutterBluePlus.startScan(
      timeout: const Duration(seconds: 0),
      androidUsesFineLocation: true,
    );

    _subscription = FlutterBluePlus.scanResults.listen((results) {
      for (ScanResult r in results) {
        final beaconId = _identifyBeacon(r);
        if (beaconId != null) {
          onBeaconFound(beaconId, r.rssi);
        }
      }
    });

    return true;
  }

  void stopScan() {
    FlutterBluePlus.stopScan();
    _subscription?.cancel();
  }

  String? _identifyBeacon(ScanResult r) => r.device.remoteId.toString();
}
import 'package:permission_handler/permission_handler.dart';

/// Quản lý toàn bộ việc xin quyền cần thiết cho BLE scanning.
class BlePermissionManager {
  /// Xin tất cả quyền cần thiết, trả về true nếu đủ quyền.
  Future<bool> requestPermissions() async {
    final statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
    ].request();

    return statuses.values.every((status) => status.isGranted);
  }

  /// Kiểm tra xem đã có đủ quyền chưa, không hiện dialog xin quyền.
  Future<bool> hasAllPermissions() async {
    final results = await Future.wait([
      Permission.bluetoothScan.status,
      Permission.bluetoothConnect.status,
      Permission.locationWhenInUse.status,
    ]);
    return results.every((status) => status.isGranted);
  }

  /// Trả về danh sách quyền đang bị từ chối, hữu ích để show UI giải thích
  /// cho user biết quyền nào còn thiếu.
  Future<List<Permission>> getDeniedPermissions() async {
    final permissions = [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
    ];

    final denied = <Permission>[];
    for (final p in permissions) {
      if (!(await p.status).isGranted) denied.add(p);
    }
    return denied;
  }

  /// Kiểm tra xem có quyền nào bị từ chối vĩnh viễn không (permanentlyDenied)
  /// — trường hợp này cần dẫn user vào Settings thủ công.
  Future<bool> hasPermanentlyDeniedPermission() async {
    final results = await Future.wait([
      Permission.bluetoothScan.status,
      Permission.bluetoothConnect.status,
      Permission.locationWhenInUse.status,
    ]);
    return results.any((status) => status.isPermanentlyDenied);
  }

  /// Mở màn hình Settings của app để user tự bật quyền thủ công.
  Future<void> openSettings() async {
    await openAppSettings();
  }
}
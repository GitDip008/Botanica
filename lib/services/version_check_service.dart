import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Reads the minimum-required version from Firestore (/config/version).
///
/// If the installed app is older than this, the app should block until update.
/// Update the Firestore doc when you publish a new release.
class VersionCheckService {
  VersionCheckService._();
  static final instance = VersionCheckService._();

  /// Returns true if a force update is required.
  Future<({bool required, String latest, String downloadUrl})>
      check() async {
    try {
      final info = await PackageInfo.fromPlatform();
      final current = info.version; // e.g. "1.0.0"

      final doc = await FirebaseFirestore.instance
          .collection('config')
          .doc('version')
          .get();
      if (!doc.exists) {
        return (required: false, latest: current, downloadUrl: '');
      }
      final data = doc.data()!;
      final minVersion = (data['minVersion'] as String?) ?? '0.0.0';
      final latest = (data['latest'] as String?) ?? current;
      final url = (data['downloadUrl'] as String?) ?? '';

      return (
        required: _isOlder(current, minVersion),
        latest: latest,
        downloadUrl: url,
      );
    } catch (_) {
      return (required: false, latest: '', downloadUrl: '');
    }
  }

  /// Compares semantic versions — returns true if [a] is older than [b].
  bool _isOlder(String a, String b) {
    final pa = a.split('.').map((p) => int.tryParse(p) ?? 0).toList();
    final pb = b.split('.').map((p) => int.tryParse(p) ?? 0).toList();
    while (pa.length < 3) pa.add(0);
    while (pb.length < 3) pb.add(0);
    for (var i = 0; i < 3; i++) {
      if (pa[i] < pb[i]) return true;
      if (pa[i] > pb[i]) return false;
    }
    return false;
  }
}

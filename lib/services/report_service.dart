import 'package:cloud_firestore/cloud_firestore.dart';
import 'auth_service.dart';

/// Lightweight Firestore mirror for visitor reports — admin panel reads from
/// here. We continue to persist locally too (SharedPreferences) for offline
/// viewing in ReportScreen.
class ReportService {
  ReportService._();
  static final ReportService instance = ReportService._();

  final _firestore = FirebaseFirestore.instance;

  /// Saves a report to Firestore. Best-effort: silently fails offline.
  Future<void> save({
    required String category,
    required String aiDescription,
    required String note,
    required double? latitude,
    required double? longitude,
    required DateTime timestamp,
  }) async {
    final user = AuthService.instance.currentUser;
    try {
      await _firestore.collection('reports').add({
        'userId': user?.id ?? 'anonymous',
        'userEmail': user?.email ?? '',
        'userName': user?.displayName ?? '',
        'category': category,
        'aiDescription': aiDescription,
        'note': note,
        'latitude': latitude,
        'longitude': longitude,
        'timestamp': timestamp.toIso8601String(),
      });
    } catch (_) {/* offline ok */}
  }

  Stream<List<Map<String, dynamic>>> watchAll() {
    return _firestore
        .collection('reports')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) {
              final m = d.data();
              m['id'] = d.id;
              return m;
            }).toList());
  }
}

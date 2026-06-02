import 'package:cloud_firestore/cloud_firestore.dart';
import 'auth_service.dart';

/// Persists earned achievement badges to the user's Firestore doc.
///
/// Badge IDs are stable strings (e.g. `plant_hunt_spring_2026`). Earned
/// badges land in `/users/{uid}.badges` as a list of:
///   `{ id, earnedAt }`
/// The chat / profile screens can then read them and display a roster.
class BadgeService {
  BadgeService._();
  static final BadgeService instance = BadgeService._();

  /// Award a badge to the current user. No-op if not signed in or already
  /// earned. Safe to call multiple times.
  Future<void> award(String badgeId) async {
    final uid = AuthService.instance.currentUser?.id;
    if (uid == null) return;
    final ref = FirebaseFirestore.instance.collection('users').doc(uid);
    try {
      await FirebaseFirestore.instance.runTransaction((tx) async {
        final snap = await tx.get(ref);
        if (!snap.exists) return;
        final data = snap.data()!;
        final existing = (data['badges'] as List?)
                ?.whereType<Map>()
                .map((e) => Map<String, dynamic>.from(e))
                .toList() ??
            <Map<String, dynamic>>[];
        if (existing.any((b) => b['id'] == badgeId)) return; // dedupe
        existing.add({
          'id': badgeId,
          'earnedAt': DateTime.now().toIso8601String(),
        });
        tx.update(ref, {'badges': existing});
      });
    } catch (_) {
      // Non-fatal — badge will be re-tried next time the user finishes.
    }
  }

  /// Read current user's badge IDs. Returns empty list on any failure.
  Future<List<String>> earnedBadgeIds() async {
    final uid = AuthService.instance.currentUser?.id;
    if (uid == null) return const [];
    try {
      final snap =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final list = (snap.data()?['badges'] as List?)
              ?.whereType<Map>()
              .map((e) => (e['id'] as String?) ?? '')
              .where((id) => id.isNotEmpty)
              .toList() ??
          const [];
      return list;
    } catch (_) {
      return const [];
    }
  }
}

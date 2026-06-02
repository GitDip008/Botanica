import 'package:cloud_firestore/cloud_firestore.dart';

/// Tracks how often each major feature is used.
///
/// Writes to a single Firestore document: `/stats/features` where each
/// feature name is a key with an incrementing count. This is far cheaper
/// than logging individual events — one write per use, one read for the
/// whole admin chart.
class UsageTrackingService {
  UsageTrackingService._();
  static final instance = UsageTrackingService._();

  // Stable feature IDs — referenced by both writers and the admin chart.
  static const featurePlantId = 'plant_id';
  static const featurePlantHunt = 'plant_hunt';
  static const featureChat = 'chat';
  static const featureBloom = 'bloom';
  static const featureMap = 'map';
  static const featureTrails = 'trails';
  static const featureSoundscape = 'soundscape';
  static const featureSearch = 'search';
  static const featureReport = 'report';
  static const featureEvent = 'event_request';

  /// All known features — used by the admin chart to show zeros for unused ones.
  static const allFeatures = [
    featurePlantId,
    featurePlantHunt,
    featureChat,
    featureBloom,
    featureMap,
    featureTrails,
    featureSoundscape,
    featureSearch,
    featureReport,
    featureEvent,
  ];

  final _doc = FirebaseFirestore.instance.collection('stats').doc('features');

  /// Records one use of a feature. Best-effort — silent on failure.
  Future<void> log(String feature) async {
    try {
      await _doc.set({feature: FieldValue.increment(1)}, SetOptions(merge: true));
    } catch (_) {}
  }

  /// Stream of feature-name → use-count, for the admin chart.
  Stream<Map<String, int>> watchCounts() {
    return _doc.snapshots().map((snap) {
      final data = snap.data() ?? {};
      final out = <String, int>{};
      for (final f in allFeatures) {
        out[f] = (data[f] as num?)?.toInt() ?? 0;
      }
      return out;
    });
  }
}

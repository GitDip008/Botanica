// lib/navigation/providers/plant_provider.dart
//
// Riverpod providers for the plant catalogue. All state lives here, not widgets.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/plant_index.dart';
import '../models/plant.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Plant list — served from the bundled static index (instant, offline).
// Live details/updates still go through the agent; this is just browse data.
// ─────────────────────────────────────────────────────────────────────────────

Plant _toPlant(PlantFacts f) => Plant(
      id: f.hankintaID ?? f.scientificName,
      name: f.scientificName,
      scientificName: f.scientificName,
      finnishName: f.finnishName,
      section: f.sectionCode ?? '',
      // Greenhouse section codes start with "G-H"; everything else is outdoor.
      isIndoor: (f.sectionCode ?? '').toUpperCase().startsWith('G-H'),
      description: f.sectionRoom,
    );

final plantsProvider = FutureProvider<List<Plant>>((ref) async {
  await PlantIndex.instance.ready();
  return PlantIndex.instance.all.map(_toPlant).toList();
});

/// Find a single plant by ID from the cached list.
/// Returns null if the list hasn't loaded yet or the ID doesn't exist.
final plantByIdProvider = Provider.family<Plant?, String>((ref, plantId) {
  final asyncPlants = ref.watch(plantsProvider);
  return asyncPlants.whenOrNull(
    data: (plants) {
      try {
        return plants.firstWhere((p) => p.id == plantId);
      } catch (_) {
        return null;
      }
    },
  );
});
// lib/models/plant.dart
//
// Data class mapped from the live API response.
// API wraps plants in {"count": N, "plants": [...]} — see ApiService.getPlants().

import 'package:equatable/equatable.dart';

class Plant extends Equatable {
  const Plant({
    required this.id,
    required this.name,
    required this.scientificName,
    this.finnishName,
    this.synonym,
    this.family,
    this.description,
    required this.section,
    required this.isIndoor,
    this.latitude,
    this.longitude,
    this.greenhouseId,
    this.placementStatus,
    this.imageUrl,
    this.thumbnailUrl,
    this.gpsLat,
    this.gpsLng,
  });

  /// taxonNumber from API — used as primary key.
  final String id;

  /// Scientific name (API "name" field).
  final String name;

  /// Same as name for now — API has no separate common name.
  final String scientificName;

  /// Finnish common name ("finnishName").
  final String? finnishName;

  /// Taxonomic synonym.
  final String? synonym;

  /// Family name (e.g. "Araceae").
  final String? family;

  /// Curator description / placement comments.
  final String? description;

  /// Square ID from placement (e.g. "A-12").
  final String section;

  /// Derived from section via SectionConfig.
  final bool isIndoor;

  /// enriched.square_x — longitude in GeoJSON coordinate space.
  final double? latitude;

  /// enriched.square_y — latitude in GeoJSON coordinate space.
  final double? longitude;

  /// enriched.greenhouse_id as string.
  final String? greenhouseId;

  /// placement.plantStatus (e.g. "Healthy", "Needs attention").
  final String? placementStatus;

  final String? imageUrl;
  final String? thumbnailUrl;

  /// Real-world GPS coordinates for outdoor plants.
  /// Set by the backend after importing from the coordinate picker tool.
  /// Null until coordinates have been assigned.
  final double? gpsLat;
  final double? gpsLng;

  /// True if this outdoor plant has real GPS coordinates assigned.
  bool get hasGpsCoords => gpsLat != null && gpsLng != null;

  String? get displayImageUrl => thumbnailUrl ?? imageUrl;
  bool get hasImage => imageUrl != null || thumbnailUrl != null;

  /// Display name — Finnish name if available, otherwise scientific name.
  String get displayName => finnishName ?? name;

  @override
  List<Object?> get props => [
    id, name, scientificName, finnishName, synonym, family,
    description, section, isIndoor, latitude, longitude,
    greenhouseId, placementStatus, imageUrl, thumbnailUrl,
    gpsLat, gpsLng,
  ];

  @override
  String toString() => 'Plant($id, $name, section=$section, indoor=$isIndoor)';
}
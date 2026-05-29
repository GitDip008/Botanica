class PlantInfo {
  final String scientificName;
  final String commonName;
  final String finnishName;     // from Kasvihuoneopas
  final String family;
  final String description;
  final String funFact;         // "Did you know?" hook from the guide
  final String originRegion;    // e.g. "Tropical belt", "Mediterranean", "Arid/desert"
  final String greenhouseSection; // e.g. "Romeo — Tropical", "Julia — Succulents"
  final String? imageUrl;       // Optional reference image (Wikipedia)
  final bool isPlant;

  const PlantInfo({
    required this.scientificName,
    required this.commonName,
    this.finnishName = '',
    required this.family,
    required this.description,
    this.funFact = '',
    this.originRegion = '',
    this.greenhouseSection = '',
    this.imageUrl,
    required this.isPlant,
  });

  PlantInfo copyWith({
    String? scientificName,
    String? commonName,
    String? finnishName,
    String? family,
    String? description,
    String? funFact,
    String? originRegion,
    String? greenhouseSection,
    String? imageUrl,
    bool? isPlant,
  }) {
    return PlantInfo(
      scientificName: scientificName ?? this.scientificName,
      commonName: commonName ?? this.commonName,
      finnishName: finnishName ?? this.finnishName,
      family: family ?? this.family,
      description: description ?? this.description,
      funFact: funFact ?? this.funFact,
      originRegion: originRegion ?? this.originRegion,
      greenhouseSection: greenhouseSection ?? this.greenhouseSection,
      imageUrl: imageUrl ?? this.imageUrl,
      isPlant: isPlant ?? this.isPlant,
    );
  }

  factory PlantInfo.notAPlant() => const PlantInfo(
        scientificName: 'Unknown',
        commonName: 'Not a plant',
        family: 'N/A',
        description: 'No plant detected in this image.',
        isPlant: false,
      );
}

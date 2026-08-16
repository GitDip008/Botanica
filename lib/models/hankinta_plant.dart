/// Model representing plant items returned by the hankintatiedot API coordinates endpoint.
class HankintaPlant {
  final int hankintaID;
  final int? taksoninNro;
  final int? lahettajanro;
  final String? hankintanumero;
  final String? saapumispvm;
  final String hankintanimi;
  final String? millaisenaSaatu;
  final String? lisatiedot;
  final String? heimo;
  final double coordinateX;
  final double coordinateY;

  const HankintaPlant({
    required this.hankintaID,
    this.taksoninNro,
    this.lahettajanro,
    this.hankintanumero,
    this.saapumispvm,
    required this.hankintanimi,
    this.millaisenaSaatu,
    this.lisatiedot,
    this.heimo,
    required this.coordinateX,
    required this.coordinateY,
  });

  /// Convenience getters for UI compatibility
  String get plantId => hankintaID.toString();
  String get plantName => hankintanimi;

  /// Parses JSON map into [HankintaPlant].
  /// Returns `null` if coordinate_x or coordinate_y cannot be parsed from the coordinates array.
  static HankintaPlant? fromJson(Map<String, dynamic> json) {
    final rawCoordinates = json['coordinates'];
    if (rawCoordinates is! List) return null;

    double? xVal;
    double? yVal;

    // Pattern to match "x <num> y <num>", case-insensitive
    final regExp = RegExp(
      r'x\s*([+-]?\d+(?:\.\d+)?)\s+y\s*([+-]?\d+(?:\.\d+)?)',
      caseSensitive: false,
    );

    for (final item in rawCoordinates) {
      if (item is String) {
        final match = regExp.firstMatch(item.trim());
        if (match != null) {
          final xStr = match.group(1);
          final yStr = match.group(2);
          if (xStr != null && yStr != null) {
            final parsedX = double.tryParse(xStr);
            final parsedY = double.tryParse(yStr);
            if (parsedX != null && parsedY != null) {
              xVal = parsedX;
              yVal = parsedY;
              break; // Retain the first valid coordinate pair found
            }
          }
        }
      }
    }

    // Exclude item if valid coordinate_x and coordinate_y are missing or invalid
    if (xVal == null || yVal == null) {
      return null;
    }

    return HankintaPlant(
      hankintaID: json['hankintaID'] is int ? json['hankintaID'] as int : int.tryParse(json['hankintaID']?.toString() ?? '0') ?? 0,
      taksoninNro: json['taksonin_nro'] as int?,
      lahettajanro: json['lahettajanro'] as int?,
      hankintanumero: json['hankintanumero'] as String?,
      saapumispvm: json['saapumispvm'] as String?,
      hankintanimi: (json['hankintanimi'] as String?)?.isNotEmpty == true ? json['hankintanimi'] as String : 'UNKNOWN PLANT',
      millaisenaSaatu: json['millaisena_saatu'] as String?,
      lisatiedot: json['lisatiedot'] as String?,
      heimo: json['heimo'] as String?,
      coordinateX: xVal,
      coordinateY: yVal,
    );
  }
}

/// Paginated API response structure for coordinates endpoint
class HankintaPaginatedResponse {
  final List<HankintaPlant> items;
  final int total;
  final int page;
  final int pageSize;
  final int pages;

  const HankintaPaginatedResponse({
    required this.items,
    required this.total,
    required this.page,
    required this.pageSize,
    required this.pages,
  });

  factory HankintaPaginatedResponse.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    final List<HankintaPlant> plantList = [];

    if (rawItems is List) {
      for (final raw in rawItems) {
        if (raw is Map<String, dynamic>) {
          final parsed = HankintaPlant.fromJson(raw);
          if (parsed != null) {
            plantList.add(parsed);
          }
        }
      }
    }

    return HankintaPaginatedResponse(
      items: plantList,
      total: (json['total'] as num?)?.toInt() ?? plantList.length,
      page: (json['page'] as num?)?.toInt() ?? 1,
      pageSize: (json['page_size'] as num?)?.toInt() ?? 10,
      pages: (json['pages'] as num?)?.toInt() ?? 1,
    );
  }
}

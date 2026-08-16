import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:botanica_ar/models/hankinta_plant.dart';

/// Service to handle plant metadata and discovery queries from the remote API.
class PlantService {
  static const String _baseUrl =
      'https://web-database-six.vercel.app/api/hankintatiedot/coordinates';

  /// Fetches paginated plant items with valid parsed coordinates from the remote API.
  Future<HankintaPaginatedResponse> fetchPlantsWithCoordinates({
    int page = 1,
    int pageSize = 10,
  }) async {
    final uri = Uri.parse('$_baseUrl?page=$page&page_size=$pageSize');
    final response = await http.get(uri);

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = json.decode(response.body);
      return HankintaPaginatedResponse.fromJson(data);
    } else {
      throw Exception(
        'Failed to fetch plants coordinates. Status code: ${response.statusCode}',
      );
    }
  }

  /// Convenience method to fetch plants for backward compatibility or simple queries.
  Future<List<HankintaPlant>> fetchNearbyPlants({
    int page = 1,
    int pageSize = 10,
  }) async {
    final paginatedResult = await fetchPlantsWithCoordinates(
      page: page,
      pageSize: pageSize,
    );
    return paginatedResult.items;
  }
}

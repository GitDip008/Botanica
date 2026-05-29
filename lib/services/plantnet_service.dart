import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/plant_info.dart';

/// Raw result from PlantNet — keeps the confidence score so callers can
/// decide whether to trust it or fall back to a different identifier.
class PlantNetResult {
  final PlantInfo info;
  final double confidence; // 0.0–1.0
  const PlantNetResult({required this.info, required this.confidence});
}

/// Plant identification via the **PlantNet API** — free, designed specifically
/// for plants, and well-suited to European flora.
class PlantNetService {
  static const _baseUrl = 'https://my-api.plantnet.org/v2/identify/all';
  static String get _apiKey => ApiConfig.plantnetApiKey;

  /// Identifies a plant from an image. Returns the top match + confidence.
  Future<PlantNetResult> identifyPlant(
    Uint8List imageBytes, {
    String organs = 'auto',
  }) async {
    if (_apiKey.isEmpty || _apiKey == 'YOUR_PLANTNET_API_KEY_HERE') {
      throw Exception(
        'PlantNet API key not configured. Add it to api_config.dart',
      );
    }

    final uri = Uri.parse('$_baseUrl?api-key=$_apiKey&lang=en');
    final request = http.MultipartRequest('POST', uri)
      ..files.add(http.MultipartFile.fromBytes(
        'images',
        imageBytes,
        filename: 'plant.jpg',
      ))
      ..fields['organs'] = organs;

    final streamed = await request.send().timeout(const Duration(seconds: 30));
    final response = await http.Response.fromStream(streamed);

    if (response.statusCode != 200) {
      if (response.statusCode == 404) {
        return PlantNetResult(
          confidence: 0,
          info: PlantInfo(
            scientificName: 'Unknown',
            commonName: 'Not a plant',
            family: 'N/A',
            description: 'No plant detected in this image.',
            isPlant: false,
          ),
        );
      }
      throw Exception(
        'PlantNet API error ${response.statusCode}: ${response.body}',
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final results = data['results'] as List?;
    if (results == null || results.isEmpty) {
      return PlantNetResult(
        confidence: 0,
        info: PlantInfo(
          scientificName: 'Unknown',
          commonName: 'Not a plant',
          family: 'N/A',
          description: 'No matches found.',
          isPlant: false,
        ),
      );
    }

    final top = results.first as Map<String, dynamic>;
    final species = top['species'] as Map<String, dynamic>;
    final family = species['family'] as Map<String, dynamic>?;
    final commonNames = species['commonNames'] as List?;
    final score = (top['score'] as num?)?.toDouble() ?? 0;

    final scientificName =
        species['scientificNameWithoutAuthor'] as String? ?? 'Unknown';
    final commonName = (commonNames != null && commonNames.isNotEmpty)
        ? commonNames.first as String
        : scientificName;
    final familyName =
        family?['scientificNameWithoutAuthor'] as String? ?? 'Unknown';

    return PlantNetResult(
      confidence: score,
      info: PlantInfo(
        scientificName: scientificName,
        commonName: commonName,
        family: familyName,
        description: '', // filled in by orchestrator from Groq/Gemini
        isPlant: true,
      ),
    );
  }
}

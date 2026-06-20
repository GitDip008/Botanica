import 'dart:convert';
import 'dart:typed_data';
import 'package:cloud_functions/cloud_functions.dart';
import '../models/plant_info.dart';

/// Raw result from PlantNet — keeps the confidence score so callers can
/// decide whether to trust it or fall back to a different identifier.
class PlantNetResult {
  final PlantInfo info;
  final double confidence; // 0.0–1.0
  const PlantNetResult({required this.info, required this.confidence});
}

/// Plant identification via the **PlantNet API**, proxied through the
/// `plantnetIdentify` Cloud Function so the API key never ships in the APK.
class PlantNetService {
  final FirebaseFunctions _functions =
      FirebaseFunctions.instanceFor(region: 'europe-north1');

  static const _notPlant = PlantNetResult(
    confidence: 0,
    info: PlantInfo(
      scientificName: 'Unknown',
      commonName: 'Not a plant',
      family: 'N/A',
      description: 'No plant detected in this image.',
      isPlant: false,
    ),
  );

  /// Identifies a plant from an image. Returns the top match + confidence.
  Future<PlantNetResult> identifyPlant(
    Uint8List imageBytes, {
    String organs = 'auto',
    String lang = 'en',
  }) async {
    final callable = _functions.httpsCallable(
      'plantnetIdentify',
      options: HttpsCallableOptions(timeout: const Duration(seconds: 40)),
    );

    final result = await callable.call<Map<String, dynamic>>({
      'imageBase64': base64Encode(imageBytes),
      'organs': organs,
      'lang': lang,
    });

    final payload = result.data;
    if (payload['notFound'] == true) return _notPlant;

    final data = Map<String, dynamic>.from(payload['data'] as Map? ?? const {});
    final results = data['results'] as List?;
    if (results == null || results.isEmpty) {
      return const PlantNetResult(
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

    final top = Map<String, dynamic>.from(results.first as Map);
    final species = Map<String, dynamic>.from(top['species'] as Map);
    final family = species['family'] as Map?;
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

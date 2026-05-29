import 'dart:typed_data';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../models/plant_info.dart';
import '../config/api_config.dart';

class GeminiService {
  static const _apiKey = ApiConfig.geminiApiKey;

  late final GenerativeModel _visionModel;
  late final GenerativeModel _chatModel;
  ChatSession? _chatSession;

  GeminiService() {
    _visionModel = GenerativeModel(model: 'gemini-2.5-flash', apiKey: _apiKey);
    _chatModel = GenerativeModel(model: 'gemini-2.5-flash', apiKey: _apiKey);
  }

  Future<PlantInfo> identifyPlant(Uint8List imageBytes) async {
    const prompt = '''Identify the plant in this image. Respond ONLY in this exact format:
SCIENTIFIC_NAME: [scientific name]
COMMON_NAME: [common name]
FAMILY: [plant family]
DESCRIPTION: [2-3 sentence description of the plant, its characteristics, and uses]

If there is no plant in the image, respond with:
SCIENTIFIC_NAME: Unknown
COMMON_NAME: Not a plant
FAMILY: N/A
DESCRIPTION: No plant detected in this image.''';

    final content = Content.multi([
      DataPart('image/jpeg', imageBytes),
      TextPart(prompt),
    ]);

    final response = await _visionModel.generateContent([content]);
    final text = response.text ?? '';
    final info = _parsePlantInfo(text);

    _chatSession = _chatModel.startChat(history: [
      Content.text(
          'I found a plant: ${info.commonName} (${info.scientificName}), '
          'family ${info.family}. ${info.description}'),
      Content('model', [
        TextPart(
            'I can see you found a ${info.commonName} (${info.scientificName}). '
            'I\'m ready to answer any questions you have about this plant!'),
      ]),
    ]);

    return info;
  }

  PlantInfo _parsePlantInfo(String text) {
    String extract(String key) {
      final regex = RegExp('$key:\\s*(.+)', caseSensitive: false);
      return regex.firstMatch(text)?.group(1)?.trim() ?? 'Unknown';
    }

    final scientificName = extract('SCIENTIFIC_NAME');
    return PlantInfo(
      scientificName: scientificName,
      commonName: extract('COMMON_NAME'),
      family: extract('FAMILY'),
      description: extract('DESCRIPTION'),
      isPlant: scientificName != 'Unknown',
    );
  }

  Future<String> sendChatMessage(String message) async {
    if (_chatSession == null) return 'Please identify a plant first.';
    final response = await _chatSession!.sendMessage(Content.text(message));
    return response.text ?? 'No response';
  }

  /// Pre-seeds chat session from an already-known PlantInfo (used by Search).
  Future<void> identifyPlantFromInfo(PlantInfo info) async {
    _chatSession = _chatModel.startChat(history: [
      Content.text(
          'I found a plant: ${info.commonName} (${info.scientificName}), '
          'family ${info.family}. ${info.description}'),
      Content('model', [
        TextPart(
            'I can see you found a ${info.commonName} (${info.scientificName}). '
            'I\'m ready to answer any questions you have about this plant!'),
      ]),
    ]);
  }

  void reset() => _chatSession = null;
}

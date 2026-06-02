import 'dart:typed_data';
import '../models/plant_info.dart';
import 'gemini_proxy.dart';

/// Gemini-backed plant identification + chat continuation.
///
/// All calls go through the `geminiCall` Cloud Function so the API key never
/// ships in the client APK. The chat history is kept locally and replayed
/// to Gemini each turn (Gemini is stateless from our perspective now).
class GeminiService {
  PlantInfo? _currentPlant;
  final List<({String role, String text})> _history = [];

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

    final text = await GeminiProxy.instance.vision(
      prompt: prompt,
      imageBytes: imageBytes,
      model: 'gemini-2.5-flash',
    );
    final info = _parsePlantInfo(text);
    _seedHistory(info);
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

  void _seedHistory(PlantInfo info) {
    _currentPlant = info;
    _history
      ..clear()
      ..add((
        role: 'user',
        text:
            'I found a plant: ${info.commonName} (${info.scientificName}), family ${info.family}. ${info.description}'
      ))
      ..add((
        role: 'model',
        text:
            'I can see you found a ${info.commonName} (${info.scientificName}). I\'m ready to answer any questions you have about this plant!'
      ));
  }

  Future<String> sendChatMessage(String message) async {
    if (_currentPlant == null) return 'Please identify a plant first.';
    _history.add((role: 'user', text: message));
    // Flatten history into a single rolling-prompt string. Gemini's stateless
    // generateContent API is good enough for these short conversations.
    final buf = StringBuffer();
    for (final m in _history) {
      buf.writeln('${m.role.toUpperCase()}: ${m.text}');
    }
    buf.write('MODEL:');
    final reply = await GeminiProxy.instance.text(
      prompt: buf.toString(),
      model: 'gemini-2.5-flash',
    );
    final cleaned = reply.isEmpty ? 'No response' : reply;
    _history.add((role: 'model', text: cleaned));
    return cleaned;
  }

  /// Pre-seeds chat session from an already-known PlantInfo (used by Search).
  Future<void> identifyPlantFromInfo(PlantInfo info) async {
    _seedHistory(info);
  }

  void reset() {
    _currentPlant = null;
    _history.clear();
  }
}

import 'dart:convert';
import 'dart:typed_data';
import 'package:cloud_functions/cloud_functions.dart';

/// Thin wrapper around the `geminiCall` Cloud Function so the Gemini API key
/// never has to ship in the APK. Use this in place of any direct
/// `GenerativeModel(...)` instantiation.
class GeminiProxy {
  GeminiProxy._();
  static final GeminiProxy instance = GeminiProxy._();

  final FirebaseFunctions _functions =
      FirebaseFunctions.instanceFor(region: 'europe-north1');

  /// Plain text completion (e.g. bloom calendar, search summaries).
  Future<String> text({
    required String prompt,
    String model = 'gemini-2.0-flash',
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final callable = _functions.httpsCallable(
      'geminiCall',
      options: HttpsCallableOptions(timeout: timeout),
    );
    final result = await callable.call<Map<String, dynamic>>({
      'prompt': prompt,
      'model': model,
    });
    return (result.data['reply'] as String? ?? '').trim();
  }

  /// Vision + text — pass image bytes (jpeg/png).
  Future<String> vision({
    required String prompt,
    required Uint8List imageBytes,
    String model = 'gemini-2.0-flash',
    String mimeType = 'image/jpeg',
    Duration timeout = const Duration(seconds: 45),
  }) async {
    final callable = _functions.httpsCallable(
      'geminiCall',
      options: HttpsCallableOptions(timeout: timeout),
    );
    final result = await callable.call<Map<String, dynamic>>({
      'prompt': prompt,
      'model': model,
      'imageBase64': base64Encode(imageBytes),
      'mimeType': mimeType,
    });
    return (result.data['reply'] as String? ?? '').trim();
  }
}

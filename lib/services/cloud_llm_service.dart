import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import '../config/api_config.dart';
import '../models/plant_info.dart';
import 'plant_identification_service.dart' show stripMarkdown;

/// Thrown when the cloud LLM returns a non-200 response.
class CloudLLMException implements Exception {
  final String message;
  const CloudLLMException(this.message);
  @override
  String toString() => message;
}

/// Thrown specifically on HTTP 429 (rate limit).
class CloudLLMRateLimitException extends CloudLLMException {
  const CloudLLMRateLimitException(super.message);
}

/// Cloud-hosted LLM via any OpenAI-compatible endpoint.
///
/// Works out of the box with:
///   • Groq         — `https://api.groq.com/openai/v1`  (recommended, free tier)
///   • OpenRouter   — `https://openrouter.ai/api/v1`
///   • Ollama       — `http://your-server:11434/v1`  (self-hosted)
///   • LiteLLM/vLLM — `http://your-server:8000/v1`
///   • Together.ai  — `https://api.together.xyz/v1`
///
/// Configure `baseUrl`, `apiKey`, and `model` in [ApiConfig].
class CloudLLMService {
  // Region must match the deployed Cloud Functions region.
  final FirebaseFunctions _functions =
      FirebaseFunctions.instanceFor(region: 'europe-north1');

  String get _model => ApiConfig.cloudLlmModel;

  // Always "configured" now — the API key lives server-side. We only fall
  // back to Gemini if the proxy call itself fails.
  bool get isConfigured => true;

  /// Per-plant conversation history.
  final List<Map<String, String>> _messages = [];

  /// Re-seeds context for a resumed chat with full message history so the
  /// LLM has memory of the previous conversation.
  void seedPlantContextWithHistory(
    PlantInfo info,
    List<({String text, bool isUser})> history,
  ) {
    seedPlantContext(info);
    for (final m in history) {
      _messages.add({
        'role': m.isUser ? 'user' : 'assistant',
        'content': m.text,
      });
    }
  }

  /// Seeds context for the identified plant. Call before sending chat messages.
  void seedPlantContext(PlantInfo info) {
    _messages.clear();
    _messages.add({
      'role': 'system',
      'content':
          'You are a friendly botanical assistant for Oulu Botanical Garden. '
              'The visitor just identified: ${info.commonName} '
              '(${info.scientificName}), family ${info.family}. '
              '${info.description}\n\n'
              '🚫 SCOPE RESTRICTION (most important rule):\n'
              'You ONLY answer questions related to the botanical world — plants, trees, flowers, '
              'mosses, fungi, gardening, horticulture, plant care, plant biology, plant-related ecology, '
              'pollinators, small garden insects, plant pests/diseases, herbal uses, foraging safety, '
              'plant history, botanists, this specific garden and its sections. '
              'If the visitor asks about ANY unrelated topic (sports, politics, news, programming, '
              'cooking unrelated to plants, math, general celebrities, world events, personal advice, etc.), '
              'POLITELY DECLINE in 1-2 sentences and offer to help with botanical questions instead. '
              'Example: "I can only help with botanical questions — plants, gardens, gardening. '
              'Is there anything about this plant I can help you with?" '
              'Adapt the decline to the user\'s language.\n\n'
              'Respond in the same language the visitor uses.\n\n'
              'RESPONSE LENGTH RULES (only for in-scope questions):\n'
              '• Simple factual questions → 1-3 sentences\n'
              '• How-to questions (recipes from plants, care, propagation, processes) → as detailed as needed, use numbered steps\n'
              '• Comparison or "why" questions → 2-5 sentences with clear reasoning\n\n'
              'FORMATTING: Simple markdown only — numbered lists, **bold**, line breaks. No code blocks or tables.\n\n'
              'TONE: Warm, knowledgeable, focused. Skip filler intros — go straight to the answer.',
    });
  }

  /// Sends a user message and returns the assistant's reply.
  ///
  /// Calls the `groqChat` Cloud Function so the Groq API key never ships in
  /// the APK. Requires the user to be signed in (Firebase Auth).
  Future<String> sendMessage(String userMessage) async {
    _messages.add({'role': 'user', 'content': userMessage});
    try {
      final callable = _functions.httpsCallable(
        'groqChat',
        options:
            HttpsCallableOptions(timeout: const Duration(seconds: 30)),
      );
      final result = await callable.call<Map<String, dynamic>>({
        'messages': _trimmedMessages(),
        'model': _model,
        'temperature': 0.7,
        'maxTokens': 600,
      });
      final reply = (result.data['reply'] as String? ?? '').trim();
      if (reply.isEmpty) {
        throw const CloudLLMException('Empty reply from chat service.');
      }
      _messages.add({'role': 'assistant', 'content': reply});
      return reply;
    } on FirebaseFunctionsException catch (e) {
      debugPrint('[CloudLLM] groqChat ${e.code}: ${e.message}');
      if (e.code == 'resource-exhausted') {
        throw const CloudLLMRateLimitException(
            'Too many requests — wait a few seconds and try again.');
      }
      throw CloudLLMException(
          'Chat service error (${e.code}). Try again shortly.');
    }
  }

  void reset() => _messages.clear();

  /// Keeps the system message + last 12 turns. Prevents history bloat from
  /// pushing us over Groq's free-tier TPM limit (~15k tokens/minute).
  List<Map<String, String>> _trimmedMessages() {
    if (_messages.length <= 13) return _messages;
    final system = _messages.first; // role: system
    final recent = _messages.sublist(_messages.length - 12);
    return [system, ...recent];
  }

  /// One-shot completion — no conversation history. Used for search, bloom
  /// calendar, plant description generation, etc.
  ///
  /// Returns null on any failure so the caller can fall back to Gemini.
  Future<String?> completeText({
    required String systemPrompt,
    required String userPrompt,
    int maxTokens = 400,
    double temperature = 0.7,
  }) async {
    try {
      final callable = _functions.httpsCallable(
        'groqChat',
        options:
            HttpsCallableOptions(timeout: const Duration(seconds: 20)),
      );
      final result = await callable.call<Map<String, dynamic>>({
        'messages': [
          {'role': 'system', 'content': systemPrompt},
          {'role': 'user', 'content': userPrompt},
        ],
        'model': _model,
        'temperature': temperature,
        'maxTokens': maxTokens,
      });
      final raw = (result.data['reply'] as String? ?? '').trim();
      if (raw.isEmpty) return null;
      return stripMarkdown(raw);
    } catch (_) {
      return null;
    }
  }
}

import 'dart:convert';
import 'package:http/http.dart' as http;
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
  String get _baseUrl => ApiConfig.cloudLlmBaseUrl;
  String get _apiKey => ApiConfig.cloudLlmApiKey;
  String get _model => ApiConfig.cloudLlmModel;

  bool get isConfigured =>
      _baseUrl.isNotEmpty &&
      _apiKey.isNotEmpty &&
      _apiKey != 'YOUR_CLOUD_LLM_API_KEY_HERE';

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
  Future<String> sendMessage(String userMessage) async {
    if (!isConfigured) {
      throw StateError(
        'Cloud LLM not configured. Set cloudLlmApiKey in api_config.dart',
      );
    }

    _messages.add({'role': 'user', 'content': userMessage});

    final uri = Uri.parse('$_baseUrl/chat/completions');
    final response = await http
        .post(
          uri,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $_apiKey',
          },
          body: jsonEncode({
            'model': _model,
            // Cap history to last 12 messages (+ system) to avoid hitting
            // per-minute token limits on Groq's free tier.
            'messages': _trimmedMessages(),
            'temperature': 0.7,
            'max_tokens': 600,
          }),
        )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode != 200) {
      // Surface a useful error (debug logs + readable user message)
      final body = response.body;
      // ignore: avoid_print
      print('[CloudLLM] Groq error ${response.statusCode}: $body');
      if (response.statusCode == 429) {
        throw const CloudLLMRateLimitException(
            'Too many requests — wait a few seconds and try again.');
      }
      throw CloudLLMException(
        'Chat service error (${response.statusCode}). Try again shortly.',
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final choices = data['choices'] as List;
    final reply = (choices.first['message']['content'] as String).trim();

    _messages.add({'role': 'assistant', 'content': reply});
    return reply;
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
    if (!isConfigured) return null;
    try {
      final uri = Uri.parse('$_baseUrl/chat/completions');
      final response = await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $_apiKey',
            },
            body: jsonEncode({
              'model': _model,
              'messages': [
                {'role': 'system', 'content': systemPrompt},
                {'role': 'user', 'content': userPrompt},
              ],
              'temperature': temperature,
              'max_tokens': maxTokens,
            }),
          )
          .timeout(const Duration(seconds: 20));
      if (response.statusCode != 200) return null;
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final raw =
          (data['choices'][0]['message']['content'] as String).trim();
      return stripMarkdown(raw);
    } catch (_) {
      return null;
    }
  }
}

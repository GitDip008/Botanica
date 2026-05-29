// Copy this file to api_config.dart and add your real API keys.
class ApiConfig {
  /// Get a key at: https://aistudio.google.com/app/apikey
  static const geminiApiKey = 'YOUR_GEMINI_API_KEY_HERE';

  /// Optional — for free plant identification via PlantNet.
  /// Get a key at: https://my.plantnet.org → Profile → API
  static const plantnetApiKey = 'YOUR_PLANTNET_API_KEY_HERE';

  // ─── Cloud LLM (chat) ──
  /// OpenAI-compatible endpoint. Defaults to Groq's free tier.
  /// Get a free key at: https://console.groq.com/keys
  static const cloudLlmBaseUrl = 'https://api.groq.com/openai/v1';
  static const cloudLlmApiKey = 'YOUR_CLOUD_LLM_API_KEY_HERE';
  static const cloudLlmModel = 'gemma2-9b-it';

  /// OpenRouteService — free walking-directions API (2,000 req/day).
  /// Get a key at https://openrouteservice.org/dev/#/signup
  static const orsApiKey = 'YOUR_OPENROUTESERVICE_KEY_HERE';
}

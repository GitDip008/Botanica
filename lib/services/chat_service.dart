import 'auth_service.dart';
import 'chat_history_service.dart';
import 'cloud_llm_service.dart' show CloudLLMService, CloudLLMRateLimitException;
import 'gemini_service.dart';
import 'local_llm_service.dart';
import '../models/plant_info.dart';
import '../models/user_model.dart';

/// Smart routing for chat — tries engines in cost-order, with tier-aware
/// retry & messaging.
///
///   Free      → 10 chat limit/day (enforced), basic "wait a moment" message
///   Premium   → no daily limit, polished retry message
///   Admin/Pro → no limits, auto-retry on rate limit, silent recovery
class ChatService {
  ChatService._();
  static final ChatService instance = ChatService._();

  final CloudLLMService _cloud = CloudLLMService();
  final LocalLLMService _local = LocalLLMService();
  final GeminiService _gemini = GeminiService();

  /// Set by UserState whenever the signed-in user changes. Lets the service
  /// adapt routing & error messages to the user's tier.
  AppUser? _currentUser;
  // ignore: use_setters_to_change_properties
  void setUser(AppUser? user) => _currentUser = user;

  CloudLLMService get cloud => _cloud;
  LocalLLMService get local => _local;
  GeminiService get gemini => _gemini;

  bool get isUsingCloud => _cloud.isConfigured;
  bool get isUsingLocal => !_cloud.isConfigured && _local.isReady;

  String get activeEngine {
    if (_cloud.isConfigured) return 'Cloud (Groq · Llama 3.3 70B)';
    if (_local.isReady) return 'On-device (Gemma)';
    return 'Gemini';
  }

  Future<void> tryInitLocal() async {
    if (_local.isReady || _local.isDownloading) return;
    try {
      await _local.installAndInitialize();
    } catch (_) {}
  }

  Future<void> seedPlantContext(PlantInfo info, {String? userPhotoPath}) async {
    _cloud.seedPlantContext(info);
    if (_local.isReady) {
      try {
        await _local.seedPlantContext(
          commonName: info.commonName,
          scientificName: info.scientificName,
          family: info.family,
          description: info.description,
        );
      } catch (_) {}
    }
    await _gemini.identifyPlantFromInfo(info);
    // Start a persisted chat session — accessible later via ChatHistoryScreen.
    await ChatHistoryService.instance
        .startSession(plant: info, userPhotoPath: userPhotoPath);
  }

  /// Special error message returned when free user has run out of daily chats.
  static const String chatLimitReachedMarker = '__CHAT_LIMIT_REACHED__';

  /// Sends a chat message with tier-aware retry behaviour.
  /// Daily limit logic for free users:
  ///   • A "chat" = unique conversation session
  ///   • Free tier can use up to 10 distinct chats per day
  ///   • Same chat used multiple times in one day = still 1 against quota
  Future<String> sendMessage(String message) async {
    final access = _currentUser?.access ?? EffectiveAccess.free;
    final sessionId = ChatHistoryService.instance.current?.id ?? '';

    // ── Daily limit gate (free users, new-chat case) ─────────────────
    if (access == EffectiveAccess.free && _currentUser != null) {
      if (!_currentUser!.canChatInSession(sessionId)) {
        return chatLimitReachedMarker;
      }
    }

    // If this is a fresh "General botany" chat, name it after the first
    // message topic so it's identifiable in the history list.
    final current = ChatHistoryService.instance.current;
    if (current != null &&
        current.messages.isEmpty &&
        current.plantScientificName == 'Botanica') {
      var title = message.trim();
      if (title.length > 40) title = '${title.substring(0, 40).trimRight()}…';
      await ChatHistoryService.instance.setName(current.id, title);
    }

    // Persist the user's message immediately (regardless of reply success)
    await ChatHistoryService.instance
        .appendMessage(text: message, isUser: true);

    Object? cloudError;

    // 1. Try cloud (Groq) — with retry for admin/premium
    if (_cloud.isConfigured) {
      final maxAttempts = (access == EffectiveAccess.adminPro) ? 3 : 1;
      for (var attempt = 0; attempt < maxAttempts; attempt++) {
        try {
          final reply = await _cloud.sendMessage(message);
          return _finalize(reply, access);
        } catch (e) {
          cloudError = e;
          if (e is CloudLLMRateLimitException && attempt + 1 < maxAttempts) {
            await Future.delayed(Duration(milliseconds: 800 * (attempt + 1)));
            continue;
          }
          // ignore: avoid_print
          print('[ChatService] Cloud LLM failed (attempt ${attempt + 1}): $e');
          break;
        }
      }
    }

    // 2. Try on-device Gemma
    if (_local.isReady) {
      try {
        return _finalize(await _local.sendMessage(message), access);
      } catch (e) {
        // ignore: avoid_print
        print('[ChatService] Local LLM failed: $e');
      }
    }

    // 3. Gemini fallback — only for admin/premium or hybrid users.
    final shouldUseGemini = access != EffectiveAccess.free || _local.isReady;
    if (shouldUseGemini) {
      try {
        return _finalize(await _gemini.sendChatMessage(message), access);
      } catch (_) {}
    }

    // ── All engines exhausted — tier-specific friendly message ─────────
    final err = _errorMessageForTier(access, cloudError);
    await ChatHistoryService.instance.appendMessage(text: err, isUser: false);
    return err;
  }

  /// On successful reply: save to history + increment usage counter for all
  /// users (free tier sees a limit, premium/admin see the count for info).
  String _finalize(String reply, EffectiveAccess access) {
    ChatHistoryService.instance.appendMessage(text: reply, isUser: false);
    final sessionId = ChatHistoryService.instance.current?.id ?? '';
    if (sessionId.isNotEmpty) {
      AuthService.instance.incrementChatUsage(sessionId);
    }
    return reply;
  }

  String _errorMessageForTier(EffectiveAccess access, Object? cloudError) {
    switch (access) {
      case EffectiveAccess.adminPro:
        return "Service is briefly unavailable. Please try again — your request is on the priority queue. 🌿";
      case EffectiveAccess.premium:
        if (cloudError is CloudLLMRateLimitException) {
          return "Service is busy — retrying… please ask again in a few seconds.";
        }
        return "Chat is briefly unavailable. We're on it — try again shortly.";
      case EffectiveAccess.free:
        if (cloudError is CloudLLMRateLimitException) {
          return "Too many people are chatting right now — wait a few seconds and try again.\n\nUpgrade to Premium for priority access. 🌿";
        }
        return "Chat is temporarily unavailable. Try again in a moment.\n\nUpgrade to Premium for the smoothest experience.";
    }
  }

  void reset() {
    _cloud.reset();
    _local.close();
    _gemini.reset();
  }
}

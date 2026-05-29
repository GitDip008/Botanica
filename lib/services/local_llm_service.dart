import 'dart:async';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:flutter_gemma/core/chat.dart';
import 'package:flutter_gemma/core/model.dart';

/// On-device chat AI powered by Gemma via MediaPipe.
///
/// The model is large (~530MB) and must be downloaded once on first use.
/// After that, all inference happens locally — zero API calls, zero per-token cost.
class LocalLLMService {
  static const _modelUrl =
      'https://huggingface.co/litert-community/Gemma3-1B-IT/resolve/main/gemma3-1b-it-int4.task';

  InferenceModel? _model;
  InferenceChat? _chat;
  bool _ready = false;
  bool _downloading = false;

  bool get isReady => _ready;
  bool get isDownloading => _downloading;

  /// True if the model file has already been downloaded and is on disk.
  Future<bool> isModelInstalled() async {
    try {
      final mgr = FlutterGemmaPlugin.instance.modelManager;
      return await mgr.isModelInstalled;
    } catch (_) {
      return false;
    }
  }

  /// Downloads the model (~530MB) and initializes inference. Call once.
  Future<void> installAndInitialize() async {
    if (_downloading || _ready) return;
    _downloading = true;
    try {
      final mgr = FlutterGemmaPlugin.instance.modelManager;
      if (!await mgr.isModelInstalled) {
        await mgr.downloadModelFromNetwork(_modelUrl);
      }
      _model = await FlutterGemmaPlugin.instance.createModel(
        modelType: ModelType.gemmaIt,
        maxTokens: 512,
      );
      _chat = await _model!.createChat(
        temperature: 0.8,
        randomSeed: 1,
        topK: 1,
      );
      _ready = true;
    } finally {
      _downloading = false;
    }
  }

  /// Sends a chat message and returns the full response text.
  Future<String> sendMessage(String message) async {
    if (!_ready || _chat == null) {
      throw StateError('Local LLM not initialized. Call installAndInitialize() first.');
    }
    await _chat!.addQueryChunk(Message(text: message, isUser: true));
    return await _chat!.generateChatResponse();
  }

  /// Streams the response token-by-token (better UX for long answers).
  Stream<String> streamMessage(String message) async* {
    if (!_ready || _chat == null) {
      throw StateError('Local LLM not initialized.');
    }
    await _chat!.addQueryChunk(Message(text: message, isUser: true));
    yield* _chat!.generateChatResponseAsync();
  }

  /// Seeds the chat with botanical context for the identified plant.
  Future<void> seedPlantContext({
    required String commonName,
    required String scientificName,
    required String family,
    String? description,
  }) async {
    if (!_ready || _model == null) return;
    _chat = await _model!.createChat(
      temperature: 0.8,
      randomSeed: 1,
      topK: 1,
    );
    final seed = 'You are a friendly, knowledgeable botanical assistant for '
        'Oulu Botanical Garden. The visitor just identified: $commonName '
        '($scientificName), family $family. '
        '${description ?? ''} '
        'Answer follow-up questions about this plant — its care, history, '
        'uses, native range, and interesting facts. Keep responses concise '
        '(2–4 sentences) and engaging.';
    await _chat!.addQueryChunk(Message(text: seed, isUser: true));
    await _chat!.generateChatResponse(); // Discard the seed acknowledgement
  }

  /// Frees model resources.
  Future<void> close() async {
    try {
      await _model?.close();
    } catch (_) {}
    _chat = null;
    _model = null;
    _ready = false;
  }
}

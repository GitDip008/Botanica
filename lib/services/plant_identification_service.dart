import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/plant_info.dart';
import 'gemini_service.dart';
import 'language_service.dart';
import 'plantnet_service.dart';
import 'wikipedia_image_service.dart';

/// Result of a Plant Hunt validation attempt.
class HuntValidationResult {
  final bool isCorrect;
  final String feedback;
  final String? detectedName;
  const HuntValidationResult({
    required this.isCorrect,
    required this.feedback,
    this.detectedName,
  });
}

/// Orchestrates the cheapest accurate plant identification flow:
///
///   1. **PlantNet** identifies the plant (free, plant-specialized)
///   2. If confidence ≥ 30%  → enrich description via Groq (free)
///   3. If confidence < 30%  → fall back to Gemini (paid but accurate)
///   4. If PlantNet fails    → also fall back to Gemini
///
/// Result is the same [PlantInfo] shape the rest of the app uses.
class PlantIdentificationService {
  PlantIdentificationService._();
  static final PlantIdentificationService instance =
      PlantIdentificationService._();

  /// Minimum PlantNet confidence to trust its identification.
  /// Below this, we use Gemini multimodal for a second opinion.
  static const _confidenceThreshold = 0.30;

  final PlantNetService _plantnet = PlantNetService();
  final GeminiService _gemini = GeminiService();

  Future<PlantInfo> identify(Uint8List imageBytes, {String organs = 'auto'}) async {
    // ── 1. Try PlantNet (free) ──────────────────────────────────────────
    PlantNetResult? plantnet;
    try {
      plantnet = await _plantnet.identifyPlant(imageBytes, organs: organs);
    } catch (_) {/* fall through to Gemini */}

    // ── 2. PlantNet returned a plant WITH high confidence → trust it ────
    if (plantnet != null &&
        plantnet.info.isPlant &&
        plantnet.confidence >= _confidenceThreshold) {
      return _enrichPlantNetResult(plantnet);
    }

    // ── 3. PlantNet failed / low confidence / no plant → DEFER TO GEMINI
    // Gemini is the authority here, including for "not a plant" verdicts.
    // We do NOT fall back to PlantNet's low-confidence guess — that's the bug
    // that caused tables to be identified as plants at 1% confidence.
    try {
      final geminiInfo = await _gemini.identifyPlant(imageBytes);
      return await _attachImage(geminiInfo); // attach Wikipedia photo if any
    } catch (_) {
      return const PlantInfo(
        scientificName: 'Unknown',
        commonName: 'Could not identify',
        family: 'N/A',
        description:
            'No plant detected in this image. Try a clearer, closer photo of a leaf, flower, or fruit.',
        isPlant: false,
      );
    }
  }

  /// Attaches a Wikipedia reference image to the identified plant.
  Future<PlantInfo> _attachImage(PlantInfo info) async {
    if (!info.isPlant) return info;
    if (info.imageUrl != null) return info;
    try {
      final url = await WikipediaImageService.instance.findImage(
        scientificName: info.scientificName,
        commonName: info.commonName,
      );
      return url == null ? info : info.copyWith(imageUrl: url);
    } catch (_) {
      return info;
    }
  }

  /// Public helper — used by search to enrich a text-only lookup with an image.
  Future<PlantInfo> attachImage(PlantInfo info) => _attachImage(info);

  /// Generates a rich botanical description for a PlantNet-identified species,
  /// using Groq (free). Falls back to Gemini if Groq is unconfigured/fails.
  Future<PlantInfo> _enrichPlantNetResult(PlantNetResult result) async {
    final base = result.info;
    final confidencePct = (result.confidence * 100).toStringAsFixed(0);

    // Try Groq first
    String? description = await _describeViaCloudLLM(base);

    // Fallback: Gemini text-only description
    description ??= await _describeViaGemini(base);

    // Final safety net — at least show *something* useful
    description ??=
        '${base.commonName} (${base.scientificName}) is a member of the ${base.family} family.';

    // Append the confidence subtly if it's worth mentioning
    final isUncertain = result.confidence < 0.6;
    final finalDesc = isUncertain
        ? '$description\n\nIdentification confidence: $confidencePct%.'
        : description;

    final enriched = PlantInfo(
      scientificName: base.scientificName,
      commonName: base.commonName,
      family: base.family,
      description: finalDesc,
      isPlant: true,
    );
    return _attachImage(enriched);
  }

  /// Groq description (free). Returns null on any failure.
  Future<String?> _describeViaCloudLLM(PlantInfo base) async {
    final key = ApiConfig.cloudLlmApiKey;
    if (key.isEmpty || key == 'YOUR_CLOUD_LLM_API_KEY_HERE') return null;

    final lang = LanguageService.instance.current.llmName;
    final userPrompt =
        'Write a 3-4 sentence engaging botanical description of ${base.commonName} '
        '(${base.scientificName}), family ${base.family}. Cover what it looks like, '
        'where it grows naturally, and one interesting or unique fact about it. '
        'Respond ENTIRELY in $lang. '
        'Plain text only — no markdown, no headings, no bullet points. '
        'Start directly with the description, no preamble.';

    try {
      final uri = Uri.parse('${ApiConfig.cloudLlmBaseUrl}/chat/completions');
      final res = await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $key',
            },
            body: jsonEncode({
              'model': ApiConfig.cloudLlmModel,
              'messages': [
                {
                  'role': 'system',
                  'content':
                      'You are a botanical educator writing for a botanical garden app. Plain prose only — no markdown formatting (no **, *, #, -, etc.).',
                },
                {'role': 'user', 'content': userPrompt},
              ],
              'temperature': 0.7,
              'max_tokens': 220,
            }),
          )
          .timeout(const Duration(seconds: 20));
      if (res.statusCode != 200) return null;
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final text =
          (data['choices'][0]['message']['content'] as String).trim();
      return _stripMarkdown(text);
    } catch (_) {
      return null;
    }
  }

  /// Gemini description (paid, fallback). Returns null on failure.
  Future<String?> _describeViaGemini(PlantInfo base) async {
    try {
      // Reuse the existing service — it has the model configured already.
      // We send a small text prompt asking for description only.
      final session = _gemini;
      await session.identifyPlantFromInfo(base); // seeds context
      final reply = await session.sendChatMessage(
        'Give a 3-4 sentence engaging description of this plant — appearance, native range, '
        'and one interesting fact. Plain text only, no markdown.',
      );
      return _stripMarkdown(reply);
    } catch (_) {
      return null;
    }
  }

  // ─── Plant Hunt validation ──────────────────────────────────────────────
  Future<HuntValidationResult> validateHunt({
    required Uint8List imageBytes,
    required String targetCommonName,
    required String targetScientific,
    required String targetFamily,
  }) async {
    try {
      final result =
          await _plantnet.identifyPlant(imageBytes, organs: 'auto');
      if (!result.info.isPlant) {
        return const HuntValidationResult(
          isCorrect: false,
          feedback: "Hmm, can't see a clear plant — try again with a closer photo!",
        );
      }

      // Low PlantNet confidence → defer to Gemini
      if (result.confidence < _confidenceThreshold) {
        return _huntFallbackGemini(
          imageBytes: imageBytes,
          targetCommonName: targetCommonName,
          targetScientific: targetScientific,
          targetFamily: targetFamily,
        );
      }

      final detected = result.info;
      final detectedSci = detected.scientificName.toLowerCase().trim();
      final detectedFam = detected.family.toLowerCase().trim();
      final targetSci = targetScientific.toLowerCase().trim();
      final targetFam = targetFamily.toLowerCase().trim();

      if (detectedSci.contains(targetSci) || targetSci.contains(detectedSci)) {
        return HuntValidationResult(
          isCorrect: true,
          feedback: "Perfect — you found the $targetCommonName! 🌿",
          detectedName: detected.commonName,
        );
      }

      if (detectedFam.isNotEmpty && detectedFam == targetFam) {
        return HuntValidationResult(
          isCorrect: true,
          feedback:
              "Great find! That's a ${detected.commonName} — same family as $targetCommonName.",
          detectedName: detected.commonName,
        );
      }

      return HuntValidationResult(
        isCorrect: false,
        feedback:
            "Not quite — that looks like a ${detected.commonName}. Keep searching!",
        detectedName: detected.commonName,
      );
    } catch (_) {
      return _huntFallbackGemini(
        imageBytes: imageBytes,
        targetCommonName: targetCommonName,
        targetScientific: targetScientific,
        targetFamily: targetFamily,
      );
    }
  }

  Future<HuntValidationResult> _huntFallbackGemini({
    required Uint8List imageBytes,
    required String targetCommonName,
    required String targetScientific,
    required String targetFamily,
  }) async {
    try {
      final detected = await _gemini.identifyPlant(imageBytes);
      if (!detected.isPlant) {
        return const HuntValidationResult(
          isCorrect: false,
          feedback: "Hmm, that doesn't look like a plant.",
        );
      }
      final sciMatch = detected.scientificName
              .toLowerCase()
              .contains(targetScientific.toLowerCase()) ||
          targetScientific
              .toLowerCase()
              .contains(detected.scientificName.toLowerCase());
      final famMatch =
          detected.family.toLowerCase() == targetFamily.toLowerCase();
      if (sciMatch || famMatch) {
        return HuntValidationResult(
          isCorrect: true,
          feedback: "Nice find! You're on the right track. 🌿",
          detectedName: detected.commonName,
        );
      }
      return HuntValidationResult(
        isCorrect: false,
        feedback:
            "That looks like ${detected.commonName} — keep searching for $targetCommonName!",
        detectedName: detected.commonName,
      );
    } catch (_) {
      return const HuntValidationResult(
        isCorrect: false,
        feedback: 'Could not check right now — try again in a moment.',
      );
    }
  }
}

// ─── Markdown stripper (shared utility) ─────────────────────────────────────
String _stripMarkdown(String s) {
  return s
      // Code fences ``` ... ```
      .replaceAll(RegExp(r'```[a-zA-Z]*\n?'), '')
      .replaceAll('```', '')
      // Inline code `x`
      .replaceAllMapped(RegExp(r'`([^`]+)`'), (m) => m.group(1)!)
      // Bold **x** or __x__
      .replaceAllMapped(RegExp(r'\*\*([^*]+)\*\*'), (m) => m.group(1)!)
      .replaceAllMapped(RegExp(r'__([^_]+)__'), (m) => m.group(1)!)
      // Italic *x* or _x_
      .replaceAllMapped(RegExp(r'(?<![*_])\*([^*\n]+)\*(?![*_])'),
          (m) => m.group(1)!)
      .replaceAllMapped(
          RegExp(r'(?<![_*])_([^_\n]+)_(?![_*])'), (m) => m.group(1)!)
      // Headings ##
      .replaceAll(RegExp(r'^#+\s*', multiLine: true), '')
      // Bullet points
      .replaceAll(RegExp(r'^[-*+]\s+', multiLine: true), '• ')
      // Links [text](url)
      .replaceAllMapped(RegExp(r'\[([^\]]+)\]\([^)]+\)'), (m) => m.group(1)!)
      // Blockquotes >
      .replaceAll(RegExp(r'^>\s*', multiLine: true), '')
      // Horizontal rules ---
      .replaceAll(RegExp(r'^-{3,}$', multiLine: true), '')
      .trim();
}

/// Exposed for use elsewhere (chat replies).
String stripMarkdown(String s) => _stripMarkdown(s);

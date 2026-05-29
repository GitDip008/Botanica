import 'dart:convert';
import 'package:http/http.dart' as http;

/// Fetches plant images from Wikipedia's free REST API.
/// No API key required. Returns null if no image is found.
class WikipediaImageService {
  WikipediaImageService._();
  static final WikipediaImageService instance = WikipediaImageService._();

  // Tiny in-memory cache to avoid repeated lookups for the same plant.
  final Map<String, String?> _cache = {};

  /// Returns a high-quality image URL for the given plant, or null if none.
  /// Tries scientific name first (most accurate), then common name as fallback.
  Future<String?> findImage({
    required String scientificName,
    String? commonName,
  }) async {
    final keys = <String>[
      scientificName,
      if (commonName != null && commonName.isNotEmpty) commonName,
    ];

    for (final key in keys) {
      if (key.isEmpty || key.toLowerCase() == 'unknown') continue;
      final cached = _cache[key];
      if (cached != null) return cached;
      if (_cache.containsKey(key)) continue; // cached null

      final url = await _fetchOne(key);
      _cache[key] = url;
      if (url != null) return url;
    }
    return null;
  }

  Future<String?> _fetchOne(String pageTitle) async {
    final encoded = Uri.encodeComponent(pageTitle.replaceAll(' ', '_'));
    final uri = Uri.parse(
        'https://en.wikipedia.org/api/rest_v1/page/summary/$encoded');

    try {
      final res = await http
          .get(uri, headers: {'User-Agent': 'BotanicaApp/1.0'})
          .timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return null;
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      // Prefer original full-res image, fall back to thumbnail
      final original = data['originalimage'] as Map<String, dynamic>?;
      if (original != null) return original['source'] as String?;
      final thumb = data['thumbnail'] as Map<String, dynamic>?;
      return thumb?['source'] as String?;
    } catch (_) {
      return null;
    }
  }
}

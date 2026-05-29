import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../config/api_config.dart';
import '../services/chat_service.dart';

class BloomScreen extends StatefulWidget {
  const BloomScreen({super.key});

  @override
  State<BloomScreen> createState() => _BloomScreenState();
}

class _BloomScreenState extends State<BloomScreen> {
  static const _apiKey = ApiConfig.geminiApiKey;
  List<_BloomEntry> _entries = [];
  bool _loading = true;

  static const _sections = [
    'Ornamental', 'Fennoscandian Mountain', 'Woodlands',
    'Grasslands', 'Economic/Medicinal', 'Systematic',
    'Romeo Greenhouse (tropical)', 'Julia Greenhouse (Mediterranean)',
  ];

  @override
  void initState() {
    super.initState();
    _fetchBlooms();
  }

  Future<void> _fetchBlooms() async {
    setState(() { _loading = true; });
    try {
      final now = DateTime.now();
      final month = now.month;
      final monthName = _monthName(month);

      const systemPrompt =
          'You are a botanist at Oulu Botanical Garden in Finland (65°N latitude). '
          'Always respond with a JSON array only — no markdown, no commentary, no preamble.';
      final userPrompt =
          'List 8 plants that would realistically be blooming or at peak in $monthName at this garden. '
          'For each plant give exactly this JSON format:\n'
          '[\n'
          '  {"common": "Common Name", "scientific": "Scientific name", "section": "one of the section names", "color": "flower colour", "note": "one sentence why notable"}\n'
          ']\n'
          'Sections to choose from: ${_sections.join(', ')}. '
          'Only include realistic Finnish/subarctic plants for outdoor sections in $monthName.';

      // 1) Try Groq first (free, fast)
      String? text = await ChatService.instance.cloud.completeText(
        systemPrompt: systemPrompt,
        userPrompt: userPrompt,
        maxTokens: 800,
      );

      // 2) Fall back to Gemini if Groq fails / isn't configured
      if (text == null) {
        final model =
            GenerativeModel(model: 'gemini-2.0-flash', apiKey: _apiKey);
        final response = await model.generateContent(
            [Content.text('$systemPrompt\n\n$userPrompt')]);
        text = (response.text ?? '').trim();
      }

      // Parse JSON array from response
      final jsonStr = _extractJson(text);
      if (jsonStr != null) {
        final parsed = _parseEntries(jsonStr);
        setState(() { _entries = parsed; _loading = false; });
      } else {
        setState(() { _entries = _fallbackEntries(month); _loading = false; });
      }
    } catch (_) {
      final now = DateTime.now();
      setState(() { _entries = _fallbackEntries(now.month); _loading = false; });
    }
  }

  String _monthName(int m) => const [
    '', 'January', 'February', 'March', 'April', 'May',
    'June', 'July', 'August', 'September', 'October', 'November', 'December'
  ][m];

  String? _extractJson(String text) {
    final start = text.indexOf('[');
    final end = text.lastIndexOf(']');
    if (start != -1 && end != -1 && end > start) {
      return text.substring(start, end + 1);
    }
    return null;
  }

  List<_BloomEntry> _parseEntries(String json) {
    final entries = <_BloomEntry>[];
    // Simple manual parse for the structured JSON
    final regex = RegExp(
      r'"common"\s*:\s*"([^"]+)".*?"scientific"\s*:\s*"([^"]+)".*?"section"\s*:\s*"([^"]+)".*?"color"\s*:\s*"([^"]+)".*?"note"\s*:\s*"([^"]+)"',
      dotAll: true,
    );
    for (final m in regex.allMatches(json)) {
      entries.add(_BloomEntry(
        common: m.group(1) ?? '',
        scientific: m.group(2) ?? '',
        section: m.group(3) ?? '',
        color: m.group(4) ?? '',
        note: m.group(5) ?? '',
      ));
    }
    return entries;
  }

  List<_BloomEntry> _fallbackEntries(int month) => [
    _BloomEntry(common: 'Wood Anemone', scientific: 'Anemone nemorosa', section: 'Woodlands', color: 'White', note: 'One of the first spring bloomers in Finnish forests.'),
    _BloomEntry(common: 'Cowslip', scientific: 'Primula veris', section: 'Grasslands', color: 'Yellow', note: 'Classic meadow plant, now rare in the wild.'),
    _BloomEntry(common: 'May Lily', scientific: 'Maianthemum bifolium', section: 'Woodlands', color: 'White', note: 'Fragrant ground-cover of boreal forest floors.'),
    _BloomEntry(common: 'Tulips (mixed)', scientific: 'Tulipa sp.', section: 'Ornamental', color: 'Red/Yellow', note: 'Spring highlight of the ornamental beds.'),
    _BloomEntry(common: 'Lapland Rhododendron', scientific: 'Rhododendron lapponicum', section: 'Fennoscandian Mountain', color: 'Purple', note: 'Arctic shrub from Lapland mountain heaths.'),
    _BloomEntry(common: 'Valerian', scientific: 'Valeriana officinalis', section: 'Economic/Medicinal', color: 'Pink', note: 'Traditional sedative herb with fragrant flowers.'),
    _BloomEntry(common: 'Bird of Paradise', scientific: 'Strelitzia reginae', section: 'Romeo Greenhouse (tropical)', color: 'Orange/Blue', note: 'Tropical showpiece of Romeo greenhouse.'),
    _BloomEntry(common: 'Bougainvillea', scientific: 'Bougainvillea spectabilis', section: 'Julia Greenhouse (Mediterranean)', color: 'Magenta', note: 'Vivid climber thriving in Julia\'s warm dry conditions.'),
  ];

  Color _sectionColor(String section) {
    if (section.contains('Ornamental')) return const Color(0xFF880E4F);
    if (section.contains('Fennoscandian')) return const Color(0xFF546E7A);
    if (section.contains('Woodland')) return const Color(0xFF1B5E20);
    if (section.contains('Grassland')) return const Color(0xFF558B2F);
    if (section.contains('Economic') || section.contains('Medicinal')) return const Color(0xFFE65100);
    if (section.contains('Systematic')) return const Color(0xFF00695C);
    if (section.contains('Romeo')) return const Color(0xFF795548);
    if (section.contains('Julia')) return const Color(0xFF2E7D32);
    return const Color(0xFF2E7D32);
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return Scaffold(
      backgroundColor: const Color(0xFF0D1F14),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A2E1E),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF66BB6A)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('🌸 In Bloom Now',
            style: TextStyle(color: Color(0xFFE8F5E9), fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF66BB6A)),
            onPressed: _fetchBlooms,
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: const Color(0xFF1A2E1E),
            child: Row(
              children: [
                const Icon(Icons.calendar_today, color: Color(0xFF66BB6A), size: 16),
                const SizedBox(width: 8),
                Text(
                  '${_monthName(now.month)} ${now.year} · Oulu Botanical Garden',
                  style: const TextStyle(color: Color(0xFF66BB6A), fontSize: 13),
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(color: Color(0xFF66BB6A)),
                        SizedBox(height: 16),
                        Text('Checking what\'s blooming...',
                            style: TextStyle(color: Color(0xFF4CAF50))),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(14),
                    itemCount: _entries.length,
                    itemBuilder: (_, i) {
                      final e = _entries[i];
                      final sColor = _sectionColor(e.section);
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A2E1E),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: sColor.withOpacity(0.5)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 10,
                              height: 60,
                              decoration: BoxDecoration(
                                color: sColor,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(e.common,
                                            style: const TextStyle(
                                                color: Color(0xFFE8F5E9),
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14)),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: sColor.withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(e.color,
                                            style: TextStyle(
                                                color: sColor.withOpacity(0.9),
                                                fontSize: 10)),
                                      ),
                                    ],
                                  ),
                                  Text(e.scientific,
                                      style: const TextStyle(
                                          color: Color(0xFF66BB6A),
                                          fontSize: 12,
                                          fontStyle: FontStyle.italic)),
                                  const SizedBox(height: 4),
                                  Text(e.note,
                                      style: const TextStyle(
                                          color: Color(0xFFE8F5E9),
                                          fontSize: 12,
                                          height: 1.4)),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Icon(Icons.location_on,
                                          color: sColor, size: 12),
                                      const SizedBox(width: 4),
                                      Text(e.section,
                                          style: TextStyle(
                                              color: sColor, fontSize: 11)),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ).animate().slideX(begin: -0.2, duration: 350.ms, delay: Duration(milliseconds: i * 60));
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _BloomEntry {
  final String common;
  final String scientific;
  final String section;
  final String color;
  final String note;
  _BloomEntry({required this.common, required this.scientific, required this.section, required this.color, required this.note});
}

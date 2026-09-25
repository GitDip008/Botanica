import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../services/chat_service.dart';
import '../services/gemini_proxy.dart';
import '../services/language_service.dart';
import '../services/usage_tracking_service.dart';
import '../theme/tokens.dart';
import '../i18n/tr.dart';

class BloomScreen extends StatefulWidget {
  const BloomScreen({super.key});

  @override
  State<BloomScreen> createState() => _BloomScreenState();
}

class _BloomScreenState extends State<BloomScreen> {
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
    UsageTrackingService.instance.log(UsageTrackingService.featureBloom);
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
          'Only include realistic Finnish/subarctic plants for outdoor sections in $monthName. '
          'Write "common", "color" and "note" in ${trLanguageName()}; keep "section" exactly as listed.';

      // 1) Try Groq first (free, fast)
      String? text = await ChatService.instance.cloud.completeText(
        systemPrompt: systemPrompt,
        userPrompt: userPrompt,
        maxTokens: 800,
      );

      // 2) Fall back to Gemini (via Cloud Function proxy) if Groq fails
      if (text == null) {
        text = await GeminiProxy.instance.text(
          prompt: '$systemPrompt\n\n$userPrompt',
        );
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

  String _monthName(int m) => [
    '', tr('January'), tr('February'), tr('March'), tr('April'), tr('May'),
    tr('June'), tr('July'), tr('August'), tr('September'), tr('October'), tr('November'), tr('December')
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
    _BloomEntry(common: tr('Wood Anemone'), scientific: tr('Anemone nemorosa'), section: tr('Woodlands'), color: tr('White'), note: tr('One of the first spring bloomers in Finnish forests.')),
    _BloomEntry(common: tr('Cowslip'), scientific: tr('Primula veris'), section: tr('Grasslands'), color: tr('Yellow'), note: tr('Classic meadow plant, now rare in the wild.')),
    _BloomEntry(common: tr('May Lily'), scientific: tr('Maianthemum bifolium'), section: tr('Woodlands'), color: tr('White'), note: tr('Fragrant ground-cover of boreal forest floors.')),
    _BloomEntry(common: tr('Tulips (mixed)'), scientific: tr('Tulipa sp.'), section: 'Ornamental', color: 'Red/Yellow', note: tr('Spring highlight of the ornamental beds.')),
    _BloomEntry(common: tr('Lapland Rhododendron'), scientific: tr('Rhododendron lapponicum'), section: tr('Fennoscandian Mountain'), color: tr('Purple'), note: tr('Arctic shrub from Lapland mountain heaths.')),
    _BloomEntry(common: tr('Valerian'), scientific: tr('Valeriana officinalis'), section: 'Economic/Medicinal', color: tr('Pink'), note: tr('Traditional sedative herb with fragrant flowers.')),
    _BloomEntry(common: tr('Bird of Paradise'), scientific: tr('Strelitzia reginae'), section: tr('Romeo Greenhouse (tropical)'), color: 'Orange/Blue', note: tr('Tropical showpiece of Romeo greenhouse.')),
    _BloomEntry(common: tr('Bougainvillea'), scientific: tr('Bougainvillea spectabilis'), section: tr('Julia Greenhouse (Mediterranean)'), color: tr('Magenta'), note: tr('Vivid climber thriving in Julia\'s warm dry conditions.')),
  ];

  Color _sectionColor(String section) {
    if (section.contains('Ornamental')) return const Color(0xFF880E4F);
    if (section.contains('Fennoscandian')) return const Color(0xFF546E7A);
    if (section.contains('Woodland')) return C.accentDim;
    if (section.contains('Grassland')) return C.accentDim;
    if (section.contains('Economic') || section.contains('Medicinal')) return const Color(0xFFE65100);
    if (section.contains('Systematic')) return const Color(0xFF00695C);
    if (section.contains('Romeo')) return const Color(0xFF795548);
    if (section.contains('Julia')) return C.accentDim;
    return C.accentDim;
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final s = LanguageService.instance.strings;
    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(
        backgroundColor: C.surface,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: C.accent),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(s.inBloomTitle,
            style: const TextStyle(color: C.textHi, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: C.accent),
            onPressed: _fetchBlooms,
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: C.surface,
            child: Row(
              children: [
                const Icon(Icons.calendar_today, color: C.accent, size: 16),
                const SizedBox(width: 8),
                Text(
                  tr('{0} {1} · Oulu Botanical Garden', [_monthName(now.month), now.year]),
                  style: const TextStyle(color: C.accent, fontSize: 13),
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(color: C.accent),
                        const SizedBox(height: 16),
                        Text(s.checkingBlooms,
                            style: const TextStyle(color: C.accent)),
                      ],
                    ),
                  )
                : _entries.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.local_florist_outlined,
                                  color: C.textFaint, size: 56),
                              const SizedBox(height: 14),
                              Text(s.noBloomsToday,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                      color: C.textHi,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700)),
                              const SizedBox(height: 6),
                              Text(s.noBloomsBody,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                      color: C.accent, fontSize: 13)),
                            ],
                          ),
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
                          color: C.surface,
                          borderRadius: BorderRadius.circular(18),
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
                                        child: Text(tr(e.common),
                                            style: const TextStyle(
                                                color: C.textHi,
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
                                        child: Text(tr(e.color),
                                            style: TextStyle(
                                                color: sColor.withOpacity(0.9),
                                                fontSize: 10)),
                                      ),
                                    ],
                                  ),
                                  Text(e.scientific,
                                      style: const TextStyle(
                                          color: C.accent,
                                          fontSize: 12,
                                          fontStyle: FontStyle.italic)),
                                  const SizedBox(height: 4),
                                  Text(tr(e.note),
                                      style: const TextStyle(
                                          color: C.textHi,
                                          fontSize: 12,
                                          height: 1.4)),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Icon(Icons.location_on,
                                          color: sColor, size: 12),
                                      const SizedBox(width: 4),
                                      Text(tr(e.section),
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

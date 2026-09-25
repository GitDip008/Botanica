import 'package:flutter/material.dart';
import '../models/plant_info.dart';
import 'package:provider/provider.dart';
import '../services/chat_service.dart';
import '../services/gemini_proxy.dart';
import '../services/gemini_service.dart';
import '../services/language_service.dart';
import '../services/plant_identification_service.dart';
import '../services/usage_tracking_service.dart';
import 'main_nav_screen.dart';
import 'plant_result_screen.dart';
import '../theme/tokens.dart';
import '../i18n/tr.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _ctrl = TextEditingController();
  bool _searching = false;
  String? _error;

  // Getter, not a field: rebuilt in the current language every build.
  List<String> get _suggestions => [
    tr('Valerian'), tr('Cloudberry'), tr('Arctic Poppy'), tr('Bird of Paradise'),
    tr('Mountain Avens'), tr('Orchid'), tr('Lapland Rhododendron'), tr('Chamomile'),
  ];

  Future<void> _search(String query) async {
    if (query.trim().isEmpty) return;
    setState(() { _searching = true; _error = null; });
    FocusScope.of(context).unfocus();
    UsageTrackingService.instance.log(UsageTrackingService.featureSearch);

    try {
      // Generate plant description in the user's selected app language.
      final lang = LanguageService.instance.current.llmName;
      final systemPrompt =
          'You are a botanist at Oulu Botanical Garden, Finland.\n\n'
          'FIRST, decide if the search query is a plant, tree, flower, fungus, '
          'moss, or any botanical subject. If it is NOT botanical (e.g. furniture, '
          'animals, people, objects, food unrelated to plants, abstract concepts), '
          'respond with EXACTLY this single line and nothing else:\n'
          'NOT_A_PLANT\n\n'
          'If it IS botanical, respond in EXACTLY this format with no extra text. '
          'Keep the field labels (SCIENTIFIC_NAME, COMMON_NAME, FAMILY, DESCRIPTION) '
          'in English, but write the DESCRIPTION text in $lang.\n'
          'SCIENTIFIC_NAME: [scientific name]\n'
          'COMMON_NAME: [common name in $lang if available, else English]\n'
          'FAMILY: [plant family in $lang]\n'
          'DESCRIPTION: [2-3 sentences in $lang about the plant, its appearance, and any relevance to Oulu Botanical Garden or Finnish/subarctic context]';
      final userPrompt = 'Search query: "$query".';

      // 1) Try Groq first (free)
      String? text = await ChatService.instance.cloud
          .completeText(systemPrompt: systemPrompt, userPrompt: userPrompt);

      // 2) Fall back to Gemini (via Cloud Function proxy) if Groq fails
      if (text == null) {
        text = await GeminiProxy.instance.text(
          prompt: '$systemPrompt\n\n$userPrompt',
          model: 'gemini-2.5-flash',
        );
      }

      final responseText = text;

      // ── Scope guard — reject non-botanical searches ──────────────────
      if (responseText.toUpperCase().contains('NOT_A_PLANT')) {
        if (mounted) {
          final s = LanguageService.instance.strings;
          setState(() {
            _searching = false;
            _error = s.notABotanicalSearch;
          });
        }
        return;
      }

      String extract(String key) {
        final regex = RegExp('$key:\\s*(.+)', caseSensitive: false);
        return regex.firstMatch(responseText)?.group(1)?.trim() ?? 'Unknown';
      }

      final scientificName = extract('SCIENTIFIC_NAME');

      // Extra guard — if the model didn't return a proper scientific name
      if (scientificName == 'Unknown') {
        if (mounted) {
          final s = LanguageService.instance.strings;
          setState(() {
            _searching = false;
            _error = s.notABotanicalSearch;
          });
        }
        return;
      }

      var info = PlantInfo(
        scientificName: scientificName,
        commonName: extract('COMMON_NAME'),
        family: extract('FAMILY'),
        description: extract('DESCRIPTION'),
        isPlant: true,
      );

      // Enrich with a reference image from Wikipedia (free, no API key).
      info = await PlantIdentificationService.instance.attachImage(info);

      if (mounted) {
        setState(() => _searching = false);
        final geminiService = GeminiService();
        await ChatService.instance.seedPlantContext(info);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PlantResultScreen(
              imagePath: '',
              plantInfo: info,
              geminiService: geminiService,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final s = LanguageService.instance.strings;
        setState(() {
          _searching = false;
          _error = '${s.searchFailed}: $e';
        });
      }
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<LanguageService>().strings;
    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(
        backgroundColor: C.surface,
        leading: IconButton(
          icon: const Icon(Icons.menu_rounded, color: C.textHi),
          onPressed: () =>
              MainNavScreen.scaffoldKey.currentState?.openDrawer(),
        ),
        title: Text(s.searchPlants,
            style: const TextStyle(color: C.textHi, fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Search bar
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _ctrl,
                    style: const TextStyle(color: C.textHi),
                    decoration: InputDecoration(
                      hintText: s.searchHint,
                      prefixIcon: const Icon(Icons.search, color: C.accent),
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onSubmitted: _search,
                    textInputAction: TextInputAction.search,
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: () => _search(_ctrl.text),
                  child: Container(
                    width: 48, height: 48,
                    decoration: const BoxDecoration(
                      color: C.accentDim,
                      shape: BoxShape.circle,
                    ),
                    child: _searching
                        ? const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)))
                        : const Icon(Icons.search, color: Colors.white, size: 22),
                  ),
                ),
              ],
            ),

            if (_error != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: C.danger.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(R.s),
                ),
                child: Text(_error!,
                    style: const TextStyle(color: C.danger, fontSize: 13, height: 1.4)),
              ),
            ],

            const SizedBox(height: 24),

            Text(s.quickSearches.toUpperCase(), style: T.overline),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8, runSpacing: 8,
              children: _suggestions.map((s) => GestureDetector(
                onTap: () { _ctrl.text = s; _search(s); },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  decoration: BoxDecoration(
                    color: C.surfaceAlt,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(s, style: const TextStyle(color: C.text, fontSize: 13.5)),
                ),
              )).toList(),
            ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

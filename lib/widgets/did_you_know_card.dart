import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../i18n/app_strings.dart';
import '../services/chat_service.dart';
import '../services/language_service.dart';

// Hardcoded fallback facts (used only if Groq is unreachable)
const _fallbacksEn = [
  'Bamboo can grow up to 91 cm in a single day — the fastest plant on Earth.',
  'A single tree can release 100 gallons of water vapor into the air daily.',
  'Carl Linnaeus invented the binomial naming system we still use today.',
  'Some lotus seeds have sprouted after 1,300 years buried in lake sediment.',
  'Sunflowers track the sun across the sky — a behaviour called heliotropism.',
  'Mycorrhizal fungi connect trees in a hidden "wood-wide-web" underground.',
  'Venus flytraps count touches before closing — to avoid wasting energy.',
  'Vanilla is the second most expensive spice in the world after saffron.',
  'A giant redwood can live for over 3,000 years and weigh 1,000 tonnes.',
  'Coffee plants originally come from Ethiopia, not South America.',
];
const _fallbacksFi = [
  'Bambu voi kasvaa jopa 91 cm yhdessä päivässä — maailman nopeimmin kasvava kasvi.',
  'Yksittäinen puu voi vapauttaa ilmaan 380 litraa vesihöyryä päivässä.',
  'Carl Linnaeus kehitti kaksiosaisen nimijärjestelmän, jota käytämme yhä.',
  'Lootuksen siemenet ovat itäneet 1 300 vuoden jälkeen järven pohjasta.',
  'Auringonkukat seuraavat aurinkoa — ilmiötä kutsutaan heliotropismiksi.',
  'Sienirihmasto yhdistää puut maan alla "metsän internetiksi".',
  'Kihokit laskevat kosketuksia ennen sulkeutumistaan säästääkseen energiaa.',
  'Vanilja on maailman toiseksi kallein mauste sahramin jälkeen.',
  'Jättiläispunapuu voi elää yli 3 000 vuotta ja painaa 1 000 tonnia.',
  'Kahvi on alun perin kotoisin Etiopiasta, ei Etelä-Amerikasta.',
];
const _fallbacksSv = [
  'Bambu kan växa upp till 91 cm på en dag — jordens snabbast växande växt.',
  'Ett enda träd kan släppa ut 380 liter vattenånga i luften per dag.',
  'Carl Linnaeus uppfann det binomiala namnsystemet vi använder än idag.',
  'Vissa lotusfrön har grott efter 1 300 år i sjösediment.',
  'Solrosor följer solen över himlen — ett beteende kallat heliotropism.',
  'Mykorrhiza-svampar förbinder träd i ett dolt "skogens internet".',
  'Venus flugfälla räknar beröringar innan den sluts för att spara energi.',
  'Vanilj är världens näst dyraste krydda efter saffran.',
  'En jätteredwood kan leva i över 3 000 år och väga 1 000 ton.',
  'Kaffeplantor kommer ursprungligen från Etiopien, inte Sydamerika.',
];

/// Shows a fresh AI-generated botanical/garden fact in the current app language.
/// Tap the refresh button to generate a new one. Maximum 3 sentences.
class DidYouKnowCard extends StatefulWidget {
  const DidYouKnowCard({super.key});

  @override
  State<DidYouKnowCard> createState() => _DidYouKnowCardState();
}

class _DidYouKnowCardState extends State<DidYouKnowCard> {
  String? _fact;
  bool _loading = false;
  AppLanguage? _lastLang;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final lang = context.read<LanguageService>().current;
    if (_lastLang != lang) {
      _lastLang = lang;
      _fetch();
    }
  }

  // 30 diverse seed topics — picked at random each fetch to force diversity.
  static const _topicSeeds = [
    'carnivorous plants (Venus flytrap, sundews)',
    'orchids',
    'mosses & lichens',
    'mushrooms / fungi',
    'tropical rainforest plants',
    'cacti and desert succulents',
    'giant trees (redwoods, sequoias)',
    'flowering pollination tricks',
    'plant symbiosis with insects',
    'a famous botanist (Linnaeus, Mendel, Hooker, Bauhin)',
    'ferns and primitive vascular plants',
    'plants and music or sound',
    'aquatic plants and water lilies',
    'bamboo growth speed',
    'plants that glow / bioluminescence',
    'fragrant flowers and perfume history',
    'medicinal use of a plant (willow bark, foxglove)',
    'coffee, tea or chocolate plant origins',
    'plants that survive fire',
    'arctic and alpine plant adaptations',
    'plant evolution (ginkgo, cycads)',
    'invasive plant species',
    'seeds with extreme longevity',
    'sunflowers and Fibonacci patterns',
    'mangrove ecosystems',
    'mycorrhizal fungal networks',
    'plants that move (Mimosa pudica)',
    'edible flowers',
    'spices and their origins (saffron, vanilla)',
    'plant defenses (thorns, toxins, latex)',
  ];

  Future<void> _fetch() async {
    setState(() => _loading = true);
    final lang = context.read<LanguageService>().current.llmName;
    // Pick a random topic seed so the LLM is forced off the cloudberry path
    final rand = Random();
    final topic = _topicSeeds[rand.nextInt(_topicSeeds.length)];

    final fact = await ChatService.instance.cloud.completeText(
      systemPrompt:
          'You are a botanical educator. Always answer in $lang only. '
          'Plain text only — no markdown, no preamble, no quotation marks.',
      userPrompt:
          'Share ONE surprising botanical fact specifically about: $topic.\n\n'
          'STRICT RULES:\n'
          '• Maximum 150 characters TOTAL.\n'
          '• 1-2 short sentences only.\n'
          '• Do NOT mention cloudberries unless the topic explicitly is cloudberries.\n'
          '• Do NOT start with "Did you know".\n'
          '• State the fact directly.',
      maxTokens: 80,
      temperature: 1.0,
    );

    if (!mounted) return;
    // Hardcoded language-specific fallback pool (used when Groq fails)
    final pool = lang == 'Finnish'
        ? _fallbacksFi
        : lang == 'Swedish'
            ? _fallbacksSv
            : _fallbacksEn;
    String shown = fact ?? pool[rand.nextInt(pool.length)];

    // Hard-cap at 150 chars client-side — LLM sometimes ignores the prompt.
    if (shown.length > 150) {
      shown = '${shown.substring(0, 147).trimRight()}…';
    }

    setState(() {
      _fact = shown;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<LanguageService>().strings;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A2E1E), Color(0xFF111F16)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2A4A2F)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.lightbulb_rounded,
                  color: Color(0xFFFFD54F), size: 20),
              SizedBox(width: 8),
              Text('🌱', style: TextStyle(fontSize: 16)),
            ],
          ),
          const SizedBox(height: 10),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 350),
            transitionBuilder: (child, animation) =>
                FadeTransition(opacity: animation, child: child),
            child: _loading
                ? Padding(
                    key: const ValueKey('loading'),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Color(0xFF66BB6A)),
                        ),
                        const SizedBox(width: 10),
                        Text(s.loadingFact,
                            style: const TextStyle(
                                color: Color(0xFF81C784),
                                fontSize: 13,
                                fontStyle: FontStyle.italic)),
                      ],
                    ),
                  )
                : Text(
                    _fact ?? '',
                    key: ValueKey(_fact),
                    style: const TextStyle(
                      color: Color(0xFFE8F5E9),
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: _loading ? null : _fetch,
              icon: const Icon(Icons.refresh_rounded,
                  size: 16, color: Color(0xFF66BB6A)),
              label: Text(
                s.newFact,
                style: const TextStyle(
                    color: Color(0xFF66BB6A),
                    fontSize: 12,
                    fontWeight: FontWeight.w600),
              ),
              style: TextButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms);
  }
}

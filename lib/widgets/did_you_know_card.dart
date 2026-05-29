import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../i18n/app_strings.dart';
import '../services/chat_service.dart';
import '../services/language_service.dart';

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

  Future<void> _fetch() async {
    setState(() => _loading = true);
    final lang = context.read<LanguageService>().current.llmName;

    final fact = await ChatService.instance.cloud.completeText(
      systemPrompt:
          'You are a botanical educator at Oulu Botanical Garden. Always answer in $lang only. '
          'Plain text only — no markdown, no preamble, no quotation marks.',
      userPrompt:
          'Share ONE surprising or delightful botanical fact — about a plant, '
          'a botanist, a flower, an ecosystem, plant evolution, or Finnish/Nordic flora. '
          'Pick something random and unexpected.\n\n'
          'STRICT RULES (must follow):\n'
          '• Maximum 150 characters TOTAL (count them — including spaces and punctuation).\n'
          '• 1-2 short sentences only.\n'
          '• Do NOT start with "Did you know".\n'
          '• Just state the fact directly.',
      maxTokens: 80,
      temperature: 0.95,
    );

    if (!mounted) return;
    String shown = fact ??
        (lang == 'Finnish'
            ? 'Kasvit tuottavat lähes 99 % maapallon hapesta.'
            : lang == 'Swedish'
                ? 'Växter producerar nästan 99 % av världens syre.'
                : 'Plants produce nearly 99% of the oxygen in our atmosphere.');

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

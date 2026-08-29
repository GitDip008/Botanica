// lib/widgets/plant_tags_bar.dart
//
// Reusable tag chips for a plant. Drop `PlantTagsBar(scientificName: ...)` onto
// any surface where a plant appears (list, search, agent, navigation).
//
//   • tap a tag  -> its curated description pops up.
//   • 2+ tags    -> a "Summary" chip asks the LLM to condense ONLY those
//                   descriptions into a short blurb (per the product rule).
//   • "Dangerous" renders as a red safety flag.
//
// Tag data is local (assets, PlantIndex) so this needs no network; only the
// optional multi-tag summary calls the LLM.

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import '../data/plant_index.dart';
import '../services/language_service.dart';

/// True when the app is showing Finnish.
bool get _isFinnish => LanguageService.instance.current.code == 'fi';

/// Pick the Finnish description if the app is in Finnish and one exists,
/// otherwise the English one.
String _descFor(PlantFacts f, String tag) =>
    (_isFinnish ? f.tagsFi[tag] : null) ?? f.tags[tag] ?? '';

class PlantTagsBar extends StatelessWidget {
  const PlantTagsBar({super.key, required this.scientificName});
  final String scientificName;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: PlantIndex.instance.ready(),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const SizedBox.shrink();
        }
        final facts = PlantIndex.instance.factsFor(scientificName);
        if (facts == null || facts.tags.isEmpty) return const SizedBox.shrink();
        final tags = facts.tags.keys.toList();
        return Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final t in tags)
              _TagChip(
                label: t,
                danger: t == 'Dangerous',
                onTap: () => _showDescription(context, t, _descFor(facts, t)),
              ),
            if (tags.length >= 2)
              _TagChip(
                label: 'Summary',
                summary: true,
                onTap: () => _showSummary(context, facts),
              ),
          ],
        );
      },
    );
  }

  void _showDescription(BuildContext context, String tag, String desc) {
    _sheet(context, tag, Text(desc,
        style: const TextStyle(color: Colors.white70, height: 1.5)));
  }

  void _showSummary(BuildContext context, PlantFacts facts) {
    _sheet(
      context,
      '${facts.tags.length} highlights',
      FutureBuilder<String>(
        future: _summarise(facts.scientificName, facts),
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Row(children: [
                SizedBox(width: 16, height: 16, child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.greenAccent)),
                SizedBox(width: 12),
                Text('Summarising…', style: TextStyle(color: Colors.white54)),
              ]),
            );
          }
          if (snap.hasError) {
            // Fall back to just listing the descriptions if the LLM is down.
            return Text(
                facts.tags.keys.map((t) => _descFor(facts, t)).join('\n\n'),
                style: const TextStyle(color: Colors.white70, height: 1.5));
          }
          return Text(snap.data ?? '',
              style: const TextStyle(color: Colors.white70, height: 1.5));
        },
      ),
    );
  }

  void _sheet(BuildContext context, String title, Widget body) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A2E1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(
                color: Colors.greenAccent,
                fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            body,
          ],
        ),
      ),
    );
  }

  /// Ask the LLM to condense ONLY the given tag descriptions. No other facts.
  /// Output language follows the app language.
  static Future<String> _summarise(String name, PlantFacts facts) async {
    final lines =
        facts.tags.keys.map((t) => '$t: ${_descFor(facts, t)}').join('\n');
    final system = _isFinnish
        ? 'Tiivistä nämä kasvin kohokohdat kahteen lyhyeen, ystävälliseen '
            'suomenkieliseen lauseeseen. Käytä VAIN annettuja tietoja.'
        : 'Summarise these highlights about a plant into two short, friendly '
            'sentences. Use ONLY the facts given, add nothing.';
    final callable = FirebaseFunctions.instanceFor(region: 'europe-north1')
        .httpsCallable('groqChat',
            options: HttpsCallableOptions(timeout: const Duration(seconds: 30)));
    final res = await callable.call<Map<String, dynamic>>({
      'messages': [
        {'role': 'system', 'content': system},
        {'role': 'user', 'content': 'Plant: $name\n$lines'},
      ],
      'maxTokens': 140,
      'temperature': 0.4,
    });
    return (res.data['reply'] as String? ?? '').trim();
  }
}

class _TagChip extends StatelessWidget {
  const _TagChip({
    required this.label,
    required this.onTap,
    this.danger = false,
    this.summary = false,
  });
  final String label;
  final VoidCallback onTap;
  final bool danger;
  final bool summary;

  @override
  Widget build(BuildContext context) {
    final color = danger
        ? Colors.redAccent
        : summary
            ? Colors.tealAccent
            : Colors.lightGreenAccent;
    return Material(
      color: color.withOpacity(0.12),
      shape: StadiumBorder(side: BorderSide(color: color.withOpacity(0.5))),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (danger) ...[
                const Icon(Icons.warning_amber_rounded,
                    size: 13, color: Colors.redAccent),
                const SizedBox(width: 4),
              ] else if (summary) ...[
                const Icon(Icons.auto_awesome, size: 13, color: Colors.tealAccent),
                const SizedBox(width: 4),
              ],
              Text(label,
                  style: TextStyle(
                      color: color, fontSize: 11, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}

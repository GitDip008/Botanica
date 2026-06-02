import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/language_service.dart';
import '../services/usage_tracking_service.dart';
import '../widgets/sound_visualizer.dart';

class SoundscapeScreen extends StatelessWidget {
  const SoundscapeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<LanguageService>().strings;
    // Log once per visit (debounced naturally by stateless build re-entry)
    UsageTrackingService.instance.log(UsageTrackingService.featureSoundscape);
    return Scaffold(
      backgroundColor: const Color(0xFF0D1F14),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A2E1E),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF66BB6A)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('🎵 ${s.soundscape}',
            style: const TextStyle(color: Color(0xFFE8F5E9), fontWeight: FontWeight.bold)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Text(
              s.soundscapeTitle,
              style: const TextStyle(color: Color(0xFF66BB6A), fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              s.soundscapeBody,
              style: const TextStyle(color: Color(0xFF4CAF50), fontSize: 14),
            ),
            const SizedBox(height: 8),
            Text(
              s.findQuietSpot,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFFE8F5E9), fontSize: 13),
            ),
            const Expanded(child: SoundVisualizer()),
          ],
        ),
      ),
    );
  }
}

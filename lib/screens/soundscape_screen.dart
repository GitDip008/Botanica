import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/language_service.dart';
import '../services/usage_tracking_service.dart';
import '../widgets/sound_visualizer.dart';
import '../theme/tokens.dart';

class SoundscapeScreen extends StatelessWidget {
  const SoundscapeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<LanguageService>().strings;
    // Log once per visit (debounced naturally by stateless build re-entry)
    UsageTrackingService.instance.log(UsageTrackingService.featureSoundscape);
    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(
        backgroundColor: C.surface,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: C.accent),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('🎵 ${s.soundscape}',
            style: const TextStyle(color: C.textHi, fontWeight: FontWeight.bold)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Text(
              s.soundscapeTitle,
              style: const TextStyle(color: C.accent, fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              s.soundscapeBody,
              style: const TextStyle(color: C.accent, fontSize: 14),
            ),
            const SizedBox(height: 8),
            Text(
              s.findQuietSpot,
              textAlign: TextAlign.center,
              style: const TextStyle(color: C.textHi, fontSize: 13),
            ),
            const Expanded(child: SoundVisualizer()),
          ],
        ),
      ),
    );
  }
}

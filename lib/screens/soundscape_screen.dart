import 'package:flutter/material.dart';
import '../widgets/sound_visualizer.dart';

class SoundscapeScreen extends StatelessWidget {
  const SoundscapeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1F14),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A2E1E),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF66BB6A)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('🎵 Soundscape',
            style: TextStyle(color: Color(0xFFE8F5E9), fontWeight: FontWeight.bold)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const SizedBox(height: 12),
            const Text(
              'Ambient Sound Visualizer',
              style: TextStyle(color: Color(0xFF66BB6A), fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            const Text(
              'Listen to the sounds of the garden',
              style: TextStyle(color: Color(0xFF4CAF50), fontSize: 14),
            ),
            const SizedBox(height: 8),
            const Text(
              'Find a quiet spot, hold still, and let the garden speak.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFFE8F5E9), fontSize: 13),
            ),
            const Expanded(child: SoundVisualizer()),
          ],
        ),
      ),
    );
  }
}

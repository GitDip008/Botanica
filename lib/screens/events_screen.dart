import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../services/language_service.dart';

class EventsScreen extends StatelessWidget {
  const EventsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<LanguageService>().strings;
    return Scaffold(
      backgroundColor: const Color(0xFF0D1F14),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A2E1E),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF66BB6A)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('📅 ${s.upcomingEvents}',
            style: const TextStyle(
                color: Color(0xFFE8F5E9), fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const _EventRow(
              date: 'May 15',
              title: 'Spring Guided Walk',
              desc:
                  'Join botanist Tuomas for a tour of the Fennoscandian section. Free.'),
          const _EventRow(
              date: 'May 22',
              title: 'Medicinal Plants Workshop',
              desc:
                  'Hands-on workshop on Finnish medicinal plants. Register via website.'),
          const _EventRow(
              date: 'Jun 7',
              title: 'Researchers\' Night',
              desc:
                  'Open evening with staff talks, plant tastings, and greenhouse access.'),
          const _EventRow(
              date: 'Jun 21',
              title: 'Midsummer Bloom Walk',
              desc:
                  'Peak-bloom guided walk. Special focus on grasslands section.'),
          const SizedBox(height: 20),
        ],
      ).animate().fadeIn(duration: 400.ms),
    );
  }
}

class _EventRow extends StatelessWidget {
  final String date;
  final String title;
  final String desc;
  const _EventRow({required this.date, required this.title, required this.desc});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2E1E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF2A4A2F)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 56,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF534AB7).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              date,
              style: const TextStyle(
                  color: Color(0xFF9B93E8),
                  fontSize: 12,
                  fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        color: Color(0xFFE8F5E9),
                        fontWeight: FontWeight.bold,
                        fontSize: 14)),
                const SizedBox(height: 4),
                Text(desc,
                    style: const TextStyle(
                        color: Color(0xFF81C784),
                        fontSize: 12.5,
                        height: 1.45)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

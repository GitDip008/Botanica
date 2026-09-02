// lib/widgets/ongoing_contest_card.dart
//
// Home-screen "Ongoing Contests" section.
//
// Holds everything a visitor can currently compete in: whatever event is
// configured in /config/contest, plus the Plant Hunt, which runs permanently.
// The event card appears and disappears on its own — driven by the Firestore
// document, no app update either way, and the stream means it also vanishes
// mid-session if someone switches it off while a visitor has the app open.
//
// The section itself always renders, because the Plant Hunt is always there.

import 'package:flutter/material.dart';

import '../models/contest.dart';
import '../screens/contest/contest_screen.dart';
import '../screens/plant_hunt_screen.dart';
import '../services/contest_service.dart';

class OngoingContestCard extends StatelessWidget {
  const OngoingContestCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: const BoxDecoration(
                  color: Color(0xFFFF7043),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 7),
              const Text(
                'ONGOING CONTESTS',
                style: TextStyle(
                  color: Color(0xFFFF7043),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // The timed event, when one is running.
          StreamBuilder<Contest?>(
            stream: ContestService.instance.watchContest(),
            builder: (context, snap) {
              final c = snap.data;
              if (c == null || !c.isLive) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _ContestTile(
                  icon: Icons.auto_awesome_rounded,
                  gradient: const [Color(0xFF3B1A5C), Color(0xFF7B1FA2)],
                  title: c.title,
                  subtitle: c.subtitle,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => ContestScreen(contest: c)),
                  ),
                ),
              );
            },
          ),

          // Always available — five plants, any day the garden is open.
          _ContestTile(
            icon: Icons.emoji_events_rounded,
            gradient: const [Color(0xFF2D1550), Color(0xFF4A1A7A)],
            title: 'Plant Hunt',
            subtitle: 'Five clues, five plants. Read the tag, score the points.',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PlantHuntScreen()),
            ),
          ),
        ],
      ),
    );
  }
}

class _ContestTile extends StatelessWidget {
  const _ContestTile({
    required this.icon,
    required this.gradient,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final List<Color> gradient;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(icon, color: const Color(0xFFFFD54F)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (subtitle.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 12.5,
                          height: 1.3,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white70),
          ],
        ),
      ),
    );
  }
}

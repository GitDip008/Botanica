// lib/widgets/ongoing_contest_card.dart
//
// Home-screen entry point for whatever contest is currently running.
//
// Renders nothing at all when no contest is live, so the section appears for the
// event and disappears the moment it ends — driven by /config/contest, with no
// app update needed either way. The stream means it also vanishes mid-session
// if someone switches it off while a visitor has the app open.

import 'package:flutter/material.dart';

import '../models/contest.dart';
import '../screens/contest/contest_screen.dart';
import '../services/contest_service.dart';

class OngoingContestCard extends StatelessWidget {
  const OngoingContestCard({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Contest?>(
      stream: ContestService.instance.watchContest(),
      builder: (context, snap) {
        final c = snap.data;
        if (c == null || !c.isLive) return const SizedBox.shrink();

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
                    'ONGOING CONTEST',
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
              GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => ContestScreen(contest: c)),
                ),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF3B1A5C), Color(0xFF7B1FA2)],
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
                        child: const Icon(Icons.auto_awesome_rounded,
                            color: Color(0xFFFFD54F)),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              c.title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (c.subtitle.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(
                                  c.subtitle,
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
              ),
            ],
          ),
        );
      },
    );
  }
}

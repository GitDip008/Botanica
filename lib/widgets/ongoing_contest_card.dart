// lib/widgets/ongoing_contest_card.dart
//
// Home-screen "Ongoing Challenges" section.
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
import '../theme/tokens.dart';
import 'ui_kit.dart';

class OngoingContestCard extends StatelessWidget {
  const OngoingContestCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Sp.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle(
            'Ongoing challenges',
            color: C.gold,
            trailing: const LiveDot(color: C.gold, size: 7),
          ),

          // The timed event, when one is running.
          StreamBuilder<Contest?>(
            stream: ContestService.instance.watchContest(),
            builder: (context, snap) {
              final c = snap.data;
              if (c == null || !c.isLive) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(bottom: Sp.m),
                child: ActionTile(
                  icon: Icons.how_to_vote_rounded,
                  color: C.gold,
                  title: c.title,
                  subtitle: c.subtitle.isEmpty
                      ? 'Add a plant and cast your vote.'
                      : c.subtitle,
                  trailing: const Pill('LIVE', color: C.gold),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => ContestScreen(contest: c)),
                  ),
                ),
              );
            },
          ),

          // Always available — five plants, any day the garden is open.
          ActionTile(
            icon: Icons.emoji_events_rounded,
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

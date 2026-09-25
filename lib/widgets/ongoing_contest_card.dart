// lib/widgets/ongoing_contest_card.dart
//
// Home-screen "Ongoing Challenges" section: the Peer Review vote (whatever is
// configured in /config/contest) and the Plant Hunt.
//
// Both are published or hidden by an admin with the switch on the card itself
// — no console, no release. Visitors only ever see what is published; admins
// see everything, with the switch, so a hidden challenge can be tested before
// it goes out. Both are streamed, so a change reaches open phones in seconds.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/contest.dart';
import '../screens/contest/contest_screen.dart';
import '../screens/plant_hunt_screen.dart';
import '../services/contest_service.dart';
import '../services/user_state.dart';
import '../theme/tokens.dart';
import 'ui_kit.dart';
import '../i18n/tr.dart';

class OngoingContestCard extends StatelessWidget {
  const OngoingContestCard({super.key});

  @override
  Widget build(BuildContext context) {
    final isAdmin = context.watch<UserState>().user?.isAdmin ?? false;
    final svc = ContestService.instance;

    return StreamBuilder<Contest?>(
      stream: svc.watchContest(),
      builder: (context, contestSnap) => StreamBuilder<bool>(
        stream: svc.watchPlantHuntActive(),
        builder: (context, huntSnap) {
          final c = contestSnap.data;
          final voteOn = c?.isLive ?? false;
          final huntOn = huntSnap.data ?? true;
          final showVote = c != null && (voteOn || isAdmin);
          final showHunt = huntOn || isAdmin;
          if (!showVote && !showHunt) return const SizedBox.shrink();

          return Padding(
            padding: const EdgeInsets.only(bottom: Sp.xxl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionTitle(
                  tr('Ongoing challenges'),
                  color: C.gold,
                  trailing: const LiveDot(color: C.gold, size: 7),
                ),
                if (showVote) ...[
                  ActionTile(
                    icon: Icons.how_to_vote_rounded,
                    color: C.gold,
                    title: c.title,
                    subtitle: c.subtitle.isEmpty
                        ? tr('Add a plant and cast your vote.')
                        : c.subtitle,
                    trailing: isAdmin
                        ? _PublishSwitch(
                            name: c.title,
                            on: voteOn,
                            onChanged: svc.setContestActive,
                          )
                        : Pill(tr('LIVE'), color: C.gold),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => ContestScreen(contest: c)),
                    ),
                  ),
                  const SizedBox(height: Sp.m),
                ],
                if (showHunt)
                  ActionTile(
                    icon: Icons.emoji_events_rounded,
                    title: tr('Plant Hunt'),
                    subtitle: tr(
                        'Five clues, five plants. Read the tag, score the points.'),
                    trailing: isAdmin
                        ? _PublishSwitch(
                            name: tr('Plant Hunt'),
                            on: huntOn,
                            onChanged: svc.setPlantHuntActive,
                          )
                        : null,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const PlantHuntScreen()),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Admin-only: publish or hide a challenge for every visitor.
class _PublishSwitch extends StatelessWidget {
  const _PublishSwitch({
    required this.name,
    required this.on,
    required this.onChanged,
  });

  final String name;
  final bool on;
  final Future<void> Function(bool) onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Switch(
          value: on,
          onChanged: (v) async {
            final messenger = ScaffoldMessenger.of(context);
            try {
              await onChanged(v);
              messenger.showSnackBar(SnackBar(
                  content: Text(v
                      ? tr('{0} is now visible to everyone.', [name])
                      : tr('{0} is now hidden.', [name]))));
            } catch (e) {
              messenger.showSnackBar(
                  SnackBar(content: Text(tr('Could not update: {0}', [e]))));
            }
          },
        ),
        Text(on ? tr('Published') : tr('Hidden'),
            style: T.label.copyWith(
                fontSize: 11, color: on ? C.accent : C.textFaint)),
      ],
    );
  }
}

// lib/screens/contest/contest_teams_tab.dart
//
// Teams: one person creates a team, everyone else joins it from the open list.
// A visitor belongs to at most one team per contest; entries they submit carry
// that team's name.

import 'package:flutter/material.dart';

import '../../models/contest.dart';
import '../../services/auth_service.dart';
import '../../services/contest_service.dart';
import '../../theme/tokens.dart';
import '../../i18n/tr.dart';

class ContestTeamsTab extends StatefulWidget {
  const ContestTeamsTab({super.key, required this.contest});
  final Contest contest;

  @override
  State<ContestTeamsTab> createState() => _ContestTeamsTabState();
}

class _ContestTeamsTabState extends State<ContestTeamsTab> {
  bool _busy = false;

  String get _uid => AuthService.instance.currentUser?.id ?? '';
  String get _name {
    final n = AuthService.instance.currentUser?.displayName ?? '';
    return n.isEmpty ? tr('Visitor') : n;
  }

  Future<void> _create() async {
    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: C.bg,
        title: Text(tr('Name your team'),
            style: TextStyle(color: C.textHi, fontSize: 17)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLength: 30,
          style: const TextStyle(color: C.textHi),
          decoration: InputDecoration(
            hintText: tr('e.g. The Creepy Crawlies'),
            hintStyle: TextStyle(color: C.textFaint),
            counterStyle: TextStyle(color: C.textFaint),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(tr('Cancel'),
                style: TextStyle(color: C.accent)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, ctrl.text.trim()),
            style: FilledButton.styleFrom(
                backgroundColor: C.gold,
                foregroundColor: const Color(0xFF231A00)),
            child: Text(tr('Create')),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty || _uid.isEmpty) return;

    setState(() => _busy = true);
    try {
      await ContestService.instance.createTeam(
        contestId: widget.contest.id,
        name: name,
        uid: _uid,
        displayName: _name,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_uid.isEmpty) {
      return Center(
        child: Text(tr('Sign in to join a team.'),
            style: TextStyle(color: C.textSoft)),
      );
    }

    return StreamBuilder<List<ContestTeam>>(
      stream: ContestService.instance.watchTeams(widget.contest.id),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final teams = snap.data!
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        final mine =
            teams.where((t) => t.memberUids.contains(_uid)).firstOrNull;

        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 96),
          children: [
            Text(
              tr('Play alone, or team up with whoever is around. Your picks count for your team.'),
              style: TextStyle(
                  color: C.textSoft, fontSize: 13, height: 1.45),
            ),
            const SizedBox(height: 16),

            if (mine == null)
              FilledButton.icon(
                onPressed: _busy ? null : _create,
                icon: const Icon(Icons.group_add_rounded),
                label: Text(tr('Create a team')),
                style: FilledButton.styleFrom(
                  backgroundColor: C.accentDim,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                ),
              )
            else
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: C.surfaceAlt,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: C.gold),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tr('Your team: {0}', [mine.name]),
                        style: const TextStyle(
                            color: C.gold,
                            fontSize: 15,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(mine.memberNames.join(', '),
                        style: const TextStyle(
                            color: C.text, fontSize: 12.5)),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () async {
                              setState(() => _busy = true);
                              try {
                                await ContestService.instance.leaveTeam(
                                  teamId: mine.id,
                                  uid: _uid,
                                  displayName: _name,
                                );
                              } finally {
                                if (mounted) setState(() => _busy = false);
                              }
                            },
                      style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(0, 0),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                      child: Text(tr('Leave team'),
                          style: TextStyle(
                              color: C.danger, fontSize: 12.5)),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 22),
            Text(tr('OPEN TEAMS'),
                style: TextStyle(
                    color: C.accent,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2)),
            const SizedBox(height: 10),

            if (teams.isEmpty)
              Text(tr('No teams yet. Create the first one.'),
                  style: TextStyle(color: C.textFaint, fontSize: 13)),

            for (final t in teams)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: C.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: t.memberUids.contains(_uid)
                        ? C.gold
                        : C.line,
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(t.name,
                              style: const TextStyle(
                                  color: C.textHi,
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w600)),
                          Text(
                              '${t.size} ${t.size == 1 ? "player" : "players"}  ·  ${t.memberNames.take(3).join(", ")}'
                              '${t.memberNames.length > 3 ? "…" : ""}',
                              style: const TextStyle(
                                  color: C.textFaint, fontSize: 11.5)),
                        ],
                      ),
                    ),
                    if (t.memberUids.contains(_uid))
                      const Icon(Icons.check_circle_rounded,
                          color: C.gold, size: 20)
                    else if (mine == null)
                      TextButton(
                        onPressed: _busy
                            ? null
                            : () async {
                                setState(() => _busy = true);
                                try {
                                  await ContestService.instance.joinTeam(
                                    teamId: t.id,
                                    uid: _uid,
                                    displayName: _name,
                                  );
                                } finally {
                                  if (mounted) setState(() => _busy = false);
                                }
                              },
                        child: Text(tr('Join'),
                            style: TextStyle(color: C.accent)),
                      ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull => isEmpty ? null : first;
}

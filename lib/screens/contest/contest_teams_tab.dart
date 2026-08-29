// lib/screens/contest/contest_teams_tab.dart
//
// Teams: one person creates a team, everyone else joins it from the open list.
// A visitor belongs to at most one team per contest; entries they submit carry
// that team's name.

import 'package:flutter/material.dart';

import '../../models/contest.dart';
import '../../services/auth_service.dart';
import '../../services/contest_service.dart';

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
    return n.isEmpty ? 'Visitor' : n;
  }

  Future<void> _create() async {
    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF0D1F14),
        title: const Text('Name your team',
            style: TextStyle(color: Color(0xFFE8F5E9), fontSize: 17)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLength: 30,
          style: const TextStyle(color: Color(0xFFE8F5E9)),
          decoration: const InputDecoration(
            hintText: 'e.g. The Creepy Crawlies',
            hintStyle: TextStyle(color: Color(0xFF6E8A72)),
            counterStyle: TextStyle(color: Color(0xFF4A7A50)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel',
                style: TextStyle(color: Color(0xFF81C784))),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, ctrl.text.trim()),
            style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFFFB300),
                foregroundColor: const Color(0xFF231A00)),
            child: const Text('Create'),
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
      return const Center(
        child: Text('Sign in to join a team.',
            style: TextStyle(color: Color(0xFF9CCC9F))),
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
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          children: [
            const Text(
              'Play alone, or team up with whoever is around. '
              'Your picks count for your team.',
              style: TextStyle(
                  color: Color(0xFF9CCC9F), fontSize: 13, height: 1.45),
            ),
            const SizedBox(height: 16),

            if (mine == null)
              FilledButton.icon(
                onPressed: _busy ? null : _create,
                icon: const Icon(Icons.group_add_rounded),
                label: const Text('Create a team'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF2E7D32),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                ),
              )
            else
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF1B4020),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFFB300)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Your team: ${mine.name}',
                        style: const TextStyle(
                            color: Color(0xFFFFD54F),
                            fontSize: 15,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(mine.memberNames.join(', '),
                        style: const TextStyle(
                            color: Color(0xFFCFE8D2), fontSize: 12.5)),
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
                      child: const Text('Leave team',
                          style: TextStyle(
                              color: Color(0xFFEF9A9A), fontSize: 12.5)),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 22),
            const Text('OPEN TEAMS',
                style: TextStyle(
                    color: Color(0xFF81C784),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2)),
            const SizedBox(height: 10),

            if (teams.isEmpty)
              const Text('No teams yet. Create the first one.',
                  style: TextStyle(color: Color(0xFF6E8A72), fontSize: 13)),

            for (final t in teams)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF111F16),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: t.memberUids.contains(_uid)
                        ? const Color(0xFFFFB300)
                        : const Color(0xFF2A4A2F),
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
                                  color: Color(0xFFE8F5E9),
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w600)),
                          Text(
                              '${t.size} ${t.size == 1 ? "player" : "players"}  ·  ${t.memberNames.take(3).join(", ")}'
                              '${t.memberNames.length > 3 ? "…" : ""}',
                              style: const TextStyle(
                                  color: Color(0xFF6E8A72), fontSize: 11.5)),
                        ],
                      ),
                    ),
                    if (t.memberUids.contains(_uid))
                      const Icon(Icons.check_circle_rounded,
                          color: Color(0xFFFFB300), size: 20)
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
                        child: const Text('Join',
                            style: TextStyle(color: Color(0xFF81C784))),
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

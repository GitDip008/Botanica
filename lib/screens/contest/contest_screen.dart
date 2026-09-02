// lib/screens/contest/contest_screen.dart
//
// The contest hub: how to play, your entries, teams, and the live leaderboard.
//
// Everything is driven by the /config/contest document, so the copy shown here
// — title, intro, the numbered steps, the slider axes — is edited in Firestore
// rather than in this file. Ending the event is one boolean.

import 'package:flutter/material.dart';

import '../../models/contest.dart';
import '../../services/auth_service.dart';
import '../../services/contest_service.dart';
import '../../services/wikipedia_image_service.dart';
import 'contest_entry_flow.dart';
import 'contest_teams_tab.dart';

class ContestScreen extends StatefulWidget {
  const ContestScreen({super.key, required this.contest});
  final Contest contest;

  @override
  State<ContestScreen> createState() => _ContestScreenState();
}

class _ContestScreenState extends State<ContestScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 4, vsync: this);

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  String get _uid => AuthService.instance.currentUser?.id ?? '';

  @override
  Widget build(BuildContext context) {
    final c = widget.contest;

    return Scaffold(
      backgroundColor: const Color(0xFF0A1A0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D1F14),
        elevation: 0,
        title: Text(c.title),
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          labelColor: const Color(0xFFFFD54F),
          unselectedLabelColor: const Color(0xFF81C784),
          indicatorColor: const Color(0xFFFFD54F),
          tabs: const [
            Tab(text: 'How to play'),
            Tab(text: 'Leaderboard'),
            Tab(text: 'My picks'),
            Tab(text: 'Teams'),
          ],
        ),
      ),
      floatingActionButton: c.isLive
          ? FloatingActionButton.extended(
              backgroundColor: const Color(0xFFFFB300),
              foregroundColor: const Color(0xFF231A00),
              icon: const Icon(Icons.add_a_photo_rounded),
              label: const Text('Add a plant'),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ContestEntryFlow(contest: c),
                ),
              ),
            )
          : null,
      body: TabBarView(
        controller: _tabs,
        children: [
          _HowToPlay(contest: c),
          _Leaderboard(contest: c),
          _MyPicks(contest: c, uid: _uid),
          ContestTeamsTab(contest: c),
        ],
      ),
    );
  }
}

class _HowToPlay extends StatelessWidget {
  const _HowToPlay({required this.contest});
  final Contest contest;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      children: [
        if (contest.subtitle.isNotEmpty)
          Text(
            contest.subtitle,
            style: const TextStyle(
              color: Color(0xFFFFD54F),
              fontSize: 16,
              fontWeight: FontWeight.w700,
              height: 1.35,
            ),
          ),
        const SizedBox(height: 10),
        if (contest.intro.isNotEmpty)
          Text(
            contest.intro,
            style: const TextStyle(
                color: Color(0xFFE8F5E9), fontSize: 14.5, height: 1.5),
          ),
        const SizedBox(height: 20),
        for (var i = 0; i < contest.steps.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 24,
                  height: 24,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: Color(0xFF2E7D32),
                    shape: BoxShape.circle,
                  ),
                  child: Text('${i + 1}',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(contest.steps[i],
                      style: const TextStyle(
                          color: Color(0xFFCFE8D2),
                          fontSize: 14,
                          height: 1.45)),
                ),
              ],
            ),
          ),
        const SizedBox(height: 12),
        const Text('THE SCALES',
            style: TextStyle(
                color: Color(0xFF81C784),
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.3)),
        const SizedBox(height: 10),
        for (final a in contest.axes)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF13301A),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(a.left,
                      style: const TextStyle(
                          color: Color(0xFFE8F5E9), fontSize: 13.5)),
                ),
                const Icon(Icons.swap_horiz_rounded,
                    size: 16, color: Color(0xFF6E8A72)),
                Expanded(
                  child: Text(a.right,
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                          color: Color(0xFFE8F5E9), fontSize: 13.5)),
                ),
              ],
            ),
          ),
        if (contest.prizeNote.isNotEmpty) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF2E1A00),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF8D6E00)),
            ),
            child: Row(
              children: [
                const Icon(Icons.emoji_events_rounded,
                    color: Color(0xFFFFD54F), size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(contest.prizeNote,
                      style: const TextStyle(
                          color: Color(0xFFFFE7A3),
                          fontSize: 13.5,
                          height: 1.4)),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _Leaderboard extends StatefulWidget {
  const _Leaderboard({required this.contest});
  final Contest contest;

  @override
  State<_Leaderboard> createState() => _LeaderboardState();
}

class _LeaderboardState extends State<_Leaderboard> {
  /// null = the overall board (most people). Otherwise the axis being ranked.
  ContestAxis? _axis;

  /// Which end of the selected scale leads. One axis therefore serves two
  /// boards — "cutest" and "creepiest" — instead of needing ten tabs for five
  /// scales.
  bool _towardRight = true;

  Contest get contest => widget.contest;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ContestEntry>>(
      stream: ContestService.instance.watchEntries(contest.id),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        // Top ten only. A public leaderboard is a motivator, not an archive —
        // and nobody at an event scrolls past the tenth plant.
        final axis = _axis;
        final rows = (axis == null
                ? ContestService.rank(snap.data!)
                : ContestService.rankByAxis(snap.data!, axis.key,
                    towardRight: _towardRight))
            .take(10)
            .toList();

        return Column(
          children: [
            _picker(),
            Expanded(child: _list(rows)),
          ],
        );
      },
    );
  }

  /// Scale picker. Horizontal because five scales plus "Most picked" will not
  /// fit across a phone, and wrapping them would push the board itself off the
  /// first screen.
  Widget _picker() {
    return SizedBox(
      height: 46,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        children: [
          _chip(
            label: 'Most picked',
            selected: _axis == null,
            onTap: () => setState(() => _axis = null),
          ),
          for (final a in contest.axes)
            _chip(
              // The end currently leading is the one worth naming: on the
              // "Cute ↔ Creepy" scale the board is either most cute or most
              // creepy, and the label has to say which.
              label: identical(a, _axis)
                  ? (_towardRight ? a.right : a.left)
                  : '${a.left} / ${a.right}',
              selected: identical(a, _axis),
              trailing: identical(a, _axis) ? Icons.swap_horiz_rounded : null,
              onTap: () => setState(() {
                // Tapping the selected scale flips which end leads.
                if (identical(a, _axis)) {
                  _towardRight = !_towardRight;
                } else {
                  _axis = a;
                  _towardRight = true;
                }
              }),
            ),
        ],
      ),
    );
  }

  Widget _chip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
    IconData? trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: selected ? const Color(0xFF3A2A06) : const Color(0xFF111F16),
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: selected
                      ? const Color(0xFFFFD54F)
                      : const Color(0xFF2A4A2F)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label,
                    style: TextStyle(
                      color: selected
                          ? const Color(0xFFFFD54F)
                          : const Color(0xFF9CCC9F),
                      fontSize: 12.5,
                      fontWeight:
                          selected ? FontWeight.w700 : FontWeight.normal,
                    )),
                if (trailing != null) ...[
                  const SizedBox(width: 5),
                  Icon(trailing, size: 14, color: const Color(0xFFFFD54F)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _list(List<LeaderboardRow> rows) {
    final axis = _axis;
    if (rows.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            axis == null
                ? 'No plants picked yet.\nBe the first.'
                : 'Nobody has rated a plant on this scale yet.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF9CCC9F), height: 1.5),
          ),
        ),
      );
    }
    return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
          itemCount: rows.length,
          itemBuilder: (_, i) {
            final r = rows[i];
            final medal = i == 0
                ? const Color(0xFFFFD54F)
                : i == 1
                    ? const Color(0xFFCFD8DC)
                    : i == 2
                        ? const Color(0xFFBCAAA4)
                        : const Color(0xFF2A4A2F);
            return GestureDetector(
              onTap: () => _showAverages(context, r),
              child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF111F16),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: i < 3 ? medal : const Color(0xFF2A4A2F),
                    width: i < 3 ? 1.5 : 1),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 28,
                    child: Text('${i + 1}',
                        style: TextStyle(
                            color: medal,
                            fontSize: 16,
                            fontWeight: FontWeight.w800)),
                  ),
                  _WikiThumb(plantName: r.plantName),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(r.plantName,
                            style: const TextStyle(
                                color: Color(0xFFE8F5E9),
                                fontSize: 14.5,
                                fontWeight: FontWeight.w600)),
                        if (r.plantSection.isNotEmpty)
                          Text(r.plantSection,
                              style: const TextStyle(
                                  color: Color(0xFF4A7A50), fontSize: 11.5)),
                      ],
                    ),
                  ),
                  // On a scale board the ranking number IS the average, so
                  // show that; the pick count stays underneath because an
                  // average of one person's opinion deserves less weight.
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        axis == null
                            ? '${r.votes}'
                            : r.averageFor(axis.key)!.toStringAsFixed(1),
                        style: TextStyle(
                            color: axis == null
                                ? const Color(0xFF81C784)
                                : const Color(0xFFFFD54F),
                            fontSize: 17,
                            fontWeight: FontWeight.w800),
                      ),
                      Text(
                        axis == null
                            ? (r.votes == 1 ? 'pick' : 'picks')
                            : '${r.votes} ${r.votes == 1 ? "pick" : "picks"}',
                        style: const TextStyle(
                            color: Color(0xFF4A7A50), fontSize: 10.5),
                      ),
                    ],
                  ),
                  const Padding(
                    padding: EdgeInsets.only(left: 4),
                    child: Icon(Icons.expand_more_rounded,
                        size: 18, color: Color(0xFF4A7A50)),
                  ),
                ],
              ),
            ),
            );
          },
        );
  }

  /// How everyone who picked this plant saw it — the mean position on each
  /// scale. Shown on tap rather than inline: it is the interesting detail, but
  /// five bars per row would bury the ranking itself.
  void _showAverages(BuildContext context, LeaderboardRow r) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0D1F14),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      // Scrollable and height-capped: five scales plus the header overflow a
      // shrink-wrapped sheet on shorter screens, and a fixed-height sheet would
      // clip instead. This adapts to however many axes the contest defines.
      isScrollControlled: true,
      builder: (_) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.8,
          ),
          child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // A picture of the plant itself, so the sheet is recognisable
              // to someone who saw it in the garden but never caught the name.
              _WikiPhoto(plantName: r.plantName),
              Text(r.plantName,
                  style: const TextStyle(
                      color: Color(0xFFE8F5E9),
                      fontSize: 17,
                      fontWeight: FontWeight.w700)),
              if (r.plantSection.isNotEmpty)
                Text(r.plantSection,
                    style: const TextStyle(
                        color: Color(0xFF4A7A50), fontSize: 12)),
              const SizedBox(height: 4),
              Text(
                '${r.votes} ${r.votes == 1 ? "person" : "people"} picked it · average of their scales',
                style: const TextStyle(color: Color(0xFF9CCC9F), fontSize: 12.5),
              ),
              const SizedBox(height: 18),
              for (final a in contest.axes)
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: _MiniScale(
                    left: a.left,
                    right: a.right,
                    value: r.averageFor(a.key) ?? 0,
                    showValue: true,
                  ),
                ),

              // Who picked it — the prize goes to a person or a team, so the
              // names have to be visible without opening the database.
              const Divider(color: Color(0xFF2A4A2F), height: 26),
              const Text('PICKED BY',
                  style: TextStyle(
                      color: Color(0xFF81C784),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final p in r.pickers)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF13301A),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: p.teamName == null
                                ? const Color(0xFF2A4A2F)
                                : const Color(0xFF8D6E00)),
                      ),
                      child: Text(p.label,
                          style: TextStyle(
                              color: p.teamName == null
                                  ? const Color(0xFFCFE8D2)
                                  : const Color(0xFFFFD54F),
                              fontSize: 12)),
                    ),
                ],
              ),
            ],
          ),
          ),
        ),
      ),
    );
  }
}

/// Wide Wikipedia photo for the leaderboard detail sheet.
///
/// Renders nothing at all when there is no image — an empty grey box above the
/// plant name would be worse than starting straight at the name.
class _WikiPhoto extends StatelessWidget {
  const _WikiPhoto({required this.plantName});
  final String plantName;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: WikipediaImageService.instance.findImage(
        scientificName: plantName,
      ),
      builder: (_, snap) {
        if (snap.data == null) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: Image.network(
                snap.data!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Wikipedia thumbnail for a leaderboard row.
///
/// Best-effort: visitors can type any name they like, so a miss is normal and
/// falls back to a leaf icon rather than an error. The service caches per name,
/// so a rebuilding list does not re-fetch.
class _WikiThumb extends StatelessWidget {
  const _WikiThumb({required this.plantName});
  final String plantName;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: WikipediaImageService.instance.findImage(
        scientificName: plantName,
      ),
      builder: (_, snap) => Container(
        width: 42,
        height: 42,
        margin: const EdgeInsets.only(right: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF13301A),
          borderRadius: BorderRadius.circular(8),
          image: snap.data == null
              ? null
              : DecorationImage(
                  image: NetworkImage(snap.data!), fit: BoxFit.cover),
        ),
        child: snap.data == null
            ? const Icon(Icons.local_florist_rounded,
                size: 18, color: Color(0xFF4A7A50))
            : null,
      ),
    );
  }
}

class _MyPicks extends StatelessWidget {
  const _MyPicks({required this.contest, required this.uid});
  final Contest contest;
  final String uid;

  @override
  Widget build(BuildContext context) {
    if (uid.isEmpty) {
      return const Center(
        child: Text('Sign in to take part.',
            style: TextStyle(color: Color(0xFF9CCC9F))),
      );
    }
    return StreamBuilder<List<ContestEntry>>(
      stream: ContestService.instance.watchMyEntries(contest.id, uid),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final mine = snap.data!..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        if (mine.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Text(
                "You haven't picked a plant yet.\nTap “Add a plant” to start.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF9CCC9F), height: 1.5),
              ),
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          itemCount: mine.length,
          itemBuilder: (_, i) => _MyPickCard(entry: mine[i], contest: contest),
        );
      },
    );
  }
}

class _MyPickCard extends StatelessWidget {
  const _MyPickCard({required this.entry, required this.contest});
  final ContestEntry entry;
  final Contest contest;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF111F16),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF2A4A2F)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // The photo the visitor actually took, full width — this tab is
          // their own record of the walk, so their picture is the point of the
          // card rather than a detail on it. Storage rules keep it readable by
          // them and an admin only.
          if (entry.photoPath != null)
            FutureBuilder<String?>(
              future: ContestService.instance.photoUrl(entry.photoPath),
              builder: (_, s) => s.data == null
                  ? const SizedBox.shrink()
                  : Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: AspectRatio(
                          aspectRatio: 4 / 3,
                          child: Image.network(
                            s.data!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                const SizedBox.shrink(),
                          ),
                        ),
                      ),
                    ),
            ),
          Row(
            children: [
              // No photo (or it would not load): a reference picture of the
              // plant stands in rather than an empty square.
              if (entry.photoPath == null)
                _WikiThumb(plantName: entry.plantName),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(entry.plantName,
                        style: const TextStyle(
                            color: Color(0xFFE8F5E9),
                            fontSize: 14.5,
                            fontWeight: FontWeight.w600)),
                    if (entry.plantSection.isNotEmpty)
                      Text(entry.plantSection,
                          style: const TextStyle(
                              color: Color(0xFF4A7A50), fontSize: 11.5)),
                    if (entry.teamName != null)
                      Text('Team ${entry.teamName}',
                          style: const TextStyle(
                              color: Color(0xFFFFB74D), fontSize: 11.5)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (final a in contest.axes)
            if (entry.ratings[a.key] != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: _MiniScale(
                  left: a.left,
                  right: a.right,
                  value: entry.ratings[a.key]!.toDouble(),
                ),
              ),
        ],
      ),
    );
  }
}

/// Read-only rendering of a position on one scale.
///
/// Takes a double so it renders both a single person's choice (a whole number)
/// and the crowd's mean (rarely one). [showValue] adds a centre tick and a
/// numeric label — useful for an average, noise for one person's own pick.
class _MiniScale extends StatelessWidget {
  const _MiniScale({
    required this.left,
    required this.right,
    required this.value,
    this.showValue = false,
  });

  final String left;
  final String right;
  final double value;
  final bool showValue;

  @override
  Widget build(BuildContext context) {
    // -5..5 -> 0..1
    final t = ((value + 5) / 10).clamp(0.0, 1.0);
    final labelStyle = TextStyle(
      color: showValue ? const Color(0xFFCFE8D2) : const Color(0xFF6E8A72),
      fontSize: showValue ? 12.5 : 10.5,
      fontWeight: showValue ? FontWeight.w600 : FontWeight.normal,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(left, style: labelStyle)),
            Text(right, style: labelStyle),
          ],
        ),
        const SizedBox(height: 4),
        LayoutBuilder(
          builder: (_, box) => Stack(
            alignment: Alignment.centerLeft,
            children: [
              Container(
                height: showValue ? 8 : 6,
                decoration: BoxDecoration(
                  color: const Color(0xFF13301A),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              // Centre tick: without it, "slightly cute" and "slightly creepy"
              // look identical at a glance.
              if (showValue)
                Positioned(
                  left: box.maxWidth / 2 - 0.5,
                  child: Container(
                      width: 1, height: 8, color: const Color(0xFF2A4A2F)),
                ),
              Positioned(
                left: (box.maxWidth - 12) * t,
                child: Container(
                  width: 12,
                  height: showValue ? 8 : 6,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFD54F),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (showValue)
          Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Text(
              value.toStringAsFixed(1),
              style: const TextStyle(color: Color(0xFF6E8A72), fontSize: 10.5),
            ),
          ),
      ],
    );
  }
}

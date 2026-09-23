// lib/screens/researchers_night_screen.dart
//
// Researchers' Night at the Botanical Garden — Friday 25 September 2026.
//
// This app is not a bystander at this event: the University's own programme
// lists it by name as "Secrets of Plants", and promises visitors that they
// will "choose your own route, identify plants along the way, and make
// surprising botanical discoveries. At the end, you can cast your vote."
//
// So the screen is built as those three steps in that order, and the rest of
// the evening's programme sits underneath — a visitor holding this app in
// meeting room Vanamo should be able to find out what else is on and where,
// without going back to a website on a phone in a dark greenhouse.
//
// The programme is hardcoded rather than fetched. It is one evening, it was
// published a week ago, and a screen that fails because a network call failed
// is worse than one that cannot be edited without a release.

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../models/contest.dart';
import '../services/contest_service.dart';
import '../theme/tokens.dart';
import '../widgets/ui_kit.dart';
import 'camera_screen.dart';
import 'contest/contest_screen.dart';
import 'trail_screen.dart';

/// When the doors are open. Used to decide whether the app says "tonight",
/// "tomorrow" or nothing at all.
final kResearchersNight = DateTime(2026, 9, 25, 17);
final kResearchersNightEnds = DateTime(2026, 9, 25, 21);

/// True from the morning of the event until the doors close.
bool get isResearchersNightToday {
  final now = DateTime.now();
  return now.year == kResearchersNight.year &&
      now.month == kResearchersNight.month &&
      now.day == kResearchersNight.day &&
      now.isBefore(kResearchersNightEnds.add(const Duration(hours: 3)));
}

/// True the day before, so the app can trail it without claiming it is on.
bool get isResearchersNightTomorrow {
  final now = DateTime.now();
  final eve = kResearchersNight.subtract(const Duration(days: 1));
  return now.year == eve.year && now.month == eve.month && now.day == eve.day;
}

/// Worth showing at all — from a week out to the end of the night.
bool get isResearchersNightSoon {
  final now = DateTime.now();
  return now.isAfter(kResearchersNight.subtract(const Duration(days: 7))) &&
      now.isBefore(kResearchersNightEnds.add(const Duration(hours: 3)));
}

/// Doors are open right now.
bool get isResearchersNightLive {
  final now = DateTime.now();
  return now.isAfter(kResearchersNight.subtract(const Duration(hours: 2))) &&
      now.isBefore(kResearchersNightEnds.add(const Duration(hours: 1)));
}

// ─── Programme ────────────────────────────────────────────────────────────────

class _Activity {
  const _Activity({
    required this.icon,
    required this.title,
    required this.blurb,
    required this.where,
    this.time,
    this.accent = C.accent,
  });

  final IconData icon;
  final String title;
  final String blurb;
  final String where;
  final String? time;
  final Color accent;
}

/// Everything happening at the garden, from the University's programme.
const _kProgramme = <_Activity>[
  _Activity(
    icon: Icons.smart_toy_rounded,
    title: 'Nature Robots',
    blurb:
        'A ladybug that reacts to temperature, a sunflower that follows the '
        'light, and a duck that checks water quality. Say hello to the parrot '
        'and see what it does — and look carefully, there is something '
        'magical hidden in the greenhouse.',
    where: 'Greenhouse Juliet',
    accent: Color(0xFF60A5FA),
  ),
  _Activity(
    icon: Icons.air_rounded,
    title: 'Scents and Sounds from Around the World',
    blurb:
        'Press the button and travel through your senses. What does nature '
        'far from Finland sound and smell like?',
    where: 'Greenhouse Juliet',
    accent: Color(0xFFC084FC),
  ),
  _Activity(
    icon: Icons.emoji_nature_rounded,
    title: 'The Bug Academy',
    blurb:
        'Live bumblebees, ants and butterflies, the researchers who study '
        'them, and a bug-drawing point if you would rather draw one.',
    where: 'Multifunctional space Sara',
    accent: Color(0xFFFBBF24),
  ),
  _Activity(
    icon: Icons.hive_rounded,
    title: 'Visit a Beehive',
    blurb:
        'A working hive behind glass. Taste the honey, buy some, and ask the '
        'beekeeper anything.',
    where: 'Botanical Garden lobby',
    accent: Color(0xFFFBBF24),
  ),
  _Activity(
    icon: Icons.music_note_rounded,
    title: 'Harmonia',
    blurb:
        'A mixed choir improvising through the garden, where music, nature '
        'and science meet. They move between locations — follow the sound.',
    where: 'Around the garden',
    time: '17:30 – 19:30',
    accent: Color(0xFFF472B6),
  ),
  _Activity(
    icon: Icons.local_fire_department_rounded,
    title: 'Making Biochar',
    blurb:
        'Brushwood into biochar in a cone kiln, and what it does for soil '
        'once it gets there.',
    where: 'Yard area',
    accent: Color(0xFFFB7185),
  ),
];

// ─── Screen ───────────────────────────────────────────────────────────────────

class ResearchersNightScreen extends StatelessWidget {
  const ResearchersNightScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar(
            backgroundColor: C.bg,
            surfaceTintColor: Colors.transparent,
            pinned: true,
            expandedHeight: 168,
            iconTheme: const IconThemeData(color: C.accent),
            flexibleSpace: FlexibleSpaceBar(
              // Left inset clears the back arrow: at the collapsed height the
              // title slides under it and the first letter is lost.
              titlePadding: const EdgeInsets.fromLTRB(56, 0, Sp.gutter, 15),
              title: const Text('Researchers’ Night',
                  style: TextStyle(
                      color: C.textHi,
                      fontSize: 17,
                      fontWeight: FontWeight.w700)),
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF15301F), C.bg],
                  ),
                ),
                child: const Align(
                  alignment: Alignment(-0.85, 0.05),
                  child: _WhenBadge(),
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(Sp.gutter, Sp.s, Sp.gutter, Sp.huge),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const Text(
                  'Become a Plant Adventurer. Choose your own route through '
                  'the garden, identify what you meet along the way, and make '
                  'a few surprising discoveries — then tell us which plant '
                  'deserves the title.',
                  style: T.body,
                ),
                const SizedBox(height: Sp.xxl),

                const SectionTitle('Your three steps', color: C.accent),
                _Step(
                  n: '1',
                  icon: Icons.route_rounded,
                  title: 'Choose your route',
                  subtitle:
                      'Ten themed trails through the greenhouses and grounds.',
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const TrailScreen())),
                ),
                _Step(
                  n: '2',
                  icon: Icons.center_focus_strong_rounded,
                  title: 'Identify what you find',
                  subtitle:
                      'Point the camera at any plant and it will tell you '
                      'what it is.',
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const CameraScreen())),
                ),
                const _VoteStep(),

                const SizedBox(height: Sp.xxl),
                const SectionTitle('Also on tonight'),
                for (final a in _kProgramme) _ActivityCard(activity: a),

                const SizedBox(height: Sp.s),
                const _GettingThere(),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _WhenBadge extends StatelessWidget {
  const _WhenBadge();

  @override
  Widget build(BuildContext context) {
    final live = isResearchersNightLive;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (live) ...[
          const LiveDot(),
          const SizedBox(width: Sp.s),
          const Text('HAPPENING NOW',
              style: TextStyle(
                  color: C.hot,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.3)),
        ] else
          const Text('FRI 25 SEPT  ·  17:00 – 21:00',
              style: TextStyle(
                  color: C.accent,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.3)),
      ],
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({
    required this.n,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.accent = C.accent,
    this.trailing,
  });

  final String n;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Color accent;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Sp.m),
      child: AppCard(
        onTap: onTap,
        child: Row(
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                IconTile(icon, color: accent),
                Positioned(
                  right: -2,
                  top: -2,
                  child: Container(
                    width: 18,
                    height: 18,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: accent,
                      shape: BoxShape.circle,
                    ),
                    child: Text(n,
                        style: const TextStyle(
                            color: C.bg,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w900)),
                  ),
                ),
              ],
            ),
            const SizedBox(width: Sp.l),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: T.h2),
                  const SizedBox(height: 3),
                  Text(subtitle, style: T.bodySm),
                ],
              ),
            ),
            trailing ??
                const Icon(Icons.arrow_forward_ios_rounded,
                    size: 14, color: C.textFaint),
          ],
        ),
      ),
    );
  }
}

/// Step three only works if a vote is actually configured, so it reads the
/// live contest rather than promising something that is not there.
class _VoteStep extends StatelessWidget {
  const _VoteStep();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Contest?>(
      stream: ContestService.instance.watchContest(),
      builder: (context, snap) {
        final c = snap.data;
        final open = c != null && c.isLive;
        return _Step(
          n: '3',
          icon: Icons.how_to_vote_rounded,
          title: 'Cast your vote',
          subtitle: open
              ? 'Which plant is the strangest, most beautiful, or most '
                  'astonishing?'
              : 'Opens when the doors do, at 17:00.',
          accent: open ? C.gold : C.textFaint,
          trailing: open
              ? const Pill('OPEN', color: C.gold)
              : const Icon(Icons.lock_clock_rounded,
                  size: 16, color: C.textFaint),
          onTap: () {
            if (open) {
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => ContestScreen(contest: c)));
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  backgroundColor: C.surfaceAlt,
                  content: Text(
                    'Voting opens at 17:00 on Friday — come back then.',
                    style: TextStyle(color: C.textHi),
                  ),
                ),
              );
            }
          },
        );
      },
    );
  }
}

class _ActivityCard extends StatelessWidget {
  const _ActivityCard({required this.activity});
  final _Activity activity;

  @override
  Widget build(BuildContext context) {
    final a = activity;
    return Padding(
      padding: const EdgeInsets.only(bottom: Sp.m),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IconTile(a.icon, color: a.accent, size: 40),
                const SizedBox(width: Sp.m),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(a.title, style: T.h2.copyWith(fontSize: 15.5)),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(Icons.place_rounded,
                              size: 12, color: C.textFaint),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(a.where,
                                style: T.label.copyWith(
                                    color: C.textFaint, fontSize: 11.5)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (a.time != null) Pill(a.time!, color: a.accent),
              ],
            ),
            const SizedBox(height: Sp.m),
            Text(a.blurb, style: T.bodySm),
          ],
        ),
      ),
    );
  }
}

class _GettingThere extends StatelessWidget {
  const _GettingThere();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      color: C.surfaceAlt,
      child: Row(
        children: [
          const IconTile(Icons.tram_rounded, color: C.accent, size: 40),
          const SizedBox(width: Sp.m),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Getting here is free', style: T.h2),
                SizedBox(height: 3),
                Text(
                  'The Potnapekka minitrain runs continuously between campus '
                  'door 2T and the Botanical Garden, 17:00 – 21:00.',
                  style: T.bodySm,
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms);
  }
}

// ─── Home-screen entry point ──────────────────────────────────────────────────

/// The banner that takes people here. Renders nothing outside the week of the
/// event, so the home screen is not carrying a dead card for the other 51.
class ResearchersNightBanner extends StatelessWidget {
  const ResearchersNightBanner({super.key});

  @override
  Widget build(BuildContext context) {
    if (!isResearchersNightSoon) return const SizedBox.shrink();

    final live = isResearchersNightLive;
    final when = live
        ? 'Happening now · until 21:00'
        : isResearchersNightToday
            ? 'Tonight · 17:00 – 21:00'
            : isResearchersNightTomorrow
                ? 'Tomorrow · 17:00 – 21:00'
                : 'Fri 25 Sept · 17:00 – 21:00';

    return Padding(
      padding: const EdgeInsets.only(bottom: Sp.xxl),
      child: AppCard(
        accent: live ? C.hot : C.accent,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ResearchersNightScreen()),
        ),
        padding: const EdgeInsets.all(Sp.l + 2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (live) ...[
                  const LiveDot(),
                  const SizedBox(width: Sp.s),
                ],
                Text(when.toUpperCase(),
                    style: T.overline.copyWith(
                        color: live ? C.hot : C.accent, letterSpacing: 1.2)),
              ],
            ),
            const SizedBox(height: Sp.m),
            const Text('Researchers’ Night', style: T.display),
            const SizedBox(height: Sp.s),
            const Text(
              'Secrets of Plants — pick a route, identify what you find, and '
              'vote for the strangest plant in the garden.',
              style: T.bodySm,
            ),
            const SizedBox(height: Sp.l),
            Row(
              children: [
                const Pill('Your route', icon: Icons.route_rounded),
                const SizedBox(width: Sp.s),
                const Pill('Vote', icon: Icons.how_to_vote_rounded, color: C.gold),
                const Spacer(),
                Icon(Icons.arrow_forward_rounded,
                    size: 18, color: live ? C.hot : C.accent),
              ],
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 500.ms).slideY(begin: 0.08, curve: Curves.easeOut);
  }
}

// lib/screens/home_screen.dart
//
// The first screen, rebuilt on lib/theme/tokens.dart.
//
// What changed and why, since the old version worked perfectly well and this
// is otherwise churn:
//
//   • Outlines gone. Every card used to carry a 1px border, which is the
//     single thing that made the app read as a decade old. Depth is surface
//     tint now.
//
//   • The clashing gradients are gone with them. Primary cards were saturated
//     purple, magenta and orange — three unrelated hues on one screen, none of
//     them botanical. One green accent carries every action; gold is reserved
//     for things you earn.
//
//   • A real type scale. Almost everything used to sit at 12-14pt, so nothing
//     looked more important than anything else. The greeting is now 30pt and
//     the hierarchy does the work headings used to.
//
//   • More air: 20pt gutters instead of 16, taller cards, bigger tap targets.
//
// Every destination the old screen offered is still here, in the same order.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../i18n/app_strings.dart';
import '../services/garden_schedule.dart';
import '../services/language_service.dart';
import '../theme/tokens.dart';
import '../widgets/did_you_know_card.dart';
import '../widgets/ongoing_contest_card.dart';
import '../widgets/ui_kit.dart';
import 'bloom_screen.dart';
import 'camera_screen.dart';
import 'event_request_screen.dart';
import 'events_screen.dart';
import 'gallery/gallery_screen.dart';
import 'main_nav_screen.dart';
import 'plants_screen.dart';
import 'report_screen.dart';
import 'researchers_night_screen.dart';
import 'schedule_screen.dart';
import 'soundscape_screen.dart';
import 'trail_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  static Route<void> _to(Widget page) => PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 260),
        pageBuilder: (_, a, __) => page,
        transitionsBuilder: (_, a, __, child) => FadeTransition(
          opacity: a,
          child: SlideTransition(
            position: Tween(begin: const Offset(0, 0.02), end: Offset.zero)
                .animate(CurvedAnimation(parent: a, curve: Curves.easeOut)),
            child: child,
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final s = context.watch<LanguageService>().strings;
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? s.goodMorning
        : hour < 17
            ? s.goodAfternoon
            : s.goodEvening;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: C.bg,
        body: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            _appBar(s),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                  Sp.gutter, Sp.l, Sp.gutter, Sp.huge),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _Greeting(greeting: greeting, s: s),
                  const SizedBox(height: Sp.xxl),

                  // Renders nothing outside the week of the event.
                  const ResearchersNightBanner(),

                  // Plant Hunt plus whatever timed challenge is running.
                  const OngoingContestCard(),

                  SectionTitle(s.sectionDidYouKnow),
                  const DidYouKnowCard(),
                  const SizedBox(height: Sp.xxl),

                  SectionTitle(s.sectionExplore),
                  ActionTile(
                    icon: Icons.center_focus_strong_rounded,
                    title: s.identifyAPlant,
                    subtitle: s.pointCameraToPlant,
                    featured: true,
                    onTap: () =>
                        Navigator.push(context, _to(const CameraScreen())),
                  ),
                  const SizedBox(height: Sp.m),
                  ActionTile(
                    icon: Icons.menu_book_rounded,
                    title: s.knowPlants,
                    subtitle: s.knowPlantsSub,
                    onTap: () =>
                        Navigator.push(context, _to(const PlantsScreen())),
                  ),
                  const SizedBox(height: Sp.m),
                  ActionTile(
                    icon: Icons.photo_camera_back_rounded,
                    title: s.gardenDiary,
                    subtitle: s.gardenDiarySub,
                    onTap: () =>
                        Navigator.push(context, _to(const GalleryScreen())),
                  ),
                  const SizedBox(height: Sp.xxl),

                  SectionTitle(s.sectionGarden),
                  _Grid(children: [
                    MiniTile(
                      icon: Icons.local_florist_rounded,
                      title: s.inBloom,
                      subtitle: s.seasonSection,
                      onTap: () =>
                          Navigator.push(context, _to(const BloomScreen())),
                    ),
                    MiniTile(
                      icon: Icons.route_rounded,
                      title: s.trails,
                      subtitle: s.selfGuidedGps,
                      onTap: () =>
                          Navigator.push(context, _to(const TrailScreen())),
                    ),
                    MiniTile(
                      icon: Icons.calendar_month_rounded,
                      title: s.upcomingEvents,
                      subtitle: s.toursHours,
                      onTap: () =>
                          Navigator.push(context, _to(const EventsScreen())),
                    ),
                    MiniTile(
                      icon: Icons.graphic_eq_rounded,
                      title: s.soundscape,
                      subtitle: s.ambientLive,
                      onTap: () => Navigator.push(
                          context, _to(const SoundscapeScreen())),
                    ),
                    MiniTile(
                      icon: Icons.event_available_rounded,
                      title: s.organizeEvent,
                      subtitle: s.eventPlanner,
                      onTap: () => Navigator.push(
                          context, _to(const EventRequestScreen())),
                    ),
                    MiniTile(
                      icon: Icons.report_problem_rounded,
                      title: s.report,
                      subtitle: s.pestIssueNote,
                      color: C.hot,
                      onTap: () =>
                          Navigator.push(context, _to(const ReportScreen())),
                    ),
                  ]),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  SliverAppBar _appBar(AppStrings s) {
    return SliverAppBar(
      pinned: true,
      backgroundColor: C.bg,
      surfaceTintColor: Colors.transparent,
      // No bottom hairline: the old one drew a hard rule across the top of
      // every scroll, which is exactly the kind of hard outline this redesign
      // removes elsewhere.
      elevation: 0,
      toolbarHeight: 66,
      titleSpacing: 0,
      leading: IconButton(
        icon: const Icon(Icons.menu_rounded, color: C.textSoft),
        onPressed: () => MainNavScreen.scaffoldKey.currentState?.openDrawer(),
      ),
      title: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.asset('logo.png', width: 32, height: 32,
                fit: BoxFit.cover),
          ),
          const SizedBox(width: Sp.m),
          const Expanded(
            child: Text('Botanica',
                style: TextStyle(
                    color: C.textHi,
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2)),
          ),
        ],
      ),
      actions: [
        Builder(
          builder: (ctx) => Padding(
            padding: const EdgeInsets.only(right: Sp.gutter),
            child: GestureDetector(
              onTap: () => Navigator.push(ctx,
                  MaterialPageRoute(builder: (_) => const ScheduleScreen())),
              child: _OpenChip(open: GardenSchedule.isOpen(), s: s),
            ),
          ),
        ),
      ],
    );
  }
}

/// Open / closed, and a way into the opening hours.
class _OpenChip extends StatelessWidget {
  const _OpenChip({required this.open, required this.s});
  final bool open;
  final AppStrings s;

  @override
  Widget build(BuildContext context) {
    final c = open ? C.accent : C.textFaint;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(R.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: c, shape: BoxShape.circle),
          ),
          const SizedBox(width: 7),
          Text(open ? s.statusOpen : s.statusClosed,
              style: TextStyle(
                  color: c, fontSize: 12, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

/// Big, quiet, and the only display-sized type on the screen.
class _Greeting extends StatelessWidget {
  const _Greeting({required this.greeting, required this.s});
  final String greeting;
  final AppStrings s;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(greeting, style: T.display),
        const SizedBox(height: Sp.s),
        Text(s.welcomeMessage, style: T.body.copyWith(color: C.textSoft)),
      ],
    ).animate().fadeIn(duration: 450.ms).slideY(
        begin: 0.06, curve: Curves.easeOut);
  }
}

/// Two-column grid that keeps its rows the same height without a fixed aspect
/// ratio, so a long label wraps instead of being clipped.
class _Grid extends StatelessWidget {
  const _Grid({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i += 2) {
      rows.add(IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: children[i]),
            const SizedBox(width: Sp.m),
            Expanded(
              child: i + 1 < children.length
                  ? children[i + 1]
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ));
      if (i + 2 < children.length) rows.add(const SizedBox(height: Sp.m));
    }
    return Column(children: rows);
  }
}

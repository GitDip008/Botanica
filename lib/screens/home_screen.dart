import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../i18n/app_strings.dart';
import '../services/garden_schedule.dart';
import '../services/language_service.dart';
import 'camera_screen.dart';
import 'bloom_screen.dart';
import 'plants_screen.dart';
import 'gallery/gallery_screen.dart';
import 'report_screen.dart';
import 'events_screen.dart';
import 'trail_screen.dart';
import 'soundscape_screen.dart';
import '../widgets/did_you_know_card.dart';
import '../widgets/ongoing_contest_card.dart';
import 'about_us_screen.dart';
import 'event_request_screen.dart';
import 'main_nav_screen.dart';
import 'schedule_screen.dart';

// ── Design tokens ──────────────────────────────────────────────────────────────
const _bg         = Color(0xFF0A1A0F);
const _surface    = Color(0xFF111F16);
const _border     = Color(0xFF2A4A2F);
const _green      = Color(0xFF4CAF50);
const _greenLight = Color(0xFF81C784);
const _textPri    = Color(0xFFE8F5E9);
const _textSec    = Color(0xFF81C784);
const _textDim    = Color(0xFF4A7A50);

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

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
        backgroundColor: _bg,
        body: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            _buildAppBar(s),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _HeroBanner(greeting: greeting, s: s)
                        .animate().fadeIn(duration: 500.ms),
                    const SizedBox(height: 20),

                    // Plant Hunt plus whatever timed event is running.
                    const OngoingContestCard(),

                    _sectionLabel(s.sectionDidYouKnow),
                    const SizedBox(height: 10),

                    const DidYouKnowCard()
                        .animate().fadeIn(duration: 500.ms, delay: 80.ms),

                    const SizedBox(height: 24),

                    _sectionLabel(s.sectionExplore),
                    const SizedBox(height: 10),

                    _PrimaryCard(
                      icon: Icons.camera_alt_rounded,
                      iconColor: _green,
                      title: s.identifyAPlant,
                      subtitle: s.pointCameraToPlant,
                      gradient: const LinearGradient(
                        colors: [Color(0xFF1B4020), Color(0xFF2E7D32)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      onTap: () => Navigator.push(context,
                          _route(const CameraScreen())),
                    ).animate().slideY(begin: 0.15, duration: 400.ms, delay: 80.ms, curve: Curves.easeOut),

                    const SizedBox(height: 10),

                    // Plant Hunt now lives in the Ongoing Contests section
                    // at the top of this screen, next to whatever event is
                    // running — it is a competition, not a way to explore.


                    // Greenhouse navigation is hidden for now: indoor positioning
                    // depends on BLE beacons that are not installed yet, and it has
                    // no web implementation at all. The screen and its A* routing
                    // remain in the tree (lib/screens/navigation_screen/) — restore
                    // the card here once beacons exist.

                    // ── Know your plants (browse the garden's own records) ────
                    _PrimaryCard(
                      icon: Icons.menu_book_rounded,
                      iconColor: const Color(0xFFFFB74D),
                      title: s.knowPlants,
                      subtitle: s.knowPlantsSub,
                      gradient: const LinearGradient(
                        colors: [Color(0xFF3A2A06), Color(0xFF8D6E00)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      onTap: () =>
                          Navigator.push(context, _route(const PlantsScreen())),
                    ).animate().slideY(begin: 0.15, duration: 400.ms, delay: 260.ms, curve: Curves.easeOut),

                    const SizedBox(height: 10),

                    // ── Garden Diary (personal photos, optionally shared) ────
                    _PrimaryCard(
                      icon: Icons.photo_library_rounded,
                      iconColor: const Color(0xFFF06292),
                      title: s.gardenDiary,
                      subtitle: s.gardenDiarySub,
                      gradient: const LinearGradient(
                        colors: [Color(0xFF3A0E28), Color(0xFF9C27B0)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      onTap: () =>
                          Navigator.push(context, _route(const GalleryScreen())),
                    ).animate().slideY(begin: 0.15, duration: 400.ms, delay: 300.ms, curve: Curves.easeOut),

                    const SizedBox(height: 24),

                    _sectionLabel(s.sectionGarden),
                    const SizedBox(height: 10),

                    // Row 1 — In Bloom + Trails
                    Row(children: [
                      Expanded(
                        child: _FeatureCard(
                          icon: Icons.local_florist_rounded,
                          iconBg: const Color(0xFF2E1A00),
                          iconColor: const Color(0xFFFFB74D),
                          title: s.inBloom,
                          subtitle: s.seasonSection,
                          onTap: () => Navigator.push(context,
                              _route(const BloomScreen())),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _FeatureCard(
                          icon: Icons.route_rounded,
                          iconBg: const Color(0xFF1A0800),
                          iconColor: const Color(0xFFFF8A65),
                          title: s.trails,
                          subtitle: s.selfGuidedGps,
                          onTap: () => Navigator.push(context,
                              _route(const TrailScreen())),
                        ),
                      ),
                    ]).animate().slideY(begin: 0.15, duration: 400.ms, delay: 220.ms, curve: Curves.easeOut),

                    const SizedBox(height: 10),

                    // Row 2 — Upcoming Events + Soundscape
                    Row(children: [
                      Expanded(
                        child: _FeatureCard(
                          icon: Icons.calendar_month_rounded,
                          iconBg: const Color(0xFF120A2E),
                          iconColor: const Color(0xFFB39DDB),
                          title: s.upcomingEvents,
                          subtitle: s.toursHours,
                          onTap: () => Navigator.push(context,
                              _route(const EventsScreen())),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _FeatureCard(
                          icon: Icons.graphic_eq_rounded,
                          iconBg: const Color(0xFF001A14),
                          iconColor: const Color(0xFF4DB6AC),
                          title: s.soundscape,
                          subtitle: s.ambientLive,
                          onTap: () => Navigator.push(context,
                              _route(const SoundscapeScreen())),
                        ),
                      ),
                    ]).animate().slideY(begin: 0.15, duration: 400.ms, delay: 270.ms, curve: Curves.easeOut),

                    const SizedBox(height: 10),

                    // Row 3 — Organize Event + Report
                    Row(children: [
                      Expanded(
                        child: _FeatureCard(
                          icon: Icons.event_available_rounded,
                          iconBg: const Color(0xFF0A1F2D),
                          iconColor: const Color(0xFF4FC3F7),
                          title: s.organizeEvent,
                          subtitle: s.eventPlanner,
                          onTap: () => Navigator.push(context,
                              _route(const EventRequestScreen())),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _FeatureCard(
                          icon: Icons.bug_report_rounded,
                          iconBg: const Color(0xFF1A0010),
                          iconColor: const Color(0xFFF48FB1),
                          title: s.report,
                          subtitle: s.pestIssueNote,
                          onTap: () => Navigator.push(context,
                              _route(const ReportScreen())),
                        ),
                      ),
                    ]).animate().slideY(begin: 0.15, duration: 400.ms, delay: 320.ms, curve: Curves.easeOut),

                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  SliverAppBar _buildAppBar(AppStrings s) {
    return SliverAppBar(
      pinned: true,
      backgroundColor: _bg,
      surfaceTintColor: Colors.transparent,
      toolbarHeight: 64,
      leading: IconButton(
        icon: const Icon(Icons.menu_rounded, color: _greenLight),
        onPressed: () =>
            MainNavScreen.scaffoldKey.currentState?.openDrawer(),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF0A1A0F), Color(0xFF0D2215)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: _border),
      ),
      title: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _border, width: 1),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(9),
              child: Image.asset('logo.png', fit: BoxFit.cover),
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text('Botanica',
                style: TextStyle(
                    color: _textPri,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3)),
          ),
          Builder(
            builder: (ctx) => GestureDetector(
              onTap: () => Navigator.push(
                ctx,
                MaterialPageRoute(builder: (_) => const ScheduleScreen()),
              ),
              child: _StatusChip(
                label: GardenSchedule.isOpen() ? s.statusOpen : s.statusClosed,
                isOpen: GardenSchedule.isOpen(),
                hint: s.tapToView,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        color: _textDim,
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.4,
      ),
    );
  }

  PageRoute _route(Widget screen) =>
      MaterialPageRoute(builder: (_) => screen);
}

// ── Status chip ────────────────────────────────────────────────────────────────
class _StatusChip extends StatelessWidget {
  final String label;
  final bool isOpen;
  final String hint;
  const _StatusChip({
    required this.label,
    required this.isOpen,
    required this.hint,
  });

  @override
  Widget build(BuildContext context) {
    final dotColor = isOpen ? const Color(0xFF66BB6A) : const Color(0xFFEF5350);
    final textColor = isOpen ? _greenLight : const Color(0xFFFFCDD2);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 7, height: 7,
                decoration:
                    BoxDecoration(color: dotColor, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              Text(label,
                  style: TextStyle(
                      color: textColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      height: 1.1)),
            ],
          ),
          Text(
            hint,
            style: const TextStyle(
              color: _textDim,
              fontSize: 8.5,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.2,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Hero banner ────────────────────────────────────────────────────────────────
class _HeroBanner extends StatelessWidget {
  final String greeting;
  final AppStrings s;
  const _HeroBanner({required this.greeting, required this.s});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [Color(0xFF162B1C), Color(0xFF0F2018)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2E7D32).withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$greeting 👋',
                    style: const TextStyle(
                        color: _textPri, fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Text(s.welcomeMessage,
                    style: const TextStyle(color: _textSec, fontSize: 13)),
                const SizedBox(height: 12),
                Builder(
                  builder: (ctx) => Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () => Navigator.push(
                        ctx,
                        MaterialPageRoute(
                            builder: (_) => const AboutUsScreen()),
                      ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E3D24),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: _border),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.info_outline_rounded,
                                color: Color(0xFFFFD54F), size: 13),
                            const SizedBox(width: 5),
                            Flexible(
                              child: Text(
                                s.aboutUs,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    color: _textSec, fontSize: 11),
                              ),
                            ),
                            const SizedBox(width: 3),
                            const Icon(Icons.arrow_forward_rounded,
                                color: _textSec, size: 11),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Image.asset('logo.png', width: 70, height: 70, fit: BoxFit.cover),
          ),
        ],
      ),
    );
  }
}

// ── Primary card (full width CTA) ─────────────────────────────────────────────
class _PrimaryCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final Gradient gradient;
  final VoidCallback onTap;

  const _PrimaryCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.gradient,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12)),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios_rounded,
                  color: Colors.white.withValues(alpha: 0.4), size: 14),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Feature card (half-width grid) ────────────────────────────────────────────
class _FeatureCard extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _FeatureCard({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(height: 12),
              Text(title,
                  style: const TextStyle(
                      color: _textPri, fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(subtitle,
                  style: const TextStyle(color: _textDim, fontSize: 11)),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/event_request.dart';
import '../services/event_service.dart';
import '../services/language_service.dart';
import '../services/holiday_hours_service.dart';
import '../services/report_service.dart';
import '../widgets/feature_usage_chart.dart';
import '../services/gallery_service.dart';
import '../models/contest.dart';
import '../services/contest_service.dart';
import '../services/hunt_submission_service.dart';
import 'admin/contest_submissions_screen.dart';
import 'admin/hunt_reviews_screen.dart';
import 'admin/reported_posts_screen.dart';
import 'admin_user_list_screen.dart';
import 'edit_holidays_screen.dart';

class AdminPanelScreen extends StatelessWidget {
  const AdminPanelScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<LanguageService>().strings;
    return Scaffold(
      backgroundColor: const Color(0xFF0A1A0F),
      appBar: AppBar(
        title: Text(s.adminPanel),
        backgroundColor: const Color(0xFF0D1F14),
        elevation: 0,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Scrape-error banner (only shown when oulu.fi scrape failed)
            StreamBuilder<HolidayHoursDoc>(
              stream: HolidayHoursService.instance.watch(),
              builder: (ctx, snap) {
                if (snap.data?.hasError != true) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const EditHolidaysScreen()),
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFF3B2A0B),
                          borderRadius: BorderRadius.circular(14),
                          border:
                              Border.all(color: const Color(0xFFFFB300)),
                        ),
                        child: Row(children: [
                          const Icon(Icons.warning_amber_rounded,
                              color: Color(0xFFFFD54F)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(s.scrapeFailedAlert,
                                style: const TextStyle(
                                    color: Color(0xFFFFE082),
                                    fontSize: 12.5,
                                    height: 1.4)),
                          ),
                          const Icon(Icons.arrow_forward_rounded,
                              color: Color(0xFFFFD54F), size: 18),
                        ]),
                      ),
                    ),
                  ),
                );
              },
            ),
            const _ReviewAlert(),
            _sectionLabel(s.statsOverview),
            const SizedBox(height: 10),
            const _StatsGrid(),
            const SizedBox(height: 24),
            _sectionLabel(s.featureUsage),
            const SizedBox(height: 10),
            const FeatureUsageChart(),
            const SizedBox(height: 24),
            _sectionLabel(s.pendingEvents),
            const SizedBox(height: 10),
            const _PendingEventsList(),
            const SizedBox(height: 24),
            _sectionLabel(s.visitorReports),
            const SizedBox(height: 10),
            const _ReportsList(),
            const SizedBox(height: 24),
            // Reported gallery posts — count badge so an admin can see there is
            // something waiting without opening the queue.
            const _ReportedPostsTile(),
            const SizedBox(height: 24),
            // Contest submissions — renders nothing when no contest is set up.
            const _ContestSubmissionsTile(),
            const _ParticipantsTile(),
            const SizedBox(height: 24),
            // Edit holiday hours tile
            Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const EditHolidaysScreen()),
                ),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF111F16),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFF2A4A2F)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.event_note_rounded,
                        color: Color(0xFFFFD54F), size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(s.editHolidays,
                          style: const TextStyle(
                              color: Color(0xFFE8F5E9),
                              fontSize: 14,
                              fontWeight: FontWeight.w600)),
                    ),
                    const Icon(Icons.arrow_forward_ios_rounded,
                        color: Color(0xFF4A7A50), size: 14),
                  ]),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) => Text(
        text.toUpperCase(),
        style: const TextStyle(
            color: Color(0xFF4A7A50),
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.4),
      );
}

// ─── Stats Grid ──────────────────────────────────────────────────────────────
class _StatsGrid extends StatelessWidget {
  const _StatsGrid();

  @override
  Widget build(BuildContext context) {
    final s = context.watch<LanguageService>().strings;
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users').snapshots(),
      builder: (context, snap) {
        final docs = snap.data?.docs ?? const [];
        final total = docs.length;
        final premium = docs.where((d) {
          final m = d.data() as Map<String, dynamic>;
          return m['tier'] == 'premium';
        }).length;
        final today = DateTime.now();
        final active = docs.where((d) {
          final m = d.data() as Map<String, dynamic>;
          final reset = m['lastUsageReset'] as String?;
          if (reset == null) return false;
          final r = DateTime.tryParse(reset);
          if (r == null) return false;
          return r.year == today.year &&
              r.month == today.month &&
              r.day == today.day;
        }).length;
        final chatsToday = docs.fold<int>(0, (sum, d) {
          final m = d.data() as Map<String, dynamic>;
          final reset = m['lastUsageReset'] as String?;
          if (reset == null) return sum;
          final r = DateTime.tryParse(reset);
          if (r == null) return sum;
          if (r.year != today.year ||
              r.month != today.month ||
              r.day != today.day) return sum;
          final ids = (m['chatsUsedTodayIds'] as List?) ?? const [];
          return sum + ids.length;
        });

        return GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 1.35,
          children: [
            _StatCard(
                icon: Icons.people_alt_rounded,
                label: s.totalUsers,
                value: '$total',
                color: const Color(0xFF64B5F6),
                filter: AdminUserFilter.all),
            _StatCard(
                icon: Icons.workspace_premium_rounded,
                label: s.premiumUsers,
                value: '$premium',
                color: const Color(0xFFFFD54F),
                filter: AdminUserFilter.premium),
            _StatCard(
                icon: Icons.bolt_rounded,
                label: s.activeToday,
                value: '$active',
                color: const Color(0xFF66BB6A),
                filter: AdminUserFilter.activeToday),
            _StatCard(
                icon: Icons.chat_bubble_rounded,
                label: s.totalChats,
                value: '$chatsToday',
                color: const Color(0xFFB39DDB),
                filter: AdminUserFilter.chatsToday),
          ],
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final AdminUserFilter filter;
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.filter,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => AdminUserListScreen(filter: filter)),
        ),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF111F16),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF2A4A2F)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(children: [
                Icon(icon, color: color, size: 20),
                const Spacer(),
                Icon(Icons.arrow_outward_rounded,
                    color: color.withValues(alpha: 0.5), size: 14),
              ]),
              const SizedBox(height: 8),
              Text(value,
                  style: const TextStyle(
                      color: Color(0xFFE8F5E9),
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      height: 1.1)),
              const SizedBox(height: 2),
              Text(label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: Color(0xFF81C784),
                      fontSize: 10.5,
                      height: 1.2)),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Pending Events List ─────────────────────────────────────────────────────
class _PendingEventsList extends StatelessWidget {
  const _PendingEventsList();

  @override
  Widget build(BuildContext context) {
    final s = context.watch<LanguageService>().strings;
    return StreamBuilder<List<EventRequest>>(
      stream: EventService.instance.watchAll(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(20),
            child: Center(
                child: CircularProgressIndicator(color: Color(0xFF66BB6A))),
          );
        }
        final events = snap.data ?? const [];
        if (events.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF111F16),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF2A4A2F)),
            ),
            child: Center(
              child: Text(s.noPendingEvents,
                  style: const TextStyle(color: Color(0xFF81C784))),
            ),
          );
        }
        return Column(
          children: events.map((e) => _EventTile(event: e)).toList(),
        );
      },
    );
  }
}

class _EventTile extends StatelessWidget {
  final EventRequest event;
  const _EventTile({required this.event});

  Color get _statusColor {
    switch (event.status) {
      case EventStatus.approved:
        return const Color(0xFF66BB6A);
      case EventStatus.rejected:
        return const Color(0xFFEF5350);
      case EventStatus.pending:
        return const Color(0xFFFFB74D);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<LanguageService>().strings;
    final dateStr = DateFormat('EEE, MMM d').format(event.date);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF111F16),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF2A4A2F)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(event.name,
                    style: const TextStyle(
                        color: Color(0xFFE8F5E9),
                        fontSize: 15,
                        fontWeight: FontWeight.w700)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(event.status.name.toUpperCase(),
                    style: TextStyle(
                        color: _statusColor,
                        fontSize: 10,
                        fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text('$dateStr · ${event.startTime} – ${event.endTime}  ·  ${event.attendees} ppl',
              style: const TextStyle(color: Color(0xFF81C784), fontSize: 12)),
          const SizedBox(height: 6),
          Text(event.description,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Color(0xFFE8F5E9), fontSize: 12.5)),
          const SizedBox(height: 6),
          Text('${event.userName} · ${event.userEmail}',
              style: const TextStyle(color: Color(0xFF4A7A50), fontSize: 11)),
          if (event.status == EventStatus.pending) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => EventService.instance
                        .setStatus(event.id, EventStatus.rejected),
                    icon: const Icon(Icons.close_rounded, size: 16),
                    label: Text(s.reject),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFEF5350),
                      side: const BorderSide(color: Color(0xFFEF5350)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => EventService.instance
                        .setStatus(event.id, EventStatus.approved),
                    icon: const Icon(Icons.check_rounded, size: 16),
                    label: Text(s.approve),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2E7D32),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Reports List ────────────────────────────────────────────────────────────
class _ReportsList extends StatelessWidget {
  const _ReportsList();

  @override
  Widget build(BuildContext context) {
    final s = context.watch<LanguageService>().strings;
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: ReportService.instance.watchAll(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(20),
            child: Center(
                child: CircularProgressIndicator(color: Color(0xFF66BB6A))),
          );
        }
        final reports = snap.data ?? const [];
        if (reports.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF111F16),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF2A4A2F)),
            ),
            child: Center(
              child: Text(s.noReports,
                  style: const TextStyle(color: Color(0xFF81C784))),
            ),
          );
        }
        return Column(
          children: reports.map((r) => _ReportTile(data: r)).toList(),
        );
      },
    );
  }
}

class _ReportTile extends StatelessWidget {
  final Map<String, dynamic> data;
  const _ReportTile({required this.data});

  @override
  Widget build(BuildContext context) {
    final ts = DateTime.tryParse(data['timestamp'] as String? ?? '');
    final dateStr =
        ts == null ? '' : DateFormat('MMM d · HH:mm').format(ts);
    final category = (data['category'] ?? '').toString();
    final note = (data['note'] ?? '').toString();
    final aiDesc = (data['aiDescription'] ?? '').toString();
    final userName = (data['userName'] ?? 'Anonymous').toString();
    final userEmail = (data['userEmail'] ?? '').toString();
    final lat = data['latitude'] as num?;
    final lng = data['longitude'] as num?;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF111F16),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF2A4A2F)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bug_report_rounded,
                  color: Color(0xFFF48FB1), size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(category,
                    style: const TextStyle(
                        color: Color(0xFFE8F5E9),
                        fontSize: 14,
                        fontWeight: FontWeight.w700)),
              ),
              Text(dateStr,
                  style: const TextStyle(color: Color(0xFF4A7A50), fontSize: 11)),
            ],
          ),
          if (note.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(note,
                style: const TextStyle(color: Color(0xFFE8F5E9), fontSize: 13)),
          ],
          if (aiDesc.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(aiDesc,
                style: const TextStyle(
                    color: Color(0xFF81C784),
                    fontSize: 12,
                    fontStyle: FontStyle.italic)),
          ],
          const SizedBox(height: 6),
          Row(
            children: [
              if (lat != null && lng != null) ...[
                const Icon(Icons.place_rounded,
                    color: Color(0xFF4A7A50), size: 12),
                const SizedBox(width: 3),
                Text(
                    '${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}',
                    style: const TextStyle(
                        color: Color(0xFF4A7A50), fontSize: 11)),
                const SizedBox(width: 10),
              ],
              const Icon(Icons.person_outline_rounded,
                  color: Color(0xFF4A7A50), size: 12),
              const SizedBox(width: 3),
              Expanded(
                child: Text(
                  userEmail.isNotEmpty ? userEmail : userName,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: Color(0xFF4A7A50), fontSize: 11),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}


/// Red, loud, and at the top of the panel — a visitor is standing in a
/// greenhouse waiting on this, unlike everything else here. Renders nothing
/// when the queue is empty rather than sitting there as permanent noise.
class _ReviewAlert extends StatelessWidget {
  const _ReviewAlert();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: HuntSubmissionService.instance.watchPendingReviewCount(),
      builder: (context, snap) {
        final n = snap.data ?? 0;
        if (n == 0) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const HuntReviewsScreen()),
              ),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF3B1414),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFEF5350), width: 1.5),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF5350),
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: const Icon(Icons.pending_actions_rounded,
                          color: Colors.white, size: 22),
                    ),
                    const SizedBox(width: 13),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            n == 1
                                ? '1 photo waiting for review'
                                : '$n photos waiting for review',
                            style: const TextStyle(
                                color: Color(0xFFFFCDD2),
                                fontSize: 15,
                                fontWeight: FontWeight.w700),
                          ),
                          const Text(
                            'A visitor is waiting on your answer. Tap to check.',
                            style: TextStyle(
                                color: Color(0xFFEF9A9A), fontSize: 12.5),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: Color(0xFFEF5350)),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Everyone who has submitted anything, and what they sent.
class _ParticipantsTile extends StatelessWidget {
  const _ParticipantsTile();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ParticipantsScreen()),
        ),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF111F16),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF2A4A2F)),
          ),
          child: Row(
            children: [
              const Icon(Icons.groups_rounded, color: Color(0xFF81C784)),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Participants',
                        style: TextStyle(
                            color: Color(0xFFE8F5E9),
                            fontSize: 14.5,
                            fontWeight: FontWeight.w600)),
                    Text('Every Plant Hunt submission, by person',
                        style: TextStyle(
                            color: Color(0xFF6E8A72), fontSize: 12.5)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Color(0xFF4A7A50)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Entry point to the contest submission log. Unlike the moderation queue this
/// hides itself entirely when no contest exists — an admin panel for a garden
/// that is not running an event should not carry a dead tile all year.
class _ContestSubmissionsTile extends StatelessWidget {
  const _ContestSubmissionsTile();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Contest?>(
      stream: ContestService.instance.watchContest(),
      builder: (context, snap) {
        final c = snap.data;
        if (c == null) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(bottom: 24),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => ContestSubmissionsScreen(contest: c)),
              ),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF111F16),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFF2A4A2F)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.emoji_events_rounded,
                        color: Color(0xFFFFD54F)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Contest submissions',
                              style: TextStyle(
                                  color: Color(0xFFE8F5E9),
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w600)),
                          Text(
                            '${c.title} · locations, teams, missing plants',
                            style: const TextStyle(
                                color: Color(0xFF6E8A72), fontSize: 12.5),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded,
                        color: Color(0xFF4A7A50)),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Entry point to the gallery moderation queue, with a live count of what is
/// waiting. Rendered even at zero so the panel does not appear to lose a
/// section — an empty queue is information too.
class _ReportedPostsTile extends StatelessWidget {
  const _ReportedPostsTile();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: GalleryService.instance.watchOpenReportCount(),
      builder: (context, snap) {
        final n = snap.data ?? 0;
        final pending = n > 0;
        return Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ReportedPostsScreen()),
            ),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: pending ? const Color(0xFF2A1414) : const Color(0xFF111F16),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: pending
                      ? const Color(0xFFEF5350)
                      : const Color(0xFF2A4A2F),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.flag_rounded,
                      color: pending
                          ? const Color(0xFFEF5350)
                          : const Color(0xFF4A7A50)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Reported photos',
                            style: TextStyle(
                                color: Color(0xFFE8F5E9),
                                fontSize: 14.5,
                                fontWeight: FontWeight.w600)),
                        Text(
                          pending
                              ? '$n waiting for review'
                              : 'Nothing to review',
                          style: TextStyle(
                            color: pending
                                ? const Color(0xFFFFCDD2)
                                : const Color(0xFF6E8A72),
                            fontSize: 12.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (pending)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 9, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFC62828),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text('$n',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w700)),
                    ),
                  const SizedBox(width: 4),
                  const Icon(Icons.chevron_right, color: Color(0xFF4A7A50)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

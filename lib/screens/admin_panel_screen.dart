import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/event_request.dart';
import '../services/event_service.dart';
import '../services/language_service.dart';
import '../services/report_service.dart';

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
            _sectionLabel(s.statsOverview),
            const SizedBox(height: 10),
            const _StatsGrid(),
            const SizedBox(height: 24),
            _sectionLabel(s.pendingEvents),
            const SizedBox(height: 10),
            const _PendingEventsList(),
            const SizedBox(height: 24),
            _sectionLabel(s.visitorReports),
            const SizedBox(height: 10),
            const _ReportsList(),
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
            _statCard(Icons.people_alt_rounded, s.totalUsers, '$total',
                const Color(0xFF64B5F6)),
            _statCard(Icons.workspace_premium_rounded, s.premiumUsers,
                '$premium', const Color(0xFFFFD54F)),
            _statCard(Icons.bolt_rounded, s.activeToday, '$active',
                const Color(0xFF66BB6A)),
            _statCard(Icons.chat_bubble_rounded, s.totalChats, '$chatsToday',
                const Color(0xFFB39DDB)),
          ],
        );
      },
    );
  }

  Widget _statCard(IconData icon, String label, String value, Color color) {
    return Container(
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
          Icon(icon, color: color, size: 20),
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
              style: const TextStyle(color: Color(0xFF81C784), fontSize: 10.5, height: 1.2)),
        ],
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

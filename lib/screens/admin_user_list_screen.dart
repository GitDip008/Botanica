import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../services/language_service.dart';

/// Which subset of users to display.
enum AdminUserFilter { all, premium, activeToday, chatsToday }

/// Reusable drill-down screen that shows users matching a filter.
///
/// Deduplicates by Firestore document ID (uid) — the same person signed in
/// from multiple devices counts as ONE row, since Firestore uses one doc
/// per uid regardless of device.
class AdminUserListScreen extends StatelessWidget {
  final AdminUserFilter filter;
  const AdminUserListScreen({super.key, required this.filter});

  String _titleFor(dynamic s) {
    switch (filter) {
      case AdminUserFilter.all:
        return s.adminAllUsers;
      case AdminUserFilter.premium:
        return s.adminPremiumUsers;
      case AdminUserFilter.activeToday:
        return s.adminActiveToday;
      case AdminUserFilter.chatsToday:
        return s.adminChatsToday;
    }
  }

  bool _matches(Map<String, dynamic> u) {
    switch (filter) {
      case AdminUserFilter.all:
        return true;
      case AdminUserFilter.premium:
        return u['tier'] == 'premium' || (u['isAdmin'] as bool? ?? false);
      case AdminUserFilter.activeToday:
        return _isToday(u['lastUsageReset'] as String?);
      case AdminUserFilter.chatsToday:
        if (!_isToday(u['lastUsageReset'] as String?)) return false;
        final ids = (u['chatsUsedTodayIds'] as List?) ?? const [];
        return ids.isNotEmpty;
    }
  }

  bool _isToday(String? iso) {
    if (iso == null) return false;
    final d = DateTime.tryParse(iso);
    if (d == null) return false;
    final now = DateTime.now();
    return d.year == now.year && d.month == now.month && d.day == now.day;
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<LanguageService>().strings;
    return Scaffold(
      backgroundColor: const Color(0xFF0A1A0F),
      appBar: AppBar(
        title: Text(_titleFor(s)),
        backgroundColor: const Color(0xFF0D1F14),
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('users').snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: Color(0xFF66BB6A)));
          }
          // Deduplicate by document ID (uid) — multiple devices = same uid
          final seen = <String>{};
          final users = <Map<String, dynamic>>[];
          for (final d in (snap.data?.docs ?? const [])) {
            if (seen.add(d.id)) {
              final m = d.data() as Map<String, dynamic>;
              m['_id'] = d.id;
              if (_matches(m)) users.add(m);
            }
          }

          if (users.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(s.noUsersMatch,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: Color(0xFF81C784), fontSize: 14)),
              ),
            );
          }

          // Sort: newest signups first
          users.sort((a, b) {
            final ad = DateTime.tryParse(a['joinedAt'] as String? ?? '') ??
                DateTime(2000);
            final bd = DateTime.tryParse(b['joinedAt'] as String? ?? '') ??
                DateTime(2000);
            return bd.compareTo(ad);
          });

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: users.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) => _UserTile(user: users[i], s: s),
          );
        },
      ),
    );
  }
}

class _UserTile extends StatelessWidget {
  final Map<String, dynamic> user;
  final dynamic s;
  const _UserTile({required this.user, required this.s});

  @override
  Widget build(BuildContext context) {
    final name = (user['displayName'] as String? ?? '').trim();
    final email = user['email'] as String? ?? '';
    final isAdmin = user['isAdmin'] as bool? ?? false;
    final isPremium = (user['tier'] as String?) == 'premium';
    final joined = DateTime.tryParse(user['joinedAt'] as String? ?? '');
    final joinedStr = joined == null
        ? '—'
        : DateFormat('MMM d, yyyy · HH:mm').format(joined);
    final chatsToday =
        ((user['chatsUsedTodayIds'] as List?) ?? const []).length;
    final initial = (name.isNotEmpty ? name : email).isNotEmpty
        ? (name.isNotEmpty ? name : email)[0].toUpperCase()
        : '?';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF111F16),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF2A4A2F)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: isAdmin
                ? const Color(0xFFB8860B)
                : isPremium
                    ? const Color(0xFF8B6914)
                    : const Color(0xFF1E3D24),
            child: Text(initial,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(
                    child: Text(
                      name.isEmpty ? email.split('@').first : name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Color(0xFFE8F5E9),
                          fontSize: 14,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                  if (isAdmin)
                    _badge(s.adminBadge, const Color(0xFFFFD54F))
                  else if (isPremium)
                    _badge(s.premium, const Color(0xFFB8860B))
                  else
                    _badge(s.free, const Color(0xFF4A7A50)),
                ]),
                const SizedBox(height: 3),
                Text(email,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Color(0xFF81C784), fontSize: 12)),
                const SizedBox(height: 6),
                Row(children: [
                  const Icon(Icons.calendar_today_rounded,
                      size: 11, color: Color(0xFF4A7A50)),
                  const SizedBox(width: 4),
                  Text('${s.registeredAt}: $joinedStr',
                      style: const TextStyle(
                          color: Color(0xFF4A7A50), fontSize: 11)),
                ]),
                if (chatsToday > 0) ...[
                  const SizedBox(height: 3),
                  Row(children: [
                    const Icon(Icons.chat_bubble_rounded,
                        size: 11, color: Color(0xFF66BB6A)),
                    const SizedBox(width: 4),
                    Text(s.chatsToday(chatsToday),
                        style: const TextStyle(
                            color: Color(0xFF66BB6A), fontSize: 11)),
                  ]),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(text,
          style: TextStyle(
              color: color, fontSize: 9, fontWeight: FontWeight.w800)),
    );
  }
}

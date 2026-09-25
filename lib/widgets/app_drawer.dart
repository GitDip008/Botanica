import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../screens/about_us_screen.dart';
import '../screens/admin_panel_screen.dart';
import '../screens/agent/agent_screen.dart';
import '../screens/event_request_screen.dart';
import '../screens/report_screen.dart';
import '../screens/settings_screen.dart';
import '../services/language_service.dart';
import '../services/user_state.dart';
import '../theme/tokens.dart';
import '../i18n/tr.dart';

/// Side navigation drawer with all main destinations + developer info.
class AppDrawer extends StatelessWidget {
  /// Callback to switch tab in MainNavScreen (0..4).
  final ValueChanged<int> onSelectTab;
  const AppDrawer({super.key, required this.onSelectTab});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<LanguageService>().strings;
    final user = context.watch<UserState>().user;
    final isAdmin = user?.isAdmin ?? false;

    return Drawer(
      backgroundColor: C.bg,
      child: SafeArea(
        child: Column(
          children: [
            // ── Header ───────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: C.line),
                ),
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.asset('logo.png', width: 44, height: 44),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(tr('Botanica'),
                            style: TextStyle(
                                color: C.textHi,
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.3)),
                        Text(user?.displayName ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: C.accent, fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── Nav items ────────────────────────────────────
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  // ── Section 1: Main navigation ───────────────
                  _item(context, Icons.home_rounded, s.navHome, () {
                    Navigator.pop(context);
                    onSelectTab(0);
                  }),
                  _item(context, Icons.map_rounded, s.navMap, () {
                    Navigator.pop(context);
                    onSelectTab(1);
                  }),
                  _item(context, Icons.search_rounded, s.navSearch, () {
                    Navigator.pop(context);
                    onSelectTab(2);
                  }),
                  _item(context, Icons.forum_rounded, s.navChat, () {
                    Navigator.pop(context);
                    onSelectTab(3);
                  }),
                  _item(context, Icons.bug_report_rounded, s.report, () {
                    Navigator.pop(context);
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const ReportScreen()));
                  }),
                  _item(context, Icons.event_rounded, s.organizeEvent, () {
                    Navigator.pop(context);
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const EventRequestScreen()));
                  }),

                  // Smart Agent — Phase 1 entry point. Hidden from gold rush
                  // until LLM is wired (Phase 2), but accessible from drawer.
                  _item(context, Icons.smart_toy_rounded, tr('Smart Agent (beta)'),
                      () {
                    Navigator.pop(context);
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const AgentScreen()));
                  }),

                  const Divider(color: C.line, height: 24),

                  // ── Section 2: Account & settings ────────────
                  _item(context, Icons.person_rounded, s.navProfile, () {
                    Navigator.pop(context);
                    onSelectTab(4);
                  }),
                  _item(context, Icons.settings_rounded, s.settings, () {
                    Navigator.pop(context);
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const SettingsScreen()));
                  }),
                  _item(context, Icons.info_outline_rounded, s.aboutUs, () {
                    Navigator.pop(context);
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const AboutUsScreen()));
                  }),

                  // ── Section 3: Admin (admin email users only) ─
                  if (isAdmin) ...[
                    const Divider(color: C.line, height: 24),
                    _item(context, Icons.admin_panel_settings_rounded,
                        s.adminPanel, () {
                      Navigator.pop(context);
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const AdminPanelScreen()));
                    }, highlight: C.gold),
                  ],
                ],
              ),
            ),

          ],
        ),
      ),
    );
  }

  Widget _item(BuildContext context, IconData icon, String label,
      VoidCallback onTap, {Color? highlight}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          child: Row(
            children: [
              Icon(icon,
                  color: highlight ?? C.accent, size: 22),
              const SizedBox(width: 14),
              Text(label,
                  style: TextStyle(
                      color: highlight ?? C.textHi,
                      fontSize: 14,
                      fontWeight:
                          highlight != null ? FontWeight.w700 : FontWeight.w500)),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/user_model.dart';
import '../../services/language_service.dart';
import '../../services/user_state.dart';
import '../../widgets/developed_by_card.dart';
import '../main_nav_screen.dart';
import '../settings_screen.dart';
import '../subscription/paywall_screen.dart';
import '../../theme/tokens.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final userState = context.watch<UserState>();
    final s = context.watch<LanguageService>().strings;
    final user = userState.user;
    if (user == null) {
      return Scaffold(
        backgroundColor: C.bg,
        body: Center(child: Text(LanguageService.instance.strings.notSignedIn, style: const TextStyle(color: Colors.white))),
      );
    }

    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.menu_rounded, color: C.textHi),
          onPressed: () =>
              MainNavScreen.scaffoldKey.currentState?.openDrawer(),
        ),
        title: Text(s.profile),
        backgroundColor: C.bg,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // ── Avatar + name ─────────────────────────────────
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: const LinearGradient(
                colors: [C.surface, C.surface],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 36,
                  backgroundColor: C.accentDim,
                  backgroundImage: user.photoUrl != null ? NetworkImage(user.photoUrl!) : null,
                  child: user.photoUrl == null
                      ? Text(
                          user.displayName.isNotEmpty ? user.displayName[0].toUpperCase() : '?',
                          style: const TextStyle(
                              color: Colors.white, fontSize: 28, fontWeight: FontWeight.w700),
                        )
                      : null,
                ),
                const SizedBox(height: 12),
                Text(user.displayName,
                    style: const TextStyle(
                        color: C.textHi, fontSize: 18, fontWeight: FontWeight.w700)),
                Text(user.email,
                    style: const TextStyle(color: C.accent, fontSize: 12)),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: user.tier.isPremium
                        ? const Color(0xFFB8860B)
                        : C.line,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        user.tier.isPremium
                            ? Icons.workspace_premium_rounded
                            : Icons.eco_rounded,
                        size: 14,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        user.tier.isPremium ? s.premium : s.free,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // ── Usage today (visible to all users) ───────────
          _sectionLabel(s.dailyUsage.toUpperCase()),
          const SizedBox(height: 8),
          _usageCard(
            icon: Icons.chat_bubble_outline_rounded,
            label: s.aiChats,
            used: user.chatsUsedToday,
            limit: AppUser.freeDailyChatLimit,
            unlimited: user.hasUnlimitedAccess,
            todayLabel: s.todayLabel,
          ),
          const SizedBox(height: 8),
          _usageCard(
            icon: Icons.emoji_events_rounded,
            label: s.plantHuntsLabel,
            used: user.huntsCompletedToday,
            limit: AppUser.freeDailyHuntLimit,
            unlimited: user.hasUnlimitedAccess,
            todayLabel: s.todayLabel,
          ),
          if (!user.hasUnlimitedAccess) ...[
            const SizedBox(height: 16),
            _UpgradeBanner(
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const PaywallScreen())),
            ),
          ],
          const SizedBox(height: 24),

          // ── Settings ──────────────────────────────────────
          _sectionLabel(s.settings.toUpperCase()),
          const SizedBox(height: 8),
          _actionTile(
            icon: Icons.settings_rounded,
            label: s.settings,
            color: C.accent,
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const SettingsScreen())),
          ),

          const SizedBox(height: 24),

          

          // ── Account actions ───────────────────────────────
          _sectionLabel(s.account.toUpperCase()),
          const SizedBox(height: 8),
          _actionTile(
            icon: Icons.logout_rounded,
            label: s.signOut,
            color: C.danger,
            onTap: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  backgroundColor: C.surface,
                  title: Text(s.signOutConfirmTitle,
                      style: const TextStyle(color: C.textHi)),
                  content: Text(s.signOutConfirmBody,
                      style: const TextStyle(color: C.accent)),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: Text(s.cancel)),
                    TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: Text(s.signOut,
                            style: const TextStyle(color: C.danger))),
                  ],
                ),
              );
              if (confirm == true) {
                await userState.signOut();
              }
            },
          ),

          const SizedBox(height: 24),
          const DevelopedByCard(),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) => Text(
        text.toUpperCase(),
        style: const TextStyle(
            color: C.textFaint,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.4),
      );

  Widget _usageCard({
    required IconData icon,
    required String label,
    required int used,
    required int limit,
    bool unlimited = false,
    String todayLabel = 'today',
  }) {
    final pct = unlimited ? 0.0 : (used / limit).clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: C.surface,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: C.accent, size: 18),
              const SizedBox(width: 8),
              Text(label,
                  style: const TextStyle(
                      color: C.textHi, fontWeight: FontWeight.w600, fontSize: 13)),
              const Spacer(),
              if (unlimited) ...[
                const Icon(Icons.all_inclusive_rounded,
                    size: 14, color: C.gold),
                const SizedBox(width: 4),
                Text('$used $todayLabel',
                    style: const TextStyle(
                        color: C.gold,
                        fontSize: 12,
                        fontWeight: FontWeight.w700)),
              ] else
                Text('$used / $limit',
                    style: const TextStyle(
                        color: C.accent,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: unlimited
                ? Container(
                    height: 6,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [C.gold, Color(0xFFB8860B)],
                      ),
                    ),
                  )
                : LinearProgressIndicator(
                    value: pct,
                    minHeight: 6,
                    backgroundColor: C.surface,
                    valueColor: AlwaysStoppedAnimation(
                      pct >= 1.0
                          ? C.danger
                          : C.accent,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _actionTile({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: C.surface,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 12),
            Text(label,
                style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w600)),
            const Spacer(),
            Icon(Icons.arrow_forward_ios_rounded, color: color.withValues(alpha: 0.4), size: 14),
          ]),
        ),
      ),
    );
  }
}

class _UpgradeBanner extends StatelessWidget {
  final VoidCallback onTap;
  const _UpgradeBanner({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<LanguageService>().strings;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFB8860B), Color(0xFF8B6914)],
            ),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(children: [
            const Icon(Icons.workspace_premium_rounded, color: Colors.white, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.upgradeToPremium,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
                  Text(s.premiumBenefits,
                      style: const TextStyle(color: C.text, fontSize: 11)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 14),
          ]),
        ),
      ),
    );
  }
}


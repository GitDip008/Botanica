import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/language_service.dart';

class PaywallScreen extends StatefulWidget {
  const PaywallScreen({super.key});

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  int _selectedPlan = 1; // 0=monthly, 1=yearly, 2=lifetime
  bool _busy = false;

  List<_PlanOption> _plansFor(LanguageService lang) {
    final s = lang.strings;
    return [
      _PlanOption(s.planMonthly, '€2.99', s.perMonthLbl, '', false),
      _PlanOption(s.planYearly, '€19.99', s.perYearLbl, s.save44, true),
      _PlanOption(s.planLifetime, '€49.99', s.oneTimeLbl, s.bestValueBadge, false),
    ];
  }

  Future<void> _subscribe() async {
    final s = LanguageService.instance.strings;
    setState(() => _busy = true);
    try {
      await AuthService.instance.updateTier(SubscriptionTier.premium);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(s.welcomePremium),
          backgroundColor: const Color(0xFF2E7D32),
        ));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageService>();
    final s = lang.strings;
    final plans = _plansFor(lang);
    return Scaffold(
      backgroundColor: const Color(0xFF0A1A0F),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFFE8F5E9)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Header ────────────────────────────────────
              const Center(
                child: Icon(Icons.workspace_premium_rounded,
                    color: Color(0xFFFFD54F), size: 64),
              ).animate().scale(duration: 400.ms),
              const SizedBox(height: 12),
              Text(s.premiumTitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: Color(0xFFE8F5E9),
                      fontSize: 26,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(s.unlockFullExperience,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Color(0xFF81C784), fontSize: 13)),

              const SizedBox(height: 28),

              // ── Benefits ──────────────────────────────────
              _benefit(Icons.chat_bubble_rounded, s.benefitUnlimitedChatsTitle,
                  s.benefitUnlimitedChatsBody),
              _benefit(Icons.emoji_events_rounded, s.benefitSeasonalHuntsTitle,
                  s.benefitSeasonalHuntsBody),
              _benefit(Icons.offline_bolt_rounded, s.benefitOfflineMapsTitle,
                  s.benefitOfflineMapsBody),
              _benefit(Icons.history_rounded, s.benefitUnlimitedHistoryTitle,
                  s.benefitUnlimitedHistoryBody),
              _benefit(Icons.eco_rounded, s.benefitMemberBadgeTitle,
                  s.benefitMemberBadgeBody),

              const SizedBox(height: 24),

              // ── Plan picker ───────────────────────────────
              for (var i = 0; i < plans.length; i++) ...[
                _PlanCard(
                  plan: plans[i],
                  selected: _selectedPlan == i,
                  onTap: () => setState(() => _selectedPlan = i),
                ),
                if (i < plans.length - 1) const SizedBox(height: 10),
              ],

              const SizedBox(height: 24),

              ElevatedButton(
                onPressed: _busy ? null : _subscribe,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFB8860B),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: _busy
                    ? const SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : Text(
                        s.startPlan(plans[_selectedPlan].title),
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700),
                      ),
              ),

              const SizedBox(height: 14),
              Text(
                s.cancelAnytime,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF4A7A50), fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _benefit(IconData icon, String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: const Color(0xFF1A2E1E),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: const Color(0xFFFFD54F), size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      color: Color(0xFFE8F5E9), fontSize: 14, fontWeight: FontWeight.w600)),
              Text(subtitle,
                  style: const TextStyle(color: Color(0xFF81C784), fontSize: 12)),
            ],
          ),
        ),
      ]),
    );
  }
}

class _PlanOption {
  final String title;
  final String price;
  final String period;
  final String badge;
  final bool highlighted;
  const _PlanOption(this.title, this.price, this.period, this.badge, this.highlighted);
}

class _PlanCard extends StatelessWidget {
  final _PlanOption plan;
  final bool selected;
  final VoidCallback onTap;

  const _PlanCard({required this.plan, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF1A3320) : const Color(0xFF111F16),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? const Color(0xFFB8860B) : const Color(0xFF2A4A2F),
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(children: [
            Icon(
              selected ? Icons.radio_button_checked_rounded : Icons.radio_button_unchecked_rounded,
              color: selected ? const Color(0xFFFFD54F) : const Color(0xFF4A7A50),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Row(
                children: [
                  Text(plan.title,
                      style: const TextStyle(
                          color: Color(0xFFE8F5E9), fontWeight: FontWeight.w600, fontSize: 14)),
                  if (plan.badge.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFB8860B),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(plan.badge,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700)),
                    ),
                  ],
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(plan.price,
                    style: const TextStyle(
                        color: Color(0xFFE8F5E9), fontSize: 16, fontWeight: FontWeight.w700)),
                Text(plan.period,
                    style: const TextStyle(color: Color(0xFF81C784), fontSize: 10)),
              ],
            ),
          ]),
        ),
      ),
    );
  }
}

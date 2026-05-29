import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';

class PaywallScreen extends StatefulWidget {
  const PaywallScreen({super.key});

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  int _selectedPlan = 1; // 0=monthly, 1=yearly, 2=lifetime
  bool _busy = false;

  static const _plans = [
    _PlanOption('Monthly', '€2.99', 'per month', '', false),
    _PlanOption('Yearly', '€19.99', 'per year', 'Save 44%', true),
    _PlanOption('Lifetime', '€49.99', 'one-time', 'Best value', false),
  ];

  Future<void> _subscribe() async {
    setState(() => _busy = true);
    try {
      // ⚠️ Once RevenueCat is wired up this will call Purchases.purchasePackage.
      // For now it just sets the tier so you can test the gated features.
      await AuthService.instance.updateTier(SubscriptionTier.premium);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('🎉 Welcome to Premium!'),
          backgroundColor: Color(0xFF2E7D32),
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
              const Text('Botanica Premium',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: Color(0xFFE8F5E9),
                      fontSize: 26,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              const Text('Unlock the full garden experience',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFF81C784), fontSize: 13)),

              const SizedBox(height: 28),

              // ── Benefits ──────────────────────────────────
              _benefit(Icons.chat_bubble_rounded, 'Unlimited AI chats',
                  'Ask anything about any plant, anytime'),
              _benefit(Icons.emoji_events_rounded, 'Seasonal Plant Hunts',
                  'New challenges every season'),
              _benefit(Icons.offline_bolt_rounded, 'Offline maps & trails',
                  'Use the app without internet'),
              _benefit(Icons.history_rounded, 'Unlimited history',
                  'Keep every plant ID and chat forever'),
              _benefit(Icons.eco_rounded, 'Garden member badge',
                  'Special perks at the gift shop'),

              const SizedBox(height: 24),

              // ── Plan picker ───────────────────────────────
              for (var i = 0; i < _plans.length; i++) ...[
                _PlanCard(
                  plan: _plans[i],
                  selected: _selectedPlan == i,
                  onTap: () => setState(() => _selectedPlan = i),
                ),
                if (i < _plans.length - 1) const SizedBox(height: 10),
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
                        'Start ${_plans[_selectedPlan].title}',
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700),
                      ),
              ),

              const SizedBox(height: 14),
              const Text(
                'Cancel anytime. Restoring previous purchases is supported.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF4A7A50), fontSize: 11),
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

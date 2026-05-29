import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

/// Stylized "Developed by" card — terminal/IDE aesthetic.
class DevelopedByCard extends StatelessWidget {
  const DevelopedByCard({super.key});

  static const _name = 'Shourove Sutradhar Dip';
  static const _github = 'https://github.com/GitDip008';
  static const _linkedin = 'https://www.linkedin.com/in/shourov-dip/';
  static const _portfolio = 'https://gitdip008.github.io/';
  static const _whatsapp = 'https://wa.me/358417413188';

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1E3D24), width: 1),
        gradient: const LinearGradient(
          colors: [Color(0xFF0D1A11), Color(0xFF0F1F15)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Terminal header bar ─────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: const BoxDecoration(
              color: Color(0xFF0A1410),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(15),
                topRight: Radius.circular(15),
              ),
              border: Border(bottom: BorderSide(color: Color(0xFF1E3D24))),
            ),
            child: Row(
              children: [
                _trafficDot(const Color(0xFFEF5350)),
                const SizedBox(width: 6),
                _trafficDot(const Color(0xFFFFB74D)),
                const SizedBox(width: 6),
                _trafficDot(const Color(0xFF66BB6A)),
                const SizedBox(width: 12),
                const Text(
                  '~/developed_by',
                  style: TextStyle(
                    color: Color(0xFF4A7A50),
                    fontSize: 11,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),

          // ── Body ────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  _name,
                  style: TextStyle(
                    color: Color(0xFFE8F5E9),
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                  ),
                ),

                const SizedBox(height: 16),

                Row(
                  children: [
                    _iconColumn(
                      icon: FontAwesomeIcons.github,
                      label: 'GitHub',
                      color: const Color(0xFFE8F5E9),
                      url: _github,
                    ),
                    const SizedBox(width: 10),
                    _iconColumn(
                      icon: FontAwesomeIcons.linkedinIn,
                      label: 'LinkedIn',
                      color: const Color(0xFF0A66C2),
                      url: _linkedin,
                    ),
                    const SizedBox(width: 10),
                    _iconColumn(
                      icon: FontAwesomeIcons.briefcase,
                      label: 'Portfolio',
                      color: const Color(0xFFFFB74D),
                      url: _portfolio,
                    ),
                    const SizedBox(width: 10),
                    _iconColumn(
                      icon: FontAwesomeIcons.whatsapp,
                      label: 'WhatsApp',
                      color: const Color(0xFF25D366),
                      url: _whatsapp,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms);
  }

  Widget _trafficDot(Color c) => Container(
        width: 10, height: 10,
        decoration: BoxDecoration(
            color: c.withValues(alpha: 0.7), shape: BoxShape.circle),
      );

  Widget _iconColumn({
    required IconData icon,
    required String label,
    required Color color,
    required String url,
  }) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => launchUrl(Uri.parse(url),
              mode: LaunchMode.externalApplication),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF0A1410),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: color.withValues(alpha: 0.25), width: 1),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FaIcon(icon, color: color, size: 18),
                const SizedBox(height: 5),
                Text(
                  label,
                  style: TextStyle(
                    color: color.withValues(alpha: 0.9),
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

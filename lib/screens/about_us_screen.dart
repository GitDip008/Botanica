import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/language_service.dart';
import '../widgets/developed_by_card.dart';

/// All-in-one info page about Oulu Botanical Garden.
/// Reachable from drawer and from tapping the Open/Closed chip on home.
class AboutUsScreen extends StatelessWidget {
  /// If true, scrolls straight to the schedule section on open.
  final bool focusSchedule;
  const AboutUsScreen({super.key, this.focusSchedule = false});

  static const _address = 'Kaitoväylä 5, 90570 Oulu';
  static const _mapsUrl =
      'https://www.google.com/maps/search/?api=1&query=University+of+Oulu+Botanical+Gardens+Kaitov%C3%A4yl%C3%A4+5+90570+Oulu';
  static const _mainEmail = 'kasvitieteellinen.puutarha@oulu.fi';
  static const _website =
      'https://www.oulu.fi/en/university/botanical-garden';

  @override
  Widget build(BuildContext context) {
    final s = context.watch<LanguageService>().strings;
    return Scaffold(
      backgroundColor: const Color(0xFF0A1A0F),
      appBar: AppBar(
        title: Text(s.aboutUs),
        backgroundColor: const Color(0xFF0D1F14),
        elevation: 0,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── Header card ───────────────────────────────────
            _headerCard(s),
            const SizedBox(height: 20),

            _section(s.admissionFee, Icons.payments_rounded, const [
              _Body(
                'Voluntary admission fee: 5 € for greenhouses and outdoor garden.\n\n'
                'Entrance fees fund garden activities and keep the garden open on weekends. '
                'Pay with MobilePay number 12657 or by bank transfer:',
              ),
              SizedBox(height: 10),
              _InfoLine('Bank', 'Danske Bank A/S'),
              _InfoLine('SWIFT', 'DABAFIHH'),
              _InfoLine('IBAN', 'FI66 8919 9710 0010 29'),
              _InfoLine('Recipient', 'Oulun yliopisto'),
              _InfoLine('Message', '2402120/pääsymaksu'),
            ]),

            _section(s.directionsAndParking, Icons.directions_rounded, [
              const _Body(
                'The Botanical Garden is in the northern corner of the Linnanmaa campus, '
                'near Lake Kuivasjärvi. Street address: Kaitoväylä 5.\n\n'
                'From motorway E4, take ramp 12 toward Teknologiakylä and Yliopisto.',
              ),
              const SizedBox(height: 10),
              _subTitle('Parking'),
              const _Body(
                'Visitor parking is paid 1 Aug – 31 May on weekdays 8:00–16:00.\n'
                '  • Short-term: 1.20 €/h (max 6 €/day) + operator fee\n'
                '  • Free outside paid hours\n'
                '  • EV / hybrid charging at guest locations: 0.20 €/kWh + base fee\n\n'
                'Payment apps: eParking · EasyPark · Parkman. Bus parking spaces available (free).',
              ),
            ]),

            _section(s.photography, Icons.photo_camera_rounded, const [
              _Body(
                'Personal photography in the greenhouses is allowed for private use.\n'
                'Commercial photography must be agreed separately — fee from 160 €/hour.',
              ),
            ]),

            _linkSection(
              icon: Icons.tour_rounded,
              title: 'Visit the Garden',
              body:
                  'The botanical garden is an excellent place for all ages to learn and enjoy the diversity of plants. In every season there is something new to find.',
              url: 'https://www.oulu.fi/en/university/botanical-garden/visit-garden',
            ),
            _linkSection(
              icon: Icons.eco_rounded,
              title: 'Seed Exchange — Index Seminum',
              body:
                  'We supply wild plant seeds and cuttings collected from Northern Finland and Lapland for international seed exchange.',
              url: 'https://www.oulu.fi/en/university/botanical-garden/seed-exchange',
            ),
            _linkSection(
              icon: Icons.science_rounded,
              title: 'Research at the Botanical Garden',
              body:
                  'In its research activities, the Botanical Garden is primarily a research support unit whose mission is to provide living plant material, breeding facilities and practical assistance to researchers and students.',
              url:
                  'https://www.oulu.fi/en/university/botanical-garden/research-botanical-garden',
            ),
            _linkSection(
              icon: Icons.museum_rounded,
              title: 'University of Oulu Botanical Museum',
              body:
                  'The Botanical Museum maintains and increases the university\'s scientific plant and fungus collections, as well as the study collections of the University of Oulu.',
              url:
                  'https://www.oulu.fi/en/research/research-infrastructures/biodiversity-unit/botanical-museum',
            ),

            _section(s.contact, Icons.email_rounded, [
              const _InfoLine('Address', _address),
              const _InfoLine('Email', _mainEmail),
              const _InfoLine('Website', 'oulu.fi/.../botanical-garden'),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _actionButton(
                      icon: Icons.location_on_rounded,
                      label: s.openInMaps,
                      color: const Color(0xFF64B5F6),
                      onTap: () => launchUrl(Uri.parse(_mapsUrl),
                          mode: LaunchMode.externalApplication),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _actionButton(
                      icon: Icons.mail_rounded,
                      label: 'Email',
                      color: const Color(0xFF66BB6A),
                      onTap: () =>
                          launchUrl(Uri.parse('mailto:$_mainEmail')),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _actionButton(
                      icon: Icons.language_rounded,
                      label: 'Website',
                      color: const Color(0xFFFFB74D),
                      onTap: () => launchUrl(Uri.parse(_website),
                          mode: LaunchMode.externalApplication),
                    ),
                  ),
                ],
              ),
            ]),

            const SizedBox(height: 20),
            const DevelopedByCard(),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  // ── Building blocks ───────────────────────────────────────────────────

  Widget _headerCard(dynamic s) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF162B1C), Color(0xFF0F2018)],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF2A4A2F)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text('Oulu Botanical Garden',
              style: TextStyle(
                  color: Color(0xFFE8F5E9),
                  fontSize: 20,
                  fontWeight: FontWeight.w800)),
          SizedBox(height: 4),
          Text('Oulun kasvitieteellinen puutarha',
              style: TextStyle(
                  color: Color(0xFF81C784),
                  fontSize: 13,
                  fontStyle: FontStyle.italic)),
          SizedBox(height: 10),
          Text(
            'University of Oulu · Linnanmaa campus\n$_address',
            style: TextStyle(color: Color(0xFFC5E1A5), fontSize: 13, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _section(String title, IconData icon, List<Widget> children) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF111F16),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF2A4A2F)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: const Color(0xFF66BB6A), size: 18),
                const SizedBox(width: 8),
                Text(title,
                    style: const TextStyle(
                        color: Color(0xFFE8F5E9),
                        fontSize: 15,
                        fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _linkSection({
    required IconData icon,
    required String title,
    required String body,
    required String url,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => launchUrl(Uri.parse(url),
              mode: LaunchMode.externalApplication),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF111F16),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF2A4A2F)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, color: const Color(0xFF66BB6A), size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(title,
                          style: const TextStyle(
                              color: Color(0xFFE8F5E9),
                              fontSize: 15,
                              fontWeight: FontWeight.w700)),
                    ),
                    const Icon(Icons.open_in_new_rounded,
                        color: Color(0xFF4A7A50), size: 16),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  body,
                  style: const TextStyle(
                      color: Color(0xFFC5E1A5), fontSize: 13, height: 1.45),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _subTitle(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text,
            style: const TextStyle(
                color: Color(0xFF81C784),
                fontSize: 13,
                fontWeight: FontWeight.w700)),
      );

  Widget _actionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 8),
              Text(label,
                  style: TextStyle(
                      color: color,
                      fontSize: 12,
                      fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Body paragraph ──────────────────────────────────────────────────────────
class _Body extends StatelessWidget {
  final String text;
  const _Body(this.text);
  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
            color: Color(0xFFC5E1A5), fontSize: 13, height: 1.5),
      );
}

// ─── Two-column info line ────────────────────────────────────────────────────
class _InfoLine extends StatelessWidget {
  final String label;
  final String value;
  const _InfoLine(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 88,
            child: Text(label,
                style: const TextStyle(
                    color: Color(0xFF4A7A50), fontSize: 12)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    color: Color(0xFFE8F5E9),
                    fontSize: 13,
                    fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}


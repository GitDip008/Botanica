import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/garden_schedule.dart';
import '../services/holiday_hours_service.dart';
import '../services/language_service.dart';

/// Minimal page shown when the Open/Closed chip is tapped.
/// Only schedule info — full garden info lives in About Us.
class ScheduleScreen extends StatelessWidget {
  const ScheduleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<LanguageService>().strings;
    final isOpen = GardenSchedule.isOpen();
    return Scaffold(
      backgroundColor: const Color(0xFF0A1A0F),
      appBar: AppBar(
        title: Text(s.openingHours),
        backgroundColor: const Color(0xFF0D1F14),
        elevation: 0,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Current status badge
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isOpen
                      ? [const Color(0xFF1B4D20), const Color(0xFF2E7D32)]
                      : [const Color(0xFF3B0B14), const Color(0xFF8C2336)],
                ),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                children: [
                  Icon(
                    isOpen ? Icons.check_circle_rounded : Icons.cancel_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    isOpen ? s.statusOpen : s.statusClosed,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),
            _section(s.greenhouses, [
              ['Monday', 'Closed'],
              ['Tuesday', '10:00 – 16:00'],
              ['Wednesday', '10:00 – 16:00'],
              ['Thursday', '10:00 – 16:00'],
              ['Friday', '10:00 – 16:00'],
              ['Saturday', '10:00 – 16:00'],
              ['Sunday', '10:00 – 16:00'],
            ]),
            const SizedBox(height: 16),
            _section(s.outdoorGarden, const [
              ['Daily', '08:00 – 20:00'],
              ['Entrance', 'Free'],
            ]),
            const SizedBox(height: 16),
            // Live holiday hours from Firestore (with hardcoded fallback)
            StreamBuilder<HolidayHoursDoc>(
              stream: HolidayHoursService.instance.watch(),
              builder: (ctx, snap) {
                final rows = (snap.data?.entries.isNotEmpty ?? false)
                    ? snap.data!.entries
                        .map((e) => [e.label, e.hours])
                        .toList()
                    : const [
                        ['Good Friday · 3 Apr', 'Closed'],
                        ['Saturday · 4 Apr', '10 – 16'],
                        ['Easter Sunday · 5 Apr', '10 – 16'],
                        ['Easter Monday · 6 Apr', 'Closed'],
                        ['May Day · 1 May', 'Closed'],
                        ['Ascension Day · 14 May', 'Closed'],
                        ['Whit Sunday · 24 May', '10 – 16'],
                        ['Midsummer Eve · 19 Jun', 'Closed'],
                        ['Midsummer Day · 20 Jun', 'Closed'],
                      ];
                return _section(s.holidayHours, rows);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _section(String title, List<List<String>> rows) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF111F16),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2A4A2F)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  color: Color(0xFFE8F5E9),
                  fontSize: 15,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          ...rows.map((r) {
            final closed = r[1].toLowerCase().contains('closed');
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Text(r[0],
                        style: const TextStyle(
                            color: Color(0xFFE8F5E9), fontSize: 13)),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      r[1],
                      textAlign: TextAlign.end,
                      style: TextStyle(
                        color: closed
                            ? const Color(0xFFEF5350)
                            : const Color(0xFF81C784),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

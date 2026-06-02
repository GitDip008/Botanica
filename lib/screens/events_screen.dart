import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/event_request.dart';
import '../services/auth_service.dart';
import '../services/event_service.dart';
import '../services/language_service.dart';

class EventsScreen extends StatefulWidget {
  /// If provided, auto-opens the event detail sheet for this ID on first load.
  /// Used when a push notification taps through to a specific event.
  final String? highlightEventId;
  const EventsScreen({super.key, this.highlightEventId});

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  bool _highlightShown = false;

  void _maybeShowHighlight(List<EventRequest> events) {
    if (_highlightShown || widget.highlightEventId == null) return;
    EventRequest? match;
    for (final e in events) {
      if (e.id == widget.highlightEventId) {
        match = e;
        break;
      }
    }
    if (match == null) return;
    _highlightShown = true;
    final m = match;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _showDetails(m);
    });
  }

  /// Hardcoded fallback events shown when the Firestore scrape isn't running.
  /// Pulled from the live list on https://www.oulu.fi/en/events — update as
  /// new ones get published. Each one links back to its oulu.fi page.
  List<EventRequest> _fallbackEvents() {
    final now = DateTime.now();
    EventRequest mk({
      required String id,
      required String name,
      required String description,
      required DateTime date,
      required String startTime,
      required String endTime,
      required String location,
      required String sourceUrl,
    }) {
      return EventRequest(
        id: id,
        userId: 'oulu',
        userName: 'Oulu University Events',
        userEmail: 'events@oulu.fi',
        name: name,
        description: description,
        attendees: 0,
        date: date,
        time: '$startTime – $endTime',
        startTime: startTime,
        endTime: endTime,
        spaceRequirements: location,
        status: EventStatus.approved,
        createdAt: now,
        isPublic: true,
        capacity: 0,
        rsvpUserIds: const [],
        sourceUrl: sourceUrl,
      );
    }

    // Snapshot of https://www.oulu.fi/en/events taken on 2026-06-02.
    // Each entry links back to its actual oulu.fi event page.
    return [
      mk(
        id: 'oulu-linnanmaa-picnic',
        name: 'Linnanmaa Picnic',
        description:
            'Annual outdoor picnic on the Linnanmaa campus lawn. Bring a blanket, meet students and staff, enjoy food and music.',
        date: DateTime.parse('2026-06-02T13:00:00Z').toLocal(),
        startTime: '15:00',
        endTime: '18:30',
        location: 'Linnanmaa campus lawn',
        sourceUrl: 'https://www.oulu.fi/en/events/linnanmaa-picnic-1',
      ),
      mk(
        id: 'oulu-textailes-day',
        name: 'A day with TEXTaiLES',
        description:
            'Discover how AI is transforming the digitization of cultural heritage textiles. Talks, demos, and Q&A with the TEXTaiLES research team.',
        date: DateTime.parse('2026-06-03T05:30:00Z').toLocal(),
        startTime: '08:30',
        endTime: '18:00',
        location: 'University of Oulu',
        sourceUrl:
            'https://www.oulu.fi/en/events/day-textailes-discover-how-ai-transforming-digitization-cultural-heritage-textiles',
      ),
      mk(
        id: 'oulu-textiles-threads',
        name: 'Unravelling Hidden Threads',
        description:
            'Digital journeys into early modern textiles. Exhibition exploring how researchers reveal hidden stories in historic fabrics.',
        date: DateTime.parse('2026-05-24T21:00:00Z').toLocal(),
        startTime: '00:00',
        endTime: '23:59',
        location: 'University of Oulu',
        sourceUrl:
            'https://www.oulu.fi/en/events/unravelling-hidden-threads-digital-journeys-early-modern-textiles',
      ),
      mk(
        id: 'oulu-mazzone-exhibition',
        name: 'Enrico Mazzone: Alitajunta',
        description:
            'Exhibition by Italian artist Enrico Mazzone, running June 1 – July 31, 2026. Surreal large-scale drawings exploring the subconscious.',
        date: DateTime.parse('2026-05-31T21:00:00Z').toLocal(),
        startTime: '00:00',
        endTime: '23:59',
        location: 'University of Oulu',
        sourceUrl:
            'https://www.oulu.fi/en/events/enrico-mazzone-alitajunta-exhibition-june-1-july-31-2026',
      ),
      mk(
        id: 'oulu-art-tours',
        name: 'Art Tours in English 2026',
        description:
            'Experience the Art Collection of the University of Oulu. Guided English-language tours running throughout 2026.',
        date: DateTime.parse('2026-01-21T22:00:00Z').toLocal(),
        startTime: '00:00',
        endTime: '23:59',
        location: 'University of Oulu Art Collection',
        sourceUrl:
            'https://www.oulu.fi/en/events/art-tours-english-2026-experience-art-collection-university-oulu',
      ),
      mk(
        id: 'oulu-ribbons-growth',
        name: 'Campus as a Stage: Ribbons of Growth',
        description:
            'Collaborative ribbon art installation. Add your own ribbon and watch the artwork grow with the campus community.',
        date: DateTime.parse('2026-01-21T22:00:00Z').toLocal(),
        startTime: '00:00',
        endTime: '23:59',
        location: 'Linnanmaa campus',
        sourceUrl:
            'https://www.oulu.fi/en/events/campus-stage-exhibitions-ribbons-growth-collaborative-ribbon-art-installation',
      ),
      mk(
        id: 'oulu-window-magnet',
        name: 'Window magnet love poem',
        description:
            'Campus as a Stage exhibition. Poetic window installations across the Linnanmaa campus throughout the year.',
        date: DateTime.parse('2026-01-21T22:00:00Z').toLocal(),
        startTime: '00:00',
        endTime: '23:59',
        location: 'Linnanmaa campus windows',
        sourceUrl:
            'https://www.oulu.fi/en/events/campus-stage-exhibitions-window-magnet-love-poem',
      ),
      mk(
        id: 'oulu-virtual-geology',
        name: 'Virtual geology',
        description:
            'Year-long virtual geology experience. Explore rocks, minerals, and geological history of northern Finland from anywhere.',
        date: DateTime.parse('2025-12-31T22:00:00Z').toLocal(),
        startTime: '00:00',
        endTime: '23:59',
        location: 'Online — University of Oulu',
        sourceUrl: 'https://www.oulu.fi/en/events/virtual-geology',
      ),
    ];
  }

  void _showDetails(EventRequest e) {
    final s = context.read<LanguageService>().strings;
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0D1F14),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _EventDetailsSheet(event: e, s: s),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<LanguageService>().strings;
    return Scaffold(
      backgroundColor: const Color(0xFF0D1F14),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A2E1E),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF66BB6A)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('📅 ${s.upcomingEvents}',
            style: const TextStyle(
                color: Color(0xFFE8F5E9), fontWeight: FontWeight.bold)),
      ),
      body: StreamBuilder<List<EventRequest>>(
        stream: EventService.instance.watchPublicApproved(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: Color(0xFF66BB6A)));
          }
          // Always include hardcoded fallback events so the page is never empty.
          // Firestore-scraped events (if any) take precedence by appearing first.
          final firestoreEvents = snap.data ?? const <EventRequest>[];
          final events = <EventRequest>[
            ...firestoreEvents,
            ..._fallbackEvents(),
          ];
          _maybeShowHighlight(events);
          if (events.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.event_busy_rounded,
                        color: Color(0xFF4A7A50), size: 64),
                    const SizedBox(height: 14),
                    Text(s.noPendingEvents,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: Color(0xFFE8F5E9),
                            fontSize: 15,
                            fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: events
                .map((e) => _EventCard(
                      event: e,
                      openLabel: s.openToAll,
                      highlight: e.id == widget.highlightEventId,
                      onTap: () => _showDetails(e),
                    ))
                .toList(),
          ).animate().fadeIn(duration: 400.ms);
        },
      ),
    );
  }
}

class _EventCard extends StatelessWidget {
  final EventRequest event;
  final String openLabel;
  final bool highlight;
  final VoidCallback onTap;
  const _EventCard({
    required this.event,
    required this.openLabel,
    required this.highlight,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('MMM d').format(event.date);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: highlight
                  ? const Color(0xFF1A3320)
                  : const Color(0xFF1A2E1E),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: highlight
                    ? const Color(0xFF66BB6A)
                    : const Color(0xFF2A4A2F),
                width: highlight ? 1.5 : 1,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 56,
                  padding:
                      const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF534AB7).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    dateStr,
                    style: const TextStyle(
                        color: Color(0xFF9B93E8),
                        fontSize: 12,
                        fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Expanded(
                          child: Text(event.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: Color(0xFFE8F5E9),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14)),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF66BB6A)
                                .withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            const Icon(Icons.public_rounded,
                                color: Color(0xFF66BB6A), size: 11),
                            const SizedBox(width: 3),
                            Text(openLabel,
                                style: const TextStyle(
                                    color: Color(0xFF66BB6A),
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700)),
                          ]),
                        ),
                      ]),
                      const SizedBox(height: 4),
                      Builder(builder: (ctx) {
                        final s2 = ctx.read<LanguageService>().strings;
                        return Text(
                            '${event.startTime} – ${event.endTime}  ·  ${s2.attendingCount(event.attendees)}',
                            style: const TextStyle(
                                color: Color(0xFF4A7A50), fontSize: 11));
                      }),
                      const SizedBox(height: 6),
                      Text(event.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Color(0xFF81C784),
                              fontSize: 12.5,
                              height: 1.45)),
                    ],
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

class _EventDetailsSheet extends StatelessWidget {
  final EventRequest event;
  final dynamic s;
  const _EventDetailsSheet({required this.event, required this.s});

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('EEEE, MMMM d, yyyy').format(event.date);
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollCtrl) => ListView(
        controller: scrollCtrl,
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: const Color(0xFF2A4A2F),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Text(event.name,
              style: const TextStyle(
                  color: Color(0xFFE8F5E9),
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  height: 1.2)),
          const SizedBox(height: 10),
          Row(children: [
            const Icon(Icons.public_rounded,
                color: Color(0xFF66BB6A), size: 16),
            const SizedBox(width: 6),
            Text(s.openToAll,
                style: const TextStyle(
                    color: Color(0xFF66BB6A),
                    fontSize: 12,
                    fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 18),
          _row(Icons.calendar_today_rounded, s.eventDate, dateStr),
          _row(Icons.access_time_rounded, s.eventTime,
              '${event.startTime} – ${event.endTime}'),
          _row(Icons.people_outline_rounded, s.eventAttendeesLabel,
              '${event.attendees}'),
          if (event.spaceRequirements.isNotEmpty)
            _row(Icons.place_outlined, s.eventSpace, event.spaceRequirements),
          _row(Icons.person_outline_rounded, s.eventOrganizer,
              event.userName.isEmpty ? event.userEmail : event.userName),
          const SizedBox(height: 18),
          Text(s.eventDescription,
              style: const TextStyle(
                  color: Color(0xFF4A7A50),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.4)),
          const SizedBox(height: 8),
          Text(event.description,
              style: const TextStyle(
                  color: Color(0xFFE8F5E9), fontSize: 14, height: 1.55)),
          if (event.sourceUrl != null) ...[
            const SizedBox(height: 14),
            InkWell(
              onTap: () async {
                final uri = Uri.parse(event.sourceUrl!);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
              child: Row(children: [
                const Icon(Icons.open_in_new_rounded,
                    color: Color(0xFF66BB6A), size: 16),
                const SizedBox(width: 6),
                Text(s.viewOnOuluFi,
                    style: const TextStyle(
                        color: Color(0xFF66BB6A),
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        decoration: TextDecoration.underline)),
              ]),
            ),
          ],
          const SizedBox(height: 20),
          _RsvpButton(event: event, s: s),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close_rounded, size: 18),
            label: Text(s.close),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF81C784),
              side: const BorderSide(color: Color(0xFF2A4A2F)),
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFF66BB6A), size: 16),
          const SizedBox(width: 10),
          SizedBox(
            width: 110,
            child: Text(label,
                style: const TextStyle(
                    color: Color(0xFF81C784), fontSize: 12)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    color: Color(0xFFE8F5E9),
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

/// RSVP / cancel / waitlist button — handles capacity logic.
class _RsvpButton extends StatefulWidget {
  final EventRequest event;
  final dynamic s;
  const _RsvpButton({required this.event, required this.s});

  @override
  State<_RsvpButton> createState() => _RsvpButtonState();
}

class _RsvpButtonState extends State<_RsvpButton> {
  bool _busy = false;
  late EventRequest _event = widget.event;

  Future<void> _toggle() async {
    final uid = AuthService.instance.currentUser?.id;
    if (uid == null) return;
    setState(() => _busy = true);
    final ok = await EventService.instance.toggleRsvp(_event.id, uid);
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (ok) {
        // Optimistically reflect the toggle locally
        final list = List<String>.from(_event.rsvpUserIds);
        if (list.contains(uid)) {
          list.remove(uid);
        } else {
          list.add(uid);
        }
        _event = EventRequest(
          id: _event.id,
          userId: _event.userId,
          userName: _event.userName,
          userEmail: _event.userEmail,
          name: _event.name,
          description: _event.description,
          attendees: _event.attendees,
          date: _event.date,
          time: _event.time,
          startTime: _event.startTime,
          endTime: _event.endTime,
          spaceRequirements: _event.spaceRequirements,
          status: _event.status,
          createdAt: _event.createdAt,
          isPublic: _event.isPublic,
          capacity: _event.capacity,
          rsvpUserIds: list,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    final uid = AuthService.instance.currentUser?.id;
    final going = uid != null && _event.rsvpUserIds.contains(uid);
    final full = _event.isFull && !going;
    final left = _event.spotsRemaining;

    String label;
    IconData icon;
    Color color;
    if (going) {
      label = s.cancelRsvp;
      icon = Icons.check_circle_rounded;
      color = const Color(0xFF66BB6A);
    } else if (full) {
      label = s.eventFull;
      icon = Icons.lock_rounded;
      color = const Color(0xFFEF5350);
    } else {
      label = left > 0 ? '${s.rsvp}  ·  ${s.spotsLeft(left)}' : s.rsvp;
      icon = Icons.event_available_rounded;
      color = const Color(0xFF2E7D32);
    }

    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: full ? Colors.grey[800] : color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
      ),
      icon: _busy
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                  color: Colors.white, strokeWidth: 2))
          : Icon(icon, size: 18),
      label: Text(label,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
      onPressed: (_busy || full || uid == null) ? null : _toggle,
    );
  }
}

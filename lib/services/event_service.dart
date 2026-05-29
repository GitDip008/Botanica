import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/event_request.dart';

/// Manages event proposals — Firestore storage, mailto email to admin, and
/// admin moderation.
class EventService {
  EventService._();
  static final EventService instance = EventService._();

  static const adminEmail = 'kasvitieteellinen.puutarha@oulu.fi';

  final _firestore = FirebaseFirestore.instance;

  /// Submits a new event request. Writes to Firestore and opens the user's
  /// email client with a pre-filled message to the garden admin.
  Future<EventRequest> submit({
    required String userId,
    required String userName,
    required String userEmail,
    required String name,
    required String description,
    required int attendees,
    required DateTime date,
    required String startTime,
    required String endTime,
    required String spaceRequirements,
  }) async {
    final docRef = _firestore.collection('events').doc();
    final req = EventRequest(
      id: docRef.id,
      userId: userId,
      userName: userName,
      userEmail: userEmail,
      name: name,
      description: description,
      attendees: attendees,
      date: date,
      time: '$startTime – $endTime',
      startTime: startTime,
      endTime: endTime,
      spaceRequirements: spaceRequirements,
      status: EventStatus.pending,
      createdAt: DateTime.now(),
    );
    await docRef.set(req.toJson());
    await _emailAdmin(req);
    return req;
  }

  Future<void> _emailAdmin(EventRequest r) async {
    final dateStr = DateFormat('EEEE, MMMM d, yyyy').format(r.date);
    final subject = 'New event request: ${r.name}';
    final body = '''A new event has been submitted via the Botanica app.

EVENT NAME
${r.name}

DESCRIPTION
${r.description}

DATE & TIME
$dateStr · ${r.startTime} – ${r.endTime}

EXPECTED ATTENDEES
${r.attendees}

SPACE REQUIREMENTS
${r.spaceRequirements}

SUBMITTED BY
${r.userName}
${r.userEmail}

Please review and respond directly to the visitor.
— Botanica admin panel''';

    final uri = Uri(
      scheme: 'mailto',
      path: adminEmail,
      queryParameters: {'subject': subject, 'body': body},
    );
    try {
      await launchUrl(uri);
    } catch (_) {/* email app may not be installed — Firestore still has it */}
  }

  /// Stream of all events for the admin panel, newest first.
  Stream<List<EventRequest>> watchAll() {
    return _firestore
        .collection('events')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => EventRequest.fromJson(d.data())).toList());
  }

  /// Stream of pending events only.
  Stream<List<EventRequest>> watchPending() {
    return _firestore
        .collection('events')
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => EventRequest.fromJson(d.data())).toList());
  }

  /// Updates the status of an event.
  Future<void> setStatus(String eventId, EventStatus status) async {
    await _firestore
        .collection('events')
        .doc(eventId)
        .update({'status': status.name});
  }
}

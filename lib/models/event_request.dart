enum EventStatus { pending, approved, rejected }

class EventRequest {
  final String id;
  final String userId;
  final String userName;
  final String userEmail;
  final String name;
  final String description;
  final int attendees;
  final DateTime date;
  final String time; // legacy single field — kept for backward compat
  final String startTime; // "14:30"
  final String endTime;   // "16:30"
  final String spaceRequirements;
  final EventStatus status;
  final DateTime createdAt;
  final bool isPublic; // open-to-all → auto-publish on approval
  final int capacity;  // 0 = unlimited
  final List<String> rsvpUserIds;
  final String? sourceUrl; // set by oulu.fi scraper

  const EventRequest({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userEmail,
    required this.name,
    required this.description,
    required this.attendees,
    required this.date,
    required this.time,
    required this.startTime,
    required this.endTime,
    required this.spaceRequirements,
    this.status = EventStatus.pending,
    required this.createdAt,
    this.isPublic = false,
    this.capacity = 0,
    this.rsvpUserIds = const [],
    this.sourceUrl,
  });

  /// Number of remaining spots (clamped to 0). Returns -1 when unlimited.
  int get spotsRemaining {
    if (capacity <= 0) return -1;
    final taken = rsvpUserIds.length;
    return (capacity - taken).clamp(0, capacity);
  }

  bool get isFull => capacity > 0 && rsvpUserIds.length >= capacity;

  Map<String, dynamic> toJson() => {
        'id': id,
        'userId': userId,
        'userName': userName,
        'userEmail': userEmail,
        'name': name,
        'description': description,
        'attendees': attendees,
        'date': date.toIso8601String(),
        'time': time,
        'startTime': startTime,
        'endTime': endTime,
        'spaceRequirements': spaceRequirements,
        'status': status.name,
        'createdAt': createdAt.toIso8601String(),
        'isPublic': isPublic,
        'capacity': capacity,
        'rsvpUserIds': rsvpUserIds,
        if (sourceUrl != null) 'sourceUrl': sourceUrl,
      };

  factory EventRequest.fromJson(Map<String, dynamic> j) => EventRequest(
        id: j['id'] as String,
        userId: j['userId'] as String,
        userName: j['userName'] as String,
        userEmail: j['userEmail'] as String,
        name: j['name'] as String,
        description: j['description'] as String,
        attendees: (j['attendees'] as num).toInt(),
        date: DateTime.parse(j['date'] as String),
        time: j['time'] as String? ?? '',
        startTime: (j['startTime'] as String?) ?? (j['time'] as String? ?? ''),
        endTime: (j['endTime'] as String?) ?? '',
        spaceRequirements: j['spaceRequirements'] as String,
        status: EventStatus.values.firstWhere(
          (s) => s.name == j['status'],
          orElse: () => EventStatus.pending,
        ),
        createdAt: DateTime.parse(j['createdAt'] as String),
        isPublic: (j['isPublic'] as bool?) ?? false,
        capacity: (j['capacity'] as num?)?.toInt() ?? 0,
        rsvpUserIds: ((j['rsvpUserIds'] as List?) ?? const [])
            .whereType<String>()
            .toList(),
        sourceUrl: j['sourceUrl'] as String?,
      );
}

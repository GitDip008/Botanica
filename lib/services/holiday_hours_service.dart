import 'package:cloud_firestore/cloud_firestore.dart';

/// One holiday-hours row — label (date + name) and the hours string.
class HolidayEntry {
  final String label;
  final String hours;
  const HolidayEntry({required this.label, required this.hours});

  Map<String, dynamic> toJson() => {'label': label, 'hours': hours};
  factory HolidayEntry.fromJson(Map<String, dynamic> j) => HolidayEntry(
        label: (j['label'] as String?) ?? '',
        hours: (j['hours'] as String?) ?? '',
      );
}

/// Snapshot of /config/holiday_hours.
class HolidayHoursDoc {
  final List<HolidayEntry> entries;
  final DateTime? lastUpdatedAt;
  final String lastUpdateSource; // 'auto' | 'manual'
  final String? scrapeError;

  const HolidayHoursDoc({
    required this.entries,
    this.lastUpdatedAt,
    this.lastUpdateSource = 'manual',
    this.scrapeError,
  });

  bool get hasError => scrapeError != null && scrapeError!.isNotEmpty;

  factory HolidayHoursDoc.fromJson(Map<String, dynamic> j) {
    final list = (j['entries'] as List?) ?? const [];
    final ts = j['lastUpdatedAt'];
    DateTime? when;
    if (ts is Timestamp) when = ts.toDate();
    if (ts is String) when = DateTime.tryParse(ts);
    return HolidayHoursDoc(
      entries:
          list.map((e) => HolidayEntry.fromJson(e as Map<String, dynamic>)).toList(),
      lastUpdatedAt: when,
      lastUpdateSource: (j['lastUpdateSource'] as String?) ?? 'manual',
      scrapeError: j['scrapeError'] as String?,
    );
  }
}

class HolidayHoursService {
  HolidayHoursService._();
  static final instance = HolidayHoursService._();

  final _doc =
      FirebaseFirestore.instance.collection('config').doc('holiday_hours');

  Stream<HolidayHoursDoc> watch() =>
      _doc.snapshots().map((s) => HolidayHoursDoc.fromJson(s.data() ?? {}));

  Future<HolidayHoursDoc?> get() async {
    final s = await _doc.get();
    if (!s.exists) return null;
    return HolidayHoursDoc.fromJson(s.data()!);
  }

  Future<void> save(List<HolidayEntry> entries) async {
    await _doc.set({
      'entries': entries.map((e) => e.toJson()).toList(),
      'lastUpdatedAt': FieldValue.serverTimestamp(),
      'lastUpdateSource': 'manual',
      'scrapeError': null,
    }, SetOptions(merge: true));
  }

  // ── Paste-text parser ──────────────────────────────────────────────────
  /// Parses pasted holiday text into HolidayEntry rows. Permissive — skips
  /// blank/garbage lines. Handles "Closed", time ranges like "10-16",
  /// "10 – 16", "10:00 – 16:00", etc.
  static List<HolidayEntry> parse(String raw) {
    final lines = raw
        .replaceAll('\r', '\n')
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    final out = <HolidayEntry>[];
    // Matches "Closed" (any case)
    final closedRe = RegExp(r'\bclosed\b', caseSensitive: false);
    // Matches time ranges:  10-16 | 10 -16 | 10–16 | 10 – 16 | 10:00-16:00
    final rangeRe = RegExp(
      r'(\d{1,2})(?::(\d{2}))?\s*[-–—]\s*(\d{1,2})(?::(\d{2}))?',
    );

    for (final line in lines) {
      // Heuristic 1 — Closed
      if (closedRe.hasMatch(line)) {
        final label = line.replaceAll(closedRe, '').trim();
        if (label.isEmpty) continue;
        out.add(HolidayEntry(label: _normLabel(label), hours: 'Closed'));
        continue;
      }
      // Heuristic 2 — time range.
      //
      // Take the LAST plausible range, not the first. A row like
      // "Whitsun 5-7 June 10-16" opens with a DATE range, and matching first
      // produced opening hours of "5 – 7". Real hours follow the date.
      final monthRe = RegExp(
        r'(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)',
        caseSensitive: false,
      );
      final candidates = rangeRe.allMatches(line).where((mm) {
        final after = line.substring(
          mm.end,
          (mm.end + 12).clamp(0, line.length),
        );
        if (monthRe.hasMatch(after)) return false; // a date span, not hours
        final sh = int.tryParse(mm.group(1) ?? '') ?? -1;
        final eh = int.tryParse(mm.group(3) ?? '') ?? -1;
        return sh >= 0 && sh <= 23 && eh >= 1 && eh <= 24 && eh > sh;
      }).toList();

      final m = candidates.isEmpty ? null : candidates.last;
      if (m != null) {
        final start = '${m.group(1)}${m.group(2) != null ? ':${m.group(2)}' : ''}';
        final end = '${m.group(3)}${m.group(4) != null ? ':${m.group(4)}' : ''}';
        final hours = '$start – $end';
        final label = line.substring(0, m.start).trim();
        if (label.isEmpty) continue;
        out.add(HolidayEntry(label: _normLabel(label), hours: hours));
        continue;
      }
      // else: skip — couldn't parse
    }
    return out;
  }

  static String _normLabel(String s) {
    // Collapse whitespace
    return s.replaceAll(RegExp(r'\s+'), ' ').trim();
  }
}

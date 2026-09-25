/// Oulu Botanical Garden opening hours.
///
///   Monday    : Closed
///   Tue – Sun : 10:00 – 16:00
class GardenSchedule {
  /// Returns true if the garden is currently open.
  /// One-off evening openings outside the normal hours, [start, end).
  static final specialOpenings = [
    (DateTime(2026, 9, 25, 17), DateTime(2026, 9, 25, 21)), // Researchers' Night
  ];

  static bool isOpen([DateTime? now]) {
    final n = now ?? DateTime.now();
    for (final (start, end) in specialOpenings) {
      if (!n.isBefore(start) && n.isBefore(end)) return true;
    }
    // Monday is closed
    if (n.weekday == DateTime.monday) return false;
    final m = n.hour * 60 + n.minute;
    const openMin = 10 * 60;
    const closeMin = 16 * 60;
    return m >= openMin && m < closeMin;
  }

  /// "16:00" format string of next opening or closing time.
  static String nextTransitionTime(DateTime now) {
    if (isOpen(now)) return '16:00';
    return '10:00';
  }
}

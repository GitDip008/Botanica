// test/holiday_parse_test.dart
//
// The holiday parser must not mistake a DATE range for opening hours. That is
// what put a row reading "5 – 7" at the top of the schedule screen.

import 'package:botanica_ar/services/holiday_hours_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('holiday hours parsing', () {
    test('a leading date range is not treated as opening hours', () {
      final r = HolidayHoursService.parse('Whitsun 5-7 June 10-16');
      expect(r.single.hours, '10 – 16');
      expect(r.single.label, contains('Whitsun'));
    });

    test('plain rows still parse', () {
      final r = HolidayHoursService.parse('Sat 4th April 10 -16');
      expect(r.single.hours, '10 – 16');
    });

    test('Closed rows are unaffected', () {
      final r = HolidayHoursService.parse('Good Friday 3rd April closed');
      expect(r.single.hours, 'Closed');
      expect(r.single.label, contains('Good Friday'));
    });

    test('a date-only row yields nothing rather than nonsense hours', () {
      // "19-21 June" with no hours must be skipped, not published as 19 – 21.
      expect(HolidayHoursService.parse('Midsummer 19-21 June'), isEmpty);
    });

    test('impossible clock values are rejected', () {
      expect(HolidayHoursService.parse('Something 40-99'), isEmpty);
    });

    test('full clock times survive', () {
      final r = HolidayHoursService.parse('Sunday 5 July 10:00 – 16:30');
      expect(r.single.hours, '10:00 – 16:30');
    });

    test('blank and junk lines are skipped', () {
      expect(HolidayHoursService.parse('\n\n   \n'), isEmpty);
    });
  });
}

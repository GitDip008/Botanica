import 'package:botanica_ar/services/garden_schedule.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('normal hours', () {
    expect(GardenSchedule.isOpen(DateTime(2026, 9, 24, 12)), isTrue); // Thu
    expect(GardenSchedule.isOpen(DateTime(2026, 9, 24, 17)), isFalse);
    expect(GardenSchedule.isOpen(DateTime(2026, 9, 28, 12)), isFalse); // Mon
  });

  test("open for Researchers' Night evening only", () {
    expect(GardenSchedule.isOpen(DateTime(2026, 9, 25, 16, 30)), isFalse);
    expect(GardenSchedule.isOpen(DateTime(2026, 9, 25, 17)), isTrue);
    expect(GardenSchedule.isOpen(DateTime(2026, 9, 25, 20, 59)), isTrue);
    expect(GardenSchedule.isOpen(DateTime(2026, 9, 25, 21)), isFalse);
  });
}

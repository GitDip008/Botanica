// test/camera_zoom_test.dart
//
// The zoom stepper. Worth pinning because the device range it has to work
// inside varies wildly — a phone may report a maximum of 4× or of 100× — and
// the first version stepped by a fraction of that range, which behaved
// completely differently on different phones.

import 'package:botanica_ar/services/camera_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('zoom stepper', () {
    test('walks whole levels up and back down', () {
      expect(nextZoom(1, 1, 1, 10), 2);
      expect(nextZoom(2, 1, 1, 10), 3);
      expect(nextZoom(3, -1, 1, 10), 2);
      expect(nextZoom(2, -1, 1, 10), 1);
    });

    test('steps the same amount whatever the device maximum', () {
      // The bug this replaces: an eighth of the range moved 0.4× on one phone
      // and 12× on another.
      expect(nextZoom(1, 1, 1, 4), 2);
      expect(nextZoom(1, 1, 1, 100), 2);
    });

    test('never leaves the supported range', () {
      expect(nextZoom(10, 1, 1, 10), 10);
      expect(nextZoom(1, -1, 1, 10), 1);
      // An ultra-wide lens starting below 1×.
      expect(nextZoom(1, -1, 0.5, 10), 0.5);
      expect(nextZoom(0.5, 1, 0.5, 10), 1);
    });

    test('a press after a pinch always moves', () {
      // Pinching leaves fractional levels. Rounding to the nearest whole number
      // must not hand back the level already showing, or the button looks dead.
      expect(nextZoom(2.4, 1, 1, 10), 3);
      expect(nextZoom(2.4, -1, 1, 10), 2);
      // Both of these read as "2.0×" on screen, so a press must land where a
      // press at exactly 2.0 would — not back on 2 itself.
      expect(nextZoom(2.0000001, -1, 1, 10), 1);
      expect(nextZoom(1.9999999, 1, 1, 10), 3);
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:music_player/core/utils/format.dart';

void main() {
  group('formatDuration', () {
    test('formats sub-minute values', () {
      expect(formatDuration(Duration.zero), '0:00');
      expect(formatDuration(const Duration(seconds: 42)), '0:42');
      expect(formatDuration(const Duration(seconds: 9)), '0:09');
    });

    test('formats minutes without padding', () {
      expect(formatDuration(const Duration(minutes: 3, seconds: 7)), '3:07');
      expect(formatDuration(const Duration(minutes: 10)), '10:00');
    });

    test('promotes to hours', () {
      expect(formatDuration(const Duration(hours: 1)), '1:00:00');
      expect(
        formatDuration(const Duration(hours: 1, minutes: 2, seconds: 5)),
        '1:02:05',
      );
      expect(
        formatDuration(const Duration(hours: 12, minutes: 4, seconds: 3)),
        '12:04:03',
      );
    });
  });

  group('formatSpeed', () {
    test('drops trailing zeros', () {
      expect(formatSpeed(1.0), '1×');
      expect(formatSpeed(2.0), '2×');
      expect(formatSpeed(0.5), '0.5×');
      expect(formatSpeed(1.25), '1.25×');
      expect(formatSpeed(0.75), '0.75×');
    });
  });

  group('formatPlayCount', () {
    test('singular only at one', () {
      expect(formatPlayCount(0), '0 plays');
      expect(formatPlayCount(1), '1 play');
      expect(formatPlayCount(12), '12 plays');
    });
  });
}

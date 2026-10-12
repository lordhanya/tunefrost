import 'package:flutter_test/flutter_test.dart';
import 'package:music_player/features/playback/equalizer_presets.dart';

void main() {
  const fiveBand = [60.0, 230.0, 910.0, 3600.0, 14000.0];
  const tenBand = [
    31.0,
    62.0,
    125.0,
    250.0,
    500.0,
    1000.0,
    2000.0,
    4000.0,
    8000.0,
    16000.0,
  ];

  group('EqualizerPreset', () {
    test('every preset is named with ascending control points', () {
      expect(kEqualizerPresets, isNotEmpty);
      for (final preset in kEqualizerPresets) {
        expect(preset.name, isNotEmpty);
        expect(preset.points.length, greaterThanOrEqualTo(2));
        for (var i = 1; i < preset.points.length; i++) {
          expect(
            preset.points[i].$1,
            greaterThan(preset.points[i - 1].$1),
            reason: '${preset.name}: control points must ascend',
          );
        }
      }
    });

    test(
      'interpolates linearly between control points and beyond the ends',
      () {
        const ramp = EqualizerPreset('ramp', [(0.0, 0.0), (1.0, 10.0)]);

        expect(ramp.gainAt(0), 0.0);
        expect(ramp.gainAt(0.25), closeTo(2.5, 1e-9));
        expect(ramp.gainAt(0.5), closeTo(5.0, 1e-9));
        expect(ramp.gainAt(1), 10.0);
        expect(ramp.gainAt(-1), 0.0); // below the lowest band holds
        expect(ramp.gainAt(9), 10.0); // above the highest band holds
      },
    );

    test('maps onto any band layout and clamps to the device range', () {
      const bass = EqualizerPreset('bass', [(0.0, 12.0), (1.0, 0.0)]);

      final gains = bass.gainsFor(fiveBand, minDb: -15, maxDb: 15);
      expect(gains, hasLength(5));
      expect(gains.first, 12.0); // lowest band takes the full boost
      expect(gains.last, 0.0); // highest band untouched
      expect(gains.first, greaterThan(gains[2]));

      // The same curve on a wider band list, and on a device that only
      // offers a narrower level range.
      expect(bass.gainsFor(tenBand, minDb: -15, maxDb: 15), hasLength(10));
      expect(bass.gainsFor(fiveBand, minDb: -6, maxDb: 6).first, 6.0);
      expect(bass.gainsFor(fiveBand, minDb: -6, maxDb: 6).last, 0.0);
    });

    test('flat is flat on every band layout', () {
      final flat = kEqualizerPresets.firstWhere((p) => p.name == 'Flat');

      expect(flat.gainsFor(fiveBand, minDb: -15, maxDb: 15), everyElement(0.0));
      expect(flat.gainsFor([], minDb: -15, maxDb: 15), isEmpty);
    });
  });
}

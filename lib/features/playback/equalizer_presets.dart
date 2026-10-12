import 'dart:math' as math;

/// A named frequency-response curve for the Android equalizer.
///
/// A preset stores control points whose horizontal axis runs from the device's
/// lowest band centre to its highest on a logarithmic scale — not a fixed list
/// of gains. Band count and spacing differ between phones, so only the shape
/// survives the trip: each band reads its own interpolated value on apply.
class EqualizerPreset {
  const EqualizerPreset(this.name, this.points);

  final String name;

  /// `[position, gainDb]` pairs, ascending in position.
  final List<(double, double)> points;

  /// Linearly interpolated gain at [position] (0 = lowest band, 1 = highest).
  double gainAt(double position) {
    if (position <= points.first.$1) return points.first.$2;
    for (var i = 1; i < points.length; i++) {
      final (x0, y0) = points[i - 1];
      final (x1, y1) = points[i];
      if (position > x1) continue;
      if (x1 == x0) return y1;
      return y0 + (y1 - y0) * (position - x0) / (x1 - x0);
    }
    return points.last.$2;
  }

  /// Maps the curve onto [centerFrequencies] (Hz), clamping every gain to the
  /// range the device's equalizer actually accepts.
  List<double> gainsFor(
    List<double> centerFrequencies, {
    required double minDb,
    required double maxDb,
  }) {
    if (centerFrequencies.isEmpty) return const [];
    final low = math.log(centerFrequencies.first);
    final high = math.log(centerFrequencies.last);
    return [
      for (final frequency in centerFrequencies)
        gainAt(high > low ? (math.log(frequency) - low) / (high - low) : 0)
            .clamp(minDb, maxDb)
            .toDouble(),
    ];
  }
}

/// Well-known response shapes, in dB against the normalised band range.
const kEqualizerPresets = <EqualizerPreset>[
  EqualizerPreset('Flat', [(0.0, 0.0), (1.0, 0.0)]),
  EqualizerPreset('Bass boost', [
    (0.0, 8.0),
    (0.2, 6.0),
    (0.4, 3.0),
    (0.7, 1.0),
    (1.0, 0.0),
  ]),
  EqualizerPreset('Treble boost', [
    (0.0, 0.0),
    (0.3, 0.5),
    (0.6, 3.0),
    (0.8, 5.5),
    (1.0, 8.0),
  ]),
  EqualizerPreset('Vocal', [
    (0.0, -2.0),
    (0.3, -1.0),
    (0.5, 4.0),
    (0.7, 4.0),
    (1.0, 1.0),
  ]),
  EqualizerPreset('Electronic', [
    (0.0, 7.0),
    (0.25, 4.0),
    (0.5, 0.0),
    (0.7, 2.5),
    (1.0, 6.0),
  ]),
  EqualizerPreset('Rock', [
    (0.0, 5.5),
    (0.25, 2.5),
    (0.5, -0.5),
    (0.7, 3.0),
    (1.0, 5.5),
  ]),
  EqualizerPreset('Pop', [
    (0.0, 3.0),
    (0.3, 1.5),
    (0.5, -1.0),
    (0.7, 1.5),
    (1.0, 3.5),
  ]),
  EqualizerPreset('Loudness', [
    (0.0, 8.0),
    (0.3, 3.5),
    (0.55, 0.0),
    (0.8, 3.0),
    (1.0, 7.0),
  ]),
];

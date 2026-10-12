import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import 'package:music_player/core/providers/theme_provider.dart';

import 'playback_providers.dart';

/// Persisted on/off switch for the Android equalizer.
class EqualizerEnabledNotifier extends Notifier<bool> {
  static const _key = 'equalizer_enabled';

  @override
  bool build() => ref.read(sharedPreferencesProvider).getBool(_key) ?? false;

  Future<void> setEnabled(bool enabled) async {
    state = enabled;
    await ref.read(sharedPreferencesProvider).setBool(_key, enabled);
  }
}

final equalizerEnabledProvider =
    NotifierProvider<EqualizerEnabledNotifier, bool>(
      EqualizerEnabledNotifier.new,
    );

/// Persisted per-band gain in dB, keyed by band index.
class EqualizerGainsNotifier extends Notifier<Map<int, double>> {
  static const _key = 'equalizer_gains';

  @override
  Map<int, double> build() {
    final gains = <int, double>{};
    final raw = ref.read(sharedPreferencesProvider).getString(_key);
    if (raw == null || raw.isEmpty) return gains;

    final values = raw.split(',');
    for (var i = 0; i < values.length; i++) {
      final gain = double.tryParse(values[i]);
      if (gain != null) gains[i] = gain;
    }
    return gains;
  }

  Future<void> set(int band, double gain) => setAll({band: gain});

  Future<void> setAll(Map<int, double> updates) async {
    final next = {...state, ...updates};
    state = next;

    // Bands are stored positionally so a device with a different band count
    // still reads back sensibly.
    final count = next.keys.fold<int>(-1, (a, b) => a > b ? a : b) + 1;
    final values = [for (var i = 0; i < count; i++) '${next[i] ?? 0.0}'];
    await ref.read(sharedPreferencesProvider).setString(_key, values.join(','));
  }
}

final equalizerGainsProvider =
    NotifierProvider<EqualizerGainsNotifier, Map<int, double>>(
      EqualizerGainsNotifier.new,
    );

/// Resolves the platform equalizer, wires the switch to it and reapplies the
/// saved gains. Null on platforms without an Android audio effect chain.
final equalizerParametersProvider = FutureProvider<AndroidEqualizerParameters?>(
  (ref) async {
    final equalizer = ref.watch(audioPlayerProvider).equalizer;
    if (equalizer == null) return null;

    ref.listen(
      equalizerEnabledProvider,
      (_, enabled) => equalizer.setEnabled(enabled),
      fireImmediately: true,
    );

    final parameters = await equalizer.parameters;
    final saved = ref.read(equalizerGainsProvider);
    for (final band in parameters.bands) {
      final gain = saved[band.index];
      if (gain != null && gain != band.gain) await band.setGain(gain);
    }
    return parameters;
  },
);

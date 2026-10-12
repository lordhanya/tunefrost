import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import 'package:music_player/core/utils/haptics.dart';
import 'package:music_player/core/widgets/glass.dart';
import 'package:music_player/core/widgets/lottie_icon.dart';

import 'widgets/mini_player.dart';
import 'equalizer_presets.dart';
import 'providers/equalizer_providers.dart';

/// Android system equalizer attached to the playback pipeline. Android only —
/// the other platforms expose no equivalent through just_audio.
class EqualizerScreen extends ConsumerWidget {
  const EqualizerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(equalizerEnabledProvider);
    final parameters = ref.watch(equalizerParametersProvider);
    final topInset = MediaQuery.paddingOf(context).top + kToolbarHeight;

    return Scaffold(
      extendBody: true,
      extendBodyBehindAppBar: true,
      appBar: glassAppBar(
        context,
        title: const Text('Equalizer'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: ListView(
        padding: EdgeInsets.only(
          top: topInset + 8,
          bottom: miniPlayerBottom(context, extra: 24),
        ),
        children: [
          SwitchListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            title: const Text('Enable equalizer'),
            secondary: const LottieIcon(LottieAssets.equalizer),
            value: enabled,
            onChanged: (value) {
              context.hapticSelect();
              ref.read(equalizerEnabledProvider.notifier).setEnabled(value);
            },
          ),
          parameters.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (_, _) =>
                const _Hint('The system equalizer is unavailable right now.'),
            data: (params) => !enabled
                ? const _Hint('Turn the equalizer on to adjust the bands.')
                : params == null
                ? const _Hint('Equalizer is only supported on Android.')
                : _Bands(params: params),
          ),
        ],
      ),
      bottomNavigationBar: const MiniPlayer(),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
    );
  }
}

class _Bands extends ConsumerStatefulWidget {
  const _Bands({required this.params});

  final AndroidEqualizerParameters params;

  @override
  ConsumerState<_Bands> createState() => _BandsState();
}

class _BandsState extends ConsumerState<_Bands> {
  /// Bumped whenever a preset drives the sliders, so each one is recreated
  /// with its new starting gain.
  int _generation = 0;

  /// The preset the bands currently match, cleared once nudged by hand.
  String? _preset;

  @override
  Widget build(BuildContext context) {
    final gains = ref.watch(equalizerGainsProvider);
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final preset in kEqualizerPresets)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(preset.name),
                      selected: _preset == preset.name,
                      onSelected: (_) => _apply(preset),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              for (final band in widget.params.bands)
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _BandSlider(
                      key: ValueKey('${band.index}-$_generation'),
                      band: band,
                      initial: gains[band.index] ?? 0.0,
                      minDb: widget.params.minDecibels,
                      maxDb: widget.params.maxDecibels,
                      onCommit: (gain) {
                        ref
                            .read(equalizerGainsProvider.notifier)
                            .set(band.index, gain);
                        setState(() => _preset = null);
                      },
                    ),
                    const SizedBox(height: 4),
                    Text(
                      frequencyLabel(band.centerFrequency),
                      style: TextStyle(
                        color: scheme.onSurfaceVariant,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }

  void _apply(EqualizerPreset preset) {
    context.hapticSelect();
    final bands = widget.params.bands;
    final gains = preset.gainsFor(
      [for (final band in bands) band.centerFrequency],
      minDb: widget.params.minDecibels,
      maxDb: widget.params.maxDecibels,
    );

    final updates = <int, double>{};
    for (var i = 0; i < bands.length; i++) {
      bands[i].setGain(gains[i]);
      updates[bands[i].index] = gains[i];
    }
    ref.read(equalizerGainsProvider.notifier).setAll(updates);
    setState(() {
      _generation++;
      _preset = preset.name;
    });
  }
}

class _BandSlider extends ConsumerStatefulWidget {
  const _BandSlider({
    super.key,
    required this.band,
    required this.initial,
    required this.minDb,
    required this.maxDb,
    required this.onCommit,
  });

  final AndroidEqualizerBand band;
  final double initial;
  final double minDb;
  final double maxDb;
  final ValueChanged<double> onCommit;

  @override
  ConsumerState<_BandSlider> createState() => _BandSliderState();
}

class _BandSliderState extends ConsumerState<_BandSlider> {
  late double _gain = widget.initial;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 176,
      child: RotatedBox(
        quarterTurns: -3,
        child: SizedBox(
          width: 176,
          child: Slider(
            value: _gain.clamp(widget.minDb, widget.maxDb),
            min: widget.minDb,
            max: widget.maxDb,
            onChangeStart: (_) => context.hapticLight(),
            onChanged: (value) {
              widget.band.setGain(value);
              setState(() => _gain = value);
            },
            onChangeEnd: (value) {
              context.hapticMedium();
              widget.onCommit(value);
            },
          ),
        ),
      ),
    );
  }
}

/// `60`, `250`, `1.2k`, `12k`…
String frequencyLabel(double hertz) {
  if (hertz >= 1000) {
    final kilo = hertz / 1000;
    final digits = kilo == kilo.roundToDouble()
        ? kilo.toStringAsFixed(0)
        : kilo.toStringAsFixed(1);
    return '${digits}k';
  }
  return hertz.round().toString();
}

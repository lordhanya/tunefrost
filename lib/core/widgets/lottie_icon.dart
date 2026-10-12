import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

/// Vendored Lottie micro-interactions. These live in `assets/lottie/` as plain
/// files rather than coming from a package: Flutter bundles *every* asset a
/// dependency declares, and the package these were sourced from ships its whole
/// 79 MB library that way. See `assets/lottie/README.md`.
abstract final class LottieAssets {
  static const String download = 'assets/lottie/download.json';
  static const String heart = 'assets/lottie/heart.json';
  static const String trash = 'assets/lottie/trash.json';
  static const String equalizer = 'assets/lottie/equalizer.json';
}

/// A Lottie micro-interaction that drops in where a Material [Icon] would.
///
/// It is tinted to the ambient [IconTheme] colour (or [color]) so it inherits
/// the same colour a Material icon would in that slot — the source animations
/// are monochrome, which the [ColorFiltered] flattens to a single hue.
///
/// By default it plays once when first built and then holds its final frame;
/// pass [loop] for an animation that should run continuously (e.g. the
/// equalizer). Plain rebuilds do not restart a one-shot animation — `Lottie`
/// keeps its controller across rebuilds, and the underlying `AssetLottie`
/// compares equal, so the composition is not re-parsed.
class LottieIcon extends StatelessWidget {
  const LottieIcon(
    this.asset, {
    super.key,
    this.size = 24,
    this.color,
    this.loop = false,
    this.fallback,
  });

  /// One of the [LottieAssets] paths.
  final String asset;

  /// Side of the square the animation is laid out in, matching `Icon.size`.
  final double size;

  /// Overrides the tint; defaults to the ambient icon colour.
  final Color? color;

  /// Whether to repeat forever instead of playing once.
  final bool loop;

  /// Shown while the composition loads/if it fails, so the slot never collapses.
  final IconData? fallback;

  @override
  Widget build(BuildContext context) {
    final tint = color ??
        IconTheme.of(context).color ??
        Theme.of(context).colorScheme.onSurface;
    return ColorFiltered(
      colorFilter: ColorFilter.mode(tint, BlendMode.srcIn),
      child: Lottie.asset(
        asset,
        width: size,
        height: size,
        fit: BoxFit.contain,
        repeat: loop,
        errorBuilder: (context, error, stackTrace) => Icon(
          fallback ?? Icons.circle_outlined,
          size: size,
          color: tint,
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import 'package:music_player/core/widgets/lottie_icon.dart';

/// The download micro-interaction: the arrow drops into the tray.
///
/// Unlike [LottieIcon], which plays when it first appears, this holds its
/// first frame and plays only when [trigger] changes — so it can be driven by
/// a tap. A pass is never restarted mid-flight (bump [trigger] again to
/// replay), and its end is reported through [onCompleted].
///
/// The Lottie composition is supplied through the widget's own
/// [AnimationController], which is the documented way to drive playback
/// manually; `animate`/`repeat` have no effect once a controller is passed.
class AnimatedDownloadIcon extends StatefulWidget {
  const AnimatedDownloadIcon({
    super.key,
    required this.trigger,
    this.size = 24,
    this.color,
    this.autoPlay = false,
    this.onCompleted,
  });

  /// Bump this value (e.g. an int counter) to play one pass.
  final int trigger;

  /// Side of the square the animation is laid out in, matching `Icon.size`.
  final double size;

  /// Overrides the tint; defaults to the ambient icon colour.
  final Color? color;

  /// Play one pass as soon as the composition loads, before any [trigger].
  final bool autoPlay;

  /// Called once each time a pass finishes.
  final VoidCallback? onCompleted;

  @override
  State<AnimatedDownloadIcon> createState() => _AnimatedDownloadIconState();
}

class _AnimatedDownloadIconState extends State<AnimatedDownloadIcon>
    with SingleTickerProviderStateMixin {
  /// Fallback length until the composition reports its own duration.
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..addStatusListener(_onStatus);

  bool _loaded = false;

  /// A pass was asked for before the composition finished loading.
  bool _pending = false;

  @override
  void initState() {
    super.initState();
    _pending = widget.autoPlay;
  }

  @override
  void didUpdateWidget(covariant AnimatedDownloadIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.trigger != widget.trigger) _play();
  }

  void _play() {
    if (!_loaded) {
      _pending = true; // play as soon as the composition is ready
      return;
    }
    if (_controller.isAnimating) return; // a repeat tap must not restart it
    _controller.forward(from: 0);
  }

  void _onStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) widget.onCompleted?.call();
  }

  @override
  void dispose() {
    _controller.removeStatusListener(_onStatus);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tint =
        widget.color ??
        IconTheme.of(context).color ??
        Theme.of(context).colorScheme.onSurface;
    return ColorFiltered(
      colorFilter: ColorFilter.mode(tint, BlendMode.srcIn),
      child: Lottie.asset(
        LottieAssets.download,
        width: widget.size,
        height: widget.size,
        fit: BoxFit.contain,
        controller: _controller,
        onLoaded: (composition) {
          // Match the composition so `forward()` runs at the artwork's real
          // speed rather than the fallback duration above.
          final duration = composition.duration;
          if (duration > Duration.zero) _controller.duration = duration;
          _loaded = true;
          if (_pending) {
            _pending = false;
            _play();
          }
        },
        errorBuilder: (context, error, stackTrace) => Icon(
          Icons.download_rounded,
          size: widget.size,
          color: tint,
        ),
      ),
    );
  }
}

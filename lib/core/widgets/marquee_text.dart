import 'package:flutter/material.dart';

/// One-line title that scrolls itself when it doesn't fit.
///
/// A title that fits the available width — and any title when the platform
/// asks for reduced motion — is rendered as a plain [Text] and never moves.
///
/// A wider title is scrolled right-to-left as a continuous ticker. The row
/// holds two copies of the text separated by [gap]; a cycle is `pause + travel`
/// long, and the wrap point renders exactly like the start, so there is no
/// jump and the whole title is readable at both ends of every pass.
///
/// Movement is a constant [pixelsPerSecond], so it reads as a steady glide
/// rather than an eased dart. The cycle is rebuilt whenever the text, the
/// available width or the style changes (e.g. a new song, a rotation, a font
/// scale change) and is torn down as soon as the text fits again.
class MarqueeText extends StatefulWidget {
  const MarqueeText(
    this.text, {
    super.key,
    required this.style,
    this.textAlign = TextAlign.start,
    this.gap = 56,
    this.pause = const Duration(milliseconds: 1400),
    this.pixelsPerSecond = 32,
  });

  final String text;
  final TextStyle style;

  /// Alignment while the text is static; the scrolling copy is left-anchored.
  final TextAlign textAlign;

  /// Blank space between the two copies, so a repeat stays distinguishable.
  final double gap;

  /// How long the full title is held still before each pass.
  final Duration pause;

  /// Constant scroll speed, in logical pixels per second.
  final double pixelsPerSecond;

  @override
  State<MarqueeText> createState() => _MarqueeTextState();
}

class _MarqueeTextState extends State<MarqueeText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this);

  /// Text width plus the inter-copy gap: how far a pass travels.
  double _distance = 0;

  /// Full cycle length in milliseconds (hold + travel).
  int _cycleMs = 0;

  /// Whether the ticker is currently driving the scroll.
  bool _running = false;

  @override
  void didUpdateWidget(covariant MarqueeText oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Any visual change invalidates the running cycle: start the next pass
    // cleanly from the top instead of continuing mid-flight under new text.
    if (oldWidget.text != widget.text ||
        oldWidget.style != widget.style ||
        oldWidget.gap != widget.gap ||
        oldWidget.pause != widget.pause ||
        oldWidget.pixelsPerSecond != widget.pixelsPerSecond) {
      _running = false;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Starts (or re-targets) the cycle. Idempotent, so it may be called from
  /// build without restarting the animation on every frame.
  void _start(double distance, int cycleMs) {
    if (_running && _distance == distance && _cycleMs == cycleMs) return;
    _distance = distance;
    _cycleMs = cycleMs;
    _running = true;
    _controller
      ..stop()
      ..duration = Duration(milliseconds: cycleMs)
      ..value = 0
      ..repeat();
  }

  void _stop() {
    if (!_running) return;
    _running = false;
    _controller
      ..stop()
      ..value = 0;
  }

  /// Mirrors how [Text] resolves its style, so the measured width matches what
  /// is actually painted (the font family comes from the theme).
  TextStyle _resolveStyle(BuildContext context) =>
      DefaultTextStyle.of(context).style.merge(widget.style);

  TextPainter _layout(BuildContext context, TextStyle style) {
    return TextPainter(
      text: TextSpan(text: widget.text, style: style),
      maxLines: 1,
      textScaler: MediaQuery.textScalerOf(context),
      textDirection: Directionality.of(context),
    )..layout();
  }

  /// Horizontal travel, in pixels, for [elapsed] seconds into the cycle.
  double _offset(double elapsed, double distance, double travelSeconds) {
    final pauseSeconds = widget.pause.inMilliseconds / 1000.0;
    if (travelSeconds <= 0 || elapsed <= pauseSeconds) return 0;
    return ((elapsed - pauseSeconds) / travelSeconds).clamp(0.0, 1.0) *
        distance;
  }

  @override
  Widget build(BuildContext context) {
    final style = _resolveStyle(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final available = constraints.maxWidth;
        final painter = _layout(context, style);
        final textWidth = painter.width;

        if (MediaQuery.disableAnimationsOf(context) ||
            !available.isFinite ||
            textWidth <= available) {
          _stop();
          return Text(
            widget.text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: widget.textAlign,
            style: style,
          );
        }

        final distance = textWidth + widget.gap;
        final travelMs = (distance / widget.pixelsPerSecond * 1000).round();
        final cycleMs = travelMs + widget.pause.inMilliseconds;
        _start(distance, cycleMs);

        return SizedBox(
          height: painter.height,
          child: ClipRect(
            // The row is laid out at its intrinsic width — wider than the
            // viewport — and then slid left; the clip trims both edges.
            child: OverflowBox(
              maxWidth: double.infinity,
              alignment: Alignment.centerLeft,
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  final elapsed = _controller.value * (cycleMs / 1000.0);
                  final offset = _offset(
                    elapsed,
                    distance,
                    travelMs / 1000.0,
                  );
                  return Transform.translate(
                    offset: Offset(-offset, 0),
                    child: child,
                  );
                },
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      widget.text,
                      maxLines: 1,
                      softWrap: false,
                      style: style,
                    ),
                    SizedBox(width: widget.gap),
                    Text(
                      widget.text,
                      maxLines: 1,
                      softWrap: false,
                      style: style,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

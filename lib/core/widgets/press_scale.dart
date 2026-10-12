import 'package:flutter/material.dart';

/// Subtle press feedback: the child scales down slightly while touched and
/// springs back on release. Built on raw [Listener] so it never competes in
/// the gesture arena — inner ink wells and taps keep working.
class PressScale extends StatefulWidget {
  const PressScale({
    super.key,
    required this.child,
    this.scale = 0.94,
    this.duration = const Duration(milliseconds: 80),
    this.releaseDuration = const Duration(milliseconds: 240),
  });

  final Widget child;
  final double scale;
  final Duration duration;
  final Duration releaseDuration;

  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => _setPressed(true),
      onPointerUp: (_) => _setPressed(false),
      onPointerCancel: (_) => _setPressed(false),
      child: AnimatedScale(
        scale: _pressed ? widget.scale : 1,
        duration: _pressed ? widget.duration : widget.releaseDuration,
        curve: Curves.easeOutCubic,
        child: widget.child,
      ),
    );
  }
}

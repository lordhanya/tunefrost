import 'dart:ui';

import 'package:flutter/services.dart';

import 'package:flutter/material.dart';

/// Frosted panel that blurs whatever is painted beneath [child].
class GlassContainer extends StatelessWidget {
  const GlassContainer({
    super.key,
    required this.child,
    this.blurSigma = 20,
    this.baseColor,
    this.borderRadius,
    this.padding,
  });

  final Widget child;
  final double blurSigma;
  final Color? baseColor;
  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color =
        baseColor ?? scheme.surface.withValues(alpha: isDark ? 0.58 : 0.72);

    return ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.zero,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: Container(color: color, padding: padding, child: child),
      ),
    );
  }
}

/// Frosted [AppBar] factory — content scrolling beneath it shows through.
///
/// Combine with `Scaffold(extendBodyBehindAppBar: true)` and give scrollable
/// bodies a top padding of `MediaQuery.padding.top + kToolbarHeight`.
AppBar glassAppBar(
  BuildContext context, {
  Key? key,
  Widget? title,
  Widget? leading,
  List<Widget>? actions,
  PreferredSizeWidget? bottom,
  double blurSigma = 20,
}) {
  final scheme = Theme.of(context).colorScheme;
  final isDark = Theme.of(context).brightness == Brightness.dark;

  return AppBar(
    key: key,
    title: title,
    leading: leading,
    actions: actions,
    bottom: bottom,
    backgroundColor: Colors.transparent,
    surfaceTintColor: Colors.transparent,
    systemOverlayStyle: isDark
        ? SystemUiOverlayStyle.light
        : SystemUiOverlayStyle.dark,
    flexibleSpace: ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: Container(
          decoration: BoxDecoration(
            color: scheme.surface.withValues(alpha: isDark ? 0.38 : 0.52),
            border: Border(
              bottom: BorderSide(
                color: scheme.outlineVariant.withValues(alpha: 0.6),
                width: 0.7,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

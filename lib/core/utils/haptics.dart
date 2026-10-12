import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/haptics_provider.dart';

/// Haptic helpers that respect the platform and the user's in-app toggle.
///
/// ```dart
/// onTap: () {
///   context.hapticSelect();
///   ...
/// }
/// ```
extension Haptics on BuildContext {
  static bool get _platformSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  bool get _enabled => ProviderScope.containerOf(
    this,
    listen: false,
  ).read(hapticsEnabledProvider);

  void _fire(Future<void> Function() feedback) {
    if (_platformSupported && _enabled) feedback();
  }

  /// Subtle tick — button presses, sheet openings.
  void hapticLight() => _fire(HapticFeedback.lightImpact);

  /// Mid tick — slider release, main play button.
  void hapticMedium() => _fire(HapticFeedback.mediumImpact);

  /// Strong tick — long press.
  void hapticHeavy() => _fire(HapticFeedback.heavyImpact);

  /// Blip — toggles, list selection.
  void hapticSelect() => _fire(HapticFeedback.selectionClick);
}

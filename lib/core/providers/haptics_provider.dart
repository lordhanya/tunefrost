import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'theme_provider.dart';

/// Toggle for haptic feedback; persisted across launches.
class HapticsNotifier extends Notifier<bool> {
  static const _key = 'haptics_enabled';

  @override
  bool build() {
    return ref.read(sharedPreferencesProvider).getBool(_key) ?? true;
  }

  Future<void> setEnabled(bool enabled) async {
    state = enabled;
    await ref.read(sharedPreferencesProvider).setBool(_key, enabled);
  }
}

final hapticsEnabledProvider = NotifierProvider<HapticsNotifier, bool>(
  HapticsNotifier.new,
);

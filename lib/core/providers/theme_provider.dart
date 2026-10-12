import 'dart:ui' show Brightness, PlatformDispatcher;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app/theme.dart';

/// Overridden in `main()` with the instance loaded before `runApp`.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('Override in main()'),
);

class ThemeModeNotifier extends Notifier<AppThemeMode> {
  static const _key = 'theme_mode';

  @override
  AppThemeMode build() {
    final raw = ref.read(sharedPreferencesProvider).getString(_key);
    return AppThemeMode.values.firstWhere(
      (mode) => mode.name == raw,
      orElse: () => AppThemeMode.system,
    );
  }

  Future<void> setMode(AppThemeMode mode) async {
    state = mode;
    await ref.read(sharedPreferencesProvider).setString(_key, mode.name);
  }
}

final themeModeProvider = NotifierProvider<ThemeModeNotifier, AppThemeMode>(
  ThemeModeNotifier.new,
);

/// Follows the OS light/dark preference from the moment the provider starts.
/// Frosty uses it to pick its matching palette (Frost in the day,
/// Midnight Frost at night) without guessing.
class PlatformBrightnessNotifier extends Notifier<Brightness> {
  @override
  Brightness build() {
    final dispatcher = PlatformDispatcher.instance;
    dispatcher.onPlatformBrightnessChanged = () {
      state = dispatcher.platformBrightness;
    };
    ref.onDispose(() {
      dispatcher.onPlatformBrightnessChanged = null;
    });
    return dispatcher.platformBrightness;
  }
}

final platformBrightnessProvider =
    NotifierProvider<PlatformBrightnessNotifier, Brightness>(
      PlatformBrightnessNotifier.new,
    );
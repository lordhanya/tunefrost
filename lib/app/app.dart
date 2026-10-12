import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/providers/theme_provider.dart';
import '../features/playback/providers/playback_providers.dart';
import 'theme.dart';

import 'package:music_player/features/library/library_screen.dart';
import 'package:music_player/features/playback/equalizer_screen.dart';
import 'package:music_player/features/playback/providers/open_media_provider.dart';
import 'package:music_player/features/playlists/screens/playlists_screen.dart';
import 'package:music_player/features/search/screens/search_screen.dart';
import 'package:music_player/features/settings/screens/privacy_screen.dart';
import 'package:music_player/features/settings/screens/settings_screen.dart';

class MusicPlayerApp extends ConsumerWidget {
  const MusicPlayerApp({super.key});

  /// [MaterialApp.builder] runs above its own [ScaffoldMessenger], so a
  /// message raised from a provider listener has to go via the key.
  static final _messengerKey = GlobalKey<ScaffoldMessengerState>();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    final systemDark =
        ref.watch(platformBrightnessProvider) == Brightness.dark;
    // Starts queue persistence and listen-history recording for the app's
    // lifetime.
    ref.watch(queuePersistenceProvider);
    ref.watch(playHistoryRecorderProvider);
    // Plays audio files the OS hands us ("Open with", default player).
    ref.watch(openMediaHandlerProvider);

    ref.listen(playbackFailuresProvider, (previous, next) {
      final message = next.value;
      if (message == null) return;
      final messenger = _messengerKey.currentState;
      if (messenger == null) return;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
        );
    });

    // Frosty keeps one brand identity but follows the OS brightness, so pick
    // the palette pair and force the matching brightness explicitly.
    final (theme, darkTheme, themeMode) = switch (mode) {
      AppThemeMode.system => (AppTheme.light, AppTheme.dark, ThemeMode.system),
      AppThemeMode.light => (AppTheme.light, AppTheme.dark, ThemeMode.light),
      AppThemeMode.dark => (AppTheme.light, AppTheme.dark, ThemeMode.dark),
      AppThemeMode.frosty => (
        AppTheme.frost,
        AppTheme.midnightFrost,
        systemDark ? ThemeMode.dark : ThemeMode.light,
      ),
    };

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Tunefrost',
      theme: theme,
      darkTheme: darkTheme,
      themeMode: themeMode,
      scaffoldMessengerKey: _messengerKey,
      initialRoute: '/library',
      routes: {
        '/library': (context) => const LibraryScreen(),
        '/playlists': (context) => const PlaylistsScreen(),
        '/search': (context) => const SearchScreen(),
        '/settings': (context) => const SettingsScreen(),
        '/privacy': (context) => const PrivacyScreen(),
        '/equalizer': (context) => const EqualizerScreen(),
      },
    );
  }
}

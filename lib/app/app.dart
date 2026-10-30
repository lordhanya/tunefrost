import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/providers/theme_provider.dart';
import '../core/services/network_quality_service.dart';
import '../features/library/providers/downloads_provider.dart';
import '../features/playback/providers/playback_providers.dart';
import 'theme.dart';

import 'package:music_player/features/library/library_screen.dart';
import 'package:music_player/features/playback/equalizer_screen.dart';
import 'package:music_player/features/playback/providers/open_media_provider.dart';
import 'package:music_player/features/playlists/screens/playlists_screen.dart';
import 'package:music_player/features/search/screens/search_screen.dart';
import 'package:music_player/features/settings/screens/privacy_screen.dart';
import 'package:music_player/features/settings/screens/settings_screen.dart';
import 'package:music_player/features/smartplay/screens/smartplay_preview_screen.dart';

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
    // Shows a snackbar when a download finishes. The notifier lives for the
    // app's lifetime, so the subscription never needs cancelling.
    ref.read(downloadsProvider.notifier).completed.listen((title) {
      final messenger = _messengerKey.currentState;
      if (messenger == null) return;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('Downloaded “$title”'),
            behavior: SnackBarBehavior.floating,
          ),
        );
    });
    ref.read(downloadsProvider.notifier).failed.listen((title) {
      final messenger = _messengerKey.currentState;
      if (messenger == null) return;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              "Couldn't download “$title”. Check your connection and try again.",
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
    });
    // The user chose a SAF folder but a download could not be verified there
    // (e.g. the storage grant was revoked). The file is still in app-private
    // storage and playable offline, but we must not silently claim it landed
    // in the chosen folder.
    ref.read(downloadsProvider.notifier).safFallback.listen((title) {
      final messenger = _messengerKey.currentState;
      if (messenger == null) return;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              "“$title” downloaded, but it could not be saved to your chosen folder; "
              "it’s stored in app storage instead.",
            ),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
          ),
        );
    });
    // Runs once per session to gently inform on slow connections.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(networkQualityProvider.notifier).checkOnce();
    });
    ref.listen(networkQualityProvider, (previous, next) {
      final wasSlow = previous?.quality == NetworkQuality.slow &&
          previous?.checked == true;
      if (next.checked && next.quality == NetworkQuality.slow && !wasSlow) {
        final messenger = _messengerKey.currentState;
        if (messenger == null) return;
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: Text(
                "Looks like your connection is a little slow. Tracks might take a moment to load.",
              ),
              behavior: SnackBarBehavior.floating,
            ),
          );
      }
    });

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
        '/smartplay': (context) => const SmartPlayScreen(),
        '/settings': (context) => const SettingsScreen(),
        '/privacy': (context) => const PrivacyScreen(),
        '/equalizer': (context) => const EqualizerScreen(),
      },
    );
  }
}

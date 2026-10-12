import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:just_audio_media_kit/just_audio_media_kit.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app.dart';
import 'core/providers/theme_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Notification / lock-screen / headset transport controls.
  //
  // ANR hardening. audio_service rebuilds a Flutter engine synchronously on
  // the main thread inside AudioService.onCreate() whenever Android has to
  // (re)create the audio service while the app process is dead — that
  // snapshot load is what trips the ANR watchdog on slow devices
  // (audio_service #1165). We cannot change the plugin, but we can stop
  // provoking it: with the default androidStopForegroundOnPause: true the
  // service leaves the foreground on pause, so Android is free to kill the
  // process; a lingering notification then restarts the service headlessly
  // and hits that slow path. Keeping the service in the foreground while
  // paused keeps the process alive and reuses the warm engine instead.
  //
  // Trade-off: the notification stays pinned while paused (it can no longer
  // be swiped away). Set this back to true if a swipe-dismissable paused
  // notification matters more than the reduced ANR exposure.
  await JustAudioBackground.init(
    androidNotificationChannelId: 'com.ashifcodes.music_player.channel.audio',
    androidNotificationChannelName: 'Music playback',
    androidStopForegroundOnPause: false,
    androidNotificationOngoing: false,
    androidShowNotificationBadge: true, // system visibility hooks (Android 13+)
    // White silhouette in res/drawable: the default mipmap launcher icon is
    // rejected by Android as a notification small icon.
    androidNotificationIcon: 'drawable/ic_notification',
  );

  // Desktop platforms have no native just_audio backend.
  if (Platform.isLinux || Platform.isWindows) {
    JustAudioMediaKit.ensureInitialized();
  }

  final prefs = await SharedPreferences.getInstance();
  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const MusicPlayerApp(),
    ),
  );
}

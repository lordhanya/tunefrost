import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/services.dart';

/// Audio files the OS asked Tunefrost to open.
///
/// Android routes "Open with" / default-player handoffs here through the
/// `VIEW` intent filter declared on `MainActivity`. [initialUri] covers a cold
/// start; [uris] carries files handed over while the app is already running
/// (`MainActivity` is `singleTop`, so those arrive via `onNewIntent`).
class OpenMediaIntent {
  static const _channel = MethodChannel(
    'com.ashifcodes.music_player/open_media',
  );

  final _uris = StreamController<String>.broadcast();
  bool _listening = false;

  /// Files opened while the app is running.
  Stream<String> get uris => _uris.stream;

  /// The file the app was launched to open, or null on a normal launch and on
  /// every platform other than Android.
  Future<String?> initialUri() async {
    if (!Platform.isAndroid) return null;
    _listen();
    try {
      return await _channel.invokeMethod<String>('getInitialUri');
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  void _listen() {
    if (_listening) return;
    _listening = true;
    _channel.setMethodCallHandler((call) async {
      final arguments = call.arguments;
      if (call.method == 'open' && arguments is String) _uris.add(arguments);
      return null;
    });
  }

  void dispose() {
    _channel.setMethodCallHandler(null);
    _uris.close();
  }
}

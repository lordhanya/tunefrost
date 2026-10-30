import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

enum NetworkQuality {
  good,
  slow,
  unknown,
}

class NetworkQualityState {
  const NetworkQualityState({
    this.quality = NetworkQuality.unknown,
    this.checked = false,
  });

  final NetworkQuality quality;
  final bool checked;

  NetworkQualityState copyWith({NetworkQuality? quality, bool? checked}) =>
      NetworkQualityState(
        quality: quality ?? this.quality,
        checked: checked ?? this.checked,
      );
}

class NetworkQualityService {
  NetworkQualityService();

  static final HttpClient _http = HttpClient()
    ..autoUncompress = true
    ..connectionTimeout = const Duration(seconds: 5);

  Future<NetworkQuality> measure() async {
    try {
      // Tiny download to estimate speed. 256KB is small enough to be fast,
      // but long enough to catch very slow connections.
      final uri = Uri.parse(
        'https://www.gstatic.com/generate_204',
      );
      final request = await _http.getUrl(uri).timeout(const Duration(seconds: 5));
      final response = await request.close().timeout(const Duration(seconds: 8));
      if (response.statusCode < 200 || response.statusCode >= 400) {
        await response.drain<void>();
        return NetworkQuality.unknown;
      }
      // For generate_204 body is empty, but the request still measures latency/connectivity.
      // Fall back to "unknown" if we can't meaningfully measure; don't force data saver.
      await response.drain<void>().timeout(const Duration(seconds: 5));
      return NetworkQuality.good;
    } catch (_) {
      return NetworkQuality.slow;
    }
  }
}

class NetworkQualityNotifier extends Notifier<NetworkQualityState> {
  @override
  NetworkQualityState build() {
    return const NetworkQualityState();
  }

  Future<void> checkOnce() async {
    if (state.checked) return;
    final service = NetworkQualityService();
    final quality = await service.measure();
    state = state.copyWith(quality: quality, checked: true);
  }
}

final networkQualityProvider =
    NotifierProvider<NetworkQualityNotifier, NetworkQualityState>(
  NetworkQualityNotifier.new,
);

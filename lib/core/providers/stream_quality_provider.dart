import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'theme_provider.dart';

enum StreamQuality {
  high,
  dataSaver,
}

class StreamQualityNotifier extends Notifier<StreamQuality> {
  static const _key = 'stream_quality';

  @override
  StreamQuality build() {
    final raw = ref.read(sharedPreferencesProvider).getString(_key);
    return StreamQuality.values.firstWhere(
      (q) => q.name == raw,
      orElse: () => StreamQuality.high,
    );
  }

  Future<void> setQuality(StreamQuality quality) async {
    state = quality;
    await ref.read(sharedPreferencesProvider).setString(_key, quality.name);
  }
}

final streamQualityProvider =
    NotifierProvider<StreamQualityNotifier, StreamQuality>(
  StreamQualityNotifier.new,
);

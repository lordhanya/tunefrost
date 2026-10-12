import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:music_player/audio/youtube_audio_source.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

/// A resolved stream as the library stores it — `fromJson` is the only
/// entry point that doesn't need a live YouTube client.
AudioOnlyStreamInfo _stored({
  String url = 'https://cdn.example/x?expire=9999999999',
}) => AudioOnlyStreamInfo.fromJson(
  jsonDecode('''
      {"videoId":{"value":"uzHgK4kgZSk"},"tag":140,"url":"$url",
       "container":{"name":"mp4"},"size":{"totalBytes":12345678},
       "bitrate":{"bitsPerSecond":128000},"audioCodec":"mp4a.40.2",
       "codec":"audio/mp4","fragments":[],"qualityLabel":"128kbps",
       "audioTrack":null}
      ''') as Map<String, dynamic>,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('stream JSON round trip', () {
    // The resolver hands this exact path to the cache and back; feeding
    // toJson()'s raw map straight to fromJson crashes on its live objects
    // (VideoId, FileSize, …), which killed playback on 3.1.0.
    test('survives jsonEncode like the resolver does', () {
      final restored = AudioOnlyStreamInfo.fromJson(
        jsonDecode(jsonEncode(_stored().toJson())) as Map<String, dynamic>,
      );

      expect(restored.videoId.value, 'uzHgK4kgZSk');
      expect(restored.tag, 140);
      expect(restored.url.toString(), _stored().url.toString());
      expect(restored.size.totalBytes, 12345678);
      expect(restored.codec.mimeType, 'audio/mp4');
    });
  });

  group('StreamLinkCache', () {
    test('round-trips a resolved stream', () async {
      SharedPreferences.setMockInitialValues({});
      final cache = StreamLinkCache(await SharedPreferences.getInstance());
      final stream = _stored();

      await cache.put('uzHgK4kgZSk', stream);
      final stored = cache.get('uzHgK4kgZSk');

      expect(stored, isNotNull);
      expect(stored!.url, stream.url);
      expect(stored.size.totalBytes, stream.size.totalBytes);
      expect(cache.get('anotherVideoId'), isNull);
    });

    test('expires a link once its signed url does', () async {
      SharedPreferences.setMockInitialValues({});
      final cache = StreamLinkCache(await SharedPreferences.getInstance());

      await cache.put(
        'uzHgK4kgZSk',
        _stored(url: 'https://cdn.example/x?expire=1000000000'),
      );

      expect(cache.get('uzHgK4kgZSk'), isNull);
    });

    test('remove forgets a link YouTube stopped honouring', () async {
      SharedPreferences.setMockInitialValues({});
      final cache = StreamLinkCache(await SharedPreferences.getInstance());
      await cache.put('uzHgK4kgZSk', _stored());

      cache.remove('uzHgK4kgZSk');

      expect(cache.get('uzHgK4kgZSk'), isNull);
    });
  });
}

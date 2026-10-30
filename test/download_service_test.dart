import 'package:flutter_test/flutter_test.dart';
import 'package:music_player/audio/youtube_audio_source.dart';
import 'package:music_player/core/models/song.dart';
import 'package:music_player/core/services/download_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DownloadService destination persistence', () {
    late SharedPreferences prefs;
    late DownloadService service;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      // The resolver is not exercised by these persistence tests; no network
      // is needed. A real (but unused) resolver satisfies the constructor.
      service = DownloadService(
        YouTubeStreamResolver(StreamLinkCache(prefs)),
        prefs,
      );
    });

    test('setDownloadDirectory persists a SAF content URI', () async {
      await service.setDownloadDirectory(
        'content://com.android.externalstorage.documents/tree/primary%3ADownload',
      );
      expect(service.downloadDirectory,
          'content://com.android.externalstorage.documents/tree/primary%3ADownload');
    });

    test('downloadDirectory is null until set', () {
      expect(service.downloadDirectory, isNull);
    });

    test('clearDownloadDirectory removes the persisted choice', () async {
      await service.setDownloadDirectory('/storage/emulated/0/Download');
      expect(service.downloadDirectory, isNotNull);
      await service.clearDownloadDirectory();
      expect(service.downloadDirectory, isNull);
    });

    test('setDownloadDirectory persists a filesystem path', () async {
      await service.setDownloadDirectory('/storage/emulated/0/Download');
      expect(service.downloadDirectory, '/storage/emulated/0/Download');
    });
  });

  group('Song.download safPath round trip', () {
    test('toJson/fromJson preserves safPath', () {
      final original = Song.download(
        videoId: 'uzHgK4kgZSk',
        title: 'Song Title',
        artist: 'Artist',
        album: 'Album',
        durationMs: 210000,
        filePath:
            '/data/user/0/com.ashifcodes.music_player/app_flutter/mochi/downloads/uzHgK4kgZSk.m4a',
        safPath:
            'content://com.android.externalstorage.documents/tree/primary%3ADownload',
      );

      final restored = Song.fromJson(original.toJson());

      expect(restored.safPath, original.safPath);
      expect(restored.filePath, original.filePath);
      expect(restored.isDownload, isTrue);
      expect(restored.sourceVideoId, 'uzHgK4kgZSk');
    });

    test('toJson/fromJson works with null safPath', () {
      final original = Song.download(
        videoId: 'abc',
        title: 'T',
        artist: 'A',
        album: 'Al',
        durationMs: 60000,
        filePath: '/data/user/0/app/mochi/downloads/abc.webm',
      );

      final restored = Song.fromJson(original.toJson());
      expect(restored.safPath, isNull);
    });
  });

  group('DownloadResult', () {
    test('fields default correctly', () {
      final result = const DownloadResult(
        playbackPath: '/data/user/0/app/mochi/downloads/v1.m4a',
      );
      expect(result.playbackPath, '/data/user/0/app/mochi/downloads/v1.m4a');
      expect(result.safPath, isNull);
      expect(result.safRequested, isFalse);
      expect(result.safWritten, isFalse);
    });

    test('safRequested/safWritten distinguish unverified SAF writes', () {
      final result = DownloadResult(
        playbackPath: '/data/user/0/app/mochi/downloads/v1.m4a',
        safPath: 'content://...tree/primary%3ADownload',
        safRequested: true,
        safWritten: false,
      );
      expect(result.safRequested, isTrue);
      expect(result.safWritten, isFalse);
    });
  });
}

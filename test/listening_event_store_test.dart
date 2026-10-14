import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:music_player/core/models/listening_event.dart';
import 'package:music_player/core/services/listening_event_store.dart';

ListeningEvent _event(
  String songId, {
  int startedAtMs = 1000,
  int playedMs = 10000,
  int durationMs = 20000,
  bool completed = true,
  bool skippedEarly = false,
}) => ListeningEvent(
  songId: songId,
  artist: 'Artist $songId',
  title: 'Title $songId',
  album: 'Album',
  startedAtMs: startedAtMs,
  playedMs: playedMs,
  durationMs: durationMs,
  completed: completed,
  skippedEarly: skippedEarly,
);

void main() {
  late Directory dir;
  late ListeningEventStore store;

  File file() => File('${dir.path}/${ListeningEventStore.fileName}');

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('tunefrost_events');
    store = ListeningEventStore(directory: () async => dir);
  });

  tearDown(() async {
    if (await dir.exists()) await dir.delete(recursive: true);
  });

  group('ListeningEventStore', () {
    test('returns nothing on a fresh install', () async {
      expect(await store.load(), isEmpty);
    });

    test('round-trips every field', () async {
      final original = _event(
        'yt:abc123',
        startedAtMs: 1700000000000,
        playedMs: 123456,
        durationMs: 180000,
        completed: false,
        skippedEarly: true,
      );

      await store.save([original]);
      final loaded = await store.load();

      expect(loaded, hasLength(1));
      expect(loaded.single, original);
      expect(loaded.single.artist, 'Artist yt:abc123');
      expect(loaded.single.title, 'Title yt:abc123');
      expect(loaded.single.album, 'Album');
    });

    test('preserves order, newest first', () async {
      await store.save([
        _event('a', startedAtMs: 3000),
        _event('b', startedAtMs: 2000),
        _event('c', startedAtMs: 1000),
      ]);

      final loaded = await store.load();
      expect(loaded.map((e) => e.songId), ['a', 'b', 'c']);
    });

    test('ignores a corrupt file rather than throwing', () async {
      await file().writeAsString('not json at all');

      expect(await store.load(), isEmpty);
    });

    test('ignores a file that is not a JSON list', () async {
      await file().writeAsString('{"songId": "x"}');

      expect(await store.load(), isEmpty);
    });

    test('drops entries without a song id', () async {
      await file().writeAsString(jsonEncode([{'artist': 'nobody'}]));

      expect(await store.load(), isEmpty);
    });

    test('keeps only the newest entries at the cap', () async {
      final total = ListeningEventStore.maxEvents + 50;
      await store.save([
        for (var i = 0; i < total; i++) _event('s$i', startedAtMs: 100000 - i),
      ]);

      final loaded = await store.load();
      expect(loaded, hasLength(ListeningEventStore.maxEvents));
      expect(loaded.first.songId, 's0');
      expect(loaded.last.songId, 's${ListeningEventStore.maxEvents - 1}');
    });

    test('tolerates unknown fields from a newer writer', () async {
      await file().writeAsString(
        jsonEncode([
          {
            'songId': 'a',
            'artist': 'Artist',
            'title': 'Title',
            'album': 'Album',
            'startedAtMs': 5,
            'playedMs': 6,
            'durationMs': 7,
            'completed': true,
            'skippedEarly': false,
            'someFutureField': 'ignored',
          },
        ]),
      );

      final loaded = await store.load();
      expect(loaded, hasLength(1));
      expect(loaded.single.playedMs, 6);
      expect(loaded.single.completed, isTrue);
    });

    test('fills in optional fields an older writer left out', () async {
      await file().writeAsString(jsonEncode([{'songId': 'a'}]));

      final loaded = await store.load();
      expect(loaded, hasLength(1));
      expect(loaded.single.durationMs, 0);
      expect(loaded.single.completed, isFalse);
      expect(loaded.single.skippedEarly, isFalse);
      expect(loaded.single.completion, 0);
    });

    test('leaves no temp file behind after a save', () async {
      await store.save([_event('a')]);

      expect(await file().exists(), isTrue);
      expect(await File('${file().path}.tmp').exists(), isFalse);
    });

    test('clear removes the persisted history', () async {
      await store.save([_event('a'), _event('b')]);
      expect(await store.load(), hasLength(2));

      await store.clear();
      expect(await store.load(), isEmpty);
      expect(await file().exists(), isFalse);
    });

    test('clear is safe when nothing was ever written', () async {
      await store.clear();

      expect(await store.load(), isEmpty);
    });
  });
}

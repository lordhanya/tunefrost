import 'package:flutter_test/flutter_test.dart';
import 'package:music_player/core/models/queue_state.dart';
import 'package:music_player/core/models/song.dart';
import 'package:music_player/core/services/queue_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

Song _song(String id) => Song(
  id: id,
  title: 'Song $id',
  artist: 'Artist',
  album: 'Album',
  durationMs: 1000,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('QueueStorage', () {
    test('returns nothing on a fresh install', () async {
      SharedPreferences.setMockInitialValues({});
      final storage = QueueStorage(await SharedPreferences.getInstance());

      expect(storage.load(), isNull);
    });

    test('saves and restores the queue plus position', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final storage = QueueStorage(prefs);

      await storage.save(
        QueueState(
          queue: [_song('1'), _song('2')],
          currentIndex: 1,
          shuffleMode: ShuffleMode.all,
          repeatMode: RepeatMode.one,
          speed: 1.5,
        ),
        const Duration(minutes: 2, seconds: 30),
      );

      final restored = QueueStorage(await SharedPreferences.getInstance())
          .load();
      expect(restored, isNotNull);

      final (state, position) = restored!;
      expect(state.queue.map((s) => s.id), ['1', '2']);
      expect(state.currentIndex, 1);
      expect(state.shuffleMode, ShuffleMode.all);
      expect(state.repeatMode, RepeatMode.one);
      expect(state.speed, 1.5);
      expect(position, const Duration(minutes: 2, seconds: 30));
    });

    test('ignores a corrupt snapshot rather than throwing', () async {
      SharedPreferences.setMockInitialValues({'queue_v1': 'not json at all'});
      final storage = QueueStorage(await SharedPreferences.getInstance());

      expect(storage.load(), isNull);
    });

    test('ignores a snapshot with an empty queue', () async {
      SharedPreferences.setMockInitialValues({
        'queue_v1': '{"queue": [], "currentIndex": 0}',
      });
      final storage = QueueStorage(await SharedPreferences.getInstance());

      expect(storage.load(), isNull);
    });
  });
}

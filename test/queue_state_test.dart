import 'package:flutter_test/flutter_test.dart';
import 'package:music_player/core/models/queue_state.dart';
import 'package:music_player/core/models/song.dart';

Song _song(String id, {String title = ''}) => Song(
  id: id,
  title: title.isEmpty ? 'Song $id' : title,
  artist: 'Artist',
  album: 'Album',
  durationMs: 1000,
);

void main() {
  group('QueueState', () {
    test('defaults to an empty stopped queue', () {
      const state = QueueState();

      expect(state.isEmpty, isTrue);
      expect(state.currentSong, isNull);
      expect(state.hasNext, isFalse);
      expect(state.hasPrevious, isFalse);
      expect(state.playbackState, PlaybackState.stopped);
      expect(state.speed, 1.0);
    });

    test('exposes neighbours of the current index', () {
      final state = QueueState(
        queue: [_song('1'), _song('2'), _song('3')],
        currentIndex: 1,
      );

      expect(state.currentSong?.id, '2');
      expect(state.previousSong?.id, '1');
      expect(state.nextSong?.id, '3');
      expect(state.hasPrevious, isTrue);
      expect(state.hasNext, isTrue);
    });

    test('guards against an out-of-range index', () {
      final state = QueueState(queue: [_song('1')], currentIndex: 5);

      expect(state.currentSong, isNull);
      expect(state.hasNext, isFalse);
      expect(state.hasPrevious, isTrue);
    });

    test('copyWith leaves untouched fields alone', () {
      final state = QueueState(
        queue: [_song('1')],
        repeatMode: RepeatMode.one,
        shuffleMode: ShuffleMode.all,
      );

      final next = state.copyWith(playbackState: PlaybackState.playing);

      expect(next.queue, state.queue);
      expect(next.repeatMode, RepeatMode.one);
      expect(next.shuffleMode, ShuffleMode.all);
      expect(next.playbackState, PlaybackState.playing);
    });

    test('equality compares queue contents, not identity', () {
      final a = QueueState(queue: [_song('1')], currentIndex: 0);
      final b = QueueState(
        queue: [_song('1', title: 'Other')],
        currentIndex: 0,
      );
      final c = QueueState(queue: [_song('1')], currentIndex: 1);

      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(c));
    });

    test('round-trips through json', () {
      final state = QueueState(
        queue: [
          _song('1'),
          Song.remote(videoId: 'abc', title: 'R', artist: 'A', durationMs: 500),
        ],
        currentIndex: 1,
        shuffleMode: ShuffleMode.all,
        repeatMode: RepeatMode.all,
        speed: 1.25,
      );

      final restored = QueueState.fromJson(state.toJson());

      expect(restored.queue, state.queue);
      expect(restored.currentIndex, 1);
      expect(restored.shuffleMode, ShuffleMode.all);
      expect(restored.repeatMode, RepeatMode.all);
      expect(restored.speed, 1.25);
      expect(restored.queue[1].isRemote, isTrue);
    });

    test('a corrupt snapshot degrades to empty instead of throwing', () {
      final restored = QueueState.fromJson(const {'currentIndex': 3});

      expect(restored.isEmpty, isTrue);
      expect(restored.currentIndex, 0);
      expect(restored.speed, 1.0);
    });
  });
}

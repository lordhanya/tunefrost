import 'package:flutter_test/flutter_test.dart';
import 'package:music_player/core/models/queue_state.dart';
import 'package:music_player/core/models/song.dart';
import 'package:music_player/core/taste/listening_stint_tracker.dart';

const _twoMinutes = Duration(minutes: 2);

Song _song(String id, {int durationMs = 120000}) => Song(
  id: id,
  title: 'Title $id',
  artist: 'Artist $id',
  album: 'Album',
  durationMs: durationMs,
);

/// Feeds the observations a normal track passes through before any position
/// has been reported: the source loads, then playback begins.
void start(
  ListeningStintTracker tracker,
  Song song, {
  Duration? duration = _twoMinutes,
  int nowMs = 1000,
}) {
  tracker.onPlayback(
    song: song,
    state: PlaybackState.buffering,
    duration: duration,
    nowMs: nowMs,
  );
  tracker.onPlayback(
    song: song,
    state: PlaybackState.playing,
    duration: duration,
    nowMs: nowMs,
  );
}

void main() {
  group('ListeningStintTracker', () {
    test('records a listen that runs to the end', () {
      final tracker = ListeningStintTracker();
      final song = _song('a');

      start(tracker, song);
      tracker.onPosition(position: _twoMinutes, nowMs: 2000);
      final event = tracker.onPlayback(
        song: song,
        state: PlaybackState.completed,
        duration: _twoMinutes,
        nowMs: 3000,
      );

      expect(event, isNotNull);
      expect(event!.completed, isTrue);
      expect(event.skippedEarly, isFalse);
      expect(event.playedMs, _twoMinutes.inMilliseconds);
      expect(event.songId, 'a');
      expect(event.startedAtMs, 1000);
    });

    test('flags an early skip and reports the time actually heard', () {
      final tracker = ListeningStintTracker();
      final song = _song('a');

      start(tracker, song);
      tracker.onPosition(position: const Duration(seconds: 3), nowMs: 2000);
      final event = tracker.onPlayback(
        song: _song('b'),
        state: PlaybackState.buffering,
        duration: _twoMinutes,
        nowMs: 3000,
      );

      expect(event, isNotNull);
      expect(event!.completed, isFalse);
      expect(event.skippedEarly, isTrue);
      expect(event.playedMs, 3000);
      expect(event.songId, 'a');
    });

    test('never emits twice for the same stint', () {
      final tracker = ListeningStintTracker();
      final song = _song('a');
      var events = 0;

      void feed(PlaybackState state) {
        final event = tracker.onPlayback(
          song: song,
          state: state,
          duration: _twoMinutes,
          nowMs: 1000,
        );
        if (event != null) events++;
      }

      feed(PlaybackState.buffering);
      feed(PlaybackState.playing);
      feed(PlaybackState.paused);
      feed(PlaybackState.playing);
      feed(PlaybackState.completed);
      feed(PlaybackState.paused);
      feed(PlaybackState.stopped);

      expect(events, 1);
    });

    test('counts a later replay of the same song as a new event', () {
      final tracker = ListeningStintTracker();
      final first = _song('a');
      final other = _song('b');

      start(tracker, first);
      final a = tracker.onPlayback(
        song: other,
        state: PlaybackState.buffering,
        duration: _twoMinutes,
        nowMs: 2000,
      );
      start(tracker, other, nowMs: 3000);
      final b = tracker.onPlayback(
        song: first,
        state: PlaybackState.buffering,
        duration: _twoMinutes,
        nowMs: 4000,
      );

      expect(a, isNotNull);
      expect(b, isNotNull);
      expect(a!.songId, 'a');
      expect(b!.songId, 'b');
    });

    test('carries the outgoing track’s own listened time across a switch', () {
      final tracker = ListeningStintTracker();
      start(tracker, _song('a'));
      tracker.onPosition(position: const Duration(seconds: 10), nowMs: 2000);

      final event = tracker.onPlayback(
        song: _song('b'),
        state: PlaybackState.buffering,
        duration: _twoMinutes,
        nowMs: 3000,
      );

      expect(event!.songId, 'a');
      expect(event.playedMs, 10000);
      expect(event.skippedEarly, isFalse);
    });

    test('treats a pause and resume as one continuous stint', () {
      final tracker = ListeningStintTracker();
      final song = _song('a');

      start(tracker, song);
      expect(
        tracker.onPlayback(
          song: song,
          state: PlaybackState.paused,
          duration: _twoMinutes,
          nowMs: 2000,
        ),
        isNull,
      );
      expect(
        tracker.onPlayback(
          song: song,
          state: PlaybackState.playing,
          duration: _twoMinutes,
          nowMs: 3000,
        ),
        isNull,
      );

      tracker.onPosition(position: const Duration(seconds: 30), nowMs: 4000);
      final event = tracker.onPlayback(
        song: song,
        state: PlaybackState.completed,
        duration: _twoMinutes,
        nowMs: 5000,
      );

      expect(event, isNotNull);
      expect(event!.playedMs, 30000);
      expect(event.completed, isTrue);
    });

    test('closes the stint when playback stops', () {
      final tracker = ListeningStintTracker();
      final song = _song('a');

      start(tracker, song);
      tracker.onPosition(position: const Duration(seconds: 45), nowMs: 2000);
      final event = tracker.onPlayback(
        song: song,
        state: PlaybackState.stopped,
        duration: _twoMinutes,
        nowMs: 3000,
      );

      expect(event, isNotNull);
      expect(event!.playedMs, 45000);
      expect(event.skippedEarly, isFalse);
    });

    test('counts each repeat-one loop separately', () {
      final tracker = ListeningStintTracker();
      final song = _song('a', durationMs: 100000);
      const length = Duration(seconds: 100);

      start(tracker, song, duration: length);
      tracker.onPosition(position: length, nowMs: 2000);
      final first = tracker.onPosition(position: Duration.zero, nowMs: 3000);
      tracker.onPosition(position: length, nowMs: 4000);
      final second = tracker.onPosition(position: Duration.zero, nowMs: 5000);

      expect(first, isNotNull);
      expect(second, isNotNull);
      expect(first!.songId, 'a');
      expect(second!.songId, 'a');
      expect(first.completed, isTrue);
      expect(second.completed, isTrue);
      expect(second.startedAtMs, 3000);
    });

    test('does not mistake a mid-track seek for a repeat', () {
      final tracker = ListeningStintTracker();
      final song = _song('a');

      start(tracker, song);
      tracker.onPosition(position: const Duration(seconds: 60), nowMs: 2000);
      final rewound = tracker.onPosition(
        position: Duration.zero,
        nowMs: 3000,
      );
      expect(rewound, isNull);

      final event = tracker.onPlayback(
        song: _song('b'),
        state: PlaybackState.buffering,
        duration: _twoMinutes,
        nowMs: 4000,
      );

      expect(event!.playedMs, 60000);
      expect(event.completed, isFalse);
    });

    test('seeking backwards cannot deflate the time heard', () {
      final tracker = ListeningStintTracker();
      final song = _song('a');

      start(tracker, song);
      tracker.onPosition(position: const Duration(seconds: 60), nowMs: 2000);
      tracker.onPosition(position: const Duration(seconds: 5), nowMs: 3000);

      final event = tracker.onPlayback(
        song: _song('b'),
        state: PlaybackState.buffering,
        duration: _twoMinutes,
        nowMs: 4000,
      );

      expect(event!.playedMs, 60000);
      expect(event.completed, isFalse);
    });

    test('completes on the player’s word when the length is unknown', () {
      final tracker = ListeningStintTracker();
      final song = _song('a', durationMs: 0);

      start(tracker, song, duration: null);
      tracker.onPosition(position: const Duration(seconds: 40), nowMs: 2000);
      final event = tracker.onPlayback(
        song: song,
        state: PlaybackState.completed,
        duration: null,
        nowMs: 3000,
      );

      expect(event, isNotNull);
      expect(event!.durationMs, 0);
      expect(event.completed, isTrue);
      expect(event.skippedEarly, isFalse);
      expect(event.completion, 1);
    });

    test('records no completion when the length is unknown and it was short', () {
      final tracker = ListeningStintTracker();
      final song = _song('a', durationMs: 0);

      start(tracker, song, duration: null);
      tracker.onPosition(position: const Duration(seconds: 2), nowMs: 2000);
      final event = tracker.onPlayback(
        song: _song('b'),
        state: PlaybackState.buffering,
        duration: null,
        nowMs: 3000,
      );

      expect(event!.durationMs, 0);
      expect(event.completed, isFalse);
      expect(event.skippedEarly, isTrue);
      expect(event.completion, 0);
    });

    test('returns nothing from flush when the track never played', () {
      final tracker = ListeningStintTracker();
      final song = _song('a');

      // A restored queue loads and pauses without ever reaching playback.
      tracker.onPlayback(
        song: song,
        state: PlaybackState.buffering,
        duration: _twoMinutes,
        nowMs: 1000,
      );
      tracker.onPlayback(
        song: song,
        state: PlaybackState.paused,
        duration: _twoMinutes,
        nowMs: 1000,
      );

      expect(tracker.flush(), isNull);
    });

    test('flush closes an open stint exactly once', () {
      final tracker = ListeningStintTracker();
      start(tracker, _song('a'));
      tracker.onPosition(position: const Duration(seconds: 12), nowMs: 2000);

      final event = tracker.flush();
      expect(event, isNotNull);
      expect(event!.playedMs, 12000);
      expect(tracker.flush(), isNull);
    });

    test('returns nothing while idle', () {
      final tracker = ListeningStintTracker();

      expect(
        tracker.onPlayback(
          song: null,
          state: PlaybackState.stopped,
          duration: null,
          nowMs: 1000,
        ),
        isNull,
      );
      expect(tracker.flush(), isNull);
    });
  });
}

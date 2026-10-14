import 'package:music_player/core/models/listening_event.dart';
import 'package:music_player/core/models/queue_state.dart';
import 'package:music_player/core/models/song.dart';

/// Decides when a listen begins and ends, and what was actually heard in
/// between.
///
/// Pure by design: playback observations go in, a finalised [ListeningEvent]
/// comes out. There is no clock, no stream and no I/O, which is why every rule
/// below is covered by unit tests rather than requiring a running player.
///
/// Observations arrive out of order in practice — a restored queue reports
/// `buffering` before anything plays, a seek jumps the position backwards, and
/// repeat-one restarts the track without ever changing the current song. Each
/// of those is handled explicitly rather than assumed away.
class ListeningStintTracker {
  /// A track abandoned before this much has been heard counts as a skip.
  static const Duration earlySkipThreshold = Duration(seconds: 5);

  /// How close to the end still counts as "completed". Repeat-one never lets
  /// the player report completion, so the high-water mark has to.
  static const Duration completionGrace = Duration(seconds: 2);

  /// The position must be this far into the track to count as an end, and
  /// within this far of the start to count as a restart. Requiring both stops a
  /// plain seek backwards from being mistaken for a repeat.
  static const Duration restartThreshold = Duration(seconds: 3);

  Song? _song;
  int _startedAtMs = 0;
  Duration _highWater = Duration.zero;
  Duration _lastPosition = Duration.zero;
  Duration? _duration;
  bool _sawPlaying = false;
  bool _completed = false;

  /// Feeds one playback observation.
  ///
  /// Returns a finalised event when this observation ended the stint in
  /// flight — a different track took over, the track completed, or the queue
  /// was cleared — and null otherwise.
  ListeningEvent? onPlayback({
    required Song? song,
    required PlaybackState state,
    required Duration? duration,
    required int nowMs,
  }) {
    final incoming = song;
    final changed = incoming?.id != _song?.id;
    final finished = changed ? _finalize() : null;
    if (changed && incoming != null) {
      _start(incoming, nowMs: nowMs);
    }

    // Nothing live now: either there never was a stint, or it just closed.
    if (_song == null) return finished;

    if (state == PlaybackState.playing) _sawPlaying = true;
    if (duration != null && duration > Duration.zero) _duration = duration;
    if (state == PlaybackState.completed) _completed = true;

    final ended =
        state == PlaybackState.completed || state == PlaybackState.stopped;
    // A fresh stint that is already over never played, so only the outgoing
    // event matters.
    return finished ?? (ended ? _finalize() : null);
  }

  /// Feeds one position observation. Cheap: a comparison, an assignment and no
  /// I/O, so it is safe to call on every tick.
  ///
  /// Returns an event only when the track wraps from its end back to its
  /// start — the one case repeat-one moves the position without changing the
  /// current song, and therefore without any playback event to listen for.
  ListeningEvent? onPosition({required Duration position, required int nowMs}) {
    final song = _song;
    if (song == null) return null;

    if (!_isRestart(position)) {
      if (position > _highWater) _highWater = position;
      _lastPosition = position;
      return null;
    }

    final duration = _duration;
    final finished = _finalize();
    _start(song, nowMs: nowMs, duration: duration);
    // Reaching the wrap means audio was flowing, so the new loop counts even
    // though no `playing` observation has arrived for it yet.
    _sawPlaying = true;
    _lastPosition = Duration.zero;
    return finished;
  }

  /// Closes the stint in flight, if any. Used when playback stops for good or
  /// the listener goes away; a second call returns null.
  ListeningEvent? flush() => _finalize();

  bool _isRestart(Duration position) {
    final duration = _duration;
    if (duration == null || duration <= Duration.zero) return false;
    final nearEnd = _lastPosition >= duration - restartThreshold;
    return nearEnd &&
        position <= restartThreshold &&
        position < _lastPosition;
  }

  ListeningEvent? _finalize() {
    final song = _song;
    if (song == null) return null;

    final heard = _highWater;
    final duration =
        _duration ?? (song.durationMs > 0 ? song.duration : null);
    final durationMs = duration?.inMilliseconds ?? 0;
    final completed =
        _completed ||
        (durationMs > 0 &&
            heard.inMilliseconds >= durationMs - completionGrace.inMilliseconds);

    final event = ListeningEvent(
      songId: song.id,
      artist: song.artist,
      title: song.title,
      album: song.album,
      startedAtMs: _startedAtMs,
      playedMs: heard.inMilliseconds,
      durationMs: durationMs,
      completed: completed,
      skippedEarly: !completed && heard < earlySkipThreshold,
    );
    final observed = _sawPlaying;
    _reset();
    // A stint that never reached playback is not a listen: a restored queue
    // that merely loads, or a source that failed before any audio, leaves no
    // trace behind.
    return observed ? event : null;
  }

  void _start(Song song, {required int nowMs, Duration? duration}) {
    _song = song;
    _startedAtMs = nowMs;
    _highWater = Duration.zero;
    _lastPosition = Duration.zero;
    _sawPlaying = false;
    _completed = false;
    _duration = duration;
  }

  void _reset() {
    _song = null;
    _startedAtMs = 0;
    _highWater = Duration.zero;
    _lastPosition = Duration.zero;
    _sawPlaying = false;
    _completed = false;
    // _duration is kept: a repeat-one restart never reloads the source, so the
    // player may not announce the length again and the next wrap needs it.
  }
}

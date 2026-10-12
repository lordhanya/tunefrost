import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math' as math;

import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:rxdart/rxdart.dart';

import 'package:music_player/core/models/queue_state.dart';
import 'package:music_player/core/models/song.dart';

import 'youtube_audio_source.dart';

/// Owns the [AudioPlayer] engine and turns its low-level events into a single
/// reactive [QueueState] stream the UI can consume.
///
/// The queue is loaded through [AudioPlayer.setAudioSources] with children
/// carrying [MediaItem] tags, so the platform media session (Android lock
/// screen, notification, Android Auto) sees a real queue and renders the
/// system prev/next controls. just_audio handles auto-advance, shuffle order
/// and loop modes natively; [QueueState] mirrors that state back to the UI.
///
/// Local files and streamed tracks share one pipeline, so a queue can freely
/// mix both.
class AudioPlayerService {
  factory AudioPlayerService(StreamLinkCache streamCache) {
    final equalizer = Platform.isAndroid ? AndroidEqualizer() : null;
    final player = AudioPlayer(
      audioPipeline: AudioPipeline(androidAudioEffects: [?equalizer]),
      // A dead source (gated stream, unreadable file) skips forward instead
      // of parking forever on a spinner; gives up after three consecutive
      // failures so a broken queue can't skip-loop for ever.
      maxSkipsOnError: 3,
    );
    return AudioPlayerService._(player, equalizer, streamCache);
  }

  AudioPlayerService._(this._player, this.equalizer, this._streamCache) {
    _playerStateSub = _player.playerStateStream.listen(_onPlayerState);
    _errorSub = _player.errorStream.listen(_onPlayerError);
    _durationSub = _player.durationStream.listen((d) => _duration.add(d));
    _positionSub = _player.positionStream.listen(_position.add);
    _currentIndexSub = _player.currentIndexStream.listen((index) {
      if (index != null && index != state.currentIndex) {
        _push(currentIndex: index);
      }
    });
    _configureAudioSession();
  }

  /// Declares the session as music (so it ducking-behaves correctly against
  /// other apps) and pauses when the output device disappears — unplugging
  /// headphones must never keep blaring from the speaker.
  Future<void> _configureAudioSession() async {
    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.music());
      _noisySub = session.becomingNoisyEventStream.listen(
        (_) => _player.pause(),
      );
    } catch (_) {
      // Session setup is best-effort; playback must never depend on it.
    }
  }

  /// Android-only 5/10 band EQ; null on other platforms.
  final AndroidEqualizer? equalizer;

  final AudioPlayer _player;
  final _stateSubject = BehaviorSubject<QueueState>.seeded(const QueueState());
  final _position = BehaviorSubject<Duration>.seeded(Duration.zero);
  final _duration = BehaviorSubject<Duration?>.seeded(null);
  final _failures = PublishSubject<String>();

  final StreamLinkCache _streamCache;
  late final YouTubeStreamResolver _resolver = YouTubeStreamResolver(
    _streamCache,
  );

  /// True while the player holds a source list mirroring [QueueState.queue].
  bool _loaded = false;

  StreamSubscription<PlayerState>? _playerStateSub;
  StreamSubscription<PlayerException>? _errorSub;
  StreamSubscription<Duration?>? _durationSub;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<int?>? _currentIndexSub;
  StreamSubscription<void>? _noisySub;

  /// Monotonic token: bumps on every new load so a slow, superseded load
  /// can never clobber the song the user actually asked for.
  int _loadToken = 0;

  final math.Random _random = math.Random();

  // ---------------------------------------------------------------------------
  // Streams
  // ---------------------------------------------------------------------------

  /// Emits the current state immediately on listen, then every update.
  Stream<QueueState> get queueStateStream => _stateSubject.stream;
  QueueState get state => _stateSubject.value;

  /// Playback position, split from [queueStateStream] so only widgets that
  /// draw a progress bar rebuild every tick.
  Stream<Duration> get positionStream => _position.stream;
  Duration get position => _position.value;

  /// Total length of the current track, null while idle.
  Stream<Duration?> get durationStream => _duration.stream;

  /// One-off messages about tracks that failed to load, for the UI to show
  /// as a SnackBar. [AudioPlayer.maxSkipsOnError] does the skipping; this
  /// only tells the listener why the track changed.
  Stream<String> get failures => _failures.stream;

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Attaches persisted playback state without starting playback.
  Future<void> restore(QueueState saved, Duration position) async {
    if (saved.isEmpty) return;
    final token = ++_loadToken;
    _push(
      queue: saved.queue,
      currentIndex: saved.currentIndex,
      shuffleMode: saved.shuffleMode,
      repeatMode: saved.repeatMode,
      speed: saved.speed,
      playbackState: PlaybackState.buffering,
    );
    try {
      await _loadSources(saved.queue, saved.currentIndex, position);
      if (token != _loadToken) return;
      _loaded = true;
      await _player.setSpeed(saved.speed);
      await _player.pause();
    } catch (_) {
      if (token == _loadToken) _push(playbackState: PlaybackState.stopped);
    }
  }

  /// Replaces the queue with [songs] and starts playback at [startIndex].
  Future<void> playAll(
    List<Song> songs, {
    int startIndex = 0,
    Duration position = Duration.zero,
  }) async {
    if (songs.isEmpty || startIndex < 0 || startIndex >= songs.length) return;
    _push(
      queue: List.unmodifiable(songs),
      currentIndex: startIndex,
      playbackState: PlaybackState.buffering,
    );

    final token = ++_loadToken;
    try {
      await _loadSources(songs, startIndex, position);
      if (token != _loadToken) return; // superseded by a newer request
      _loaded = true;
      await _player.play();
    } catch (_) {
      // Unreadable/corrupt file or dead stream: park in a paused state
      // instead of crashing.
      if (token == _loadToken) _push(playbackState: PlaybackState.paused);
    }
  }

  Future<void> togglePlay() async {
    if (_player.playing) {
      await _player.pause();
    } else if (_player.processingState == ProcessingState.completed) {
      // Finished the last track: restart it.
      await _player.seek(Duration.zero);
      await _player.play();
    } else if (state.currentSong != null) {
      await _player.play();
    }
  }

  Future<void> pause() => _player.pause();

  Future<void> seek(Duration position) => _player.seek(position);

  Future<void> playNext() => _seekRelative(forward: true);

  Future<void> playPrevious() async {
    // Standard behavior: restart the current track if the listener is more
    // than a few seconds in, otherwise go to the previous one.
    if (_player.position > const Duration(seconds: 3) || !_player.hasPrevious) {
      await _player.seek(Duration.zero);
      return;
    }
    await _seekRelative(forward: false);
  }

  Future<void> setSpeed(double speed) async {
    await _player.setSpeed(speed.clamp(0.5, 3.0));
    _push(speed: speed.clamp(0.5, 3.0));
  }

  Future<void> toggleShuffle() async {
    final enabled = state.shuffleMode == ShuffleMode.off;
    _push(shuffleMode: enabled ? ShuffleMode.all : ShuffleMode.off);
    await _player.setShuffleModeEnabled(enabled);
  }

  /// Replaces the queue with [songs] and starts somewhere random in it.
  Future<void> shuffleAll(List<Song> songs) async {
    if (songs.isEmpty) return;
    await playAll(songs, startIndex: _random.nextInt(songs.length));
    if (state.shuffleMode == ShuffleMode.off) await toggleShuffle();
  }

  Future<void> cycleRepeat() async {
    final next = switch (state.repeatMode) {
      RepeatMode.off => RepeatMode.all,
      RepeatMode.all => RepeatMode.one,
      RepeatMode.one => RepeatMode.off,
    };
    _push(repeatMode: next);
    // LoopMode.all is safe now: the queue is one concatenating source, so
    // "all" wraps across tracks instead of looping a single file.
    await _player.setLoopMode(_loopMode(next));
  }

  Future<void> stop() async {
    _loadToken++;
    await _player.stop();
    // Clearing the player's sources clears the system queue too, so the
    // media notification dismisses itself.
    if (_loaded) {
      await _player.clearAudioSources();
      _loaded = false;
    }
    _position.add(Duration.zero);
    _duration.add(null);
    _push(playbackState: PlaybackState.stopped);
  }

  /// Appends [songs] to the end of the queue.
  Future<void> addToQueue(List<Song> songs) async {
    if (songs.isEmpty) return;
    final s = state;
    if (s.isEmpty) {
      await playAll(songs);
      return;
    }
    _push(queue: List.unmodifiable([...s.queue, ...songs]));
    await _append(songs);
  }

  /// Inserts [songs] right after the current track ("play next"). With
  /// shuffle on, just_audio's shuffled order decides the actual playback
  /// position, matching the rest of the queue's behavior.
  Future<void> playNextInQueue(List<Song> songs) async {
    if (songs.isEmpty) return;
    final s = state;
    if (s.isEmpty) {
      await playAll(songs);
      return;
    }
    final insertAt = s.currentIndex + 1;
    final queue = [...s.queue]..insertAll(insertAt, songs);
    _push(queue: List.unmodifiable(queue));
    if (_loaded) {
      await _player.insertAudioSources(
        insertAt,
        songs.map(_audioSource).toList(),
      );
    }
  }

  /// Removes the queue entry at [index]. Removing the current track hands
  /// playback to its successor (predecessor when it was last).
  Future<void> removeFromQueue(int index) async {
    final s = state;
    if (index < 0 || index >= s.queue.length) return;
    if (s.queue.length == 1) {
      await stop();
      return;
    }
    final queue = [...s.queue]..removeAt(index);
    final wasPlaying = s.playbackState == PlaybackState.playing;

    if (index < s.currentIndex) {
      _push(queue: List.unmodifiable(queue), currentIndex: s.currentIndex - 1);
    } else if (index == s.currentIndex) {
      _push(
        queue: List.unmodifiable(queue),
        currentIndex: index >= queue.length ? queue.length - 1 : index,
        playbackState: PlaybackState.buffering,
      );
    } else {
      _push(queue: List.unmodifiable(queue));
    }
    if (!_loaded) return;
    await _player.removeAudioSourceAt(index);
    // Keep playback alive when the track that was playing gets removed.
    if (wasPlaying) await _player.play();
  }

  /// Moves a queue entry; the current song stays current.
  Future<void> moveInQueue(int from, int to) async {
    final s = state;
    if (from == to ||
        from < 0 ||
        to < 0 ||
        from >= s.queue.length ||
        to >= s.queue.length) {
      return;
    }
    final queue = [...s.queue];
    final item = queue.removeAt(from);
    queue.insert(to, item);

    int current = s.currentIndex;
    if (from == current) {
      current = to;
    } else if (from < current && to >= current) {
      current--;
    } else if (from > current && to <= current) {
      current++;
    }
    _push(queue: List.unmodifiable(queue), currentIndex: current);
    if (_loaded) await _player.moveAudioSource(from, to);
  }

  /// Drops every entry after the current one.
  Future<void> clearUpcoming() async {
    final s = state;
    if (!s.hasNext) return;
    final keepUntil = s.currentIndex + 1;
    _push(queue: List.unmodifiable(s.queue.sublist(0, keepUntil)));
    if (_loaded) {
      await _player.removeAudioSourceRange(keepUntil, s.queue.length);
    }
  }

  /// Jumps directly to the queue entry at [index].
  Future<void> jumpTo(int index) async {
    final s = state;
    if (index < 0 || index >= s.queue.length || index == s.currentIndex) {
      return;
    }
    _push(currentIndex: index, playbackState: PlaybackState.buffering);
    await _player.seek(Duration.zero, index: index);
    await _player.play(); // matches the old autoplay behavior
  }

  Future<void> dispose() async {
    _loadToken++;
    await _playerStateSub?.cancel();
    await _errorSub?.cancel();
    await _durationSub?.cancel();
    await _positionSub?.cancel();
    await _currentIndexSub?.cancel();
    await _noisySub?.cancel();
    await _player.dispose();
    await _stateSubject.close();
    await _position.close();
    await _duration.close();
    await _failures.close();
  }

  // ---------------------------------------------------------------------------
  // Internals
  // ---------------------------------------------------------------------------

  Future<void> _loadSources(
    List<Song> songs,
    int startIndex,
    Duration position,
  ) => _player.setAudioSources(
    songs.map(_audioSource).toList(),
    initialIndex: startIndex,
    initialPosition: position,
  );

  Future<void> _append(List<Song> songs) async {
    if (!_loaded) return;
    await _player.addAudioSources(songs.map(_audioSource).toList());
  }

  /// Steps one track forward/back in play order. LoopMode.one is lifted for
  /// the duration so next/previous move to a neighbor instead of restarting
  /// the current track (repeat-one listeners still expect next to advance).
  Future<void> _seekRelative({required bool forward}) async {
    if (state.isEmpty) return;
    final restoreLoop = state.repeatMode == RepeatMode.one;
    if (restoreLoop) await _player.setLoopMode(LoopMode.off);
    try {
      if (forward) {
        if (_player.hasNext) {
          await _player.seekToNext();
        } else {
          // End of queue with repeat off: park in the completed state.
          await _player.pause();
          _push(playbackState: PlaybackState.completed);
        }
      } else if (_player.hasPrevious) {
        await _player.seekToPrevious();
      } else {
        await _player.seek(Duration.zero);
      }
    } finally {
      if (restoreLoop) await _player.setLoopMode(LoopMode.one);
    }
  }

  LoopMode _loopMode(RepeatMode repeat) => switch (repeat) {
    RepeatMode.off => LoopMode.off,
    RepeatMode.all => LoopMode.all,
    RepeatMode.one => LoopMode.one,
  };

  AudioSource _audioSource(Song song) {
    final tag = _mediaItem(song);
    final resolver = _resolver;
    return song.videoId == null
        ? AudioSource.uri(_playbackUri(song), tag: tag)
        : YouTubeAudioSource(
            videoId: song.videoId!,
            resolver: resolver,
            tag: tag,
          );
  }

  /// The tag feeds the media notification / lock-screen player: every metadata
  /// string must be non-empty or SystemUI drops the controls.
  MediaItem _mediaItem(Song song) => MediaItem(
    id: song.id,
    album: song.album.trim().isEmpty ? 'Unknown album' : song.album,
    title: song.title.trim().isEmpty ? 'Unknown title' : song.title,
    artist: song.artist.trim().isEmpty ? 'Unknown artist' : song.artist,
    artUri: switch (song.artworkPath) {
      null => null,
      // Downloads keep the YouTube thumbnail URL even though they now play
      // from a local file, so decide by scheme, not by song source.
      final path when _isHttp(path) => Uri.tryParse(path),
      final path => Uri.file(path),
    },
  );

  /// Whether [path] is a network URL rather than a local file path.
  static bool _isHttp(String path) =>
      path.startsWith('http://') || path.startsWith('https://');

  /// Android must open the MediaStore `content://` URI: raw file paths into
  /// shared storage are rejected (EACCES) under scoped storage. Desktop and
  /// the rare Android song without a URI use the file path.
  Uri _playbackUri(Song song) {
    if (!Platform.isAndroid || song.contentUri == null) {
      return Uri.file(song.filePath ?? '');
    }
    return Uri.parse(song.contentUri!);
  }

  void _onPlayerState(PlayerState playerState) {
    // Auto-advance across the concatenating source is handled by just_audio;
    // completed only fires at the end of the queue with LoopMode.off.
    final playback = switch (playerState.processingState) {
      ProcessingState.idle => PlaybackState.stopped,
      ProcessingState.loading ||
      ProcessingState.buffering => PlaybackState.buffering,
      ProcessingState.ready =>
        playerState.playing ? PlaybackState.playing : PlaybackState.paused,
      ProcessingState.completed => PlaybackState.completed,
    };
    _push(playbackState: playback);
  }

  /// A source failed to load — dead CDN link, gated YouTube payload,
  /// unreadable file. The player skips forward on its own; we just name the
  /// track that failed so the skip isn't silent.
  void _onPlayerError(PlayerException error) {
    final song = state.currentSong;
    if (song == null) return;
    final action = song.videoId == null ? 'play' : 'stream';
    _failures.add("Couldn't $action “${song.title}”");
  }

  void _push({
    List<Song>? queue,
    int? currentIndex,
    ShuffleMode? shuffleMode,
    RepeatMode? repeatMode,
    PlaybackState? playbackState,
    double? speed,
  }) {
    if (_stateSubject.isClosed) return;
    _stateSubject.add(
      state.copyWith(
        queue: queue,
        currentIndex: currentIndex,
        shuffleMode: shuffleMode,
        repeatMode: repeatMode,
        playbackState: playbackState,
        speed: speed,
      ),
    );
  }
}

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:on_audio_query_pluse/on_audio_query.dart';
import 'package:rxdart/rxdart.dart';

import 'package:music_player/audio/audio_player_service.dart';
import 'package:music_player/audio/youtube_audio_source.dart';
import 'package:music_player/core/models/queue_state.dart';
import 'package:music_player/core/models/song.dart';
import 'package:music_player/core/providers/play_history_provider.dart';
import 'package:music_player/core/providers/theme_provider.dart';
import 'package:music_player/core/services/queue_storage.dart';

final queueStorageProvider = Provider<QueueStorage>(
  (ref) => QueueStorage(ref.watch(sharedPreferencesProvider)),
);

final streamLinkCacheProvider = Provider<StreamLinkCache>(
  (ref) => StreamLinkCache(ref.watch(sharedPreferencesProvider)),
);

/// The playback engine. Lives for the lifetime of the app and comes back up
/// holding whatever queue was persisted last time.
final audioPlayerProvider = Provider<AudioPlayerService>((ref) {
  final service = AudioPlayerService(ref.watch(streamLinkCacheProvider));

  final saved = ref.watch(queueStorageProvider).load();
  if (saved != null) {
    final (state, position) = saved;
    service.restore(state, position);
  }

  ref.onDispose(service.dispose);
  return service;
});

/// Persists the queue: immediately on any queue/transport change, and every
/// 15s while playing so a force-quit doesn't lose the playback position.
final queuePersistenceProvider = Provider<void>((ref) {
  final storage = ref.watch(queueStorageProvider);
  final player = ref.watch(audioPlayerProvider);

  void save() => storage.save(player.state, player.position);

  final onState = player.queueStateStream.distinct().skip(1).listen((_) {
    save();
  });
  final onPosition = player.positionStream
      .where((_) => player.state.playbackState == PlaybackState.playing)
      .throttleTime(const Duration(seconds: 15))
      .listen((_) {
        save();
      });

  ref.onDispose(onState.cancel);
  ref.onDispose(onPosition.cancel);
});

/// Queue, current index, transport state and playback speed.
///
/// Position and duration are deliberately separate (see [positionProvider]) —
/// they change several times a second and would otherwise rebuild every
/// listener of the queue.
final playbackStateProvider = StreamProvider<QueueState>(
  (ref) => ref.watch(audioPlayerProvider).queueStateStream,
);

/// Playback position, for progress bars and time labels only.
final positionProvider = StreamProvider<Duration>(
  (ref) => ref.watch(audioPlayerProvider).positionStream,
);

/// Length of the current track; null while the player is idle.
final durationProvider = StreamProvider<Duration?>(
  (ref) => ref.watch(audioPlayerProvider).durationStream,
);

/// Messages about tracks that failed to load, e.g. a YouTube stream the
/// server refused. Each value is shown once as a SnackBar.
final playbackFailuresProvider = StreamProvider<String>(
  (ref) => ref.watch(audioPlayerProvider).failures,
);

/// The song currently loaded in the player, or null when idle.
final currentSongProvider = Provider<Song?>(
  (ref) => ref.watch(playbackStateProvider).value?.currentSong,
);

/// Marks a song as played once the listener has actually heard it.
///
/// Nothing is counted while paused, while the track is skipped within five
/// seconds, or twice for the same stint — so fast scrubbing through the
/// library, resuming, or a restored queue on launch can't inflate recents
/// or play counts.
final playHistoryRecorderProvider = Provider<void>((ref) {
  Timer? timer;
  String? seen;
  var counted = false;

  ref.listen(playbackStateProvider, (_, next) {
    final state = next.value;
    final id = state?.currentSong?.id;
    final playing = state?.playbackState == PlaybackState.playing;

    if (id != seen) {
      seen = id;
      counted = false;
      timer?.cancel();
      timer = null;
    }
    if (!playing || id == null || counted) {
      timer?.cancel();
      timer = null;
      return;
    }
    timer ??= Timer(const Duration(seconds: 5), () {
      counted = true;
      ref.read(recentPlayedProvider.notifier).markPlayed(id);
      ref.read(playCountsProvider.notifier).increment(id);
    });
  }, fireImmediately: true);

  ref.onDispose(() {
    timer?.cancel();
  });
});

/// What the sleep timer will do when it fires.
sealed class SleepTimer {
  const SleepTimer();
}

/// Nothing armed.
final class SleepTimerOff extends SleepTimer {
  const SleepTimerOff();
}

/// Pauses once [remaining] reaches zero; the countdown lives in the state.
final class SleepTimerFor extends SleepTimer {
  const SleepTimerFor(this.remaining);

  final Duration remaining;
}

/// Pauses the moment the current track hands over to the next one.
final class SleepTimerEndOfTrack extends SleepTimer {
  const SleepTimerEndOfTrack();
}

class SleepTimerNotifier extends Notifier<SleepTimer> {
  Timer? _timer;

  /// The song [SleepTimerEndOfTrack] was armed against.
  String? _armedSongId;

  @override
  SleepTimer build() {
    ref.onDispose(() => _timer?.cancel());

    // just_audio auto-advances with no "about to change track" event, so
    // end-of-track fires on the change itself — the previous track is over.
    ref.listen(playbackStateProvider, (_, next) {
      if (state is! SleepTimerEndOfTrack || _armedSongId == null) return;
      final id = next.value?.currentSong?.id;
      if (id == _armedSongId) return;
      _armedSongId = null;
      state = const SleepTimerOff();
      if (id != null) ref.read(audioPlayerProvider).pause();
    });

    return const SleepTimerOff();
  }

  /// Arms (or re-arms) the timer; [SleepTimerOff] cancels whatever was set.
  void start(SleepTimer mode) {
    _timer?.cancel();
    _timer = null;
    _armedSongId = null;

    switch (mode) {
      case SleepTimerOff():
        state = mode;
      case SleepTimerEndOfTrack():
        final songId = ref.read(playbackStateProvider).value?.currentSong?.id;
        _armedSongId = songId;
        state = songId == null ? const SleepTimerOff() : mode; // idle: disarm
      case SleepTimerFor():
        state = mode;
        _timer = Timer.periodic(const Duration(seconds: 1), (_) {
          final current = state;
          if (current is! SleepTimerFor) return;
          final next = current.remaining - const Duration(seconds: 1);
          if (next > Duration.zero) {
            state = SleepTimerFor(next);
            return;
          }
          _fire();
        });
    }
  }

  void _fire() {
    _timer?.cancel();
    _timer = null;
    _armedSongId = null;
    state = const SleepTimerOff();
    ref.read(audioPlayerProvider).pause();
  }
}

final sleepTimerProvider = NotifierProvider<SleepTimerNotifier, SleepTimer>(
  SleepTimerNotifier.new,
);

/// In-memory album artwork for a song.
///
/// Family argument is `(songId, pixelSize)` — records have structural
/// equality, so the same query is shared by every consumer. Streamed songs
/// have a remote thumbnail instead of a MediaStore id, and return null so
/// [SongArtwork] falls back to the network image.
final songArtworkProvider = FutureProvider.autoDispose
    .family<Uint8List?, (String, int)>((ref, query) async {
      final (id, size) = query;
      final songId = int.tryParse(id);
      if (songId == null) return null;
      try {
        return await OnAudioQuery().queryArtwork(
          songId,
          ArtworkType.AUDIO,
          format: ArtworkFormat.JPEG,
          size: size,
        );
      } catch (_) {
        return null;
      }
    });

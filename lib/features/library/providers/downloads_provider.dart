import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:music_player/audio/youtube_audio_source.dart';
import 'package:music_player/core/models/song.dart';
import 'package:music_player/core/providers/theme_provider.dart';
import 'package:music_player/core/services/download_service.dart';

import '../../playback/providers/playback_providers.dart';

final downloadServiceProvider = Provider<DownloadService>(
  (ref) => DownloadService(
    // Shares the stream-link cache with playback, so a download reuses a
    // freshly extracted link instead of asking YouTube again.
    YouTubeStreamResolver(ref.watch(streamLinkCacheProvider)),
    ref.watch(sharedPreferencesProvider),
  ),
);

/// Snapshot of the download shelf: finished songs plus live progress.
class DownloadsState {
  const DownloadsState({
    this.songs = const [],
    this.progress = const {},
    this.active = const {},
    this.failed = const {},
  });

  /// Downloaded songs, newest first.
  final List<Song> songs;

  /// Fraction 0..1 keyed by source video id for downloads in flight.
  final Map<String, double> progress;

  /// Source video ids currently downloading.
  final Set<String> active;

  /// Source video ids whose last attempt failed.
  final Set<String> failed;

  DownloadsState copyWith({
    List<Song>? songs,
    Map<String, double>? progress,
    Set<String>? active,
    Set<String>? failed,
  }) => DownloadsState(
    songs: songs ?? this.songs,
    progress: progress ?? this.progress,
    active: active ?? this.active,
    failed: failed ?? this.failed,
  );
}

class DownloadsNotifier extends Notifier<DownloadsState> {
  /// Per-video cancel flags, cleared once the download settles.
  final Map<String, bool> _cancel = {};

  @override
  DownloadsState build() =>
      DownloadsState(songs: ref.read(downloadServiceProvider).loadIndex());

  bool isDownloaded(String videoId) =>
      state.songs.any((s) => s.sourceVideoId == videoId);

  bool isDownloading(String videoId) => state.active.contains(videoId);

  /// Downloads [song]; calling again for the same video while a download is
  /// running (or finished) is a no-op. Finished copies land newest-first.
  Future<void> start(Song song) async {
    final videoId = song.videoId;
    if (videoId == null || isDownloaded(videoId) || isDownloading(videoId)) {
      return;
    }
    final service = ref.read(downloadServiceProvider);
    _cancel[videoId] = false;
    state = state.copyWith(
      active: {...state.active, videoId},
      progress: {...state.progress, videoId: 0},
      failed: {...state.failed}..remove(videoId),
    );
    try {
      final path = await service.download(
        song,
        onProgress: (fraction) {
          state = state.copyWith(
            progress: {...state.progress, videoId: fraction},
          );
        },
        isCancelled: () => _cancel[videoId] ?? false,
      );
      final saved = Song.download(
        videoId: videoId,
        title: song.title,
        artist: song.artist,
        album: song.album,
        durationMs: song.durationMs,
        artworkUrl: song.artworkPath,
        filePath: path,
        dateAdded: DateTime.now(),
      );
      final songs = [saved, ...state.songs];
      await service.saveIndex(songs);
      state = state.copyWith(songs: songs);
    } catch (_) {
      // The service deletes partial files; keep the song retryable unless
      // the run was cancelled.
      if (state.active.contains(videoId)) {
        state = state.copyWith(failed: {...state.failed, videoId});
      }
    } finally {
      _cancel.remove(videoId);
      state = state.copyWith(
        active: {...state.active}..remove(videoId),
        progress: {...state.progress}..remove(videoId),
      );
    }
  }

  /// Aborts the in-flight download for [videoId]; its partial file is removed.
  void cancel(String videoId) {
    _cancel[videoId] = true;
  }

  /// Deletes a finished download: stored file plus its index entry.
  Future<void> remove(Song download) async {
    final service = ref.read(downloadServiceProvider);
    await service.removeFile(download);
    final songs = List.of(state.songs)..removeWhere((s) => s.id == download.id);
    await service.saveIndex(songs);
    state = state.copyWith(songs: songs);
  }

  /// Deletes every download and frees the storage.
  Future<void> clearAll() async {
    final service = ref.read(downloadServiceProvider);
    for (final song in state.songs) {
      await service.removeFile(song);
    }
    await service.saveIndex(const []);
    state = state.copyWith(songs: const []);
  }
}

final downloadsProvider = NotifierProvider<DownloadsNotifier, DownloadsState>(
  DownloadsNotifier.new,
);

import 'package:music_player/core/models/song.dart';
import 'package:music_player/core/taste/candidate.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

/// Searches YouTube's catalogue and maps hits onto [Song] so streamed tracks
/// flow through the queue, the lock-screen controls and every list exactly
/// like local files.
///
/// Only the audio-only adaptive stream is ever fetched (see
/// `YouTubeAudioSource`); no video player is created, which is why playback
/// here carries no ads.
///
/// The endpoint behind both methods is YouTube's own search results page,
/// read through `youtube_explode_dart`. It is **not** the official YouTube
/// Data API and carries no API key, registration or Google authorisation —
/// see `PRIVACY.md`. Nothing here should be described as an authorized API
/// integration.
class YoutubeRepository {
  const YoutubeRepository();

  Future<List<Song>> search(String query) async {
    final youtube = YoutubeExplode();
    try {
      final videos = await youtube.search.search(query);
      return [
        for (final video in videos)
          if (!video.isLive &&
              (video.duration ?? Duration.zero) > Duration.zero)
            Song.remote(
              videoId: video.id.value,
              title: video.title,
              artist: video.author,
              durationMs: video.duration!.inMilliseconds,
              artworkPath: video.thumbnails.highResUrl,
            ),
      ];
    } finally {
      youtube.close();
    }
  }

  /// Discovery for Smart Play: one page of results per [queries] entry,
  /// returned as raw [Candidate]s so ranking and deduplication stay
  /// downstream concerns.
  ///
  /// One client is opened for the whole batch rather than per query — opening
  /// and closing a connection four times for four seeds is wasteful. The
  /// default `TypeFilters.video` is kept deliberately: `sp` accepts a single
  /// filter, so passing a sort filter here would silently stop restricting
  /// results to videos.
  ///
  /// A query that fails on its own yields whatever the others produced; only
  /// a batch where *every* query failed reports failure, so one blip does not
  /// empty the preview while a genuine outage is still reported honestly.
  Future<List<Candidate>> searchCandidates(
    List<String> queries, {
    int limitPerQuery = 20,
  }) async {
    final wanted = queries.where((q) => q.trim().isNotEmpty).toList();
    if (wanted.isEmpty) return const [];

    final youtube = YoutubeExplode();
    try {
      final seen = <String>{};
      final candidates = <Candidate>[];
      Object? firstError;
      var completed = 0;

      for (final query in wanted) {
        try {
          final videos = await youtube.search.search(query);
          var taken = 0;
          for (final video in videos) {
            if (taken >= limitPerQuery) break;
            if (video.isLive ||
                (video.duration ?? Duration.zero) <= Duration.zero) {
              continue;
            }
            if (!seen.add(video.id.value)) continue;
            candidates.add(_candidate(video, query));
            taken++;
          }
          completed++;
        } catch (error) {
          firstError ??= error;
        }
      }

      if (completed == 0 && firstError != null) throw firstError;
      return candidates;
    } finally {
      youtube.close();
    }
  }

  Candidate _candidate(Video video, String seed) => Candidate(
    videoId: video.id.value,
    title: video.title,
    author: video.author,
    durationMs: video.duration!.inMilliseconds,
    viewCount: video.engagement.viewCount,
    uploadedAtMs: video.uploadDate?.millisecondsSinceEpoch ?? 0,
    thumbnailUrl: video.thumbnails.highResUrl,
    seed: seed,
  );
}

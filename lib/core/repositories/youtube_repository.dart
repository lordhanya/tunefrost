import 'package:music_player/core/models/song.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

/// Searches YouTube's catalogue and maps hits onto [Song] so streamed tracks
/// flow through the queue, the lock-screen controls and every list exactly
/// like local files.
///
/// Only the audio-only adaptive stream is ever fetched (see
/// `YouTubeAudioSource`); no video player is created, which is why playback
/// here carries no ads.
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
}

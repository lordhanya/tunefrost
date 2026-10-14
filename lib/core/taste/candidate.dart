import 'package:music_player/core/models/song.dart';
import 'package:music_player/core/taste/title_metadata.dart';

/// One upload the discovery provider returned for a seed query.
///
/// Deliberately a plain value type rather than youtube_explode_dart's `Video`:
/// tests then construct candidates freely without dragging in thumbnails,
/// channel ids and freezed-generated equality.
class Candidate {
  const Candidate({
    required this.videoId,
    required this.title,
    required this.author,
    required this.durationMs,
    required this.viewCount,
    required this.uploadedAtMs,
    required this.thumbnailUrl,
    required this.seed,
  });

  final String videoId;

  /// Raw upload title, exactly as the provider returned it. Displayed
  /// verbatim; [TitleMetadata.songCore] is the normalized form used for keys.
  final String title;

  /// The **channel** that uploaded it — a brand such as `7clouds`, or an
  /// auto-generated `… - Topic` page.
  ///
  /// For streamed music this is not a fallback, it is *the* identity: the
  /// queue's `Song.artist` carries `video.author` there, so that is the exact
  /// key the taste profile recorded any preference against. Title parsing
  /// only improves on it when a real performer can be resolved.
  final String author;

  final int durationMs;
  final int viewCount;

  /// Best effort. The provider reports upload dates relative to "now", so
  /// this is approximate rather than the true publish time.
  final int uploadedAtMs;

  final String thumbnailUrl;

  /// The seed query that returned this upload, verbatim.
  ///
  /// Carried because it is personalisation that survives a title naming
  /// nobody — the normal case for a channel's own uploads, whose titles
  /// never contain the channel name that identified them as worth searching.
  /// An empty value means "provenance unknown" and simply earns no boost.
  final String seed;

  /// Namespaced id, so a streamed candidate can never collide with a local or
  /// downloaded track that happens to share a number.
  String get id => Song.remoteId(videoId);

  /// Queue-ready song. Pass [artist] when a real performer was resolved;
  /// without it the channel stands in, exactly as plain search does today.
  Song toSong({String? artist}) {
    final resolved = artist?.trim() ?? '';
    return Song.remote(
      videoId: videoId,
      title: title,
      artist: resolved.isEmpty ? author : resolved,
      durationMs: durationMs,
      artworkPath: thumbnailUrl.isEmpty ? null : thumbnailUrl,
    );
  }
}

/// A candidate that survived exclusions, with its score and the evidence
/// behind it. The signals are kept so the preview can say *why* something
/// ranked where it did instead of showing an unexplained number.
class RankedCandidate {
  const RankedCandidate({
    required this.candidate,
    required this.metadata,
    required this.score,
    required this.signals,
  });

  final Candidate candidate;
  final TitleMetadata metadata;
  final double score;

  /// Component scores before weighting — `affinity`, `seed`, `popularity`,
  /// `recency`, `duration`. Each is already in a documented range, so the
  /// preview can render them without knowing the weights.
  final Map<String, double> signals;
}

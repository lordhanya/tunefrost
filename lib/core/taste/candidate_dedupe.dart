import 'package:music_player/core/taste/candidate.dart';

/// Whether two candidates are the same *recording* — the same song, in the
/// same arrangement, uploaded more than once.
///
/// [TitleMetadata.songCore] plus [TitleMetadata.versionKey] does the heavy
/// lifting: channel noise, brackets and `feat.` are already gone, and a live
/// take carries a marker the studio version does not. The artist clause is
/// the remaining guard against a title collision — `Creep` by Radiohead and
/// `Creep` by TLC are different songs that share a name, and dropping one
/// because their titles match would lose music outright.
///
/// When exactly one of the two has no confident artist, there is nothing to
/// distinguish them with, so they collapse into whichever came first. The
/// ordering is therefore the dedupe order: callers pass candidates already
/// ranked, and the best upload wins.
bool sameRecording(RankedCandidate a, RankedCandidate b) {
  final ma = a.metadata;
  final mb = b.metadata;
  if (ma.songCore != mb.songCore) return false;
  if (ma.versionKey != mb.versionKey) return false;
  if (ma.artist.isNotEmpty && mb.artist.isNotEmpty && ma.artist != mb.artist) {
    return false;
  }
  return true;
}

/// Removes duplicate uploads, keeping the first (highest-ranked) of each.
///
/// Ranked on purpose: deduping before ranking would keep whichever upload
/// happened to be returned first rather than the one worth recommending.
List<RankedCandidate> dedupeCandidates(List<RankedCandidate> ranked) {
  final kept = <RankedCandidate>[];
  for (final candidate in ranked) {
    final isDuplicate = kept.any((k) => sameRecording(k, candidate));
    if (!isDuplicate) kept.add(candidate);
  }
  return kept;
}

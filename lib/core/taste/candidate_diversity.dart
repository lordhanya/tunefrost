import 'package:music_player/core/taste/candidate.dart';
import 'package:music_player/core/taste/title_metadata.dart';

/// How many recommendations one uploader may contribute to a single preview.
///
/// Streaming results cluster: the channels a listener plays most are exactly
/// the channels best placed to answer that listener's seed queries, so
/// without a cap one uploader can fill the whole list on the strength of a
/// single over-represented seed.
const int kSmartPlayMaxPerChannel = 2;

/// Limits how many rows any one uploader contributes to [ranked], preserving
/// the order of everything it keeps.
///
/// This is a *selection* over an already-scored list: it never reads a score,
/// never re-sorts and never re-weights, so the ranking the ranker produced is
/// the ranking the listener sees, minus the rows that broke the cap. Run it
/// after `dedupeCandidates` — otherwise a channel's two allowed slots can be
/// spent on two copies of one song while its distinct recordings are cut.
///
/// Uploader identity only, deliberately. It counts [Candidate.author], the
/// channel that uploaded a video, and never the performer parsed out of the
/// title: one channel legitimately carries many artists, and one artist
/// legitimately carries several versions of a song. Because the rule reads
/// nothing beyond the channel and the input order, a cover, a live take or a
/// remix is neither merged with the studio version nor favoured over it — it
/// competes for a slot like any other row. Version markers survive untouched.
///
/// Channels are compared with [foldName], so `7clouds`, `7CLOUDS` and
/// `7clouds!` are one bucket. Comparison stops at that normalisation: word
/// breaks are preserved, so `7 Clouds` stays a different uploader rather than
/// being guessed into `7clouds` — an assumption the cap has no evidence for.
/// A candidate whose channel folds to nothing — missing, blank or
/// punctuation-only — is likewise never grouped, because nothing proves two
/// such rows came from the same uploader, and bucketing them anyway would drop
/// rows this rule has no evidence against; they are therefore also never
/// filtered by it.
///
/// Deterministic and greedy: of each channel's rows, the first [perChannel]
/// in ranked order survive. When there are not enough distinct channels to
/// fill the list the result is simply shorter — the cap is never relaxed to
/// make up the difference, so fewer results is the intended outcome.
List<RankedCandidate> applyChannelDiversity(
  List<RankedCandidate> ranked, {
  required int perChannel,
}) {
  final taken = <String, int>{};
  final kept = <RankedCandidate>[];

  for (final item in ranked) {
    final channel = foldName(item.candidate.author);
    if (channel.isEmpty) {
      kept.add(item);
      continue;
    }
    final count = taken[channel] ?? 0;
    if (count >= perChannel) continue;
    taken[channel] = count + 1;
    kept.add(item);
  }

  return kept;
}

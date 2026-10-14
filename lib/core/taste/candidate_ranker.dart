import 'dart:math' as math;

import 'package:music_player/core/taste/candidate.dart';
import 'package:music_player/core/taste/title_metadata.dart';
import 'package:music_player/core/taste/taste_profile.dart';

/// Anything outside this is not worth recommending: a clip is too short to be
/// a song, and past an hour it is a set, an album or a podcast.
const int _minDurationMs = 30 * 1000;
const int _maxDurationMs = 60 * 60 * 1000;

/// The band a comfortable listen sits in; the duration signal ramps to its
/// best here and falls away towards both hard limits.
const int _goodMinMs = 60 * 1000;
const int _goodMaxMs = 20 * 60 * 1000;

/// Over how long an upload's age stops counting in its favour.
const int _recencyWindowMs = 3 * 365 * 24 * 60 * 60 * 1000;

/// Weights. Affinity dominates by design — this list exists to reflect the
/// listener, and popularity is only a tie-break inside that.
const double _affinityWeight = 3.0;
const double _seedWeight = 1.0;
const double _popularityWeight = 0.6;
const double _recencyWeight = 0.2;
const double _durationWeight = 0.8;

/// Everything ranking needs from outside itself: the taste profile, what is
/// already owned or playing, and the names worth recognising.
class RankContext {
  const RankContext({
    required this.profile,
    required this.nowMs,
    this.libraryIds = const {},
    this.queuedIds = const {},
    this.knownArtists = const {},
  });

  final TasteProfile profile;

  /// Ids already in the local library — a recommendation of something the
  /// listener already owns is a wasted row.
  final Set<String> libraryIds;

  /// Ids currently queued.
  final Set<String> queuedIds;

  /// Already-folded performer names from outside the profile (library tags,
  /// favourite snapshots). The profile's own seeds are folded here too.
  final Set<String> knownArtists;

  /// Injected, so recency is testable without a clock.
  final int nowMs;
}

/// Scores, orders and drops candidates.
///
/// Exclusions run before scoring so an unavailable song can never rank well
/// by accident: blocked (already heard recently), already owned, already
/// queued, or an implausible duration. Everything afterwards is a weighted
/// sum of signals each normalised into a documented range, and the ordering
/// is total — score, then title, then id — so identical inputs always
/// produce an identical list and the tests can assert exactly that.
List<RankedCandidate> rankCandidates(
  List<Candidate> candidates,
  RankContext context,
) {
  final affinityByFolded = <String, double>{
    for (final entry in context.profile.artistAffinity.entries)
      foldName(entry.key): entry.value,
  };
  final seeds = context.profile.seedArtists;
  final seedIndexByFolded = <String, int>{
    for (var i = 0; i < seeds.length; i++) foldName(seeds[i]): i,
  };
  final known = <String>{...context.knownArtists, ...seedIndexByFolded.keys};

  final eligible = [
    for (final candidate in candidates)
      if (!_excluded(candidate, context)) candidate,
  ];

  // Popularity is only meaningful relative to the batch it is compared in.
  final maxViews = eligible.fold<int>(
    0,
    (best, candidate) =>
        candidate.viewCount > best ? candidate.viewCount : best,
  );
  final logMax = maxViews > 0 ? math.log(1 + maxViews) : 0.0;
  final seedCount = seeds.length;

  final ranked = <RankedCandidate>[];
  for (final candidate in eligible) {
    final metadata = parseTitleMetadata(
      TitleParseInput(
        title: candidate.title,
        author: candidate.author,
        knownArtists: known,
      ),
    );

    // The performer when one was resolved; otherwise the upload channel.
    // For streamed music the channel *is* the identity the taste profile
    // recorded the preference under — `Song.artist` there is `video.author`
    // — so matching it is not a guess but the same key the play was scored
    // against. Local tracks, whose tags name real performers, resolve at
    // parse time and take precedence whenever they are known.
    final artistKey = foldName(metadata.artist);
    final channelKey = foldName(candidate.author);
    final fromArtist = metadata.hasArtist
        ? (affinityByFolded[artistKey] ?? 0.0)
        : 0.0;
    final affinity = fromArtist != 0.0
        ? fromArtist
        : affinityByFolded[channelKey] ?? 0.0;

    // Provenance first: which query returned this upload is a fact rather
    // than an inference, and it survives a title that names nobody. A parsed
    // artist that also happens to be a seed is a stronger statement still,
    // so the earliest of any matching sources wins.
    var seedIndex = -1;
    for (final name in [
      candidate.seed,
      candidate.author,
      if (metadata.hasArtist) metadata.artist,
    ]) {
      final index = seedIndexByFolded[foldName(name)] ?? -1;
      if (index >= 0 && (seedIndex < 0 || index < seedIndex)) {
        seedIndex = index;
      }
    }
    final seedBoost = seedIndex < 0 || seedCount == 0
        ? 0.0
        : 1 - seedIndex / seedCount;

    final popularity = logMax <= 0 || candidate.viewCount <= 0
        ? 0.0
        : math.log(1 + candidate.viewCount) / logMax;

    final signals = <String, double>{
      'affinity': affinity,
      'seed': seedBoost,
      'popularity': popularity,
      'recency': _recencyFit(candidate.uploadedAtMs, context.nowMs),
      'duration': _durationFit(candidate.durationMs),
    };

    ranked.add(
      RankedCandidate(
        candidate: candidate,
        metadata: metadata,
        score:
            affinity * _affinityWeight +
            seedBoost * _seedWeight +
            popularity * _popularityWeight +
            signals['recency']! * _recencyWeight +
            signals['duration']! * _durationWeight,
        signals: signals,
      ),
    );
  }

  ranked.sort(_byScoreThenTitle);
  return ranked;
}

bool _excluded(Candidate candidate, RankContext context) {
  final id = candidate.id;
  if (candidate.videoId.trim().isEmpty) return true;
  if (context.profile.blockedIds.contains(id)) return true;
  if (context.libraryIds.contains(id)) return true;
  if (context.queuedIds.contains(id)) return true;
  return candidate.durationMs < _minDurationMs ||
      candidate.durationMs > _maxDurationMs;
}

int _byScoreThenTitle(RankedCandidate a, RankedCandidate b) {
  final byScore = b.score.compareTo(a.score);
  if (byScore != 0) return byScore;
  final byTitle = foldName(a.candidate.title)
      .compareTo(foldName(b.candidate.title));
  if (byTitle != 0) return byTitle;
  return a.candidate.videoId.compareTo(b.candidate.videoId);
}

/// Smoothly rises to 1 between 30s and a minute, holds until 20 minutes, then
/// falls towards -1 at the hour. Continuous on purpose: a step would make a
/// 59-second track and a 61-second one differ by more than a whole signal.
double _durationFit(int durationMs) {
  if (durationMs <= _goodMinMs) {
    return -1 + 2 * (durationMs / _goodMinMs);
  }
  if (durationMs <= _goodMaxMs) return 1;
  final span = _maxDurationMs - _goodMaxMs;
  return (1 - 2 * ((durationMs - _goodMaxMs) / span)).clamp(-1.0, 1.0);
}

double _recencyFit(int uploadedAtMs, int nowMs) {
  if (uploadedAtMs <= 0) return 0;
  final age = nowMs - uploadedAtMs;
  if (age < 0) return 1; // clock skew, not time travel
  if (age > _recencyWindowMs) return 0;
  return 1 - age / _recencyWindowMs;
}

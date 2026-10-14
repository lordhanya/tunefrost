import 'dart:math' as math;

import 'package:music_player/core/models/listening_event.dart';
import 'package:music_player/core/models/song.dart';
import 'package:music_player/core/taste/listening_stint_tracker.dart';

/// What Tunefrost has learned about your ears, derived purely from data the
/// app already owns: what you actually heard, what you favoured, and how often
/// you played it. Nothing here leaves the device.
///
/// An affinity is a signed number in -1..1: positive means you keep coming
/// back to it, negative means you keep abandoning it. Scores are normalised by
/// their own largest magnitude, so comparing across artists stays meaningful
/// without a fixed scale.
class TasteProfile {
  const TasteProfile({
    this.artistAffinity = const {},
    this.songAffinity = const {},
    this.blockedIds = const {},
    this.seedArtists = const [],
  });

  final Map<String, double> artistAffinity;
  final Map<String, double> songAffinity;

  /// Songs to step past when picking what plays next: the recents window plus
  /// the most recently finished listens. Repeated listens are handled by
  /// affinity alone; this is what keeps a session from circling.
  final Set<String> blockedIds;

  /// Strongest names first, capped — the entry point Phases 2 and 3 read.
  ///
  /// Whatever the profile keyed the preference on, not necessarily a
  /// performer: a tagged local file records its artist, a streamed one records
  /// its uploader channel. Callers must not assume every seed is an artist.
  final List<String> seedArtists;

  static const empty = TasteProfile();

  bool get isEmpty => artistAffinity.isEmpty && songAffinity.isEmpty;
}

/// Recency half-life: an event this many days old contributes half its weight.
const double _halfLifeDays = 30.0;

/// How much heavier a favourite is than a single completed listen.
const double _favoriteWeight = 3.0;

/// Ceiling on how far an early skip pushes an artist down: a full-length
/// abandon counts for this much, a shorter one proportionally less. Small
/// enough that one skip cannot undo a session of finished tracks, large
/// enough to register.
const double _skipPenalty = 0.5;

/// Placeholder artist names a source can hand us when it has no real tags.
///
/// Untagged files all arrive as the same fake name, so without this they
/// pile into one confident-looking bucket and dominate the seeds. A rejected
/// name still scores its song; it simply never becomes an artist.
const Set<String> _unusableArtists = {
  'unknown artist',
  'unknown',
  '<unknown>',
  'various artists',
  'various artist',
  'va',
  'tunefrost',
};

/// Whether [name] is a real, usable artist for ranking.
///
/// Deliberately conservative: it only rejects things that are definitely not
/// an artist — a placeholder, a URL, or a filename-long blob — because a
/// false rejection throws away genuine listening signal.
bool isUsableArtistName(String name) {
  final candidate = name.trim();
  if (candidate.isEmpty || candidate.length > 60) return false;
  if (_unusableArtists.contains(candidate.toLowerCase())) return false;
  return !candidate.contains('://') &&
      !candidate.toLowerCase().contains('www.');
}

/// Most recent listens held out as exclusions.
const int _blockedWindow = 40;

/// How many artists are exposed as seeds.
const int _seedArtistLimit = 20;

/// Builds a [TasteProfile] from the three signals the app already keeps plus
/// the listening history Phase 1 records.
///
/// Pure and time-injectable: no provider, no clock, no I/O.
TasteProfile buildTasteProfile({
  required List<ListeningEvent> events,
  required List<Song> favorites,
  required Map<String, int> playCounts,
  required List<String> recentlyPlayed,
  Map<String, String> artistBySongId = const {},
  int? nowMs,
}) {
  final now = nowMs ?? DateTime.now().millisecondsSinceEpoch;
  final artists = <String, double>{};
  final songs = <String, double>{};

  // Play counts only carry ids. Fold in every artist we do know — recorded
  // listens, favourites, and whatever the caller resolved from the library —
  // so a local track played a hundred times still lifts its artist.
  final artistById = <String, String>{
    for (final event in events)
      if (event.songId.isNotEmpty && event.artist.trim().isNotEmpty)
        event.songId: event.artist,
    for (final song in favorites)
      if (song.id.isNotEmpty && song.artist.trim().isNotEmpty)
        song.id: song.artist,
    ...artistBySongId,
  };

  void add(String? artist, String songId, double weight) {
    if (songId.isEmpty) return;
    songs[songId] = (songs[songId] ?? 0) + weight;
    final name = artist ?? '';
    if (!isUsableArtistName(name)) return;
    final key = name.trim();
    artists[key] = (artists[key] ?? 0) + weight;
  }

  for (final event in events) {
    final age = now - event.startedAtMs;
    final recency = _decay(age);
    if (recency <= 0) continue;
    final score = event.skippedEarly ? _skipWeight(event) : event.completion;
    add(event.artist, event.songId, recency * score);
  }

  for (final song in favorites) {
    add(song.artist, song.id, _favoriteWeight);
  }

  for (final entry in playCounts.entries) {
    // Logarithmic, so one track played 200 times cannot drown out everything
    // else you like.
    add(artistById[entry.key], entry.key, math.log(1 + entry.value));
  }

  return TasteProfile(
    artistAffinity: _normalise(artists),
    songAffinity: _normalise(songs),
    blockedIds: _blocked(recentlyPlayed, events),
    seedArtists: _seeds(artists),
  );
}

/// Exponential decay over the half-life, 1.0 for something heard right now.
double _decay(int ageMs) {
  if (ageMs <= 0) return 1.0;
  final days = ageMs / Duration.millisecondsPerDay;
  return math.pow(0.5, days / _halfLifeDays).toDouble();
}

/// Weight of a listen abandoned before [ListeningStintTracker.earlySkipThreshold].
///
/// Proportional to how much was actually heard, so a two-second accidental
/// tap (`-0.1`) barely dents an artist, while staying with a track for
/// four seconds before bailing (`-0.4`) counts as a real rejection. The same
/// threshold decides when a skip *is* a skip, so the penalty reaches its
/// ceiling exactly where a listen stops being scored as one.
double _skipWeight(ListeningEvent event) {
  final threshold = ListeningStintTracker.earlySkipThreshold.inMilliseconds;
  final fraction = (event.playedMs / threshold).clamp(0.0, 1.0);
  return -_skipPenalty * fraction;
}

/// Scales so the strongest signal lands on ±1. A negative score survives as a
/// negative affinity: abandoning a track over and over is a preference too.
Map<String, double> _normalise(Map<String, double> scores) {
  if (scores.isEmpty) return const {};
  final peak = scores.values.map((value) => value.abs()).reduce(math.max);
  if (peak <= 0) return const {};
  return {for (final entry in scores.entries) entry.key: entry.value / peak};
}

Set<String> _blocked(List<String> recentlyPlayed, List<ListeningEvent> events) {
  // Events are stored newest first, so the head of the list is the window.
  final recentEvents = events.take(_blockedWindow);
  return {...recentlyPlayed, for (final event in recentEvents) event.songId};
}

/// Positive affinity only, strongest first, with a deterministic tie-break so
/// two artists at the same score always present in the same order.
List<String> _seeds(Map<String, double> artists) {
  final ranked = artists.entries.where((entry) => entry.value > 0).toList()
    ..sort((a, b) {
      final byScore = b.value.compareTo(a.value);
      if (byScore != 0) return byScore;
      final byName = a.key.toLowerCase().compareTo(b.key.toLowerCase());
      return byName != 0 ? byName : a.key.compareTo(b.key);
    });
  return [for (final entry in ranked.take(_seedArtistLimit)) entry.key];
}

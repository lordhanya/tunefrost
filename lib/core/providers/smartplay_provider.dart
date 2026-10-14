import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:music_player/core/models/song.dart';
import 'package:music_player/core/providers/listening_provider.dart';
import 'package:music_player/core/providers/play_history_provider.dart';
import 'package:music_player/core/providers/search_provider.dart';
import 'package:music_player/core/providers/theme_provider.dart';
import 'package:music_player/core/taste/candidate.dart';
import 'package:music_player/core/taste/candidate_dedupe.dart';
import 'package:music_player/core/taste/candidate_diversity.dart';
import 'package:music_player/core/taste/candidate_ranker.dart';
import 'package:music_player/core/taste/title_metadata.dart';

import '../../features/library/providers/library_provider.dart';
import '../../features/playback/providers/playback_providers.dart';

/// How many seed artists are queried per refresh, and how many results each
/// is asked for. Four pages of twenty is already ~80 candidates before
/// deduplication — more would cost requests without adding variety the
/// listener can perceive.
const int kSmartPlaySeedLimit = 4;
const int kSmartPlayResultsPerSeed = 20;

/// Whether Smart Play is allowed to make requests at all.
///
/// Off by default: enabling it sends queries *derived from listening
/// history* to the discovery provider, which is a meaningfully different act
/// from the listener typing a search themselves. Leaving it opt-in keeps
/// every existing behaviour unchanged until someone turns it on.
class SmartPlayDiscoveryNotifier extends Notifier<bool> {
  static const _key = 'mochi_smartplay_discovery';

  @override
  bool build() => ref.read(sharedPreferencesProvider).getBool(_key) ?? false;

  Future<void> set(bool value) async {
    state = value;
    await ref.read(sharedPreferencesProvider).setBool(_key, value);
  }
}

final smartPlayDiscoveryEnabledProvider =
    NotifierProvider<SmartPlayDiscoveryNotifier, bool>(
      SmartPlayDiscoveryNotifier.new,
    );

enum SmartPlayStatus { idle, loading, ready, empty, error }

/// Counters behind the preview's header, so the screen reports what actually
/// happened instead of a bare list.
class SmartPlayStats {
  const SmartPlayStats({
    this.seedCount = 0,
    this.rawCount = 0,
    this.excludedCount = 0,
    this.duplicateCount = 0,
    this.resolvedArtistCount = 0,
  });

  /// How many seed queries discovery was given, taken from the profile's
  /// strongest entries. They are named whatever the profile recorded them
  /// under — a channel for streamed music, an artist for tagged local files —
  /// which is why the preview labels this "seeds" rather than "artists".
  final int seedCount;

  final int rawCount;
  final int excludedCount;

  /// How many survived ranking but collapsed in deduplication. Rows dropped by
  /// [applyChannelDiversity] are deliberately not folded in: they are neither
  /// duplicates nor exclusions, and counting them here would misreport both.
  final int duplicateCount;

  /// Of the final list, how many had a performer we could stand behind; the
  /// remainder display the uploader's channel and are labelled as such.
  final int resolvedArtistCount;
}

class SmartPlayPreview {
  const SmartPlayPreview({
    required this.status,
    this.candidates = const [],
    this.seeds = const [],
    this.stats = const SmartPlayStats(),
    this.message = '',
  });

  final SmartPlayStatus status;
  final List<RankedCandidate> candidates;
  final List<String> seeds;
  final SmartPlayStats stats;
  final String message;

  static const idle = SmartPlayPreview(status: SmartPlayStatus.idle);
  static const loading = SmartPlayPreview(status: SmartPlayStatus.loading);
}

/// Orchestrates discovery: taste profile → seed queries → raw candidates →
/// exclusions and ranking → deduplication.
///
/// This class holds the *sequencing* only. Parsing, ranking and deduplication
/// live in `core/taste` as pure units, so every rule that decides what a
/// listener is offered is testable without a network, a player or a clock.
///
/// Nothing here touches the queue: the result is inert until a person taps
/// Play in the preview.
class SmartPlayPreviewNotifier extends Notifier<SmartPlayPreview> {
  var _busy = false;

  @override
  SmartPlayPreview build() => SmartPlayPreview.idle;

  Future<void> refresh() async {
    if (_busy) return;
    if (!ref.read(smartPlayDiscoveryEnabledProvider)) {
      state = SmartPlayPreview.idle;
      return;
    }

    // Every input is read before the first await: holding `ref` across a
    // suspension is what turns a fast navigation into a late throw.
    final profile = ref.read(tasteProfileProvider);
    final seeds = profile.seedArtists.take(kSmartPlaySeedLimit).toList();
    final library = ref.read(musicLibraryProvider).value ?? const <Song>[];
    final favorites = ref.read(favoritesProvider);
    final queued = ref.read(playbackStateProvider).value;
    final repository = ref.read(youtubeRepositoryProvider);
    final nowMs = DateTime.now().millisecondsSinceEpoch;

    if (seeds.isEmpty) {
      state = const SmartPlayPreview(
        status: SmartPlayStatus.empty,
        message:
            'Smart Play needs a few artists you keep coming back to before it '
            'can suggest anything. Play some music, then come back.',
      );
      return;
    }

    state = SmartPlayPreview.loading;
    _busy = true;
    try {
      final raw = await repository.searchCandidates(
        seeds,
        limitPerQuery: kSmartPlayResultsPerSeed,
      );

      final context = RankContext(
        profile: profile,
        nowMs: nowMs,
        libraryIds: _idsOf([...library, ...favorites]),
        queuedIds: {
          for (final song in queued?.queue ?? const <Song>[]) song.id,
        },
        knownArtists: _namesOf([...library, ...favorites]),
      );

      // Rank first, drop duplicates second, cap per-channel third. Dedupe
      // ahead of the cap so a channel's two slots are spent on distinct
      // recordings rather than on copies of one; the cap only ever removes
      // rows, it never re-ranks what survives.
      final ranked = rankCandidates(raw, context);
      final deduped = dedupeCandidates(ranked);
      final candidates = applyChannelDiversity(
        deduped,
        perChannel: kSmartPlayMaxPerChannel,
      );
      final resolved = [
        for (final item in candidates)
          if (item.metadata.hasArtist) item,
      ];

      state = SmartPlayPreview(
        status: candidates.isEmpty
            ? SmartPlayStatus.empty
            : SmartPlayStatus.ready,
        candidates: candidates,
        seeds: seeds,
        message: candidates.isEmpty
            ? 'Nothing survived filtering for these artists. Try again after '
                  'listening to something else, or play a little more first.'
            : '',
        stats: SmartPlayStats(
          seedCount: seeds.length,
          rawCount: raw.length,
          excludedCount: raw.length - ranked.length,
          duplicateCount: ranked.length - deduped.length,
          resolvedArtistCount: resolved.length,
        ),
      );
    } catch (_) {
      state = const SmartPlayPreview(
        status: SmartPlayStatus.error,
        message:
            'Could not reach the discovery service. Check your connection and '
            'try again.',
      );
    } finally {
      _busy = false;
    }
  }
}

final smartPlayPreviewProvider =
    NotifierProvider<SmartPlayPreviewNotifier, SmartPlayPreview>(
      SmartPlayPreviewNotifier.new,
    );

Set<String> _idsOf(List<Song> songs) => {for (final song in songs) song.id};

/// Folded with [foldName], the same function the ranker matches against — two
/// different normalizations would mean a name stored could never be found.
Set<String> _namesOf(List<Song> songs) => {
  for (final song in songs)
    if (song.artist.trim().isNotEmpty) foldName(song.artist),
};

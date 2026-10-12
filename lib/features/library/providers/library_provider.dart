import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:on_audio_query_pluse/on_audio_query.dart';

import 'package:music_player/core/models/album.dart';
import 'package:music_player/core/models/artist.dart';
import 'package:music_player/core/models/song.dart';
import 'package:music_player/core/providers/play_history_provider.dart';
import 'package:music_player/core/providers/theme_provider.dart';
import 'package:music_player/core/repositories/local_music_repository.dart';
import 'package:music_player/core/repositories/music_repository.dart';

/// Thrown by [musicLibraryProvider] when audio access was refused. The UI
/// switches on this instead of matching on an error message.
class PermissionDeniedException implements Exception {
  const PermissionDeniedException();

  @override
  String toString() => 'Music permission was not granted.';
}

enum LibrarySort { title, artist, album, dateAdded, duration, playCount }

extension LibrarySortLabel on LibrarySort {
  String get label => switch (this) {
    LibrarySort.title => 'Title',
    LibrarySort.artist => 'Artist',
    LibrarySort.album => 'Album',
    LibrarySort.dateAdded => 'Recently added',
    LibrarySort.duration => 'Duration',
    LibrarySort.playCount => 'Most played',
  };
}

class LibrarySortNotifier extends Notifier<LibrarySort> {
  static const _key = 'library_sort';

  @override
  LibrarySort build() =>
      LibrarySort.values.asNameMap()[ref
          .read(sharedPreferencesProvider)
          .getString(_key)] ??
      LibrarySort.title;

  Future<void> setSort(LibrarySort sort) async {
    state = sort;
    await ref.read(sharedPreferencesProvider).setString(_key, sort.name);
  }
}

final librarySortProvider = NotifierProvider<LibrarySortNotifier, LibrarySort>(
  LibrarySortNotifier.new,
);

final musicRepositoryProvider = Provider<MusicRepository>(
  (ref) => LocalMusicRepository(),
);

/// Every song on the device, in whatever order the media store returns.
///
/// Permission MUST be granted before `querySongs` — the plugin throws a
/// platform exception when querying without it.
final musicLibraryProvider = FutureProvider<List<Song>>((ref) async {
  if (!await OnAudioQuery().permissionsRequest(retryRequest: true)) {
    throw const PermissionDeniedException();
  }
  return ref.watch(musicRepositoryProvider).getSongs();
});

/// The library sorted by the user's chosen key.
final sortedLibraryProvider = FutureProvider<List<Song>>((ref) async {
  final songs = await ref.watch(musicLibraryProvider.future);
  final sort = ref.watch(librarySortProvider);
  // Only the play-count sort subscribes to the counters, so recording a play
  // never re-sorts the library under any of the other five keys.
  final counts = sort == LibrarySort.playCount
      ? ref.watch(playCountsProvider)
      : const <String, int>{};
  final ordered = counts.isEmpty
      ? [...songs]
      : [
          for (final song in songs)
            song.copyWith(playCount: counts[song.id] ?? 0),
        ];
  return ordered..sort((a, b) => compareSongs(a, b, sort));
});

/// Songs grouped by album, ordered alphabetically regardless of the song sort.
final albumsProvider = Provider<List<Album>>(
  (ref) => Album.group(ref.watch(musicLibraryProvider).value ?? const []),
);

/// Artists grouped from the tag, ordered alphabetically regardless of sort.
final artistsProvider = Provider<List<Artist>>(
  (ref) => Artist.group(ref.watch(musicLibraryProvider).value ?? const []),
);

/// Favourites, most recently added first. Songs still on the device take their
/// live library entry; streamed and downloaded favourites fall back to the
/// snapshot stored when the heart was tapped.
final favoriteSongsProvider = Provider<List<Song>>((ref) {
  final favorites = ref.watch(favoritesProvider);
  if (favorites.isEmpty) return const [];
  final byId = {
    for (final song in ref.watch(musicLibraryProvider).value ?? const [])
      song.id: song,
  };
  return [for (final song in favorites) byId[song.id] ?? song];
});

/// Recently played songs, newest first, resolved against the loaded library.
/// Songs deleted from the device are dropped silently.
final recentPlayedSongsProvider = Provider<List<Song>>((ref) {
  final byId = {
    for (final song in ref.watch(sortedLibraryProvider).value ?? const [])
      song.id: song,
  };
  return ref
      .watch(recentPlayedProvider)
      .map((id) => byId[id])
      .whereType<Song>()
      .toList(growable: false);
});

/// Favourite-key group: strips leading articles ("the", "a", "an"), folds
/// case and collapses whitespace, so "The Warning" and "the   warning" both
/// sort and section under "W".
///
/// Shared by [compareSongs] and the A–Z rail so the rail's letters always
/// match the order the list is actually in.
String sortKey(String value) {
  final words = value
      .trim()
      .toLowerCase()
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty)
      .toList(growable: false);
  final start =
      words.length > 1 && const {'the', 'a', 'an'}.contains(words.first)
      ? 1
      : 0;
  return words.skip(start).join(' ');
}

/// Sequence-aware comparison: "Song 2" sorts before "Song 10", leading zeros
/// break the tie ("2" < "02"), and everything else falls back to plain
/// case-folded lexicographic order. Inputs should be pre-folded by [sortKey].
int naturalCompare(String a, String b) {
  final tokensA = RegExp(r'\d+|\D+')
      .allMatches(a)
      .map((m) => m.group(0)!)
      .toList();
  final tokensB = RegExp(r'\d+|\D+')
      .allMatches(b)
      .map((m) => m.group(0)!)
      .toList();

  final shared = math.min(tokensA.length, tokensB.length);
  for (var i = 0; i < shared; i++) {
    final numA = int.tryParse(tokensA[i]);
    final numB = int.tryParse(tokensB[i]);
    if (numA != null && numB != null) {
      if (numA != numB) return numA.compareTo(numB);
      if (tokensA[i].length != tokensB[i].length) {
        return tokensA[i].length.compareTo(tokensB[i].length);
      }
    } else {
      final byText = tokensA[i].compareTo(tokensB[i]);
      if (byText != 0) return byText;
    }
  }
  return tokensA.length.compareTo(tokensB.length);
}

/// Total ordering: the chosen key first, then title, then id — so equal keys
/// always land in the same sequence regardless of the platform's sort.
/// [LibrarySort.artist] and [LibrarySort.album] group that way too; every
/// alphabetical key uses article-aware, sequence-aware comparison.
int compareSongs(Song a, Song b, LibrarySort sort) {
  int byKey(String x, String y) => naturalCompare(sortKey(x), sortKey(y));

  int tieBreak() {
    final byTitle = byKey(a.title, b.title);
    return byTitle != 0 ? byTitle : a.id.compareTo(b.id);
  }

  switch (sort) {
    case LibrarySort.title:
      return tieBreak();
    case LibrarySort.artist:
      final group = byKey(a.artist, b.artist);
      return group != 0 ? group : tieBreak();
    case LibrarySort.album:
      final group = byKey(a.album, b.album);
      return group != 0 ? group : tieBreak();
    case LibrarySort.dateAdded:
      // Newest first.
      final time =
          (b.dateAdded?.millisecondsSinceEpoch ?? 0) -
          (a.dateAdded?.millisecondsSinceEpoch ?? 0);
      return time != 0 ? time : tieBreak();
    case LibrarySort.duration:
      final length = b.durationMs - a.durationMs;
      return length != 0 ? length : tieBreak();
    case LibrarySort.playCount:
      final plays = b.playCount - a.playCount;
      return plays != 0 ? plays : tieBreak();
  }
}

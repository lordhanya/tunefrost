import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:music_player/core/models/song.dart';
import 'package:music_player/core/repositories/youtube_repository.dart';

import '../../features/library/providers/library_provider.dart';

/// Where search results come from.
enum SearchScope { library, youtube }

class SearchScopeNotifier extends Notifier<SearchScope> {
  @override
  SearchScope build() => SearchScope.library;

  void select(SearchScope scope) => state = scope;
}

final searchScopeProvider = NotifierProvider<SearchScopeNotifier, SearchScope>(
  SearchScopeNotifier.new,
);

/// Raw text typed into the search field, committed after a 250ms debounce.
class SearchQueryNotifier extends Notifier<String> {
  Timer? _debounce;

  @override
  String build() {
    ref.onDispose(() => _debounce?.cancel());
    return '';
  }

  void update(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      state = query.trim();
    });
  }
}

final searchQueryProvider = NotifierProvider<SearchQueryNotifier, String>(
  SearchQueryNotifier.new,
);

final youtubeRepositoryProvider = Provider<YoutubeRepository>(
  (ref) => const YoutubeRepository(),
);

/// Streamed results for the committed [searchQueryProvider] value.
///
/// `autoDispose` so backing out of the screen drops the in-flight request.
final youtubeSearchProvider = FutureProvider.autoDispose
    .family<List<Song>, String>((ref, query) async {
      if (query.isEmpty) return const [];
      return ref.watch(youtubeRepositoryProvider).search(query);
    });

/// Songs matching the current query (title / artist / album), or `[]` while
/// the field is empty so the screen can show suggestions instead.
final searchResultsProvider = Provider<List<Song>>((ref) {
  final query = ref.watch(searchQueryProvider);
  if (query.isEmpty) return const [];

  final needle = query.toLowerCase();
  return [
    for (final song in ref.watch(sortedLibraryProvider).value ?? const <Song>[])
      if (song.title.toLowerCase().contains(needle) ||
          song.artist.toLowerCase().contains(needle) ||
          song.album.toLowerCase().contains(needle))
        song,
  ];
});

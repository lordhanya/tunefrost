import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:music_player/core/models/song.dart';
import 'package:music_player/core/providers/search_provider.dart';
import 'package:music_player/core/utils/haptics.dart';
import 'package:music_player/core/widgets/alphabet_scrollbar.dart';
import 'package:music_player/core/widgets/glass.dart';

import '../../library/library_screen.dart';
import '../../library/providers/library_provider.dart';
import '../../library/widgets/song_tile.dart';
import '../../playback/widgets/mini_player.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final results = ref.watch(searchResultsProvider);
    final query = ref.watch(searchQueryProvider);
    final scope = ref.watch(searchScopeProvider);
    final scheme = Theme.of(context).colorScheme;
    final topInset = MediaQuery.paddingOf(context).top + kToolbarHeight;

    return Scaffold(
      extendBody: true,
      extendBodyBehindAppBar: true,
      appBar: glassAppBar(
        context,
        title: const Text('Search'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(16, topInset + 12, 16, 4),
            child: GlassContainer(
              borderRadius: BorderRadius.circular(14),
              blurSigma: 16,
              child: TextField(
                controller: _controller,
                autofocus: true,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Search songs, artists, albums...',
                  prefixIcon: const Icon(Icons.search_rounded),
                  border: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  filled: false,
                  suffixIcon: _controller.text.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.clear_rounded),
                          onPressed: () {
                            _controller.clear();
                            ref.read(searchQueryProvider.notifier).update('');
                            setState(() {});
                          },
                        ),
                ),
                onChanged: (value) {
                  ref.read(searchQueryProvider.notifier).update(value);
                  setState(() {});
                },
              ),
            ),
          ),
          if (query.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: SegmentedButton<SearchScope>(
                showSelectedIcon: false,
                style: SegmentedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
                segments: const [
                  ButtonSegment(
                    value: SearchScope.library,
                    label: Text('On device'),
                    icon: Icon(Icons.phone_iphone_rounded, size: 16),
                  ),
                  ButtonSegment(
                    value: SearchScope.youtube,
                    label: Text('YouTube Music'),
                    icon: Icon(Icons.music_video_outlined, size: 16),
                  ),
                ],
                selected: {scope},
                onSelectionChanged: (selection) {
                  context.hapticSelect();
                  ref
                      .read(searchScopeProvider.notifier)
                      .select(selection.first);
                },
              ),
            ),
          Expanded(child: _buildResults(query, results, scope, scheme)),
        ],
      ),
      bottomNavigationBar: const MiniPlayer(),
    );
  }

  Widget _buildResults(
    String query,
    List<Song> local,
    SearchScope scope,
    ColorScheme scheme,
  ) {
    if (query.isEmpty) return const _RecentSearches();

    if (scope == SearchScope.youtube) {
      return ref
          .watch(youtubeSearchProvider(query))
          .when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => _Hint(
              'YouTube search failed. Check your connection and try again.',
              color: scheme.onSurfaceVariant,
            ),
            data: (songs) => songs.isEmpty
                ? _Hint('No matches found', color: scheme.onSurfaceVariant)
                : _SongResults(songs: songs, scroll: _scroll),
          );
    }

    if (local.isEmpty) {
      return _Hint('No matches found', color: scheme.onSurfaceVariant);
    }
    return _SongResults(songs: local, scroll: _scroll, withRail: true);
  }
}

class _SongResults extends StatelessWidget {
  const _SongResults({
    required this.songs,
    required this.scroll,
    this.withRail = false,
  });

  final List<Song> songs;
  final ScrollController scroll;
  final bool withRail;

  @override
  Widget build(BuildContext context) {
    final labels = [for (final song in songs) sectionLabel(song.title)];
    final rail =
        withRail && songs.length >= 20 && AlphabetScrollbar.isSorted(labels);

    return Stack(
      children: [
        ListView.builder(
          controller: scroll,
          padding: EdgeInsets.only(bottom: miniPlayerBottom(context)),
          itemExtent: kSongTileExtent,
          itemCount: songs.length,
          itemBuilder: (context, index) =>
              SongTile(song: songs[index], songs: songs, index: index),
        ),
        if (rail)
          Positioned(
            right: 0,
            top: 8,
            bottom: 8,
            child: AlphabetScrollbar(
              controller: scroll,
              labels: labels,
              itemExtent: kSongTileExtent,
              topPadding: 0,
            ),
          ),
      ],
    );
  }
}

/// Suggestions while the search field is empty: what was playing recently.
class _RecentSearches extends ConsumerWidget {
  const _RecentSearches();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recent = ref.watch(recentPlayedSongsProvider);
    final scheme = Theme.of(context).colorScheme;

    if (recent.isEmpty) {
      return _Hint(
        'Search your music library,\nor stream from YouTube Music.',
        color: scheme.onSurfaceVariant,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Text(
            'Recently played',
            style: TextStyle(
              color: scheme.onSurfaceVariant,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.only(bottom: miniPlayerBottom(context)),
            itemExtent: kSongTileExtent,
            itemCount: recent.length,
            itemBuilder: (context, index) =>
                SongTile(song: recent[index], songs: recent, index: index),
          ),
        ),
      ],
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint(this.text, {required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(color: color, fontSize: 15, height: 1.5),
        ),
      ),
    );
  }
}

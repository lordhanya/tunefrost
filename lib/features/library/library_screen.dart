import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:music_player/core/models/song.dart';
import 'package:music_player/core/widgets/alphabet_scrollbar.dart';
import 'package:music_player/core/widgets/glass.dart';

import '../playback/widgets/mini_player.dart';
import '../playback/widgets/song_artwork.dart';
import 'providers/downloads_provider.dart';
import 'providers/library_provider.dart';
import 'song_list_screen.dart';
import 'widgets/song_tile.dart';

/// A-Z section header letter for a title, derived from the same normalized
/// key as [compareSongs] so rail letters always match the list's actual
/// order ("The Warning" sections under W, digits under #). Digits and symbols
/// collapse to `#`.
String sectionLabel(String title) {
  final key = sortKey(title);
  if (key.isEmpty) return '#';
  final code = key.codeUnitAt(0);
  return (code >= 97 && code <= 122) ? key[0].toUpperCase() : '#';
}

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 5, vsync: this);
  final ScrollController _scroll = ScrollController();

  @override
  void dispose() {
    _tabs.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final libraryAsync = ref.watch(sortedLibraryProvider);
    final scheme = Theme.of(context).colorScheme;
    final topInset =
        MediaQuery.paddingOf(context).top + kToolbarHeight + kTextTabBarHeight;

    return Scaffold(
      extendBody: true,
      extendBodyBehindAppBar: true,
      appBar: glassAppBar(
        context,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: Image.asset(
                'assets/icons/brand_icon.png',
                width: 30,
                height: 30,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'Tunefrost',
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          indicatorColor: scheme.primary,
          labelColor: scheme.primary,
          unselectedLabelColor: scheme.onSurfaceVariant,
          indicatorSize: TabBarIndicatorSize.label,
          tabs: const [
            Tab(text: 'Songs'),
            Tab(text: 'Albums'),
            Tab(text: 'Artists'),
            Tab(text: 'Favourites'),
            Tab(text: 'Downloads'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.sort_rounded),
            tooltip: 'Sort',
            onPressed: () => showLibrarySortSheet(context, ref),
          ),
          IconButton(
            icon: const Icon(Icons.search_rounded),
            tooltip: 'Search',
            onPressed: () => Navigator.of(context).pushNamed('/search'),
          ),
          IconButton(
            icon: const Icon(Icons.playlist_play_rounded),
            tooltip: 'Playlists',
            onPressed: () => Navigator.of(context).pushNamed('/playlists'),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: () => Navigator.of(context).pushNamed('/settings'),
          ),
        ],
      ),
      body: Padding(
        padding: EdgeInsets.only(top: topInset),
        child: libraryAsync.when(
          // Sorting or a newly recorded play rebuilds the list — that must
          // not blank the screen back to a spinner.
          skipLoadingOnReload: true,
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => switch (error) {
            PermissionDeniedException() => _PermissionRequest(
              onGrant: () => ref.invalidate(musicLibraryProvider),
            ),
            _ => const _Message('Could not read your music library'),
          },
          data: (songs) => TabBarView(
            controller: _tabs,
            children: [
              songs.isEmpty
                  ? const _Message('No music found.')
                  : _SongsTab(songs: songs, scroll: _scroll),
              const _AlbumsTab(),
              const _ArtistsTab(),
              const _FavoritesTab(),
              const _DownloadsTab(),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const MiniPlayer(),
    );
  }
}

Future<void> showLibrarySortSheet(BuildContext context, WidgetRef ref) {
  final current = ref.read(librarySortProvider);

  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: RadioGroup<LibrarySort>(
        groupValue: current,
        onChanged: (value) {
          if (value == null) return;
          Navigator.of(sheetContext).pop();
          ref.read(librarySortProvider.notifier).setSort(value);
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                'Sort by',
                style: Theme.of(sheetContext).textTheme.titleMedium,
              ),
            ),
            for (final sort in LibrarySort.values)
              RadioListTile<LibrarySort>(value: sort, title: Text(sort.label)),
            const SizedBox(height: 8),
          ],
        ),
      ),
    ),
  );
}

class _SongsTab extends ConsumerWidget {
  const _SongsTab({required this.songs, required this.scroll});

  final List<Song> songs;
  final ScrollController scroll;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final labels = [for (final song in songs) sectionLabel(song.title)];
    final sort = ref.watch(librarySortProvider);

    // The rail assumes a strictly alphabetical list, so it only appears on
    // title sort.
    final railEligible =
        sort == LibrarySort.title &&
        songs.length >= 20 &&
        AlphabetScrollbar.isSorted(labels);

    // Ordered by plays, the play count is the more useful number to show.
    final byPlays = sort == LibrarySort.playCount;

    return Stack(
      children: [
        ListView.builder(
          controller: scroll,
          padding: EdgeInsets.only(bottom: miniPlayerBottom(context)),
          itemExtent: kSongTileExtent,
          itemCount: songs.length,
          itemBuilder: (context, index) => SongTile(
            song: songs[index],
            songs: songs,
            index: index,
            trailing: byPlays ? PlayCountLabel(songs[index].playCount) : null,
          ),
        ),
        if (railEligible)
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

class _AlbumsTab extends ConsumerWidget {
  const _AlbumsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final albums = ref.watch(albumsProvider);
    if (albums.isEmpty) return const _Message('No albums found.');

    return ListView.builder(
      padding: EdgeInsets.only(bottom: miniPlayerBottom(context)),
      itemCount: albums.length,
      itemBuilder: (context, index) {
        final album = albums[index];
        final cover = album.firstSong;
        if (cover == null) return const SizedBox.shrink();
        return ListTile(
          leading: SongArtwork(
            song: cover,
            dimension: 56,
            radius: 8,
            querySize: 150,
          ),
          title: Text(
            album.displayName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            '${album.displayArtist} • ${album.songs.length} songs',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => SongListScreen(
                title: album.displayName,
                subtitle: album.displayArtist,
                songs: album.songs,
                cover: cover,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ArtistsTab extends ConsumerWidget {
  const _ArtistsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final artists = ref.watch(artistsProvider);
    if (artists.isEmpty) return const _Message('No artists found.');

    final scheme = Theme.of(context).colorScheme;
    return ListView.builder(
      padding: EdgeInsets.only(bottom: miniPlayerBottom(context)),
      itemCount: artists.length,
      itemBuilder: (context, index) {
        final artist = artists[index];
        final cover = artist.topSong;
        if (cover == null) return const SizedBox.shrink();
        return ListTile(
          leading: SongArtwork(
            song: cover,
            dimension: 56,
            radius: 28,
            querySize: 150,
          ),
          title: Text(
            artist.displayName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            '${artist.songs.length} songs • ${artist.albumCount} albums',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: Icon(Icons.chevron_right_rounded, color: scheme.outline),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => SongListScreen(
                title: artist.displayName,
                subtitle: '${artist.songs.length} songs',
                songs: artist.songs,
                cover: cover,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _FavoritesTab extends ConsumerWidget {
  const _FavoritesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final songs = ref.watch(favoriteSongsProvider);
    if (songs.isEmpty) {
      return const _Message(
        'Nothing here yet.\nTap the heart on Now playing, or use the\nsong menu to add favourites.',
      );
    }

    return ListView.builder(
      padding: EdgeInsets.only(bottom: miniPlayerBottom(context)),
      itemExtent: kSongTileExtent,
      itemCount: songs.length,
      itemBuilder: (context, index) =>
          SongTile(song: songs[index], songs: songs, index: index),
    );
  }
}

class _DownloadsTab extends ConsumerWidget {
  const _DownloadsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final songs = ref.watch(downloadsProvider).songs;
    if (songs.isEmpty) {
      return const _Message(
        'Songs you download from YouTube\nwill collect here for offline play.',
      );
    }
    return ListView.builder(
      padding: EdgeInsets.only(bottom: miniPlayerBottom(context)),
      itemExtent: kSongTileExtent,
      itemCount: songs.length,
      itemBuilder: (context, index) =>
          SongTile(song: songs[index], songs: songs, index: index),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontSize: 15,
            height: 1.5,
          ),
        ),
      ),
    );
  }
}

class _PermissionRequest extends StatelessWidget {
  const _PermissionRequest({required this.onGrant});

  final VoidCallback onGrant;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.library_music_outlined, size: 56, color: scheme.outline),
            const SizedBox(height: 20),
            const Text(
              'Allow access to your music',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            Text(
              'Tunefrost needs permission to read the audio files stored on this '
              'device. Nothing leaves your phone.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: scheme.onSurfaceVariant,
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(onPressed: onGrant, child: const Text('Grant access')),
            const SizedBox(height: 8),
            TextButton(
              onPressed: openAppSettings,
              child: const Text('Open app settings'),
            ),
          ],
        ),
      ),
    );
  }
}

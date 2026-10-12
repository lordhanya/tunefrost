import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:music_player/core/utils/format.dart';
import 'package:music_player/core/utils/haptics.dart';
import 'package:music_player/core/widgets/alphabet_scrollbar.dart';
import 'package:music_player/core/widgets/glass.dart';

import '../../library/widgets/song_actions_sheet.dart';
import '../../library/widgets/song_tile.dart';
import '../../playback/providers/playback_providers.dart';
import '../../playback/widgets/mini_player.dart';
import '../providers/playlist_providers.dart';

/// Songs of one playlist: play, reorder by dragging rows, per-row menu.
class PlaylistDetailScreen extends ConsumerStatefulWidget {
  const PlaylistDetailScreen({super.key, required this.playlistId});

  final String playlistId;

  @override
  ConsumerState<PlaylistDetailScreen> createState() =>
      _PlaylistDetailScreenState();
}

class _PlaylistDetailScreenState extends ConsumerState<PlaylistDetailScreen> {
  /// Shared with the A–Z rail so it can follow and drive the list's scroll.
  /// `ReorderableListView` takes no controller, so the list picks it up
  /// through `PrimaryScrollController`.
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final playlists = ref.watch(playlistsProvider).value ?? const [];
    final playlist = playlists
        .where((p) => p.id == widget.playlistId)
        .firstOrNull;
    final songsAsync = ref.watch(playlistSongsProvider(widget.playlistId));
    final scheme = Theme.of(context).colorScheme;
    final topInset = MediaQuery.paddingOf(context).top + kToolbarHeight;

    if (playlist == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: Text(
            'Playlist not found',
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
        ),
      );
    }

    return Scaffold(
      extendBody: true,
      extendBodyBehindAppBar: true,
      appBar: glassAppBar(
        context,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(playlist.name),
        actions: songsAsync.maybeWhen(
          data: (songs) => songs.isEmpty
              ? null
              : [
                  IconButton(
                    icon: const Icon(Icons.shuffle_rounded),
                    tooltip: 'Shuffle play',
                    onPressed: () =>
                        ref.read(audioPlayerProvider).shuffleAll(songs),
                  ),
                  IconButton(
                    icon: const Icon(Icons.play_arrow_rounded),
                    tooltip: 'Play all',
                    onPressed: () =>
                        ref.read(audioPlayerProvider).playAll(songs),
                  ),
                ],
          orElse: () => null,
        ),
      ),
      body: songsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text(error.toString())),
        data: (songs) {
          if (songs.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  'No songs yet.\nLong-press a song in your library '
                  'to add it.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontSize: 15,
                  ),
                ),
              ),
            );
          }
          final labels = songs
              .map((song) {
                final trimmed = song.title.trim();
                if (trimmed.isEmpty) return '#';
                final c = trimmed[0].toUpperCase();
                final code = c.codeUnitAt(0);
                return code >= 65 && code <= 90 ? c : '#';
              })
              .toList(growable: false);
          final topPadding = topInset + 16;
          return Stack(
            children: [
              PrimaryScrollController(
                controller: _scrollController,
                child: ReorderableListView.builder(
                  padding: EdgeInsets.only(
                    top: topPadding,
                    bottom: miniPlayerBottom(context),
                  ),
                  itemCount: songs.length,
                  onReorderItem: (from, to) {
                    context.hapticLight();
                    ref
                        .read(playlistsProvider.notifier)
                        .moveSong(widget.playlistId, from, to);
                  },
                  itemBuilder: (context, index) {
                    final song = songs[index];
                    return SizedBox(
                      height: kSongTileExtent,
                      child: SongTile(
                        key: ValueKey(
                          'pl-${widget.playlistId}-${song.id}-$index',
                        ),
                        song: song,
                        songs: songs,
                        index: index,
                        showActions: false,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              formatDuration(song.duration),
                              style: TextStyle(
                                color: scheme.onSurfaceVariant,
                                fontSize: 12,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.more_horiz_rounded,
                                size: 20,
                              ),
                              color: scheme.onSurfaceVariant,
                              visualDensity: VisualDensity.compact,
                              onPressed: () {
                                context.hapticLight();
                                showSongActionsSheet(
                                  context,
                                  ref,
                                  song: song,
                                  playlistId: widget.playlistId,
                                  playlistIndex: index,
                                );
                              },
                            ),
                            ReorderableDragStartListener(
                              index: index,
                              child: Icon(
                                Icons.drag_indicator_rounded,
                                size: 20,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              if (songs.length >= 20 && AlphabetScrollbar.isSorted(labels))
                Positioned(
                  right: 0,
                  top: topInset + 8,
                  bottom: 8,
                  child: AlphabetScrollbar(
                    controller: _scrollController,
                    labels: labels,
                    itemExtent: kSongTileExtent,
                    topPadding: topPadding,
                  ),
                ),
            ],
          );
        },
      ),
      bottomNavigationBar: const MiniPlayer(),
    );
  }
}

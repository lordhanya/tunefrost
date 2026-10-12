import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:music_player/core/models/song.dart';
import 'package:music_player/core/utils/haptics.dart';
import 'package:music_player/core/widgets/glass.dart';

import '../playback/providers/playback_providers.dart';
import '../playback/widgets/mini_player.dart';
import '../playback/widgets/song_artwork.dart';
import 'widgets/song_tile.dart';

/// Album and artist drill-down: cover and play actions above the track list.
class SongListScreen extends StatelessWidget {
  const SongListScreen({
    super.key,
    required this.title,
    required this.songs,
    required this.cover,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final List<Song> songs;

  /// Song whose artwork anchors the header; always one of [songs].
  final Song cover;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final topInset = MediaQuery.paddingOf(context).top + kToolbarHeight;

    return Scaffold(
      extendBody: true,
      extendBodyBehindAppBar: true,
      appBar: glassAppBar(
        context,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w500),
            ),
            if (subtitle != null)
              Text(
                subtitle!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
              ),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: ListView.builder(
        padding: EdgeInsets.only(
          top: topInset,
          bottom: miniPlayerBottom(context),
        ),
        // No fixed itemExtent: the header is taller than a row, so each tile
        // carries its own height instead.
        itemCount: songs.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) return _CoverHeader(cover: cover, songs: songs);
          final i = index - 1;
          return SizedBox(
            height: kSongTileExtent,
            child: SongTile(song: songs[i], songs: songs, index: i),
          );
        },
      ),
      bottomNavigationBar: const MiniPlayer(),
    );
  }
}

/// The cover plus the two things you do with a track list: play it or shuffle it.
class _CoverHeader extends ConsumerWidget {
  const _CoverHeader({required this.cover, required this.songs});

  final Song cover;
  final List<Song> songs;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final player = ref.read(audioPlayerProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
      child: Column(
        children: [
          SongArtwork(song: cover, dimension: 200, radius: 14, querySize: 500),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('Play all'),
                onPressed: () {
                  context.hapticMedium();
                  player.playAll(songs);
                },
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.shuffle_rounded),
                label: const Text('Shuffle'),
                onPressed: () {
                  context.hapticMedium();
                  player.shuffleAll(songs);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

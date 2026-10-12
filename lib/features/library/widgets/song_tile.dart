import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:music_player/app/transitions.dart';
import 'package:music_player/core/models/song.dart';
import 'package:music_player/core/utils/format.dart';
import 'package:music_player/core/utils/haptics.dart';

import '../../playback/providers/playback_providers.dart';
import '../../playback/widgets/song_artwork.dart';
import 'song_actions_sheet.dart';

/// Uniform row height for song lists — matches two-line ListTile and keeps
/// the A-Z index rail's scroll math exact.
const double kSongTileExtent = 72;

/// One row in the song lists: artwork, title/artist, duration.
/// Tap plays it (or opens Now Playing when it is already current);
/// long press opens the queue/playlist actions sheet.
class SongTile extends ConsumerWidget {
  const SongTile({
    super.key,
    required this.song,
    required this.songs,
    required this.index,
    this.trailing,
    this.showActions = true,
  });

  final Song song;
  final List<Song> songs;
  final int index;

  /// Replaces the default duration label (used by playlist rows).
  final Widget? trailing;

  /// Set false in reorderable lists where long press starts a drag.
  final bool showActions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isCurrent = ref.watch(currentSongProvider)?.id == song.id;
    final scheme = Theme.of(context).colorScheme;

    return ListTile(
      leading: Hero(
        tag: 'artwork-${song.id}',
        child: SongArtwork(song: song, dimension: 44, querySize: 120),
      ),
      title: Text(
        song.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: isCurrent ? scheme.primary : scheme.onSurface),
      ),
      subtitle: Text(
        song.artist,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
      ),
      trailing:
          trailing ??
          Text(
            formatDuration(song.duration),
            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
          ),
      onTap: () {
        context.hapticSelect();
        if (isCurrent) {
          openNowPlaying(context);
        } else {
          ref.read(audioPlayerProvider).playAll(songs, startIndex: index);
        }
      },
      onLongPress: showActions
          ? () {
              context.hapticHeavy();
              showSongActionsSheet(context, ref, song: song);
            }
          : null,
    );
  }
}

/// Stands in for the duration when a list is ordered by play count.
class PlayCountLabel extends StatelessWidget {
  const PlayCountLabel(this.count, {super.key});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Text(
      formatPlayCount(count),
      style: TextStyle(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        fontSize: 12,
      ),
    );
  }
}

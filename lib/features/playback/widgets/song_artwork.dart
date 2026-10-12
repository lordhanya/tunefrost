import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:music_player/core/models/song.dart';

import '../providers/playback_providers.dart';

/// Square album artwork with a palette-consistent placeholder while the
/// art is loading or missing.
///
/// Streamed songs carry a remote thumbnail instead of a MediaStore id, so
/// they load over the network instead of querying the media store.
class SongArtwork extends ConsumerWidget {
  const SongArtwork({
    super.key,
    required this.song,
    required this.dimension,
    this.radius = 6,
    this.querySize = 200,
  });

  final Song song;

  /// Layout size of the square, in logical pixels.
  final double dimension;
  final double radius;

  /// Pixel size requested from the media store (small = fast).
  final int querySize;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bytes = ref.watch(songArtworkProvider((song.id, querySize))).value;
    final artwork = song.artworkPath;
    // Remote thumbnails load over the network, including for downloads that
    // kept the YouTube thumbnail even though they now play from a file.
    final url = (song.isRemote || artwork?.startsWith('http') == true)
        ? artwork
        : null;

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox.square(
        dimension: dimension,
        child: url != null && url.isNotEmpty
            ? Image.network(
                url,
                fit: BoxFit.cover,
                gaplessPlayback: true,
                errorBuilder: (_, _, _) =>
                    _ArtworkPlaceholder(dimension: dimension),
              )
            : bytes != null
            ? Image.memory(bytes, fit: BoxFit.cover, gaplessPlayback: true)
            : _ArtworkPlaceholder(dimension: dimension),
      ),
    );
  }
}

/// Neutral note glyph on a themed plate — shown while art loads or is absent.
class _ArtworkPlaceholder extends StatelessWidget {
  const _ArtworkPlaceholder({required this.dimension});

  final double dimension;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ColoredBox(
      color: scheme.surfaceContainerHighest,
      child: Center(
        // A fixed share of the plate, so a tile and a full-screen cover both
        // read as "artwork missing" rather than a speck or a full bleed.
        child: Icon(
          Icons.music_note_rounded,
          size: dimension * 0.45,
          color: scheme.outline,
        ),
      ),
    );
  }
}

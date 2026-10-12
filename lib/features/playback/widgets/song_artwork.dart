import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:music_player/core/models/song.dart';

import '../providers/playback_providers.dart';

/// Bundled cover art for songs that have none of their own.
const _defaultArtworkAsset = 'assets/thumbnail/default_thumbnail.png';

/// Square album artwork.
///
/// Streamed songs carry a remote thumbnail instead of a MediaStore id, so they
/// load over the network instead of querying the media store. Anything with no
/// art of its own — local song with no embedded cover, or a thumbnail that
/// fails to load — falls back to the bundled default cover; the neutral note
/// plate is used only while the media store is still being queried.
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
    final art = ref.watch(songArtworkProvider((song.id, querySize)));
    final bytes = art.value;
    final artwork = song.artworkPath;
    // Remote thumbnails load over the network, including for downloads that
    // kept the YouTube thumbnail even though they now play from a file.
    final url = (song.isRemote || artwork?.startsWith('http') == true)
        ? artwork
        : null;

    final Widget image;
    if (url != null && url.isNotEmpty) {
      image = Image.network(
        url,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        // A thumbnail that fails to load is indistinguishable from one that
        // was never there.
        errorBuilder: (_, _, _) => _DefaultArtwork(dimension: dimension),
      );
    } else if (bytes != null) {
      image = Image.memory(bytes, fit: BoxFit.cover, gaplessPlayback: true);
    } else if (art.isLoading) {
      // Still asking the media store: stay neutral rather than flash the
      // "no thumbnail" cover in front of art that is about to arrive.
      image = _ArtworkPlaceholder(dimension: dimension);
    } else {
      image = _DefaultArtwork(dimension: dimension);
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox.square(dimension: dimension, child: image),
    );
  }
}

/// Bundled cover shown to songs that have no artwork of their own.
///
/// The master is far larger than any artwork slot, so it is decoded at the
/// size it is actually drawn at — a 44px tile never needs the full bitmap.
class _DefaultArtwork extends StatelessWidget {
  const _DefaultArtwork({required this.dimension});

  final double dimension;

  @override
  Widget build(BuildContext context) {
    final pixels = (dimension * MediaQuery.devicePixelRatioOf(context)).round();
    return Image.asset(
      _defaultArtworkAsset,
      fit: BoxFit.cover,
      gaplessPlayback: true,
      cacheWidth: pixels > 0 ? pixels : null,
    );
  }
}

/// Neutral note glyph on a themed plate — shown only while artwork is still
/// being resolved, so a song that does have art never flashes the default
/// cover first.
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

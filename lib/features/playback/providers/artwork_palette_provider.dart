import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:palette_generator/palette_generator.dart';

import 'package:music_player/core/models/song.dart';
import 'playback_providers.dart';

/// Ambient colors extracted from a song's artwork, tuned for a subtle glow.
///
/// Only the dominant / vibrant / muted tones are kept — never the full
/// rainbow of the cover — so the effect stays minimal and readable.
class ArtworkPalette {
  const ArtworkPalette({
    required this.dominantColor,
    required this.vibrantColor,
    required this.mutedColor,
    required this.isLight,
  });

  final Color dominantColor;
  final Color vibrantColor;
  final Color mutedColor;
  final bool isLight;

  /// The best single color for a subtle ambient glow.
  ///
  /// Prefers vibrant when it sits in a readable mid-tone range, otherwise
  /// falls back to dominant so the glow never washes out the UI.
  Color get glowColor {
    final vibrant = vibrantColor;
    final lum = vibrant.computeLuminance();
    if (lum > 0.18 && lum < 0.82) return vibrant;
    return dominantColor;
  }
}

/// Extracts a trimmed palette from [song]'s artwork.
///
/// Remote thumbnails load over the network; local artwork is read from the
/// media store via [songArtworkProvider]; anything else falls back to the
/// bundled default cover. Extraction failures degrade gracefully to null.
final artworkPaletteProvider =
    FutureProvider.autoDispose.family<ArtworkPalette?, Song>((ref, song) async {
  final artwork = song.artworkPath;
  final isRemote = song.isRemote || (artwork?.startsWith('http') == true);

  ImageProvider? imageProvider;

  if (isRemote && artwork != null && artwork.isNotEmpty) {
    imageProvider = NetworkImage(artwork);
  } else {
    final songId = int.tryParse(song.id);
    if (songId != null) {
      final fetched = await ref.read(
        songArtworkProvider((song.id, 400)).future,
      );
      if (fetched is Uint8List && fetched.isNotEmpty) {
        imageProvider = MemoryImage(fetched);
      }
    }
    imageProvider ??= const AssetImage(
      'assets/thumbnail/default_thumbnail.png',
    );
  }

  try {
    final palette = await PaletteGenerator.fromImageProvider(
      imageProvider,
      maximumColorCount: 16,
      size: const Size(400, 400),
    );

    final dominant = palette.dominantColor?.color ?? Colors.grey;
    final vibrant = palette.vibrantColor?.color ?? dominant;
    final muted = palette.mutedColor?.color ?? dominant;

    return ArtworkPalette(
      dominantColor: dominant,
      vibrantColor: vibrant,
      mutedColor: muted,
      isLight: dominant.computeLuminance() > 0.5,
    );
  } catch (_) {
    return null;
  }
});

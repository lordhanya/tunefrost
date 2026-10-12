import 'package:collection/collection.dart';
import 'package:music_player/core/models/song.dart';

/// An artist derived from the device's song list (grouped by the artist tag).
class Artist {
  const Artist({required this.name, required this.songs});

  final String name;
  final List<Song> songs;

  static const _unknownArtist = 'Unknown artist';

  String get displayName => name.trim().isEmpty ? _unknownArtist : name.trim();

  Song? get topSong => songs.firstOrNull;

  /// Distinct album tags across this artist's songs.
  int get albumCount => songs.map((s) => s.album.trim()).toSet().length;

  /// Groups [songs] by artist and sorts them by display name ('#' first).
  static List<Artist> group(List<Song> songs) {
    final index = <String, List<Song>>{};
    for (final song in songs) {
      (index[song.artist] ??= []).add(song);
    }
    final artists = index.entries
        .map((e) => Artist(name: e.key, songs: e.value))
        .toList();
    artists.sort((a, b) {
      final aName = a.name.trim();
      final bName = b.name.trim();
      if (aName.isEmpty) return bName.isEmpty ? 0 : -1;
      if (bName.isEmpty) return 1;
      return aName.toLowerCase().compareTo(bName.toLowerCase());
    });
    return artists;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Artist && other.name == name;

  @override
  int get hashCode => name.hashCode;
}

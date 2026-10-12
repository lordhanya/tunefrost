import 'package:collection/collection.dart';
import 'package:music_player/core/models/song.dart';

/// An album derived from the device's song list (grouped by album + artist).
class Album {
  const Album({required this.name, required this.artist, required this.songs});

  /// Raw album tag as written in the file metadata. May be empty.
  final String name;
  final String artist;
  final List<Song> songs;

  static const _unknownAlbum = 'Unknown album';
  static const _unknownArtist = 'Unknown artist';

  String get displayName => name.trim().isEmpty ? _unknownAlbum : name.trim();

  String get displayArtist =>
      artist.trim().isEmpty ? _unknownArtist : artist.trim();

  Song? get firstSong => songs.firstOrNull;

  /// Groups [songs] by album name + artist, preserving the order in which the
  /// albums first appear.
  static List<Album> group(List<Song> songs) {
    final index = <(String, String), List<Song>>{};
    for (final song in songs) {
      (index[(song.album, song.artist)] ??= []).add(song);
    }
    return index.entries
        .map((e) => Album(name: e.key.$1, artist: e.key.$2, songs: e.value))
        .toList();
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Album && other.name == name && other.artist == artist;

  @override
  int get hashCode => Object.hash(name, artist);
}

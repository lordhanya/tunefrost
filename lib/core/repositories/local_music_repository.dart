import 'package:music_player/core/models/song.dart';
import 'package:music_player/core/repositories/music_repository.dart';
import 'package:on_audio_query_pluse/on_audio_query.dart';

class LocalMusicRepository implements MusicRepository {
  final OnAudioQuery _audioQuery = OnAudioQuery();

  @override
  Future<List<Song>> getSongs() async {
    final songs = await _audioQuery.querySongs();
    return songs.map(_mapSong).toList();
  }

  @override
  Future<List<Song>> searchSongs(String query) async {
    final songs = await _audioQuery.querySongs();
    return songs
        .where((song) => _matchesSearch(song, query))
        .map(_mapSong)
        .toList();
  }

  bool _matchesSearch(SongModel song, String query) {
    final lowerQuery = query.toLowerCase();
    return song.title.toLowerCase().contains(lowerQuery) ||
        _artistContains(song.artist, lowerQuery) ||
        _albumContains(song.album, lowerQuery);
  }

  bool _artistContains(String? artist, String lowerQuery) {
    if (artist == null) return false;
    return artist.toLowerCase().contains(lowerQuery);
  }

  bool _albumContains(String? album, String lowerQuery) {
    if (album == null) return false;
    return album.toLowerCase().contains(lowerQuery);
  }

  Song _mapSong(SongModel song) {
    return Song(
      id: song.id.toString(),
      title: song.title,
      artist: song.artist ?? 'Unknown Artist',
      album: song.album ?? 'Unknown Album',
      durationMs: song.duration ?? 0,
      filePath: song.data,
      contentUri: song.uri,
      dateAdded: switch (song.dateAdded) {
        final seconds? when seconds > 0 => DateTime.fromMillisecondsSinceEpoch(
          seconds * 1000,
        ),
        _ => null,
      },
    );
  }
}

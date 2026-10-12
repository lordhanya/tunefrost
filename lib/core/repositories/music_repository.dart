import 'package:music_player/core/models/song.dart';

abstract class MusicRepository {
  Future<List<Song>> getSongs();

  Future<List<Song>> searchSongs(String query);
}

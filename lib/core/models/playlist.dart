import 'package:music_player/core/models/song.dart';

class Playlist {
  final String id;
  final String name;
  final List<Song> songs;
  final DateTime createdAt;

  const Playlist({
    required this.id,
    required this.name,
    required this.songs,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'songs': [for (final song in songs) song.toJson()],
    'createdAt': createdAt.millisecondsSinceEpoch,
  };

  factory Playlist.fromJson(Map<String, dynamic> json) => Playlist(
    id: json['id'] as String,
    name: json['name'] as String,
    songs:
        (json['songs'] as List<dynamic>?)
            ?.map((e) => Song.fromJson(e as Map<String, dynamic>))
            .toList() ??
        const [],
    createdAt: DateTime.fromMillisecondsSinceEpoch(
      json['createdAt'] as int? ?? 0,
    ),
  );
}

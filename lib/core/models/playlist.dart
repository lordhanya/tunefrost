class Playlist {
  final String id;
  final String name;
  final List<String> songIds;
  final DateTime createdAt;

  const Playlist({
    required this.id,
    required this.name,
    required this.songIds,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'songIds': songIds,
    'createdAt': createdAt.millisecondsSinceEpoch,
  };

  factory Playlist.fromJson(Map<String, dynamic> json) => Playlist(
    id: json['id'] as String,
    name: json['name'] as String,
    songIds:
        (json['songIds'] as List<dynamic>?)?.map((e) => e as String).toList() ??
        const [],
    createdAt: DateTime.fromMillisecondsSinceEpoch(
      json['createdAt'] as int? ?? 0,
    ),
  );
}

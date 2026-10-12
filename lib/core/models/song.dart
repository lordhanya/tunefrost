class Song {
  final String id;
  final String title;
  final String artist;
  final String album;
  final int durationMs;

  /// Absolute path to the file; null for streamed songs.
  final String? filePath;

  /// MediaStore content URI (e.g. `content://media/external/audio/media/42`).
  /// On Android this must be used for playback: raw file paths to shared
  /// storage are blocked by scoped storage even with the media permission.
  final String? contentUri;

  /// Platform video id (e.g. `dQw4w9WgXcQ`); null for local files.
  final String? videoId;

  /// Local artwork path, or a thumbnail URL for streamed songs.
  final String? artworkPath;

  final DateTime? dateAdded;

  /// How many times this song has actually been heard. The media store has no
  /// play-count column, so the app counts it itself; it is not part of the
  /// JSON snapshot because the queue only needs playback state.
  final int playCount;

  const Song({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    required this.durationMs,
    this.filePath,
    this.contentUri,
    this.videoId,
    this.artworkPath,
    this.dateAdded,
    this.playCount = 0,
  });

  /// Builds a streamed song shaped exactly like a local one, so the queue,
  /// lock-screen controls and every list screen work unchanged.
  factory Song.remote({
    required String videoId,
    required String title,
    required String artist,
    required int durationMs,
    String album = '',
    String? artworkPath,
  }) => Song(
    id: remoteId(videoId),
    videoId: videoId,
    title: title,
    artist: artist,
    album: album,
    durationMs: durationMs,
    artworkPath: artworkPath,
  );

  /// Namespaced id so a video id can never collide with a MediaStore id.
  static String remoteId(String videoId) => 'yt:$videoId';

  /// A streamed song saved to app storage. It plays from [filePath] exactly
  /// like a local file — [videoId] is deliberately null so the queue never
  /// resolves it again — while the original upload id stays addressable
  /// through [sourceVideoId] for "download again" dialogs.
  factory Song.download({
    required String videoId,
    required String title,
    required String artist,
    required String album,
    required int durationMs,
    required String filePath,
    String? artworkUrl,
    DateTime? dateAdded,
  }) => Song(
    id: downloadId(videoId),
    videoId: null,
    title: title,
    artist: artist,
    album: album,
    durationMs: durationMs,
    filePath: filePath,
    artworkPath: artworkUrl,
    dateAdded: dateAdded,
  );

  /// Namespaced id so a download can never collide with the streamed copy.
  static String downloadId(String videoId) => 'dl:$videoId';

  /// Whether this song is a locally saved copy of a YouTube upload.
  bool get isDownload => id.startsWith('dl:');

  /// The YouTube upload this song was downloaded from, when available.
  String? get sourceVideoId => isDownload ? id.substring(3) : videoId;

  /// A copy with a different [playCount] — the only field that is derived at
  /// runtime rather than read from the file or the media store.
  Song copyWith({int? playCount}) => Song(
    id: id,
    title: title,
    artist: artist,
    album: album,
    durationMs: durationMs,
    filePath: filePath,
    contentUri: contentUri,
    videoId: videoId,
    artworkPath: artworkPath,
    dateAdded: dateAdded,
    playCount: playCount ?? this.playCount,
  );

  bool get isRemote => videoId != null;

  Duration get duration => Duration(milliseconds: durationMs);

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'artist': artist,
    'album': album,
    'durationMs': durationMs,
    'filePath': filePath,
    'contentUri': contentUri,
    'videoId': videoId,
    'artworkPath': artworkPath,
    'dateAdded': dateAdded?.millisecondsSinceEpoch,
  };

  factory Song.fromJson(Map<String, dynamic> json) => Song(
    id: json['id'] as String,
    title: json['title'] as String,
    artist: json['artist'] as String,
    album: json['album'] as String,
    durationMs: (json['durationMs'] as num?)?.toInt() ?? 0,
    filePath: json['filePath'] as String?,
    contentUri: json['contentUri'] as String?,
    videoId: json['videoId'] as String?,
    artworkPath: json['artworkPath'] as String?,
    dateAdded: json['dateAdded'] == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(json['dateAdded'] as int),
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Song && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Song($id, "$title")';
}

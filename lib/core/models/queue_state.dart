import 'package:flutter/foundation.dart';

import 'package:music_player/core/models/song.dart';

enum ShuffleMode { off, all }

enum RepeatMode { off, all, one }

enum PlaybackState { stopped, playing, paused, buffering, completed }

/// Immutable snapshot of the playback queue and transport status.
///
/// Playback position and duration intentionally live outside this class —
/// they change several times a second and would rebuild every listener.
class QueueState {
  final List<Song> queue;
  final int currentIndex;
  final ShuffleMode shuffleMode;
  final RepeatMode repeatMode;
  final PlaybackState playbackState;

  /// Playback speed multiplier (1.0 is normal).
  final double speed;

  const QueueState({
    this.queue = const [],
    this.currentIndex = 0,
    this.shuffleMode = ShuffleMode.off,
    this.repeatMode = RepeatMode.off,
    this.playbackState = PlaybackState.stopped,
    this.speed = 1.0,
  });

  QueueState copyWith({
    List<Song>? queue,
    int? currentIndex,
    ShuffleMode? shuffleMode,
    RepeatMode? repeatMode,
    PlaybackState? playbackState,
    double? speed,
  }) => QueueState(
    queue: queue ?? this.queue,
    currentIndex: currentIndex ?? this.currentIndex,
    shuffleMode: shuffleMode ?? this.shuffleMode,
    repeatMode: repeatMode ?? this.repeatMode,
    playbackState: playbackState ?? this.playbackState,
    speed: speed ?? this.speed,
  );

  bool get isEmpty => queue.isEmpty;
  Song? get currentSong =>
      queue.isEmpty || currentIndex < 0 || currentIndex >= queue.length
      ? null
      : queue[currentIndex];

  bool get hasNext => currentIndex < queue.length - 1;
  bool get hasPrevious => currentIndex > 0;

  Song? get nextSong => hasNext ? queue[currentIndex + 1] : null;
  Song? get previousSong => hasPrevious ? queue[currentIndex - 1] : null;

  Map<String, dynamic> toJson() => {
    'queue': queue.map((s) => s.toJson()).toList(),
    'currentIndex': currentIndex,
    'shuffleMode': shuffleMode.name,
    'repeatMode': repeatMode.name,
    'speed': speed,
  };

  factory QueueState.fromJson(Map<String, dynamic> json) {
    final queue = (json['queue'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(Song.fromJson)
        .toList();

    // A snapshot can outlive the queue it describes (e.g. a trim during an
    // upgrade), so clamp instead of trusting the stored index.
    final stored = json['currentIndex'] as int? ?? 0;
    final currentIndex = queue.isEmpty ? 0 : stored.clamp(0, queue.length - 1);

    return QueueState(
      queue: queue,
      currentIndex: currentIndex,
      shuffleMode:
          ShuffleMode.values.asNameMap()[json['shuffleMode']] ??
          ShuffleMode.off,
      repeatMode:
          RepeatMode.values.asNameMap()[json['repeatMode']] ?? RepeatMode.off,
      speed: (json['speed'] as num?)?.toDouble() ?? 1.0,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is QueueState &&
          other.currentIndex == currentIndex &&
          other.shuffleMode == shuffleMode &&
          other.repeatMode == repeatMode &&
          other.playbackState == playbackState &&
          other.speed == speed &&
          listEquals(other.queue, queue);

  @override
  int get hashCode => Object.hash(
    currentIndex,
    shuffleMode,
    repeatMode,
    playbackState,
    speed,
    Object.hashAll(queue),
  );
}

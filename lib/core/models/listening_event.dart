/// One finished stint of listening: what was heard, for how long, and whether
/// it ran to the end or was abandoned early.
///
/// Deliberately a plain value type. The rules that decide *when* a listen
/// starts and ends live in `ListeningStintTracker`, and the aggregation lives
/// in `buildTasteProfile`, so both stay unit-testable without a player, a
/// stream or a disk.
class ListeningEvent {
  const ListeningEvent({
    required this.songId,
    required this.artist,
    required this.title,
    required this.album,
    required this.startedAtMs,
    required this.playedMs,
    required this.durationMs,
    required this.completed,
    required this.skippedEarly,
  });

  /// The song's own id, so local, streamed and downloaded copies stay distinct
  /// exactly as they do in the queue.
  final String songId;

  final String artist;
  final String title;
  final String album;

  /// Wall clock, milliseconds since epoch, when the stint began. Drives the
  /// recency decay in the taste profile.
  final int startedAtMs;

  /// Milliseconds actually heard. Tracked as a high-water mark, so seeking
  /// backwards can never deflate it and can never fabricate a completion.
  final int playedMs;

  /// Track length as reported by the player, or 0 when it never reported one.
  final int durationMs;

  /// Heard to the end — either the player said so, or the high-water mark
  /// finished within the tracker's completion grace.
  final bool completed;

  /// Abandoned before the early-skip threshold.
  final bool skippedEarly;

  /// Fraction of the track that was actually heard, clamped to 0..1.
  ///
  /// Returns 1 when completed and 0 when the length is unknown, so callers can
  /// score an event without ever dividing by zero.
  double get completion {
    if (durationMs <= 0) return completed ? 1 : 0;
    return (playedMs / durationMs).clamp(0.0, 1.0);
  }

  Map<String, dynamic> toJson() => {
    'songId': songId,
    'artist': artist,
    'title': title,
    'album': album,
    'startedAtMs': startedAtMs,
    'playedMs': playedMs,
    'durationMs': durationMs,
    'completed': completed,
    'skippedEarly': skippedEarly,
  };

  /// Tolerant reader: a field added by a later version is ignored, and one
  /// missing from an older file falls back to a usable default, so history
  /// written by either side still loads.
  factory ListeningEvent.fromJson(Map<String, dynamic> json) => ListeningEvent(
    songId: json['songId'] as String? ?? '',
    artist: json['artist'] as String? ?? '',
    title: json['title'] as String? ?? '',
    album: json['album'] as String? ?? '',
    startedAtMs: (json['startedAtMs'] as num?)?.toInt() ?? 0,
    playedMs: (json['playedMs'] as num?)?.toInt() ?? 0,
    durationMs: (json['durationMs'] as num?)?.toInt() ?? 0,
    completed: json['completed'] as bool? ?? false,
    skippedEarly: json['skippedEarly'] as bool? ?? false,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ListeningEvent &&
          other.songId == songId &&
          other.startedAtMs == startedAtMs &&
          other.playedMs == playedMs &&
          other.durationMs == durationMs &&
          other.completed == completed &&
          other.skippedEarly == skippedEarly;

  @override
  int get hashCode => Object.hash(
    songId,
    startedAtMs,
    playedMs,
    durationMs,
    completed,
    skippedEarly,
  );

  @override
  String toString() =>
      'ListeningEvent($songId, played ${playedMs}ms'
      ', completed: $completed, skipped: $skippedEarly)';
}

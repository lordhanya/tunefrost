/// Formats [duration] as `m:ss`, or `h:mm:ss` past an hour
/// (e.g. `0:42`, `3:07`, `1:02:05`).
String formatDuration(Duration duration) {
  final seconds = duration.inSeconds % 60;
  final twoDigits = seconds.toString().padLeft(2, '0');

  final hours = duration.inHours;
  if (hours > 0) {
    final minutes = (duration.inMinutes % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$twoDigits';
  }
  return '${duration.inMinutes}:$twoDigits';
}

/// Formats a playback speed multiplier as `1×`, `1.25×`, `0.75×`.
String formatSpeed(double speed) {
  final digits = speed == speed.roundToDouble()
      ? speed.toStringAsFixed(0)
      : speed.toString();
  return '$digits×';
}

/// Formats a play count as `1 play` or `12 plays`.
String formatPlayCount(int count) {
  final noun = count == 1 ? 'play' : 'plays';
  return '$count $noun';
}

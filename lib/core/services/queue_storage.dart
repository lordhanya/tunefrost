import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:music_player/core/models/queue_state.dart';

/// The queue plus the position to resume at.
typedef SavedPlayback = (QueueState, Duration);

/// Persists the playback queue so a cold start resumes where the listener
/// left off.
class QueueStorage {
  const QueueStorage(this._prefs);

  static const _key = 'queue_v1';

  final SharedPreferences _prefs;

  SavedPlayback? load() {
    final raw = _prefs.getString(_key);
    if (raw == null) return null;
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final state = QueueState.fromJson(json);
      if (state.isEmpty) return null;
      return (state, Duration(milliseconds: json['position'] as int? ?? 0));
    } catch (_) {
      // Corrupt snapshot: never let persistence block playback.
      return null;
    }
  }

  Future<void> save(QueueState state, Duration position) => _prefs.setString(
    _key,
    jsonEncode({...state.toJson(), 'position': position.inMilliseconds}),
  );
}

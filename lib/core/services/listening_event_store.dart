import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'package:music_player/core/models/listening_event.dart';

/// Persists Smart Play's listening history as one JSON document in the app
/// documents directory.
///
/// Writes are atomic — a temp file then a rename — so a crash mid-write can
/// never leave a half-written log behind, and the file is capped so it cannot
/// grow without bound. The reader is as forgiving as `QueueStorage`: a
/// missing, corrupt or unreadable file yields an empty history rather than an
/// exception.
class ListeningEventStore {
  ListeningEventStore({Future<Directory> Function()? directory})
    : _directory = directory ?? getApplicationDocumentsDirectory;

  static const fileName = 'listening_events.json';

  /// Newest this many entries are kept; the oldest fall off the end.
  static const maxEvents = 2000;

  /// Injected in tests so the store needs no platform channel.
  final Future<Directory> Function() _directory;

  Future<File> _file() async {
    final dir = await _directory();
    return File('${dir.path}/$fileName');
  }

  /// Newest first, matching the in-memory order the notifier keeps.
  Future<List<ListeningEvent>> load() async {
    try {
      final file = await _file();
      if (!await file.exists()) return const [];
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(ListeningEvent.fromJson)
          .where((event) => event.songId.isNotEmpty)
          .toList();
    } catch (_) {
      // Corrupt or unreadable: start over rather than crash the recorder.
      return const [];
    }
  }

  Future<void> save(List<ListeningEvent> events) async {
    final capped = events.length > maxEvents
        ? events.sublist(0, maxEvents)
        : events;
    final file = await _file();
    final tmp = File('${file.path}.tmp');
    await tmp.writeAsString(
      jsonEncode([for (final event in capped) event.toJson()]),
      flush: true,
    );
    await tmp.rename(file.path);
  }

  /// Removes the persisted history entirely. The in-memory copy is the
  /// notifier's responsibility to clear alongside this.
  Future<void> clear() async {
    try {
      final file = await _file();
      if (await file.exists()) await file.delete();
      final tmp = File('${file.path}.tmp');
      if (await tmp.exists()) await tmp.delete();
    } catch (_) {
      // Nothing left to delete is a success for our purposes.
    }
  }
}

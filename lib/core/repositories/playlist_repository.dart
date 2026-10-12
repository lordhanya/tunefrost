import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'package:music_player/core/models/playlist.dart';

/// Persists playlists as a single JSON document in the app documents
/// directory, written atomically (temp file + rename) so a crash mid-write
/// can never corrupt existing data.
class PlaylistRepository {
  Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/playlists.json');
  }

  Future<List<Playlist>> load() async {
    try {
      final file = await _file();
      if (!await file.exists()) return const [];
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(Playlist.fromJson)
          .toList();
    } catch (_) {
      // Corrupt or unreadable file: start fresh rather than crash.
      return const [];
    }
  }

  Future<void> save(List<Playlist> playlists) async {
    final file = await _file();
    final tmp = File('${file.path}.tmp');
    await tmp.writeAsString(
      jsonEncode(playlists.map((p) => p.toJson()).toList()),
      flush: true,
    );
    await tmp.rename(file.path);
  }
}

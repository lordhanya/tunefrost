import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:music_player/core/models/playlist.dart';
import 'package:music_player/core/models/song.dart';
import 'package:music_player/core/repositories/playlist_repository.dart';

final playlistRepositoryProvider = Provider<PlaylistRepository>(
  (ref) => PlaylistRepository(),
);

final playlistsProvider =
    AsyncNotifierProvider<PlaylistsNotifier, List<Playlist>>(
      PlaylistsNotifier.new,
    );

class PlaylistsNotifier extends AsyncNotifier<List<Playlist>> {
  @override
  Future<List<Playlist>> build() => ref.read(playlistRepositoryProvider).load();

  Future<void> _write(List<Playlist> playlists) async {
    state = AsyncData(playlists);
    await ref.read(playlistRepositoryProvider).save(playlists);
  }

  Future<Playlist> create(String name) async {
    final playlist = Playlist(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: name.trim(),
      songs: const [],
      createdAt: DateTime.now(),
    );
    await _write([playlist, ...?state.value]);
    return playlist;
  }

  Future<void> rename(String id, String name) async {
    final playlists = [...?state.value];
    final index = playlists.indexWhere((p) => p.id == id);
    if (index == -1 || name.trim().isEmpty) return;
    playlists[index] = Playlist(
      id: id,
      name: name.trim(),
      songs: playlists[index].songs,
      createdAt: playlists[index].createdAt,
    );
    await _write(playlists);
  }

  Future<void> delete(String id) async {
    final playlists = [...?state.value].where((p) => p.id != id).toList();
    await _write(playlists);
  }

  Future<void> addSongs(String id, List<Song> songs) async {
    final playlists = [...?state.value];
    final index = playlists.indexWhere((p) => p.id == id);
    if (index == -1 || songs.isEmpty) return;
    final existing = playlists[index].songs;
    final added = songs
        .where((s) => !existing.any((e) => e.id == s.id))
        .toList();
    if (added.isEmpty) return;
    playlists[index] = Playlist(
      id: id,
      name: playlists[index].name,
      songs: [...existing, ...added],
      createdAt: playlists[index].createdAt,
    );
    await _write(playlists);
  }

  Future<void> removeSong(String id, int songIndex) async {
    final playlists = [...?state.value];
    final index = playlists.indexWhere((p) => p.id == id);
    if (index == -1) return;
    final songs = [...playlists[index].songs];
    if (songIndex < 0 || songIndex >= songs.length) return;
    songs.removeAt(songIndex);
    playlists[index] = Playlist(
      id: id,
      name: playlists[index].name,
      songs: songs,
      createdAt: playlists[index].createdAt,
    );
    await _write(playlists);
  }

  Future<void> moveSong(String id, int from, int to) async {
    final playlists = [...?state.value];
    final index = playlists.indexWhere((p) => p.id == id);
    if (index == -1 || from == to) return;
    final songs = [...playlists[index].songs];
    if (from < 0 || to < 0 || from >= songs.length || to >= songs.length) {
      return;
    }
    final item = songs.removeAt(from);
    songs.insert(to, item);
    playlists[index] = Playlist(
      id: id,
      name: playlists[index].name,
      songs: songs,
      createdAt: playlists[index].createdAt,
    );
    await _write(playlists);
  }
}

/// Returns the songs of a playlist in their stored order.
final playlistSongsProvider = FutureProvider.family<List<Song>, String>((
  ref,
  playlistId,
) async {
  final playlists = await ref.watch(playlistsProvider.future);
  final playlist = playlists.firstWhereOrNull((p) => p.id == playlistId);
  if (playlist == null) return const [];
  return playlist.songs;
});

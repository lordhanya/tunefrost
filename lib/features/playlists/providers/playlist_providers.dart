import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:music_player/core/models/playlist.dart';
import 'package:music_player/core/models/song.dart';
import 'package:music_player/core/repositories/playlist_repository.dart';

import '../../library/providers/library_provider.dart';

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
      songIds: const [],
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
      songIds: playlists[index].songIds,
      createdAt: playlists[index].createdAt,
    );
    await _write(playlists);
  }

  Future<void> delete(String id) async {
    final playlists = [...?state.value].where((p) => p.id != id).toList();
    await _write(playlists);
  }

  Future<void> addSongs(String id, List<String> songIds) async {
    final playlists = [...?state.value];
    final index = playlists.indexWhere((p) => p.id == id);
    if (index == -1 || songIds.isEmpty) return;
    final existing = playlists[index].songIds;
    final added = songIds.where((s) => !existing.contains(s)).toList();
    if (added.isEmpty) return;
    playlists[index] = Playlist(
      id: id,
      name: playlists[index].name,
      songIds: [...existing, ...added],
      createdAt: playlists[index].createdAt,
    );
    await _write(playlists);
  }

  Future<void> removeSong(String id, int songIndex) async {
    final playlists = [...?state.value];
    final index = playlists.indexWhere((p) => p.id == id);
    if (index == -1) return;
    final ids = [...playlists[index].songIds];
    if (songIndex < 0 || songIndex >= ids.length) return;
    ids.removeAt(songIndex);
    playlists[index] = Playlist(
      id: id,
      name: playlists[index].name,
      songIds: ids,
      createdAt: playlists[index].createdAt,
    );
    await _write(playlists);
  }

  Future<void> moveSong(String id, int from, int to) async {
    final playlists = [...?state.value];
    final index = playlists.indexWhere((p) => p.id == id);
    if (index == -1 || from == to) return;
    final ids = [...playlists[index].songIds];
    if (from < 0 || to < 0 || from >= ids.length || to >= ids.length) return;
    final item = ids.removeAt(from);
    ids.insert(to, item);
    playlists[index] = Playlist(
      id: id,
      name: playlists[index].name,
      songIds: ids,
      createdAt: playlists[index].createdAt,
    );
    await _write(playlists);
  }
}

/// Resolves a playlist's song ids against the local library, preserving
/// playlist order. Songs no longer on the device are skipped.
final playlistSongsProvider = FutureProvider.family<List<Song>, String>((
  ref,
  playlistId,
) async {
  final playlists = await ref.watch(playlistsProvider.future);
  final library = await ref.watch(musicLibraryProvider.future);
  final playlist = playlists.firstWhereOrNull((p) => p.id == playlistId);
  if (playlist == null) return const [];
  final byId = {for (final song in library) song.id: song};
  return [
    for (final id in playlist.songIds)
      if (byId[id] != null) byId[id]!,
  ];
});

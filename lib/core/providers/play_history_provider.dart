import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:music_player/core/models/song.dart';
import 'package:music_player/core/providers/theme_provider.dart';

/// Favourite songs, newest first, stored as full snapshots so tracks the local
/// library cannot resolve — YouTube streams and downloads — survive a restart.
/// [favoriteSongsProvider] swaps in live library metadata where it can.
class FavoritesNotifier extends Notifier<List<Song>> {
  static const _key = 'favorite_songs';

  @override
  List<Song> build() {
    final raw = ref.read(sharedPreferencesProvider).getString(_key);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return [
        for (final entry in decoded)
          Song.fromJson(entry as Map<String, dynamic>),
      ];
    } catch (_) {
      return const []; // unreadable prefs start over clean
    }
  }

  Future<void> toggle(Song song) async {
    final next = List<Song>.of(state);
    final index = next.indexWhere((s) => s.id == song.id);
    if (index == -1) {
      next.insert(0, song);
    } else {
      next.removeAt(index);
    }
    state = next;
    await ref
        .read(sharedPreferencesProvider)
        .setString(_key, jsonEncode([for (final s in next) s.toJson()]));
  }
}

final favoritesProvider = NotifierProvider<FavoritesNotifier, List<Song>>(
  FavoritesNotifier.new,
);

/// Favourite ids, for cheap membership checks in the UI.
final favoriteIdsProvider = Provider<Set<String>>(
  (ref) => {for (final song in ref.watch(favoritesProvider)) song.id},
);

/// Song ids in the order they were last listened to, newest first.
class RecentPlayedNotifier extends Notifier<List<String>> {
  static const _key = 'recently_played_ids';

  /// Long enough to back a "recently played" view, short enough to read whole.
  static const _max = 60;

  @override
  List<String> build() => List.of(
    ref.read(sharedPreferencesProvider).getStringList(_key) ?? const [],
  );

  Future<void> markPlayed(String songId) async {
    state = [
      songId,
      ...state.where((id) => id != songId),
    ].take(_max).toList(growable: false);
    await ref.read(sharedPreferencesProvider).setStringList(_key, state);
  }
}

final recentPlayedProvider =
    NotifierProvider<RecentPlayedNotifier, List<String>>(
      RecentPlayedNotifier.new,
    );

/// Song id → how many times it has been played through. Feeds the
/// "Most played" sort, so it has to survive a restart.
class PlayCountsNotifier extends Notifier<Map<String, int>> {
  static const _key = 'play_counts';

  @override
  Map<String, int> build() {
    final raw = ref.read(sharedPreferencesProvider).getString(_key);
    if (raw == null || raw.isEmpty) return const <String, int>{};
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return {
        for (final entry in decoded.entries)
          if (entry.value is num) entry.key: (entry.value as num).toInt(),
      };
    } catch (_) {
      return const <String, int>{}; // unreadable prefs start over clean
    }
  }

  Future<void> increment(String songId) async {
    state = {...state, songId: (state[songId] ?? 0) + 1};
    await ref
        .read(sharedPreferencesProvider)
        .setString(_key, jsonEncode(state));
  }
}

final playCountsProvider =
    NotifierProvider<PlayCountsNotifier, Map<String, int>>(
      PlayCountsNotifier.new,
    );

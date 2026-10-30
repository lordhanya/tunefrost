import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:music_player/core/models/listening_event.dart';
import 'package:music_player/core/providers/play_history_provider.dart';
import 'package:music_player/core/services/listening_event_store.dart';
import 'package:music_player/core/taste/taste_profile.dart';

final listeningEventStoreProvider = Provider<ListeningEventStore>(
  (ref) => ListeningEventStore(),
);

/// Smart Play's listening history, newest first, capped at
/// [ListeningEventStore.maxEvents].
///
/// Disk writes are deliberately coalesced: a burst of skips costs one write,
/// not one per event, and a position tick never reaches the disk at all.
class ListeningEventsNotifier extends Notifier<List<ListeningEvent>> {
  /// Long enough to swallow a queue-skip burst, short enough that losing it to
  /// a force-quit is barely felt.
  static const _flushDelay = Duration(seconds: 2);

  late final ListeningEventStore _store;

  Timer? _flush;
  bool _dirty = false;
  Future<void>? _loading;

  @override
  List<ListeningEvent> build() {
    _store = ref.read(listeningEventStoreProvider);
    ref.onDispose(() {
      _flush?.cancel();
      _flush = null;
      if (!_dirty) return;
      _dirty = false;
      try {
        unawaited(_store.save(state));
      } catch (_) {
        // Torn down mid-write: a stray final event is not worth crashing for.
      }
    });
    return const [];
  }

  /// Brings in whatever previous runs recorded. Memoised, so callers can await
  /// it before recording without ever racing the load and losing an event.
  Future<void> load() => _loading ??= _store.load().then((stored) {
    if (stored.isNotEmpty) state = stored;
  });

  /// Prepends one finished listen and schedules a write.
  ///
  /// Consecutive entries for the same song are collapsed to avoid spamming
  /// history when a track loops (e.g. repeat-one) or restarts. A song that is
  /// played again after a different track still gets its own entry.
  Future<void> record(ListeningEvent event) async {
    await load();
    if (state.isNotEmpty && state.first.songId == event.songId) {
      // Same song as the most recent listen: treat as one session, don't
      // create a duplicate entry. Still flush pending writes.
      _scheduleFlush();
      return;
    }
    state = [event, ...state].take(ListeningEventStore.maxEvents).toList(
      growable: false,
    );
    _scheduleFlush();
  }

  /// Empties the in-memory history and the persisted file together, so the
  /// taste profile rebuilt from this state is correct on the next frame.
  Future<void> clear() async {
    _flush?.cancel();
    _flush = null;
    _dirty = false;
    state = const [];
    await _store.clear();
  }

  void _scheduleFlush() {
    _dirty = true;
    _flush ??= Timer(_flushDelay, () {
      _flush = null;
      if (!_dirty) return;
      _dirty = false;
      try {
        unawaited(_store.save(state));
      } catch (_) {
        // A transient write failure leaves history unwritten, not corrupt:
        // the next event simply schedules another attempt.
      }
    });
  }
}

final listeningEventsProvider =
    NotifierProvider<ListeningEventsNotifier, List<ListeningEvent>>(
      ListeningEventsNotifier.new,
    );

/// What Tunefrost knows about your listening, derived entirely on-device.
///
/// Rebuilds the moment a listen finalises and the moment history is cleared —
/// there is no cache to invalidate.
final tasteProfileProvider = Provider<TasteProfile>((ref) {
  return buildTasteProfile(
    events: ref.watch(listeningEventsProvider),
    favorites: ref.watch(favoritesProvider),
    playCounts: ref.watch(playCountsProvider),
    recentlyPlayed: ref.watch(recentPlayedProvider),
  );
});

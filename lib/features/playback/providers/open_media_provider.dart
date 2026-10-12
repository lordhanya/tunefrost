import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:music_player/core/models/song.dart';
import 'package:music_player/core/services/open_media_intent.dart';
import 'package:music_player/features/library/providers/library_provider.dart';

import 'playback_providers.dart';

/// The OS handoff channel, kept alive for the app's lifetime.
final openMediaIntentProvider = Provider<OpenMediaIntent>((ref) {
  final intent = OpenMediaIntent();
  ref.onDispose(intent.dispose);
  return intent;
});

/// Plays audio files handed over by the OS, on a cold start as well as while
/// the app is already running.
///
/// Watched once for the app's lifetime (see `MusicPlayerApp`), so it must not
/// be disposed while the app is alive.
final openMediaHandlerProvider = Provider<void>((ref) {
  final intent = ref.watch(openMediaIntentProvider);

  /// Guards against the same file being played twice: the launch URI can
  /// arrive through both [OpenMediaIntent.initialUri] and the event stream.
  final opened = <String>{};

  Future<void> play(String uri) async {
    if (uri.isEmpty || !opened.add(uri)) return;
    final library = await _library(ref);
    final song = _match(library, uri) ?? _fallback(uri);
    final player = ref.read(audioPlayerProvider);
    final index = library.indexWhere((candidate) => candidate.id == song.id);
    if (index >= 0) {
      // A file we already know: queue the library from there, exactly like
      // tapping its row.
      await player.playAll(library, startIndex: index);
    } else {
      await player.playAll([song]);
    }
  }

  final subscription = intent.uris.listen(play);
  ref.onDispose(subscription.cancel);

  unawaited(
    intent.initialUri().then((uri) {
      if (uri != null) return play(uri);
    }),
  );
});

/// The device library: the already-loaded snapshot when there is one, a fresh
/// query otherwise. Empty when media permission is missing or the query fails
/// — the file still plays, it just loses its rich metadata.
Future<List<Song>> _library(Ref ref) async {
  final cached = ref.read(musicLibraryProvider).value;
  if (cached != null) return cached;
  try {
    return await ref.read(musicRepositoryProvider).getSongs();
  } catch (_) {
    return const [];
  }
}

/// The media-store id at the end of a `content://` URI: `.../audio/media/42`
/// → `42`, which is the id a library [Song] carries.
String? _contentId(String uri) {
  if (!uri.startsWith('content://')) return null;
  final segments = Uri.tryParse(uri)?.pathSegments ?? const <String>[];
  if (segments.isEmpty) return null;
  final last = segments.last;
  return int.tryParse(last) == null ? null : last;
}

Song? _match(List<Song> library, String uri) {
  final id = _contentId(uri);
  for (final song in library) {
    if (song.contentUri == uri || (id != null && song.id == id)) return song;
  }
  return null;
}

/// A song for a URI the media store has not indexed into our snapshot yet.
/// Tags are thin, but it plays: the OS grants read access to a URI it handed
/// us, so no media permission is required to open it.
Song _fallback(String uri) {
  final segments = Uri.tryParse(uri)?.pathSegments ?? const <String>[];
  final name = segments.isEmpty ? '' : Uri.decodeComponent(segments.last);
  final title = name.replaceAll(RegExp(r'\.[A-Za-z0-9]+$'), '').trim();
  final isContent = uri.startsWith('content://');
  return Song(
    id: isContent ? 'file:$uri' : uri,
    title: title.isEmpty ? 'Unknown title' : title,
    artist: 'Unknown Artist',
    album: 'Unknown Album',
    durationMs: 0,
    filePath: isContent ? null : _filePath(uri),
    contentUri: isContent ? uri : null,
  );
}

String? _filePath(String uri) {
  if (uri.startsWith('file://')) return Uri.parse(uri).toFilePath();
  return uri; // a bare filesystem path
}

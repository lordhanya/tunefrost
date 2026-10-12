import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import 'package:music_player/audio/youtube_audio_source.dart';
import 'package:music_player/core/models/song.dart';

/// Thrown when an in-flight download is cancelled by the user.
class DownloadCancelledException implements Exception {
  const DownloadCancelledException();
  @override
  String toString() => 'Download cancelled.';
}

/// Saves a YouTube stream to app storage using the same byte-range chunking
/// (and the same live link-refresh on a dead CDN link) that playback uses,
/// so downloads are never capped by the encoder the way whole-file fetches are.
class DownloadService {
  DownloadService(this._resolver, this._prefs);

  final YouTubeStreamResolver _resolver;
  final SharedPreferences _prefs;

  static const _indexKey = 'mochi_downloads_v1';
  static const _chunk = 1 << 18; // 256 KiB — matches streaming chunk size

  static final HttpClient _http = HttpClient()..autoUncompress = false;

  Future<Directory> _directory() async {
    final base = await getApplicationDocumentsDirectory();
    final directory = Directory('${base.path}/mochi/downloads');
    if (!await directory.exists()) await directory.create(recursive: true);
    return directory;
  }

  /// The persisted list of finished downloads.
  List<Song> loadIndex() {
    final raw = _prefs.getString(_indexKey);
    if (raw == null) return const [];
    try {
      return (jsonDecode(raw) as List<dynamic>)
          .whereType<Map<String, dynamic>>()
          .map(Song.fromJson)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> saveIndex(List<Song> songs) => _prefs.setString(
    _indexKey,
    jsonEncode([for (final s in songs) s.toJson()]),
  );

  /// Removes the stored file for a finished download.
  Future<void> removeFile(Song download) async {
    final path = download.filePath;
    if (path == null) return;
    final file = File(path);
    if (await file.exists()) await file.delete();
  }

  /// Streams [song] to app storage, reporting fraction 0..1 via [onProgress].
  /// Aborts (and cleans up its partial file) when [isCancelled] turns true.
  /// Resolves with the absolute path of the saved file.
  Future<String> download(
    Song song, {
    void Function(double fraction)? onProgress,
    bool Function()? isCancelled,
  }) async {
    final videoId = song.videoId;
    if (videoId == null) throw ArgumentError('Only streamed songs download');

    final directory = await _directory();
    var stream = await _resolver.resolve(videoId);
    final target = File('${directory.path}/$videoId.${_extensionOf(stream)}');
    if (await target.exists()) {
      await target.delete();
    }

    final sink = target.openWrite();
    try {
      final length = stream.size.totalBytes;
      var position = 0;
      while (position < length) {
        if (isCancelled?.call() ?? false) {
          throw const DownloadCancelledException();
        }
        final end = math.min(position + _chunk, length);
        final (next, response) = await _request(videoId, stream, position, end);
        stream = next;
        await for (final chunk in response) {
          sink.add(chunk);
        }
        position = end;
        onProgress?.call(position / length);
      }
      await sink.flush();
    } catch (_) {
      await sink.close();
      if (await target.exists()) await target.delete();
      rethrow;
    }
    await sink.close();
    return target.path;
  }

  /// Fetches one chunk, transparently replacing a dead signed link with a
  /// freshly extracted one (kept to the same format so bytes stay aligned).
  Future<(AudioOnlyStreamInfo, HttpClientResponse)> _request(
    String videoId,
    AudioOnlyStreamInfo stream,
    int start,
    int end,
  ) async {
    HttpClientResponse response;
    try {
      response = await _get(stream.url, start, end);
    } catch (_) {
      stream = await _freshLink(videoId, stream);
      response = await _get(stream.url, start, end);
    }
    if (_ok(response.statusCode)) return (stream, response);

    await response.drain<void>();
    stream = await _freshLink(videoId, stream);
    response = await _get(stream.url, start, end);
    if (_ok(response.statusCode)) return (stream, response);

    await response.drain<void>();
    throw HttpException(
      'Stream request failed (${response.statusCode})',
      uri: stream.url,
    );
  }

  Future<AudioOnlyStreamInfo> _freshLink(
    String videoId,
    AudioOnlyStreamInfo previous,
  ) async {
    _resolver.invalidate(videoId);
    final fresh = await _resolver.resolve(videoId);
    // A different format mid-download would produce a corrupt file, so
    // refuse the substitute rather than save garbage.
    if (fresh.tag != previous.tag) throw const NoAudioStreamException();
    return fresh;
  }

  Future<HttpClientResponse> _get(Uri url, int start, int end) async {
    final request = await _http.getUrl(url);
    request.headers.set(HttpHeaders.rangeHeader, 'bytes=$start-${end - 1}');
    return request.close();
  }

  bool _ok(int status) =>
      status == HttpStatus.ok || status == HttpStatus.partialContent;

  /// Extension to save under; the bytes are the raw adaptive stream, so the
  /// extension just has to be honest about the container/codec.
  String _extensionOf(AudioOnlyStreamInfo stream) {
    final mime = stream.codec.mimeType;
    return switch (mime) {
      'audio/mp4' => 'm4a',
      'audio/webm' => 'webm',
      'audio/opus' || 'audio/x-opus' => 'opus',
      'audio/aac' => 'aac',
      _ => 'webm',
    };
  }
}

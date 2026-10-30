import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import 'package:music_player/audio/youtube_audio_source.dart';
import 'package:music_player/core/models/song.dart';
import 'package:music_player/core/providers/stream_quality_provider.dart';

/// Thrown when an in-flight download is cancelled by the user.
class DownloadCancelledException implements Exception {
  const DownloadCancelledException();
  @override
  String toString() => 'Download cancelled.';
}

/// Result of [DownloadService.download].
///
/// [playbackPath] is always an app-private filesystem path the file can be
/// played from offline. [safPath], when non-null, is the persisted SAF tree
/// URI of the user-chosen folder a user-visible copy was written to.
class DownloadResult {
  const DownloadResult({
    required this.playbackPath,
    this.safPath,
    this.safRequested = false,
    this.safWritten = false,
  });

  /// App-private path used for offline playback (`Uri.file(playbackPath)`).
  final String playbackPath;

  /// SAF tree URI of the user-chosen folder, or null when no SAF folder is in
  /// use / the copy could not be verified there.
  final String? safPath;

  /// Whether the user had chosen a SAF folder and a write to it was attempted.
  final bool safRequested;

  /// Whether the SAF copy was written and verified.
  final bool safWritten;
}

/// Thrown when the chosen SAF download folder cannot be written to.
class DownloadFolderException implements Exception {
  const DownloadFolderException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Saves a YouTube stream to user-chosen storage using the same byte-range
/// chunking (and the same live link-refresh on a dead CDN link) that playback
/// uses, so downloads are never capped by the encoder the way whole-file
/// fetches are.
///
/// On Android 13+ scoped storage blocks `dart:io` writes to user-picked
/// shared folders, so a user-chosen folder is accessed through the Storage
/// Access Framework (a persisted `content://` tree URI) via a native channel.
/// The file is always also kept in app-private storage so it remains playable
/// offline even if the SAF grant is later revoked.
class DownloadService {
  DownloadService(this._resolver, this._prefs);

  final YouTubeStreamResolver _resolver;
  final SharedPreferences _prefs;

  static const _indexKey = 'mochi_downloads_v1';
  static const _dirKey = 'mochi_downloads_dir';
  static const _chunk = 1 << 18; // 256 KiB — matches streaming chunk size

  static final HttpClient _http = HttpClient()
    ..autoUncompress = false
    ..connectionTimeout = const Duration(seconds: 15);

  /// Channel to the native SAF file operations in MainActivity.
  static const MethodChannel _safChannel = MethodChannel(
    'com.ashifcodes.music_player/saf',
  );

  /// The directory where downloads are stored, or null if not yet chosen.
  ///
  /// This is either an app-private filesystem path or a persisted SAF
  /// `content://` tree URI returned by the folder picker.
  String? get downloadDirectory => _prefs.getString(_dirKey);

  /// Sets the directory where future downloads will be stored.
  Future<void> setDownloadDirectory(String path) async {
    await _prefs.setString(_dirKey, path);
  }

  /// Clears the stored download directory so the user is re-prompted.
  Future<void> clearDownloadDirectory() async {
    await _prefs.remove(_dirKey);
  }

  Future<Directory> _appDownloadDir() async {
    final base = await getApplicationDocumentsDirectory();
    final directory = Directory('${base.path}/mochi/downloads');
    if (!await directory.exists().timeout(const Duration(seconds: 5))) {
      await directory.create(recursive: true).timeout(const Duration(seconds: 5));
    }
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

  /// Removes the stored file for a finished download: the app-private playback
  /// copy and, when a SAF copy was made, that copy too.
  Future<void> removeFile(Song download) async {
    final path = download.filePath;
    if (path != null) {
      final file = File(path);
      if (await file.exists()) await file.delete();
    }
    if (download.safPath != null && download.filePath != null) {
      final fileName = download.filePath!.split('/').last;
      try {
        await _safDelete(download.safPath!, fileName);
      } catch (_) {
        // Best effort: the app-private copy is already gone.
      }
    }
  }

  /// Streams [song] to app storage, then (when a SAF folder is chosen) to the
  /// user's chosen folder, reporting fraction 0..1 via [onProgress].
  ///
  /// Aborts (and cleans up its partial file) when [isCancelled] turns true.
  /// Resolves with a [DownloadResult]: [playbackPath] is always an app-private
  /// path playable offline; [safPath]/[safWritten] describe the user-visible
  /// copy in the chosen SAF folder.
  Future<DownloadResult> download(
    Song song, {
    void Function(double fraction)? onProgress,
    bool Function()? isCancelled,
    StreamQuality quality = StreamQuality.high,
  }) async {
    final videoId = song.videoId;
    if (videoId == null) throw ArgumentError('Only streamed songs download');

    // Always keep an app-private playback copy so downloads play offline.
    final appDir = await _appDownloadDir().timeout(const Duration(seconds: 15));

    // Stream chunks to a temp file first (dart:io preserves streaming,
    // progress reporting and cancellation).
    final tempDir = await getTemporaryDirectory();
    final tempFile = File('${tempDir.path}/tunefrost_dl_$videoId.tmp');

    var stream = await _resolver.resolve(videoId, quality: quality);
    final length = stream.size.totalBytes;
    if (length <= 0) {
      try { await tempFile.delete(); } catch (_) {}
      throw HttpException('Stream reported empty size', uri: stream.url);
    }

    final sink = tempFile.openWrite();
    try {
      var position = 0;
      while (position < length) {
        if (isCancelled?.call() ?? false) {
          throw const DownloadCancelledException();
        }
        final end = math.min(position + _chunk, length);
        final (next, response) = await _request(
          videoId,
          stream,
          position,
          end,
          quality: quality,
        );
        stream = next;
        await for (final chunk in response.timeout(
          const Duration(seconds: 60),
        )) {
          if (isCancelled?.call() ?? false) {
            throw const DownloadCancelledException();
          }
          sink.add(chunk);
        }
        position = end;
        onProgress?.call(position / length);
      }
      await sink.flush().timeout(const Duration(seconds: 30));
    } catch (_) {
      try {
        await sink.close().timeout(const Duration(seconds: 5));
      } catch (_) {}
      try { await tempFile.delete(); } catch (_) {}
      rethrow;
    }
    await sink.close().timeout(const Duration(seconds: 10));

    final extension = _extensionOf(stream);
    final fileName = '$videoId.$extension';

    // Permanent app-private playback copy.
    final playbackPath = '${appDir.path}/$fileName';
    await tempFile.copy(playbackPath).timeout(const Duration(seconds: 30));
    try { await tempFile.delete(); } catch (_) {}

    // When the user chose a SAF folder, write a user-visible copy there and
    // verify it actually landed. This is never silent: if the write fails the
    // caller learns via [safRequested]/[safWritten].
    String? safPath;
    bool safRequested = false;
    bool safWritten = false;
    final dir = downloadDirectory;
    if (dir != null && dir.startsWith('content://')) {
      safRequested = true;
      try {
        await _safCopyFile(playbackPath, dir, fileName);
        final exists = await _safExists(dir, fileName);
        if (!exists) {
          throw Exception('SAF copy could not be verified');
        }
        safPath = dir;
        safWritten = true;
      } catch (e) {
        // Keep the app-private playback copy; the caller is told the SAF
        // folder write failed so it can inform the user instead of staying
        // silent.
        safPath = null;
        safWritten = false;
      }
    }

    return DownloadResult(
      playbackPath: playbackPath,
      safPath: safPath,
      safRequested: safRequested,
      safWritten: safWritten,
    );
  }

  /// Copies [localPath] into the SAF tree as [fileName] via the native channel.
  Future<void> _safCopyFile(String localPath, String treeUri, String fileName) async {
    await _safChannel.invokeMethod<void>('safCopyFile', {
      'treeUri': treeUri,
      'tempPath': localPath,
      'fileName': fileName,
    });
  }

  /// Whether [fileName] exists in the SAF tree.
  Future<bool> _safExists(String treeUri, String fileName) async {
    final result = await _safChannel.invokeMethod<bool>('safExists', {
      'treeUri': treeUri,
      'fileName': fileName,
    });
    return result ?? false;
  }

  /// Deletes [fileName] from the SAF tree if present.
  Future<void> _safDelete(String treeUri, String fileName) async {
    await _safChannel.invokeMethod<void>('safDelete', {
      'treeUri': treeUri,
      'fileName': fileName,
    });
  }

  /// Fetches one chunk, transparently replacing a dead signed link with a
  /// freshly extracted one (kept to the same format so bytes stay aligned).
  Future<(AudioOnlyStreamInfo, HttpClientResponse)> _request(
    String videoId,
    AudioOnlyStreamInfo stream,
    int start,
    int end, {
    StreamQuality quality = StreamQuality.high,
  }) async {
    HttpClientResponse response;
    try {
      response = await _get(stream.url, start, end);
    } catch (_) {
      stream = await _freshLink(videoId, stream, quality: quality);
      response = await _get(stream.url, start, end);
    }
    if (_ok(response.statusCode)) return (stream, response);

    await response.drain<void>().timeout(const Duration(seconds: 30));
    stream = await _freshLink(videoId, stream, quality: quality);
    response = await _get(stream.url, start, end);
    if (_ok(response.statusCode)) return (stream, response);

    await response.drain<void>().timeout(const Duration(seconds: 30));
    throw HttpException(
      'Stream request failed (${response.statusCode})',
      uri: stream.url,
    );
  }

  Future<AudioOnlyStreamInfo> _freshLink(
    String videoId,
    AudioOnlyStreamInfo previous, {
    StreamQuality quality = StreamQuality.high,
  }) async {
    _resolver.invalidate(videoId);
    final fresh = await _resolver.resolve(videoId, quality: quality);
    // A different format mid-download would produce a corrupt file, so
    // refuse the substitute rather than save garbage.
    if (fresh.tag != previous.tag) throw const NoAudioStreamException();
    return fresh;
  }

  Future<HttpClientResponse> _get(Uri url, int start, int end) async {
    final request = await _http
        .getUrl(url)
        .timeout(const Duration(seconds: 15));
    request.headers.set(HttpHeaders.rangeHeader, 'bytes=$start-${end - 1}');
    return request.close().timeout(const Duration(seconds: 15));
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

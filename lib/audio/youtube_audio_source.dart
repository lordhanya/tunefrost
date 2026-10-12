// StreamAudioSource is still marked experimental upstream, but it is the only
// extension point just_audio exposes for byte-range backed sources.
// ignore_for_file: experimental_member_use

import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

/// Thrown when a video exposes no audio-only adaptive stream.
class NoAudioStreamException implements Exception {
  const NoAudioStreamException();
  @override
  String toString() => 'This video has no playable audio stream.';
}

/// visionOS player client (from yt-dlp's profile): the CDN serves the same
/// audio without the ~1 MiB streaming cap applied to the Android clients.
final _visionOs = YoutubeApiClient({
  'context': {
    'client': {
      'clientName': 'VISIONOS',
      'clientVersion': '1.02',
      'deviceMake': 'Apple',
      'deviceModel': 'RealityDevice17,1',
      'userAgent':
          'Mozilla/5.0 (Macintosh; Intel Mac OS X 15_7_3) AppleWebKit/605.1.15 '
          '(KHTML, like Gecko) Version/26.0 Safari/605.1.15',
      'osName': 'visionOS',
      'osVersion': '26.5.23O471',
    },
  },
}, 'https://www.youtube.com/youtubei/v1/player?prettyPrint=false');

/// Resolves the highest-bitrate audio-only stream of a video and hands it to
/// [just_audio].
///
/// Only the audio track is requested, which is why playback here carries no
/// ads: ad insertion happens in the YouTube player, not on the media stream.
/// Resolution runs in a background isolate so a track switch never blocks the
/// UI thread, and the signed result is cached until its `expire` timestamp.
class YouTubeStreamResolver {
  const YouTubeStreamResolver(this._cache);

  final StreamLinkCache _cache;

  Future<AudioOnlyStreamInfo> resolve(String videoId) async {
    final cached = _cache.get(videoId);
    if (cached != null) return cached;
    // toJson() keeps live objects (VideoId, FileSize, …) in the map, which
    // fromJson refuses; crossing the isolate as JSON text flattens them.
    final stream = AudioOnlyStreamInfo.fromJson(
      jsonDecode(await _extract(videoId)) as Map<String, dynamic>,
    );
    await _cache.put(videoId, stream);
    return stream;
  }

  static Future<String> _extract(String videoId) =>
      Isolate.run(() => _extractManifest(videoId));

  /// Forgets the cached link for [videoId]; the next resolve starts over.
  void invalidate(String videoId) => _cache.remove(videoId);

  static Future<String> _extractManifest(String videoId) async {
    final youtube = YoutubeExplode();
    try {
      // visionOS signs uncapped stream URLs; androidSdkless backs it up for
      // videos the library cannot resolve with visionOS.
      final manifest = await youtube.videos.streams.getManifest(
        videoId,
        ytClients: [_visionOs, YoutubeApiClient.androidSdkless],
        requireWatchPage: true,
      );
      // sortByBitrate() is descending despite its doc comment, so first is
      // the highest bitrate (the library's own pickers read `.first`).
      final streams = manifest.audioOnly.sortByBitrate();
      final best = streams.firstOrNull;
      if (best == null) throw const NoAudioStreamException();
      return jsonEncode(best.toJson());
    } finally {
      youtube.close();
    }
  }
}

/// Stores resolved stream metadata keyed by video id, expiring it when the
/// signed CDN url does (roughly six hours).
class StreamLinkCache {
  const StreamLinkCache(this._prefs);

  static const _prefix = 'yt_stream_v2_';

  final SharedPreferences _prefs;

  AudioOnlyStreamInfo? get(String videoId) {
    final raw = _prefs.getString('$_prefix$videoId');
    if (raw == null) return null;
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final expires = json['expires'] as int? ?? 0;
      if (expires <= DateTime.now().millisecondsSinceEpoch ~/ 1000) return null;
      return AudioOnlyStreamInfo.fromJson(
        json['stream'] as Map<String, dynamic>,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> put(String videoId, AudioOnlyStreamInfo stream) {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final expires =
        int.tryParse(stream.url.queryParameters['expire'] ?? '') ??
        now + 5 * 3600;
    return _prefs.setString(
      '$_prefix$videoId',
      jsonEncode({'expires': expires, 'stream': stream.toJson()}),
    );
  }

  /// Drops a link YouTube stopped honouring (revoked early, or expired) so
  /// the next play extracts a fresh one instead of reusing a dead URL.
  void remove(String videoId) => _prefs.remove('$_prefix$videoId');
}

/// Streams the resolved audio bytes to just_audio, honouring HTTP range
/// requests so seeking does not re-download the file.
///
/// googlevideo refuses to serve the whole file in a single range request and
/// caps or revokes signed links after heavy use, so the requested span is
/// fetched in small bounded chunks instead. A dead link is dropped and a
/// fresh one extracted on the fly before re-reading the chunk.
class YouTubeAudioSource extends StreamAudioSource {
  YouTubeAudioSource({
    required this.videoId,
    required this.resolver,
    super.tag,
  });

  final String videoId;
  final YouTubeStreamResolver resolver;

  static final _http = HttpClient()..autoUncompress = false;

  /// Chunk size for upstream range requests: big enough to be efficient,
  /// small enough to stay under googlevideo's per-request limit.
  static const _chunk = 1 << 18; // 256 KiB

  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    final stream = await resolver.resolve(videoId);
    final length = stream.size.totalBytes;

    start ??= 0;
    end = end == null || end > length ? length : end;

    return StreamAudioResponse(
      sourceLength: length,
      contentLength: end - start,
      offset: start,
      stream: _ranged(stream, start, end),
      contentType: stream.codec.mimeType,
    );
  }

  Stream<List<int>> _ranged(
    AudioOnlyStreamInfo stream,
    int start,
    int end,
  ) async* {
    var pos = start;
    while (pos < end) {
      final chunkEnd = math.min(pos + _chunk, end);
      final (next, response) = await _requestChunk(stream, pos, chunkEnd);
      stream = next;
      yield* response;
      pos = chunkEnd;
    }
  }

  /// Fetches one chunk, transparently replacing a dead signed link with a
  /// freshly extracted one (kept to the same format so bytes stay aligned).
  Future<(AudioOnlyStreamInfo, HttpClientResponse)> _requestChunk(
    AudioOnlyStreamInfo stream,
    int start,
    int end,
  ) async {
    HttpClientResponse response;
    try {
      response = await _get(stream.url, start, end);
    } catch (_) {
      stream = await _freshLink(stream);
      response = await _get(stream.url, start, end);
    }
    if (_isOk(response.statusCode)) return (stream, response);

    await response.drain<void>();
    stream = await _freshLink(stream);
    response = await _get(stream.url, start, end);
    if (_isOk(response.statusCode)) return (stream, response);

    await response.drain<void>();
    if (kDebugMode) {
      debugPrint('yt stream failed (${response.statusCode}), link refreshed');
    }
    throw HttpException(
      'Stream request failed (${response.statusCode})',
      uri: stream.url,
    );
  }

  Future<AudioOnlyStreamInfo> _freshLink(AudioOnlyStreamInfo previous) async {
    resolver.invalidate(videoId);
    final fresh = await resolver.resolve(videoId);
    // A different format mid-stream would corrupt the audio, so refuse it.
    if (fresh.tag != previous.tag) throw const NoAudioStreamException();
    if (kDebugMode) debugPrint('yt stream link refreshed on the fly');
    return fresh;
  }

  Future<HttpClientResponse> _get(Uri url, int start, int end) async {
    final request = await _http.getUrl(url);
    request.headers.set(HttpHeaders.rangeHeader, 'bytes=$start-${end - 1}');
    return request.close();
  }

  bool _isOk(int status) =>
      status == HttpStatus.ok || status == HttpStatus.partialContent;
}

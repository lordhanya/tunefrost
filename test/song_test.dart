import 'package:flutter_test/flutter_test.dart';
import 'package:music_player/core/models/song.dart';

Song _local({String id = '1', String title = 'Song'}) => Song(
  id: id,
  title: title,
  artist: 'Artist',
  album: 'Album',
  durationMs: 180000,
  filePath: '/music/a.mp3',
  contentUri: 'content://media/external/audio/media/1',
  dateAdded: DateTime.fromMillisecondsSinceEpoch(1700000000000),
);

void main() {
  group('Song', () {
    test('round-trips local metadata through json', () {
      final song = _local();
      final restored = Song.fromJson(song.toJson());

      expect(restored, song);
      expect(restored.title, song.title);
      expect(restored.filePath, song.filePath);
      expect(restored.contentUri, song.contentUri);
      expect(restored.dateAdded, song.dateAdded);
      expect(restored.isRemote, isFalse);
    });

    test('round-trips streamed metadata through json', () {
      final song = Song.remote(
        videoId: 'dQw4w9WgXcQ',
        title: 'Never Gonna Give You Up',
        artist: 'Rick Astley',
        durationMs: 213000,
        artworkPath: 'https://i.ytimg.com/vi/dQw4w9WgXcQ/hqdefault.jpg',
      );

      final restored = Song.fromJson(song.toJson());

      expect(restored, song);
      expect(restored.videoId, 'dQw4w9WgXcQ');
      expect(restored.isRemote, isTrue);
      expect(restored.filePath, isNull);
      expect(restored.artworkPath, song.artworkPath);
    });

    test('namespaced remote ids cannot collide with media store ids', () {
      expect(Song.remoteId('42'), 'yt:42');
      expect(Song.remoteId('42') == _local(id: '42').id, isFalse);
    });

    test('equality follows the id only', () {
      expect(_local(), _local(title: 'Different'));
      expect(_local(id: '1'), isNot(_local(id: '2')));
    });

    test('copyWith replaces only the play count', () {
      final song = _local().copyWith(playCount: 7);

      expect(song.playCount, 7);
      expect(song.title, 'Song');
      expect(song.filePath, '/music/a.mp3');
      expect(
        song.dateAdded,
        DateTime.fromMillisecondsSinceEpoch(1700000000000),
      );
      expect(song, _local()); // identity still rides on the id
      expect(
        song.copyWith().playCount,
        7,
      ); // nothing to replace, nothing changes
    });

    test('tolerates a snapshot missing optional fields', () {
      final restored = Song.fromJson(const {
        'id': '7',
        'title': 'Bare',
        'artist': 'Someone',
        'album': '',
        'durationMs': 1000,
      });

      expect(restored.filePath, isNull);
      expect(restored.videoId, isNull);
      expect(restored.dateAdded, isNull);
      expect(restored.duration, const Duration(seconds: 1));
    });
  });
}

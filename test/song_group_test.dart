import 'package:flutter_test/flutter_test.dart';
import 'package:music_player/core/models/album.dart';
import 'package:music_player/core/models/artist.dart';
import 'package:music_player/core/models/song.dart';

Song _song({required String title, String artist = 'A', String album = 'L'}) =>
    Song(
      id: title,
      title: title,
      artist: artist,
      album: album,
      durationMs: 1000,
    );

void main() {
  group('Album.group', () {
    test('groups by album and artist together', () {
      final albums = Album.group([
        _song(title: '1', album: 'Keep', artist: 'X'),
        _song(title: '2', album: 'Keep', artist: 'X'),
        _song(title: '3', album: 'Keep', artist: 'Y'),
        _song(title: '4', album: 'Other', artist: 'X'),
      ]);

      expect(albums, hasLength(3));
      final keep = albums.singleWhere(
        (a) => a.name == 'Keep' && a.artist == 'X',
      );
      expect(keep.songs.map((s) => s.id), ['1', '2']);
    });

    test('labels empty tags as unknown', () {
      final album = Album.group([_song(title: '1', album: '   ', artist: '')])
          .single;

      expect(album.displayName, 'Unknown album');
      expect(album.displayArtist, 'Unknown artist');
    });
  });

  group('Artist.group', () {
    test('sorts alphabetically and counts albums', () {
      final artists = Artist.group([
        _song(title: '1', artist: 'beta', album: 'L1'),
        _song(title: '2', artist: 'Alpha', album: 'L2'),
        _song(title: '3', artist: 'Alpha', album: 'L2'),
        _song(title: '4', artist: '   '),
        _song(title: '5', artist: 'beta', album: 'L3'),
      ]);

      expect(artists.map((a) => a.displayName), [
        'Unknown artist',
        'Alpha',
        'beta',
      ]);
      expect(artists[1].albumCount, 1);
      expect(artists[2].albumCount, 2);
    });

    test('topSong is the first song grouped', () {
      final artist = Artist.group([
        _song(title: 'first'),
        _song(title: 'second'),
      ]).single;

      expect(artist.topSong?.title, 'first');
    });
  });
}

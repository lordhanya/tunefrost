import 'package:flutter_test/flutter_test.dart';
import 'package:music_player/core/models/song.dart';
import 'package:music_player/features/library/providers/library_provider.dart';

Song _song({
  required String id,
  required String title,
  String artist = '',
  String album = '',
  int durationMs = 0,
  int playCount = 0,
  DateTime? dateAdded,
}) => Song(
  id: id,
  title: title,
  artist: artist,
  album: album,
  durationMs: durationMs,
  playCount: playCount,
  dateAdded: dateAdded,
);

List<Song> _sorted(List<Song> songs, LibrarySort sort) =>
    [...songs]..sort((a, b) => compareSongs(a, b, sort));

void main() {
  final songs = [
    _song(
      id: '1',
      title: 'Beta',
      artist: 'zebra',
      album: 'Sea',
      durationMs: 90,
    ),
    _song(
      id: '2',
      title: 'alpha',
      artist: 'Ant',
      album: 'Air',
      durationMs: 300,
      dateAdded: DateTime.fromMillisecondsSinceEpoch(2000),
    ),
    _song(id: '3', title: 'Alpha', artist: 'Ant', album: 'Air', durationMs: 60),
    _song(
      id: '4',
      title: 'Gamma',
      artist: 'Ant',
      album: 'Sea',
      dateAdded: DateTime.fromMillisecondsSinceEpoch(1000),
    ),
  ];

  group('compareSongs', () {
    test('title is case-insensitive and falls back to id', () {
      expect(_sorted(songs, LibrarySort.title).map((s) => s.id), [
        '2',
        '3',
        '1',
        '4',
      ]);
    });

    test('artist groups equal artists by title', () {
      expect(_sorted(songs, LibrarySort.artist).map((s) => s.id), [
        '2',
        '3',
        '4',
        '1',
      ]);
    });

    test('album groups equal albums by title', () {
      expect(_sorted(songs, LibrarySort.album).map((s) => s.id), [
        '2',
        '3',
        '1',
        '4',
      ]);
    });

    test('newest additions come first', () {
      expect(_sorted(songs, LibrarySort.dateAdded).map((s) => s.id), [
        '2',
        '4',
        '3',
        '1', // missing dateAdded sorts last
      ]);
    });

    test('longest tracks come first', () {
      expect(_sorted(songs, LibrarySort.duration).map((s) => s.id), [
        '2',
        '1',
        '3',
        '4',
      ]);
    });

    test('most played comes first, ties fall back to title', () {
      final played = [
        _song(id: '1', title: 'Beta', playCount: 3),
        _song(id: '2', title: 'alpha', playCount: 12),
        _song(id: '3', title: 'Alpha', playCount: 3),
        _song(id: '4', title: 'Gamma'),
      ];
      expect(_sorted(played, LibrarySort.playCount).map((s) => s.id), [
        '2', // 12 plays
        '3', // 3 plays, "Alpha" before "Beta"
        '1',
        '4', // never played, so last
      ]);
    });
  });

  test('every sort key is labelled', () {
    for (final sort in LibrarySort.values) {
      expect(sort.label, isNotEmpty);
    }
  });

  test('leading articles are stripped: "The Warning" sorts under W', () {
    final songs = [
      _song(id: '1', title: 'The Warning'),
      _song(id: '2', title: 'A Day to Remember'),
      _song(id: '3', title: 'Wonderful Life'),
    ];
    expect(_sorted(songs, LibrarySort.title).map((s) => s.id), [
      '2', // a day …
      '1', // the warning (w) — before "Wonderful" (w) by the next letter
      '3', // wonderful
    ]);
  });

  test('numeric titles compare naturally: Song 2 before Song 10', () {
    final songs = [
      _song(id: '1', title: 'Song 10'),
      _song(id: '2', title: 'Song 9'),
      _song(id: '3', title: 'Song 2'),
    ];
    expect(_sorted(songs, LibrarySort.title).map((s) => s.id), [
      '3', // song 2
      '2', // song 9
      '1', // song 10
    ]);
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:music_player/core/models/listening_event.dart';
import 'package:music_player/core/models/song.dart';
import 'package:music_player/core/taste/listening_stint_tracker.dart';
import 'package:music_player/core/taste/taste_profile.dart';

const _dayMs = 24 * 60 * 60 * 1000;

/// A point in time comfortably after every event these tests write.
const _now = 1000 + 400 * _dayMs;

ListeningEvent _event({
  required String songId,
  required String artist,
  int startedAtMs = 1000,
  int playedMs = 120000,
  int durationMs = 120000,
  bool completed = true,
  bool skippedEarly = false,
}) => ListeningEvent(
  songId: songId,
  artist: artist,
  title: 'Title $songId',
  album: 'Album',
  startedAtMs: startedAtMs,
  playedMs: playedMs,
  durationMs: durationMs,
  completed: completed,
  skippedEarly: skippedEarly,
);

Song _favorite(String id, String artist) => Song(
  id: id,
  title: 'Title $id',
  artist: artist,
  album: 'Album',
  durationMs: 1,
);

TasteProfile _build({
  List<ListeningEvent> events = const [],
  List<Song> favorites = const [],
  Map<String, int> playCounts = const {},
  List<String> recentlyPlayed = const [],
  Map<String, String> artistBySongId = const {},
}) => buildTasteProfile(
  events: events,
  favorites: favorites,
  playCounts: playCounts,
  recentlyPlayed: recentlyPlayed,
  artistBySongId: artistBySongId,
  nowMs: _now,
);

void main() {
  group('ListeningEvent.completion', () {
    test('never divides by zero when the length is unknown', () {
      final unheard = _event(
        songId: 'a',
        artist: 'A',
        durationMs: 0,
        completed: false,
        playedMs: 0,
      );
      final finished = _event(
        songId: 'a',
        artist: 'A',
        durationMs: 0,
        completed: true,
        playedMs: 0,
      );

      expect(unheard.completion, 0);
      expect(finished.completion, 1);
    });

    test('clamps a played time beyond the length', () {
      final event = _event(
        songId: 'a',
        artist: 'A',
        durationMs: 10000,
        playedMs: 999999,
      );

      expect(event.completion, 1);
    });
  });

  group('isUsableArtistName', () {
    test('rejects placeholders and anything that is not an artist', () {
      final unusable = [
        '',
        '   ',
        'Unknown Artist',
        ' UNKNOWN ARTIST ',
        '<unknown>',
        'unknown',
        'Various Artists',
        'va',
        'Tunefrost',
        'http://free-mp3.site/artist',
        'https://free-mp3.site/artist',
        'www.site.com',
        'a' * 61,
      ];

      for (final name in unusable) {
        expect(isUsableArtistName(name), isFalse, reason: '"$name"');
      }
    });

    test('accepts ordinary artist names', () {
      final usable = [
        'P!nk',
        'AC/DC',
        'Florence + The Machine',
        'blink-182',
        'A.R. Rahman',
        'Madonna',
        '  Radiohead  ',
      ];

      for (final name in usable) {
        expect(isUsableArtistName(name), isTrue, reason: '"$name"');
      }
    });
  });

  group('buildTasteProfile', () {
    test('is empty for empty inputs rather than throwing', () {
      final profile = _build();

      expect(profile.isEmpty, isTrue);
      expect(profile.artistAffinity, isEmpty);
      expect(profile.songAffinity, isEmpty);
      expect(profile.blockedIds, isEmpty);
      expect(profile.seedArtists, isEmpty);
    });

    test('does not raise an artist on abandoned tracks', () {
      final profile = _build(
        events: [
          _event(
            songId: 's',
            artist: 'Skipper',
            playedMs: 3000,
            completed: false,
            skippedEarly: true,
          ),
        ],
      );

      expect(profile.artistAffinity['Skipper']!, lessThanOrEqualTo(0));
      expect(profile.seedArtists, isNot(contains('Skipper')));
    });

    test('rises with the number of finished listens', () {
      final profile = _build(
        events: [
          _event(songId: 'a1', artist: 'A'),
          _event(songId: 'a2', artist: 'A'),
          _event(songId: 'a3', artist: 'A'),
          _event(songId: 'b1', artist: 'B'),
        ],
      );

      expect(profile.artistAffinity['A'], closeTo(1.0, 1e-9));
      expect(profile.artistAffinity['B'], closeTo(1 / 3, 1e-9));
      expect(profile.seedArtists.first, 'A');
      expect(profile.seedArtists.last, 'B');
    });

    test('one early skip cannot outweigh several finished listens', () {
      final profile = _build(
        events: [
          _event(songId: 's1', artist: 'A'),
          _event(songId: 's2', artist: 'A'),
          _event(songId: 's3', artist: 'A'),
          _event(
            songId: 's4',
            artist: 'A',
            playedMs: 2000,
            completed: false,
            skippedEarly: true,
          ),
        ],
      );

      expect(profile.artistAffinity['A']!, greaterThan(0));
      expect(profile.seedArtists, contains('A'));
    });

    test('favourites lift an artist with no listening history at all', () {
      final profile = _build(favorites: [_favorite('f', 'Fav')]);

      expect(profile.artistAffinity['Fav'], closeTo(1.0, 1e-9));
      expect(profile.songAffinity['f'], closeTo(1.0, 1e-9));
      expect(profile.seedArtists, contains('Fav'));
    });

    test('a favourite still outweighs an abandoned track', () {
      final profile = _build(
        events: [
          _event(
            songId: 's',
            artist: 'Starter',
            playedMs: 3000,
            completed: false,
            skippedEarly: true,
          ),
        ],
        favorites: [_favorite('f', 'Fav')],
      );

      // The favourite sets the scale, so the abandoned track lands at
      // -0.5 / 3.0 — still clearly negative, just not amplified.
      expect(profile.artistAffinity['Fav'], closeTo(1.0, 1e-9));
      expect(profile.artistAffinity['Starter'], lessThan(0));
      expect(
        profile.artistAffinity['Starter']!.abs(),
        lessThan(profile.artistAffinity['Fav']!),
      );
    });

    test('keeps every affinity inside -1..1', () {
      final profile = _build(
        events: [
          _event(songId: 's1', artist: 'A'),
          _event(songId: 's2', artist: 'B'),
          _event(
            songId: 's3',
            artist: 'C',
            playedMs: 1000,
            completed: false,
            skippedEarly: true,
          ),
        ],
        favorites: [_favorite('f', 'A')],
      );

      for (final value in profile.artistAffinity.values) {
        expect(value, inInclusiveRange(-1.0, 1.0));
      }
      for (final value in profile.songAffinity.values) {
        expect(value, inInclusiveRange(-1.0, 1.0));
      }
    });

    test('decays an older listen to half its weight', () {
      final profile = _build(
        events: [
          _event(songId: 'new', artist: 'Fresh', startedAtMs: _now),
          _event(
            songId: 'old',
            artist: 'Stale',
            startedAtMs: _now - 30 * _dayMs,
          ),
        ],
      );

      expect(profile.artistAffinity['Fresh'], closeTo(1.0, 1e-9));
      expect(profile.artistAffinity['Stale'], closeTo(0.5, 1e-9));
    });

    test('excludes recent plays from what plays next', () {
      final profile = _build(
        events: [_event(songId: 'recentEvent', artist: 'A')],
        recentlyPlayed: ['rec1', 'rec2'],
      );

      expect(profile.blockedIds, containsAll(['rec1', 'rec2', 'recentEvent']));
    });

    test('seeds break ties deterministically by name', () {
      final profile = _build(
        events: [
          _event(songId: 'z', artist: 'Zeta'),
          _event(songId: 'al', artist: 'Alpha'),
        ],
      );

      expect(profile.artistAffinity['Zeta'], profile.artistAffinity['Alpha']);
      expect(profile.seedArtists, ['Alpha', 'Zeta']);
    });

    test('lifts an artist for a play count it can resolve', () {
      final profile = _build(
        playCounts: {'p': 10},
        artistBySongId: {'p': 'Local'},
      );

      expect(profile.artistAffinity['Local'], closeTo(1.0, 1e-9));
      expect(profile.songAffinity['p'], closeTo(1.0, 1e-9));
    });

    test(
      'leaves an artist untouched when the play count cannot be resolved',
      () {
        final profile = _build(playCounts: {'p': 10});

        expect(profile.artistAffinity, isEmpty);
        // The count still says something, it just has nobody to credit.
        expect(profile.songAffinity['p'], closeTo(1.0, 1e-9));
      },
    );

    test('scales play counts slowly, so a favourite still outranks one', () {
      // log(11) ~= 2.40 sits under the favourite's weight of 3.0, which is
      // roughly the design rule: it takes ~19 plays to match one favourite.
      final profile = _build(
        favorites: [_favorite('f', 'Fav')],
        playCounts: {'p': 10},
        artistBySongId: {'p': 'Grinder'},
      );

      expect(profile.artistAffinity['Fav'], closeTo(1.0, 1e-9));
      expect(
        profile.artistAffinity['Grinder']!,
        lessThan(profile.artistAffinity['Fav']!),
      );
    });

    test('weighs an early skip by how much was actually heard', () {
      final profile = _build(
        events: [
          _event(
            songId: 'tap',
            artist: 'Tap',
            playedMs: 1000,
            completed: false,
            skippedEarly: true,
          ),
          _event(
            songId: 'bail',
            artist: 'Bail',
            playedMs: 4000,
            completed: false,
            skippedEarly: true,
          ),
        ],
      );

      // Raw weights are -0.1 and -0.4, so the shared scale puts Bail at the
      // floor and the two-second tap only a quarter of the way down.
      expect(profile.artistAffinity['Bail'], closeTo(-1.0, 1e-9));
      expect(profile.artistAffinity['Tap'], closeTo(-0.25, 1e-9));
      expect(profile.artistAffinity['Tap']!, greaterThan(-1.0));
      // Both are still rejections: neither becomes a seed.
      expect(profile.seedArtists, isEmpty);
    });

    test('gives a full-length early skip the whole penalty', () {
      final profile = _build(
        events: [
          _event(
            songId: 's',
            artist: 'Full',
            playedMs: ListeningStintTracker.earlySkipThreshold.inMilliseconds,
            completed: false,
            skippedEarly: true,
          ),
        ],
      );

      expect(profile.artistAffinity['Full'], closeTo(-1.0, 1e-9));
      expect(profile.seedArtists, isEmpty);
    });

    test('never lets an untagged file pile into one fake artist', () {
      final profile = _build(
        events: [
          _event(songId: 'f1', artist: 'Unknown Artist'),
          _event(songId: 'f2', artist: 'Unknown Artist'),
          _event(songId: 'f3', artist: '  unknown artist  '),
        ],
      );

      // Ten such files would otherwise outweigh every real artist in the app.
      expect(profile.artistAffinity, isEmpty);
      expect(profile.seedArtists, isEmpty);
      // The listens themselves still count and still block a replay.
      expect(profile.songAffinity.keys, containsAll(['f1', 'f2', 'f3']));
      expect(profile.blockedIds, containsAll(['f1', 'f2', 'f3']));
    });

    test('never lifts an artist from a URL or a junk tag', () {
      final profile = _build(
        favorites: [
          _favorite('f', 'http://free-mp3.site'),
          _favorite('g', 'www.site.com'),
          _favorite('h', 'Unknown Artist'),
          _favorite('ok', 'Radiohead'),
        ],
      );

      expect(profile.artistAffinity.keys, ['Radiohead']);
      expect(profile.seedArtists, ['Radiohead']);
      expect(profile.songAffinity.keys, containsAll(['f', 'g', 'h', 'ok']));
    });
  });
}

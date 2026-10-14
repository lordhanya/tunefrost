import 'package:flutter_test/flutter_test.dart';
import 'package:music_player/core/taste/title_metadata.dart';

void main() {
  group('foldName', () {
    test('lowercases and collapses punctuation and whitespace', () {
      expect(foldName('  Daft Punk  '), 'daft punk');
      expect(foldName('A.B, C!'), 'a b c');
      expect(foldName('AC/DC'), 'ac dc');
      expect(foldName('   '), '');
    });

    test('keeps non-Latin letters so those titles still match themselves', () {
      expect(foldName('Молчат Дома'), 'молчат дома');
      expect(foldName('夜に駆ける'), '夜に駆ける');
      expect(foldName('Café del Mar'), 'café del mar');
    });

    test('is idempotent — folding twice changes nothing', () {
      const once = 'Тест — Проверка!';
      expect(foldName(foldName(once)), foldName(once));
    });
  });

  group('parseTitleMetadata — artist resolution', () {
    test('trusts a YouTube auto-generated `- Topic` channel', () {
      final parsed = parseTitleMetadata(
        const TitleParseInput(title: 'Creep', author: 'Radiohead - Topic'),
      );

      expect(parsed.artist, 'Radiohead');
      expect(parsed.confidence, ArtistConfidence.high);
      expect(parsed.songCore, 'creep');
      expect(parsed.versionMarkers, isEmpty);
    });

    test('trusts a title segment that names an artist we already know', () {
      final parsed = parseTitleMetadata(
        const TitleParseInput(
          title: 'Radiohead - Creep (Official Video)',
          author: 'SomeChannel',
          knownArtists: {'radiohead'},
        ),
      );

      expect(parsed.artist, 'Radiohead');
      expect(parsed.confidence, ArtistConfidence.high);
      expect(parsed.songCore, 'creep');
      expect(parsed.versionMarkers, isEmpty);
    });

    test('falls back to title/channel agreement with medium confidence', () {
      final parsed = parseTitleMetadata(
        const TitleParseInput(
          title: 'Creep - Radiohead',
          author: 'RadioheadVEVO',
        ),
      );

      expect(parsed.artist, 'Radiohead');
      expect(parsed.confidence, ArtistConfidence.medium);
      expect(parsed.songCore, 'creep');
    });

    test('refuses to guess when nothing corroborates the split', () {
      final parsed = parseTitleMetadata(
        const TitleParseInput(
          title: 'Creep - Radiohead',
          author: 'SomeChannel',
        ),
      );

      expect(parsed.artist, '');
      expect(parsed.confidence, ArtistConfidence.none);
      // The title is still usable as a key, so deduplication still works
      // even though no performer was claimed.
      expect(parsed.songCore, 'creep radiohead');
    });

    test('does not mistake a channel name for a performer', () {
      final parsed = parseTitleMetadata(
        const TitleParseInput(title: 'Creep', author: 'RadioheadVEVO'),
      );

      expect(parsed.artist, '');
      expect(parsed.confidence, ArtistConfidence.none);
      expect(parsed.songCore, 'creep');
    });

    test('rejects a placeholder that arrives via a known-artist match', () {
      final parsed = parseTitleMetadata(
        const TitleParseInput(
          title: 'Unknown Artist - Creep',
          author: 'SomeChannel',
          knownArtists: {'unknown artist'},
        ),
      );

      expect(parsed.artist, '');
      expect(parsed.confidence, ArtistConfidence.none);
      expect(parsed.songCore, 'creep');
    });

    test('handles a non-Latin artist end to end', () {
      final parsed = parseTitleMetadata(
        const TitleParseInput(title: 'Судно', author: 'Молчат Дома - Topic'),
      );

      expect(parsed.artist, 'Молчат Дома');
      expect(parsed.confidence, ArtistConfidence.high);
      expect(parsed.songCore, 'судно');
    });

    test('falls back to the whole title when the title is only the artist', () {
      final parsed = parseTitleMetadata(
        const TitleParseInput(
          title: 'Radiohead',
          author: 'SomeChannel',
          knownArtists: {'radiohead'},
        ),
      );

      expect(parsed.artist, 'Radiohead');
      expect(parsed.confidence, ArtistConfidence.high);
      expect(parsed.songCore, 'radiohead');
    });

    test('returns empty metadata for an empty title', () {
      final parsed = parseTitleMetadata(
        const TitleParseInput(title: '', author: 'SomeChannel'),
      );

      expect(parsed.artist, '');
      expect(parsed.confidence, ArtistConfidence.none);
      expect(parsed.songCore, '');
      expect(parsed.versionMarkers, isEmpty);
    });
  });

  group('parseTitleMetadata — version markers', () {
    TitleMetadata parse(String title) => parseTitleMetadata(
      TitleParseInput(title: title, author: 'Radiohead - Topic'),
    );

    test('a plain upload carries no marker', () {
      expect(parse('Creep').versionMarkers, isEmpty);
    });

    test('a live take is marked and still shares the studio song core', () {
      final studio = parse('Creep');
      final live = parse('Creep - Live');
      final bracketedLive = parse('Creep (Live)');

      expect(live.versionMarkers, {'live'});
      expect(bracketedLive.versionMarkers, {'live'});
      expect(studio.songCore, live.songCore);
      expect(studio.songCore, bracketedLive.songCore);
      expect(studio.versionKey, isNot(bracketedLive.versionKey));
    });

    test('covers and remixes are each marked separately', () {
      expect(parse('Creep (Cover)').versionMarkers, {'cover'});
      expect(parse('Creep - Remix').versionMarkers, {'remix'});
      expect(parse('Creep - Sped Up').versionMarkers, {'sped up'});
      expect(parse('Creep - Radio Edit').versionMarkers, {
        'edit',
        'radio edit',
      });
      expect(parse('Creep (Radio Edit)').versionMarkers, {
        'edit',
        'radio edit',
      });
    });

    test('channel noise does not become a version marker', () {
      expect(parse('Creep (Official Video)').versionMarkers, isEmpty);
      expect(parse('Creep - Official Audio').versionMarkers, isEmpty);
      expect(parse('Creep - Official Video').versionMarkers, isEmpty);
    });

    test('channel noise is stripped, so those uploads share a core', () {
      final plain = parse('Creep');
      expect(parse('Creep (Official Video)').songCore, plain.songCore);
      expect(parse('Creep - Official Audio').songCore, plain.songCore);
      expect(parse('Creep - Official Video').songCore, plain.songCore);
      expect(parse('Creep (Official Video)').versionKey, plain.versionKey);
    });

    test('trailing-only stripping leaves a real title alone', () {
      // Removing `video` from the middle of a genuine song name would
      // collide it with an unrelated track.
      expect(
        parseTitleMetadata(
          const TitleParseInput(
            title: 'Video Games',
            author: 'Lana Del Rey - Topic',
          ),
        ).songCore,
        'video games',
      );
    });
  });

  group('parseTitleMetadata — identity noise', () {
    TitleMetadata parse(String title) => parseTitleMetadata(
      TitleParseInput(title: title, author: 'Radiohead - Topic'),
    );

    test('drops a feat. credit so credited and plain titles agree', () {
      final plain = parse('Creep');

      expect(parse('Creep feat. Thom Yorke').songCore, plain.songCore);
      expect(parse('Creep ft. Thom Yorke').songCore, plain.songCore);
      expect(parse('Creep featuring Thom Yorke').songCore, plain.songCore);
      expect(parse('Creep feat. Thom Yorke').versionKey, plain.versionKey);
    });

    test('keeps a version marker that follows the credit', () {
      final parsed = parse('Creep feat. Thom Yorke - Live');

      expect(parsed.songCore, 'creep');
      expect(parsed.versionMarkers, {'live'});
    });

    test('drops a trailing year', () {
      expect(parse('Creep 2011').songCore, parse('Creep').songCore);
      expect(parse('Creep (2011)').songCore, parse('Creep').songCore);
    });

    test('does not cut a real title that merely contains a credit word', () {
      // Falls back to the whole title rather than returning an empty core, so
      // both uploads of it still key the same way.
      expect(parse('Featuring').songCore, 'featuring');
    });
  });

  group('versionKey', () {
    test('is order independent — Dart sets compare by identity', () {
      const a = TitleMetadata(
        artist: '',
        confidence: ArtistConfidence.none,
        songCore: 'creep',
        versionMarkers: {'live', 'remix'},
      );
      const b = TitleMetadata(
        artist: '',
        confidence: ArtistConfidence.none,
        songCore: 'creep',
        versionMarkers: {'remix', 'live'},
      );

      expect(a.versionKey, b.versionKey);
      expect(a.versionKey, 'live+remix');
    });

    test('differs when the recordings differ', () {
      const studio = TitleMetadata(
        artist: '',
        confidence: ArtistConfidence.none,
        songCore: 'creep',
        versionMarkers: {},
      );
      const live = TitleMetadata(
        artist: '',
        confidence: ArtistConfidence.none,
        songCore: 'creep',
        versionMarkers: {'live'},
      );

      expect(studio.versionKey, isNot(live.versionKey));
    });
  });

  group('hasArtist', () {
    test('is false whenever the artist could not be trusted', () {
      const none = TitleMetadata(
        artist: '',
        confidence: ArtistConfidence.none,
        songCore: 'creep',
        versionMarkers: {},
      );
      const high = TitleMetadata(
        artist: 'Radiohead',
        confidence: ArtistConfidence.high,
        songCore: 'creep',
        versionMarkers: {},
      );

      expect(none.hasArtist, isFalse);
      expect(high.hasArtist, isTrue);
    });
  });
}

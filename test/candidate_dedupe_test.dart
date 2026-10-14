import 'package:flutter_test/flutter_test.dart';
import 'package:music_player/core/taste/candidate.dart';
import 'package:music_player/core/taste/candidate_dedupe.dart';
import 'package:music_player/core/taste/title_metadata.dart';

/// Builds a ranked candidate through the real parser — the dedupe rules only
/// make sense against identities the app would actually produce.
RankedCandidate _item({
  required String title,
  required String videoId,
  String author = 'SomeChannel',
  double score = 0,
  Set<String> knownArtists = const {},
}) {
  final metadata = parseTitleMetadata(
    TitleParseInput(title: title, author: author, knownArtists: knownArtists),
  );
  return RankedCandidate(
    candidate: Candidate(
      videoId: videoId,
      title: title,
      author: author,
      durationMs: 200000,
      viewCount: 0,
      uploadedAtMs: 0,
      thumbnailUrl: '',
      seed: '',
    ),
    metadata: metadata,
    score: score,
    signals: const {},
  );
}

void main() {
  group('sameRecording', () {
    test('two uploads of one song are the same recording', () {
      final a = _item(title: 'Creep', videoId: 'a');
      final b = _item(title: 'Creep', videoId: 'b');

      expect(sameRecording(a, b), isTrue);
      expect(sameRecording(a, a), isTrue);
    });

    test('different songs are not the same recording', () {
      expect(
        sameRecording(
          _item(title: 'Creep', videoId: 'a'),
          _item(title: 'Karma Police', videoId: 'b'),
        ),
        isFalse,
      );
    });

    test('a live take is not the studio recording', () {
      expect(
        sameRecording(
          _item(title: 'Creep', videoId: 'a'),
          _item(title: 'Creep (Live)', videoId: 'b'),
        ),
        isFalse,
      );
    });

    test('a cover is not the original', () {
      expect(
        sameRecording(
          _item(title: 'Creep', videoId: 'a'),
          _item(title: 'Creep (Cover)', videoId: 'b'),
        ),
        isFalse,
      );
    });

    test('two different songs that share a title are both kept', () {
      final radiohead = _item(
        title: 'Creep',
        videoId: 'a',
        author: 'Radiohead - Topic',
      );
      final tlc = _item(title: 'Creep', videoId: 'b', author: 'TLC - Topic');

      expect(radiohead.metadata.artist, 'Radiohead');
      expect(tlc.metadata.artist, 'TLC');
      expect(sameRecording(radiohead, tlc), isFalse);
    });

    test('an unattributed upload collapses into an attributed one', () {
      // Nothing distinguishes them, so the conservative move is to keep one
      // rather than show the same song twice, once with an artist and once
      // without.
      final attributed = _item(
        title: 'Creep',
        videoId: 'a',
        author: 'Radiohead - Topic',
      );
      final unattributed = _item(title: 'Creep', videoId: 'b');

      expect(sameRecording(attributed, unattributed), isTrue);
    });
  });

  group('dedupe against real-world title noise', () {
    test('a feat. credit does not split one recording into two', () {
      final ranked = [
        _item(title: 'Creep feat. Thom Yorke', videoId: 'a'),
        _item(title: 'Creep', videoId: 'b'),
      ];

      expect(dedupeCandidates(ranked).map((item) => item.candidate.videoId), [
        'a',
      ]);
    });

    test('a trailing year does not split one recording into two', () {
      final ranked = [
        _item(title: 'Creep 2011', videoId: 'a'),
        _item(title: 'Creep (2011 Remastered)', videoId: 'b'),
      ];

      expect(dedupeCandidates(ranked).map((item) => item.candidate.videoId), [
        'a',
      ]);
    });

    test('still keeps a genuinely different song with a similar title', () {
      final ranked = [
        _item(title: 'Creep', videoId: 'studio'),
        _item(title: 'Creep Live in Buenos Aires', videoId: 'live'),
      ];

      expect(dedupeCandidates(ranked), hasLength(2));
    });
  });

  group('dedupeCandidates', () {
    test('returns an empty list unchanged', () {
      expect(dedupeCandidates(const []), isEmpty);
    });

    test('collapses repeated uploads, keeping the best ranked one', () {
      final ranked = [
        _item(title: 'Creep', videoId: 'best', score: 5),
        _item(title: 'Creep', videoId: 'worse', score: 1),
        _item(title: 'Creep', videoId: 'worst', score: 0),
      ];

      final deduped = dedupeCandidates(ranked);

      expect(deduped, hasLength(1));
      expect(deduped.single.candidate.videoId, 'best');
    });

    test('preserves the order of everything that survives', () {
      final ranked = [
        _item(title: 'Creep', videoId: 'a', score: 3),
        _item(title: 'Karma Police', videoId: 'b', score: 2),
        _item(title: 'Creep', videoId: 'c', score: 1),
        _item(title: 'No Surprises', videoId: 'd', score: 0),
      ];

      expect(dedupeCandidates(ranked).map((item) => item.candidate.videoId), [
        'a',
        'b',
        'd',
      ]);
    });

    test('treats differently worded titles of one song as duplicates', () {
      const seeds = {'radiohead'};
      final ranked = [
        _item(title: 'Creep', videoId: 'a', knownArtists: seeds),
        _item(
          title: 'Creep (Official Video)',
          videoId: 'b',
          knownArtists: seeds,
        ),
        _item(
          title: 'Creep - Official Audio',
          videoId: 'c',
          knownArtists: seeds,
        ),
        _item(title: 'Radiohead - Creep', videoId: 'd', knownArtists: seeds),
      ];

      final deduped = dedupeCandidates(ranked);

      expect(deduped, hasLength(1));
      expect(deduped.single.candidate.videoId, 'a');
    });

    test('keeps live, studio and cover recordings side by side', () {
      final ranked = [
        _item(title: 'Creep', videoId: 'studio'),
        _item(title: 'Creep - Live', videoId: 'live'),
        _item(title: 'Creep (Live)', videoId: 'liveAgain'),
        _item(title: 'Creep (Cover)', videoId: 'cover'),
      ];

      expect(dedupeCandidates(ranked).map((item) => item.candidate.videoId), [
        'studio',
        'live',
        'cover',
      ]);
    });

    test('identifies a bracketed marker as the same as a separated one', () {
      final ranked = [
        _item(title: 'Creep - Radio Edit', videoId: 'tail'),
        _item(title: 'Creep (Radio Edit)', videoId: 'bracket'),
      ];

      expect(dedupeCandidates(ranked).map((item) => item.candidate.videoId), [
        'tail',
      ]);
    });

    test('does not collapse same-titled songs by different artists', () {
      final ranked = [
        _item(
          title: 'Creep',
          videoId: 'radiohead',
          author: 'Radiohead - Topic',
        ),
        _item(title: 'Creep', videoId: 'tlc', author: 'TLC - Topic'),
      ];

      expect(dedupeCandidates(ranked), hasLength(2));
    });

    test('keeps whichever entry comes first, so callers must rank first', () {
      // The survivor is chosen by position, never by score — deduping an
      // unranked batch would keep whichever upload the provider happened to
      // return first.
      final ranked = [
        _item(title: 'Creep', videoId: 'first', score: 1),
        _item(title: 'Creep', videoId: 'second', score: 9),
      ];

      expect(dedupeCandidates(ranked).single.candidate.videoId, 'first');
    });
  });
}

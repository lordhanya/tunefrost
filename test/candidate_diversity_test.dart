import 'package:flutter_test/flutter_test.dart';

import 'package:music_player/core/taste/candidate.dart';
import 'package:music_player/core/taste/candidate_dedupe.dart';
import 'package:music_player/core/taste/candidate_diversity.dart';
import 'package:music_player/core/taste/candidate_ranker.dart';
import 'package:music_player/core/taste/title_metadata.dart';
import 'package:music_player/core/taste/taste_profile.dart';

/// A raw candidate exactly as discovery would return it: no performer parsed,
/// no upload date, so recency scores zero whatever the clock reads.
Candidate _candidate(
  String videoId,
  String author, {
  String title = 'Song',
  int viewCount = 0,
}) => Candidate(
  videoId: videoId,
  title: title,
  author: author,
  durationMs: 200000,
  viewCount: viewCount,
  uploadedAtMs: 0,
  thumbnailUrl: '',
  seed: '',
);

/// The same candidate after ranking. Channel diversity reads only the uploader
/// and the order it is handed, so the score and metadata here are inert —
/// [rankCandidates] is exercised on its own in the pipeline test below.
RankedCandidate _item(
  String videoId,
  String author, {
  String title = 'Song',
  Set<String> versionMarkers = const {},
}) => RankedCandidate(
  candidate: _candidate(videoId, author, title: title),
  metadata: TitleMetadata(
    artist: '',
    confidence: ArtistConfidence.none,
    songCore: title.toLowerCase(),
    versionMarkers: versionMarkers,
  ),
  score: 0,
  signals: const {},
);

List<String> _ids(List<RankedCandidate> items) => [
  for (final item in items) item.candidate.videoId,
];

/// Whether every id in [part] appears in [whole] in the same relative order —
/// the only way the cap is allowed to shorten a list: by dropping, never by
/// moving anything.
bool _isSubsequence(List<String> part, List<String> whole) {
  var i = 0;
  for (final id in whole) {
    if (i < part.length && part[i] == id) i++;
  }
  return i == part.length;
}

/// Empty profile, fixed clock. Every candidate below carries no upload date,
/// so recency scores zero whatever the clock reads and the ordering this test
/// asserts cannot drift with the day it is run.
final RankContext _ctx = RankContext(profile: const TasteProfile(), nowMs: 0);

void main() {
  group('applyChannelDiversity', () {
    test('is configured to two rows per uploader', () {
      expect(kSmartPlayMaxPerChannel, 2);
    });

    test('keeps at most the configured limit from one channel', () {
      final out = applyChannelDiversity([
        _item('a', '7clouds'),
        _item('b', '7clouds'),
        _item('c', '7clouds'),
        _item('d', '7clouds'),
      ], perChannel: kSmartPlayMaxPerChannel);

      expect(_ids(out), ['a', 'b']);
    });

    test('still admits candidates from other channels', () {
      final out = applyChannelDiversity([
        _item('a', '7clouds'),
        _item('b', '7clouds'),
        _item('c', '7clouds'),
        _item('d', 'Proximity'),
        _item('e', 'Trap Nation'),
      ], perChannel: 2);

      expect(_ids(out), ['a', 'b', 'd', 'e']);
    });

    test('returns fewer rows rather than relaxing the cap', () {
      final out = applyChannelDiversity([
        _item('a', '7clouds'),
        _item('b', '7clouds'),
        _item('c', '7clouds'),
      ], perChannel: 2);

      expect(_ids(out), ['a', 'b']);
      expect(out, hasLength(2));
    });

    test('handles empty input', () {
      expect(applyChannelDiversity(const [], perChannel: 2), isEmpty);
    });

    test('preserves the relative order of the rows it keeps', () {
      final input = [
        _item('r1', 'Ch1'),
        _item('r2', 'Ch2'),
        _item('r3', 'Ch1'),
        _item('r4', 'Ch2'),
        _item('r5', 'Ch1'),
        _item('r6', 'Ch2'),
        _item('r7', 'Ch3'),
        _item('r8', 'Ch1'),
      ];

      final out = applyChannelDiversity(input, perChannel: 2);

      expect(_ids(out), ['r1', 'r2', 'r3', 'r4', 'r7']);
      expect(_isSubsequence(_ids(out), _ids(input)), isTrue);
    });

    test('does not mutate the list it is given', () {
      final input = [_item('a', 'Ch'), _item('b', 'Ch'), _item('c', 'Ch')];

      applyChannelDiversity(input, perChannel: 2);

      expect(_ids(input), ['a', 'b', 'c']);
    });

    test('never drops rows whose channel name is missing', () {
      final out = applyChannelDiversity([
        _item('1', ''),
        _item('2', ''),
        _item('3', ''),
        _item('4', ''),
        _item('5', 'Proximity'),
        _item('6', 'Proximity'),
        _item('7', 'Proximity'),
      ], perChannel: 2);

      // Four unnamed rows cannot be shown to come from one uploader, so
      // bucketing them together would discard three for no evidence at all.
      expect(_ids(out), ['1', '2', '3', '4', '5', '6']);
    });

    test('never drops rows whose channel name folds to nothing', () {
      final out = applyChannelDiversity([
        _item('1', '!!!'),
        _item('2', '—'),
        _item('3', '*'),
        _item('4', '   '),
      ], perChannel: 2);

      expect(_ids(out), ['1', '2', '3', '4']);
    });

    test('groups a channel by its folded name, not its spelling', () {
      final out = applyChannelDiversity([
        _item('1', '7clouds'),
        _item('2', '7CLOUDS'),
        _item('3', ' 7clouds '),
        _item('4', '7clouds!'),
        _item('5', 'Proximity'),
      ], perChannel: 2);

      // Case, stray whitespace and trailing punctuation all fold away, so
      // these are one uploader and only its first two rows survive.
      expect(_ids(out), ['1', '2', '5']);
    });

    test('does not merge channels that differ only by spacing', () {
      // Folding normalises case and punctuation but preserves word breaks, so
      // `7clouds` and `7 Clouds` stay separate uploaders rather than being
      // guessed into one — a merger this rule has no evidence for. Two
      // distinct channels therefore keep both of their rows.
      final out = applyChannelDiversity([
        _item('1', '7clouds'),
        _item('2', '7clouds'),
        _item('3', '7 Clouds'),
        _item('4', '7 Clouds'),
      ], perChannel: 2);

      expect(_ids(out), ['1', '2', '3', '4']);
    });

    test('honours a limit other than the configured one', () {
      final input = [
        _item('1', 'Ch'),
        _item('2', 'Ch'),
        _item('3', 'Ch'),
        _item('4', 'Ch'),
      ];

      expect(_ids(applyChannelDiversity(input, perChannel: 3)), [
        '1',
        '2',
        '3',
      ]);
      expect(_ids(applyChannelDiversity(input, perChannel: 1)), ['1']);
      expect(applyChannelDiversity(input, perChannel: 0), isEmpty);
      expect(applyChannelDiversity(input, perChannel: -1), isEmpty);
    });

    test('does not merge distinct versions of one song', () {
      // Deduplication has already run: these are four different recordings of
      // one song on one channel, all legitimately kept. The cap may only count
      // them as rows — it must leave their markers and their identities alone.
      final out = applyChannelDiversity([
        _item('studio', '7clouds', title: 'Creep'),
        _item('live', '7clouds', title: 'Creep Live', versionMarkers: {'live'}),
        _item(
          'cover',
          '7clouds',
          title: 'Creep Cover',
          versionMarkers: {'cover'},
        ),
        _item(
          'remix',
          '7clouds',
          title: 'Creep Remix',
          versionMarkers: {'remix'},
        ),
        _item('other', 'Proximity', title: 'Karma'),
      ], perChannel: 2);

      expect(_ids(out), ['studio', 'live', 'other']);
      expect(out.first.metadata.versionMarkers, isEmpty);
      expect(out[1].metadata.versionMarkers, {'live'});
    });

    test('runs after deduplication without disturbing either stage', () {
      // The pipeline shape used by Smart Play: rank, dedupe, then cap. The cap
      // must drop 7clouds' third row, the duplicate upload must already be
      // gone before it runs, and nothing may be moved.
      final raw = [
        _candidate('a1', '7clouds', title: 'Alpha', viewCount: 1000000),
        _candidate('b1', '7clouds', title: 'Bravo', viewCount: 500000),
        _candidate('b2', '7clouds', title: 'Bravo', viewCount: 500000),
        _candidate('c1', '7clouds', title: 'Charlie', viewCount: 250000),
        _candidate('p1', 'Proximity', title: 'Delta', viewCount: 100),
        _candidate('n1', 'Trap Nation', title: 'Echo', viewCount: 50),
      ];

      final ranked = rankCandidates(raw, _ctx);
      final deduped = dedupeCandidates(ranked);
      final out = applyChannelDiversity(
        deduped,
        perChannel: kSmartPlayMaxPerChannel,
      );

      expect(_ids(ranked), ['a1', 'b1', 'b2', 'c1', 'p1', 'n1']);
      expect(_ids(deduped), ['a1', 'b1', 'c1', 'p1', 'n1']);
      expect(_ids(out), ['a1', 'b1', 'p1', 'n1']);
      expect(_isSubsequence(_ids(out), _ids(ranked)), isTrue);
    });
  });
}

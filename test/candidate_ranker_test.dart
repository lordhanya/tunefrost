import 'package:flutter_test/flutter_test.dart';
import 'package:music_player/core/models/song.dart';
import 'package:music_player/core/taste/candidate.dart';
import 'package:music_player/core/taste/candidate_ranker.dart';
import 'package:music_player/core/taste/taste_profile.dart';

Candidate _cand({
  required String videoId,
  required String title,
  String author = 'SomeChannel',
  int durationMs = 200000,
  int viewCount = 1000,
  int uploadedAtMs = 0,
  String seed = '',
}) => Candidate(
  videoId: videoId,
  title: title,
  author: author,
  durationMs: durationMs,
  viewCount: viewCount,
  uploadedAtMs: uploadedAtMs,
  thumbnailUrl: '',
  seed: seed,
);

RankContext _ctx({
  TasteProfile profile = TasteProfile.empty,
  Set<String> libraryIds = const {},
  Set<String> queuedIds = const {},
  Set<String> knownArtists = const {},
  int nowMs = 0,
}) => RankContext(
  profile: profile,
  libraryIds: libraryIds,
  queuedIds: queuedIds,
  knownArtists: knownArtists,
  nowMs: nowMs,
);

void main() {
  group('exclusions', () {
    test('returns an empty list unchanged', () {
      expect(rankCandidates(const [], _ctx()), isEmpty);
    });

    test('drops a candidate already heard recently', () {
      final out = rankCandidates([
        _cand(videoId: 'x', title: 'Creep'),
      ], _ctx(profile: TasteProfile(blockedIds: {Song.remoteId('x')})));

      expect(out, isEmpty);
    });

    test('drops a candidate already in the library', () {
      final out = rankCandidates([
        _cand(videoId: 'x', title: 'Creep'),
      ], _ctx(libraryIds: {Song.remoteId('x')}));

      expect(out, isEmpty);
    });

    test('drops a candidate already queued', () {
      final out = rankCandidates([
        _cand(videoId: 'x', title: 'Creep'),
      ], _ctx(queuedIds: {Song.remoteId('x')}));

      expect(out, isEmpty);
    });

    test('drops a clip that is too short and a file that is too long', () {
      expect(
        rankCandidates([
          _cand(videoId: 'a', title: 'Creep', durationMs: 8000),
        ], _ctx()),
        isEmpty,
      );
      expect(
        rankCandidates([
          _cand(videoId: 'b', title: 'Creep', durationMs: 90 * 60 * 1000),
        ], _ctx()),
        isEmpty,
      );
    });

    test('keeps a long live recording — variants are not filtered away', () {
      final out = rankCandidates([
        _cand(
          videoId: 'x',
          title: 'Creep - Live',
          author: 'Radiohead - Topic',
          durationMs: 45 * 60 * 1000,
        ),
      ], _ctx());

      expect(out, hasLength(1));
      expect(out.single.metadata.versionMarkers, {'live'});
    });

    test('excludes before scoring, so a blocked favourite cannot win', () {
      final out = rankCandidates(
        [_cand(videoId: 'x', title: 'Creep', author: 'Radiohead - Topic')],
        _ctx(
          profile: TasteProfile(
            artistAffinity: {'Radiohead': 1.0},
            blockedIds: {Song.remoteId('x')},
          ),
        ),
      );

      expect(out, isEmpty);
    });
  });

  group('ranking', () {
    test('ranks a seed artist above an unrelated result', () {
      final out = rankCandidates([
        _cand(videoId: 'other', title: 'Blue'),
        _cand(videoId: 'seeded', title: 'Creep', author: 'Radiohead - Topic'),
      ], _ctx(profile: TasteProfile(seedArtists: ['Radiohead'])));

      expect(out.map((item) => item.candidate.videoId), ['seeded', 'other']);
      expect(out.first.signals['seed'], 1.0);
      expect(out.last.signals['seed'], 0.0);
    });

    test('ranks an artist you keep returning to first', () {
      final out = rankCandidates([
        _cand(videoId: 'other', title: 'Blue'),
        _cand(videoId: 'liked', title: 'Creep', author: 'Radiohead - Topic'),
      ], _ctx(profile: TasteProfile(artistAffinity: {'Radiohead': 1.0})));

      expect(out.map((item) => item.candidate.videoId), ['liked', 'other']);
      expect(out.first.signals['affinity'], 1.0);
      expect(out.first.score, greaterThan(out.last.score));
    });

    test('pushes an artist you abandon below an unknown one', () {
      final out = rankCandidates([
        _cand(videoId: 'wanted', title: 'Creep', author: 'Radiohead - Topic'),
        _cand(videoId: 'other', title: 'Blue'),
      ], _ctx(profile: TasteProfile(artistAffinity: {'Radiohead': -1.0})));

      expect(out.map((item) => item.candidate.videoId), ['other', 'wanted']);
    });

    test('finds an affinity stored with different casing and spacing', () {
      final out = rankCandidates([
        _cand(videoId: 'a', title: 'Creep', author: 'Radiohead - Topic'),
      ], _ctx(profile: TasteProfile(artistAffinity: {'  RADIOHEAD ': 0.5})));

      expect(out.single.signals['affinity'], 0.5);
    });

    test('recognises an artist name the caller supplied', () {
      final out = rankCandidates(
        [_cand(videoId: 'a', title: 'Radiohead - Creep')],
        _ctx(
          knownArtists: {'radiohead'},
          profile: TasteProfile(artistAffinity: {'Radiohead': 1.0}),
        ),
      );

      expect(out.single.metadata.artist, 'Radiohead');
      expect(out.single.signals['affinity'], 1.0);
    });

    test('scores safely when no view counts are available', () {
      final out = rankCandidates([
        _cand(videoId: 'a', title: 'Creep', viewCount: 0),
        _cand(videoId: 'b', title: 'Blue', viewCount: 0),
      ], _ctx());

      expect(out, hasLength(2));
      for (final item in out) {
        expect(item.score.isFinite, isTrue);
        expect(item.signals['popularity'], 0);
      }
    });

    test('breaks ties by title then id, so the order is total', () {
      final out = rankCandidates([
        _cand(videoId: 'b', title: 'Zebra'),
        _cand(videoId: 'a', title: 'Apple'),
        _cand(videoId: 'c', title: 'apple'),
      ], _ctx());

      expect(out.map((item) => item.candidate.videoId), ['a', 'c', 'b']);
    });
  });

  group('channel identity and seed provenance', () {
    test('matches a preference recorded under the upload channel', () {
      final out = rankCandidates([
        _cand(videoId: 'a', title: 'Creep', author: '7clouds'),
      ], _ctx(profile: TasteProfile(artistAffinity: {'7clouds': 1.0})));

      expect(out.single.metadata.artist, '');
      expect(out.single.signals['affinity'], 1.0);
    });

    test('a resolved performer wins over the channel', () {
      final out = rankCandidates(
        [
          _cand(
            videoId: 'a',
            title: 'Radiohead - Creep',
            author: 'SomeChannel',
          ),
        ],
        _ctx(
          knownArtists: {'radiohead'},
          profile: TasteProfile(
            artistAffinity: {'Radiohead': 0.4, 'SomeChannel': 1.0},
          ),
        ),
      );

      expect(out.single.metadata.artist, 'Radiohead');
      expect(out.single.signals['affinity'], 0.4);
    });

    test('ranks by the seed that found the upload, artist or no artist', () {
      final out = rankCandidates([
        _cand(videoId: 'x', title: 'Unrelated Song', author: 'SomeChannel'),
        _cand(
          videoId: 'y',
          title: 'Other Song',
          author: 'OtherChannel',
          seed: 'Radiohead',
        ),
      ], _ctx(profile: TasteProfile(seedArtists: ['Radiohead', 'Coldplay'])));

      expect(out.map((item) => item.candidate.videoId), ['y', 'x']);
      expect(out.first.signals['seed'], 1.0);
      expect(out.last.signals['seed'], 0.0);
    });

    test('takes the earliest seed when several sources match', () {
      final out = rankCandidates([
        _cand(
          videoId: 'y',
          title: 'Song',
          author: 'Coldplay',
          seed: 'Radiohead',
        ),
      ], _ctx(profile: TasteProfile(seedArtists: ['Radiohead', 'Coldplay'])));

      // Two seeds total, matched index 0: 1 - 0/2.
      expect(out.single.signals['seed'], 1.0);
    });

    test('provenance and channel preference are independent signals', () {
      final out = rankCandidates(
        [
          _cand(
            videoId: 'a',
            title: 'Radiohead - Creep',
            author: '7clouds',
            seed: 'Radiohead',
          ),
        ],
        _ctx(
          knownArtists: {'radiohead'},
          profile: TasteProfile(
            artistAffinity: {'7clouds': -1.0},
            seedArtists: ['Radiohead'],
          ),
        ),
      );

      expect(out.single.signals['affinity'], -1.0);
      expect(out.single.signals['seed'], 1.0);
    });
  });

  group('signals', () {
    test('keeps every component inside its documented range', () {
      final out = rankCandidates(
        [
          _cand(
            videoId: 'a',
            title: 'Creep - Live',
            author: 'Radiohead - Topic',
            viewCount: 500000000,
            durationMs: 40 * 60 * 1000,
          ),
        ],
        _ctx(
          profile: TasteProfile(
            artistAffinity: {'Radiohead': -1.0},
            seedArtists: ['Radiohead'],
          ),
          nowMs: Duration(days: 365 * 5).inMilliseconds,
        ),
      );

      final signals = out.single.signals;
      expect(signals['affinity'], inInclusiveRange(-1, 1));
      expect(signals['seed'], inInclusiveRange(0, 1));
      expect(signals['popularity'], inInclusiveRange(0, 1));
      expect(signals['recency'], inInclusiveRange(0, 1));
      expect(signals['duration'], inInclusiveRange(-1, 1));
      expect(out.single.score.isFinite, isTrue);
    });

    test('gives full marks to a track just under the good-duration floor', () {
      final out = rankCandidates([
        _cand(videoId: 'a', title: 'Creep', durationMs: 60 * 1000),
      ], _ctx());

      expect(out.single.signals['duration'], 1.0);
    });

    test('does not reward an upload older than the recency window', () {
      final out = rankCandidates([
        _cand(videoId: 'a', title: 'Creep', uploadedAtMs: 0),
      ], _ctx(nowMs: Duration(days: 365 * 10).inMilliseconds));

      expect(out.single.signals['recency'], 0);
    });
  });
}

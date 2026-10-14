import 'package:music_player/core/taste/taste_profile.dart';

/// How much an artist name deserves to be believed.
///
/// Smart Play only ranks against [ArtistConfidence.medium] and above: a
/// misattributed performer silently corrupts affinity, while an admitted
/// blank simply costs a match. The preview surfaces whichever level was hit
/// so weak extraction is visible rather than buried.
enum ArtistConfidence {
  /// Nothing trustworthy — the channel is a brand, not a performer.
  none,

  /// A title segment agrees with the uploader's channel name.
  medium,

  /// The title matched a name we already know, or YouTube's own `- Topic`
  /// channel, which exists precisely to name performers.
  high,
}

/// What an upload's title tells us about the recording it carries.
///
/// Pure and deterministic: raw strings in, identity out. No network, no
/// clock, no player — which is why every rule below is unit-tested instead of
/// being discovered at runtime on a real search result.
class TitleMetadata {
  const TitleMetadata({
    required this.artist,
    required this.confidence,
    required this.songCore,
    required this.versionMarkers,
  });

  /// Performer name, or `''` when [confidence] is [ArtistConfidence.none].
  final String artist;

  final ArtistConfidence confidence;

  /// Lowercased, punctuation-free song title with the artist, channel noise
  /// and version markers removed. Only ever used as a key — the preview
  /// always shows the raw [Candidate.title].
  final String songCore;

  /// Which recording of this song this is: `live`, `cover`, `remix`, … Two
  /// uploads of one recording produce the same set; a live take does not.
  final Set<String> versionMarkers;

  static const empty = TitleMetadata(
    artist: '',
    confidence: ArtistConfidence.none,
    songCore: '',
    versionMarkers: {},
  );

  bool get hasArtist =>
      artist.isNotEmpty && confidence != ArtistConfidence.none;

  /// Sorted markers joined, because Dart's `Set` compares by identity and a
  /// plain `==` on two independently built sets would silently never match.
  String get versionKey => (versionMarkers.toList()..sort()).join('+');
}

/// Folds a name exactly the way every comparison in Smart Play does —
/// lowercased, punctuation-free, whitespace collapsed, Unicode letters kept
/// so non-Latin titles survive.
///
/// Exported so callers build their known-artist set with this very function:
/// two different normalizers would mean an artist looked up could never
/// equal the artist stored.
String foldName(String value) => value
    .toLowerCase()
    .replaceAll(RegExp(r'[^\p{L}\p{N}]+', unicode: true), ' ')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

/// Splits a title on separators with surrounding whitespace, so hyphenated
/// words inside a single token are never mistaken for a boundary.
final RegExp _separator = RegExp(r'\s[-–—|]\s');

/// Bracketed qualifiers: `(Official Video)`, `[Live]`, `【夜に駆ける】`.
final RegExp _bracket = RegExp(r'[\(\[\{【［]([^()\[\]{}【】［］]*)[\)\]\}】］]');

/// `Channel - Topic` marks YouTube's auto-generated performer page, which is
/// the single most authoritative artist signal a search result can carry.
final RegExp _topicSuffix = RegExp(r'\s*-\s*topic\s*$', caseSensitive: false);

/// Trailing wording that says nothing about which recording this is.
const Set<String> _noiseWords = {
  'official',
  'video',
  'audio',
  'music',
  'lyric',
  'lyrics',
  'hd',
  '4k',
  '2k',
  'hq',
  'mv',
  'visualizer',
  'visualiser',
  'animated',
  'animation',
  'remaster',
  'remastered',
  'deluxe',
  'explicit',
  'version',
  'song',
};

const Set<String> _noisePhrases = {
  'official video',
  'official music video',
  'official audio',
  'music video',
  'lyric video',
  'lyrics video',
  'audio video',
  'hd video',
  'full song',
  'official song',
};

/// Wording that genuinely denotes a *different recording*, and must
/// therefore survive deduplication.
///
/// Deliberately includes `edit`, `acoustic` and `demo`: keeping two entries
/// that turn out to be the same costs one wasted row, while silently
/// throwing away a live take or a cover loses music the listener wanted.
const Set<String> _versionWords = {
  'live',
  'cover',
  'covers',
  'remix',
  'remixed',
  'bootleg',
  'edit',
  'extended',
  'instrumental',
  'karaoke',
  'slowed',
  'nightcore',
  'unplugged',
  'acoustic',
  'demo',
  'reprise',
  'flipped',
};

const Set<String> _versionPhrases = {
  'sped up',
  'speed up',
  'radio edit',
  'club mix',
  'original mix',
  'extended mix',
  'extended edit',
  'live session',
};

/// Parsing inputs. Everything here is plain data, so the whole unit runs in
/// a test with no platform, network or clock.
class TitleParseInput {
  const TitleParseInput({
    required this.title,
    required this.author,
    this.knownArtists = const {},
  });

  final String title;

  /// Upload channel, not performer — see [Candidate.author].
  final String author;

  /// Already-folded via [foldName]: taste seeds plus library and favourite
  /// artist names. Matching one of these is what resolves the age-old
  /// `Artist - Song` versus `Song - Artist` ambiguity outright.
  final Set<String> knownArtists;
}

/// Derives performer and recording identity from an upload title.
///
/// Artist resolution is tried in strict order of authority:
///  1. [ArtistConfidence.high] — the uploader is YouTube's `- Topic` page.
///  2. [ArtistConfidence.high] — a title segment equals a name we know.
///  3. [ArtistConfidence.medium] — a title segment agrees with the channel.
///  4. [ArtistConfidence.none] — nothing corroborates, so nothing is claimed.
///
/// Step 4 is the conservative default. Guessing the wrong half of a
/// `Song - Artist` split would invent an artist shared by unrelated uploads,
/// the same silent failure the `Unknown Artist` bucket in a local library
/// produces — so it is far better to report "artist not determined".
TitleMetadata parseTitleMetadata(TitleParseInput input) {
  final raw = input.title.trim();
  if (raw.isEmpty) return TitleMetadata.empty;

  // Pull qualifiers aside before splitting: `(Live)` is evidence about the
  // recording, not a fourth segment of the title.
  final qualifiers = _bracket
      .allMatches(raw)
      .map((m) => m.group(1) ?? '')
      .toList(growable: false);
  final remainder = raw.replaceAll(_bracket, ' ');

  final segments = remainder
      .split(_separator)
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList(growable: false);

  final authorFolded = foldName(input.author);
  var artist = '';
  var confidence = ArtistConfidence.none;
  var artistSegment = -1;

  final topic = _topicArtist(input.author);
  if (topic != null && isUsableArtistName(topic)) {
    artist = topic;
    confidence = ArtistConfidence.high;
  } else {
    for (var i = 0; i < segments.length; i++) {
      if (input.knownArtists.contains(foldName(segments[i]))) {
        artist = segments[i];
        confidence = ArtistConfidence.high;
        artistSegment = i;
        break;
      }
    }
    if (!confidence.isHigh) {
      for (var i = 0; i < segments.length; i++) {
        final segment = segments[i];
        final folded = foldName(segment);
        if (folded.length < 4 || !_agrees(folded, authorFolded)) continue;
        artist = _shorterName(segment, input.author);
        confidence = ArtistConfidence.medium;
        artistSegment = i;
        break;
      }
    }
  }

  // The remaining segments are the song itself.
  final rest = [
    for (var i = 0; i < segments.length; i++)
      if (i != artistSegment) segments[i],
  ].join(' ');

  final parsed = _cleanSongCore(rest, qualifiers);
  return TitleMetadata(
    artist: isUsableArtistName(artist) ? artist.trim() : '',
    confidence: isUsableArtistName(artist) ? confidence : ArtistConfidence.none,
    songCore: parsed.$1.isEmpty ? foldName(raw) : parsed.$1,
    versionMarkers: parsed.$2,
  );
}

extension on ArtistConfidence {
  bool get isHigh => this == ArtistConfidence.high;
}

/// True when either string substantially contains the other, which is how a
/// title segment and a channel name corroborate each other.
bool _agrees(String segment, String author) {
  if (segment.length < 4 || author.length < 4) return false;
  return author.contains(segment) || segment.contains(author);
}

/// Between a title segment and the channel that carries it, the shorter folded
/// form is the more specific name: `Radiohead` beats `RadioheadVEVO`, and
/// `Radiohead` beats `Radiohead Official`.
String _shorterName(String segment, String author) {
  final segmentFolded = foldName(segment);
  final authorFolded = foldName(author);
  return segmentFolded.length <= authorFolded.length ? segment : author.trim();
}

String? _topicArtist(String author) {
  final match = _topicSuffix.firstMatch(author.trim());
  if (match == null) return null;
  return author.trim().substring(0, match.start).trim();
}

/// Strips trailing noise and version wording from [rest], collecting the
/// version wording it finds.
///
/// Trailing-only on purpose: `"Video Games"` keeps its title, because
/// deleting the word `video` from the middle of a real song name would
/// collide it with an unrelated track. A failure to strip is safe — both
/// uploads of a recording are stripped the same way, so they still match.
(String, Set<String>) _cleanSongCore(String rest, List<String> qualifiers) {
  final markers = <String>{};
  for (final qualifier in qualifiers) {
    final words = foldName(qualifier)
        .split(' ')
        .where((t) => t.isNotEmpty)
        .toList(growable: false);
    for (final word in words) {
      if (_versionWords.contains(word)) markers.add(word);
    }
    for (var i = 1; i < words.length; i++) {
      final bigram = '${words[i - 1]} ${words[i]}';
      if (_versionPhrases.contains(bigram)) markers.add(bigram);
    }
  }

  final tokens = foldName(rest).split(' ').where((t) => t.isNotEmpty).toList();

  // A `feat.` credit introduces names, not identity: dropping it and
  // everything after lets two uploads of one song differ only by who is
  // credited and still collapse. Credit words and trailing years only, and
  // never the reverse — cutting from the *first* `With` or a mid-title number
  // would mangle real names the way stripping `video` from `Video Games`
  // would, which is exactly the bug trailing-only stripping exists to avoid.
  bool isYear(String token) {
    if (token.length != 4) return false;
    final value = int.tryParse(token);
    return value != null && value >= 1900 && value <= 2099;
  }

  const creditWords = {'feat', 'feats', 'ft', 'featuring'};

  // Every round removes at least one token, so this terminates; the guard
  // exists only so an unexpected pattern can never spin forever.
  var guard = 0;
  while (tokens.isNotEmpty && guard++ < 12) {
    if (_popped(tokens, _versionPhrases, 2, markers)) continue;
    if (_popped(tokens, _noisePhrases, 3, null)) continue;
    if (_popped(tokens, _noisePhrases, 2, null)) continue;
    if (_popped(tokens, _versionWords, 1, markers)) continue;
    if (_popped(tokens, _noiseWords, 1, null)) continue;
    if (isYear(tokens.last)) {
      tokens.removeLast();
      continue;
    }
    break;
  }

  for (var i = 0; i < tokens.length; i++) {
    if (creditWords.contains(tokens[i])) {
      tokens.removeRange(i, tokens.length);
      break;
    }
  }

  return (tokens.join(' '), markers);
}

/// Pops a trailing run of [length] tokens if it is a known phrase, recording
/// it in [markers] when given.
bool _popped(
  List<String> tokens,
  Set<String> known,
  int length,
  Set<String>? markers,
) {
  if (tokens.length < length) return false;
  final tail = length == 1
      ? tokens.last
      : tokens.sublist(tokens.length - length).join(' ');
  if (!known.contains(tail)) return false;
  if (markers != null) {
    markers.add(tail);
    // A multi-word marker also records its version-bearing parts, so that
    // `Radio Edit` and `(Radio Edit)` land on the same set. Without this the
    // bracket path (which scans every word) and the trailing path (which
    // consumes the whole phrase at once) would disagree, and two uploads of
    // one recording would fail to deduplicate.
    for (final part in tail.split(' ')) {
      if (_versionWords.contains(part)) markers.add(part);
    }
  }
  tokens.removeRange(tokens.length - length, tokens.length);
  return true;
}

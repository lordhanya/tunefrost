# Tunefrost

**A local-first music player for Android that can also stream from YouTube Music.**

[![Flutter](https://img.shields.io/badge/Flutter-3.47-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.13-0175C2?logo=dart&logoColor=white)](https://dart.dev)
[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](LICENSE)

Tunefrost plays the music already on your device. When a track isn't in your
library, search for it and stream it from YouTube Music — or download it for
offline listening. No account, no cloud library, no tracking.

## Features

- **Local library** — reads the audio already on your phone (songs, albums,
  artists, album art), with sorting and grouping.
- **YouTube Music search & streaming** — search either your local library or
  YouTube, and stream results directly. Stream URLs are cached so replays
  resolve fast.
- **Offline downloads** — save streamed tracks for playback without a connection.
- **Proper background playback** — gapless audio with lock-screen and
  notification controls that survive screen-off.
- **Playlists** — create, rename and delete; reorder the queue inline.
- **"Up next" queue** — reorderable, jump-to-any-track, and per-row removal.
  Swipe the now-playing artwork left or right to skip.
- **Playback controls** — shuffle, repeat modes and variable speed.
- **Equalizer** — wired to Android's system equalizer.
- **Opens with the system** — appears in the "Open with" chooser and can be set
  as the default music player; opening an audio file plays it.
- **Polished UI** — Zen Maru Gothic typography and hand-picked Lottie
  micro-interactions.

## Tech stack

| Concern           | Choice                                              |
| ----------------- | --------------------------------------------------- |
| State management  | Riverpod                                            |
| Audio             | `just_audio`, `just_audio_background`, `audio_session` |
| Local media scan  | `on_audio_query_pluse`                              |
| YouTube           | `youtube_explode_dart`                              |
| Platform audio    | `just_audio_media_kit`                              |
| Permissions       | `permission_handler`                                |
| Animations        | `lottie`                                            |

## Architecture

```
lib/
  app/        app shell, theme, route transitions
  audio/      playback service, YouTube audio source
  core/       models · providers · repositories · services · utils · widgets
  features/   home · library · playback · playlists · search · settings
  main.dart
```

Repositories own data access (`local_music_repository`,
`youtube_repository`, `playlist_repository`), services own long-lived
behaviour (`download_service`, `queue_storage`), and Riverpod providers glue
them to the UI. The audio playback service is a single source of truth for the
queue.

> The Dart package name is `music_player`; the shipped app is Tunefrost.

## Getting started

**Prerequisites:** [Flutter](https://docs.flutter.dev/get-started/install) 3.47+
and an Android device or emulator. Android is the primary target.

```bash
git clone https://github.com/lordhanya/tunefrost.git
cd tunefrost
flutter pub get
flutter run
```

### Regenerating launcher icons

The launcher icons are generated from the masters in `assets/icons/`. Only the
small brand mark is bundled at runtime; the 1024px masters are build-time
inputs only.

```bash
dart run flutter_launcher_icons
```

## Tests

Aimed at the pure logic — queue state and persistence, sorting, grouping,
formatting, presets and the stream-link cache:

```bash
flutter test        # 43 tests
flutter analyze
```

## Third-party notices

- **Typeface** — [Zen Maru Gothic](https://fonts.google.com/specimen/Zen+Maru+Gothic),
  SIL Open Font License.
- **Lottie icons** — a small hand-picked subset, vendored in `assets/lottie/`.
  Sources and licences are documented in
  [`assets/lottie/README.md`](assets/lottie/README.md); some are from icons8 and
  carry an attribution requirement.
- **YouTube** — Tunefrost is an independent project and is **not affiliated with,
  endorsed by, or connected to Google or YouTube**. Streaming and downloading
  content is done at your own risk and may be restricted by
  [YouTube's Terms of Service](https://www.youtube.com/t/terms) and local
  copyright law. Only access content you have the right to use.

## Privacy

Tunefrost collects no personal data — no accounts, no analytics, no ads, no
backend. See [`PRIVACY.md`](PRIVACY.md).

## License

Distributed under the [GNU General Public License v3.0](LICENSE).

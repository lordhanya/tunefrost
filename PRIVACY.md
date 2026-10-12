# Privacy Policy — Tunefrost

**Last updated: 12 October 2026**

## The short version

Tunefrost collects **no personal data**. There are no accounts, no analytics, no
crash reporters, no advertising SDKs, and no server operated by the developer
that receives anything from the app.

Everything the app stores stays on your device, and uninstalling removes it.

## What the app accesses

| Access                     | Why                                                                   |
| -------------------------- | --------------------------------------------------------------------- |
| Music files on your device | To list and play your library (songs, albums, artists) and album art  |
| Internet                   | To search and stream from YouTube Music                                |

## What is stored on your device

- App settings, kept in Android shared preferences.
- A small cache that maps YouTube video IDs to resolved stream URLs, so
  repeated plays resolve faster.
- Any audio you download, written to app storage.

None of this leaves the device.

## Third parties

**YouTube / Google.** When you search for or stream a track, the app makes
requests directly to YouTube to resolve stream URLs. That traffic goes to
Google, not to the developer, and is subject to
[Google's Privacy Policy](https://policies.google.com/privacy). The developer
cannot see, collect or retain it.

The "Developed by Ashif" entry in Settings opens `ashifcodes.tech` in your
browser. That is a link you choose to tap — the app makes no background request
to it.

## Permissions requested

- `READ_MEDIA_AUDIO`, `READ_MEDIA_IMAGES` — read your music library and album art.
- `READ_EXTERNAL_STORAGE`, `WRITE_EXTERNAL_STORAGE` — legacy storage access on
  older Android versions.
- `INTERNET` — streaming and search.
- `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_MEDIA_PLAYBACK`, `WAKE_LOCK`,
  `POST_NOTIFICATIONS` — background playback with lock-screen and notification
  controls.

## Children

Tunefrost is not directed at children under 13, and it knowingly collects no
personal information from anyone of any age.

## Changes

If this policy ever changes, the updated version will be published in this file
in the same repository.

## Contact

Questions? Find me at [ashifcodes.tech](https://ashifcodes.tech).

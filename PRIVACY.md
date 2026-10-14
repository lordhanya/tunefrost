# Privacy Policy — Tunefrost

**Last updated: 14 October 2026**

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
| Search phrases derived from your listening | To find new music — **only while Smart Play discovery is on**, which is off by default |

## What is stored on your device

- App settings, kept in Android shared preferences.
- A small cache that maps YouTube video IDs to resolved stream URLs, so
  repeated plays resolve faster.
- Any audio you download, written to app storage.
- A listening history for Smart Play: for each track, how long you actually
  listened, whether it played to the end, and whether you skipped it early.
  It is used only on your device to build your taste profile — a small set of
  artist and track scores, computed locally. Neither the history nor the
  profile is ever uploaded or shared. You can delete it at any time from
  **Settings → Data → Listening history**, which removes both the stored
  entries and the profile built from them.

All of it is stored on your device only.

## What Smart Play sends (optional, off by default)

Smart Play discovery is **off until you switch it on** — from
**Settings → Data → Smart Play discovery**, or the switch at the top of the
Smart Play screen.

When it is on, the app turns your taste profile into a few search queries —
at most four artist names at a time — and sends those phrases to the
discovery provider so it can find music you have not heard.

- **What is transmitted:** the search phrases themselves, derived from the
  artists you listen to.
- **What is never transmitted:** your listening history, play counts,
  favourites, scores, affinities, seed lists, or any other part of the taste
  profile. Only the derived query text leaves the device.
- **How often:** when you first open the Smart Play screen, and whenever you
  tap refresh. Nothing runs in the background.
- **Turning it off** stops the requests immediately; nothing is queued for a
  later retry.

## Third parties

**YouTube / Google.** When you search for or stream a track, the app makes
requests directly to YouTube to resolve stream URLs. When Smart Play
discovery is on, the artist-name phrases it derives from your listening go
to YouTube as search queries. All of that traffic goes to Google, not to the
developer, and is subject to
[Google's Privacy Policy](https://policies.google.com/privacy). The developer
cannot see, collect or retain it, and none of it carries your listening
history or taste profile.

To be precise about how those requests are made: the app reads YouTube's
public web pages rather than the official YouTube Data API, so there is no
authorized API relationship behind them. That is stated plainly here rather
than described as an official integration.

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

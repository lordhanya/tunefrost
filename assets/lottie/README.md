# Vendored Lottie icons

These four micro-interactions are copied out of the
[`flutter_animated_icons`](https://pub.dev/packages/flutter_animated_icons)
collection rather than depended on directly.

**Why vendored:** that package declares its entire library (2,461 files,
**79 MB**) in its pubspec `assets:`, and Flutter bundles every asset a
dependency declares. Depending on it would add ~79 MB to the app. We ship only
the animations we use — **~36 KB total**.

| File             | Source animation                          | Used for                     |
| ---------------- | ----------------------------------------- | ---------------------------- |
| `download.json`  | icons8.com `download_material_filled`    | download action              |
| `heart.json`     | useanimations.com `heart`                 | favourite toggle             |
| `trash.json`     | useanimations.com `trash`                 | delete actions               |
| `equalizer.json` | icons8.com `tune`                         | equalizer entry points       |

All are monochrome and are tinted at runtime (see
`lib/core/widgets/lottie_icon.dart`).

## Licensing

The `flutter_animated_icons` wrapper is MIT, but the animations themselves come
from third-party libraries with their own terms:

- **useanimations.com** — free, MIT-licensed animations.
- **icons8.com** — free with an attribution/"link back" requirement
  (<https://icons8.com/license>). `equalizer.json` (`tune`) and
  `download.json` (`download_material_filled`) are from here.

Replace or attribute `equalizer.json` and `download.json` before a public
release if you want to stay clear of the icons8 free-tier obligation.

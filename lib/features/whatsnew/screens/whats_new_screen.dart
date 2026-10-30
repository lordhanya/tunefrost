import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:music_player/features/whatsnew/providers/whats_new_provider.dart';
import 'package:music_player/features/whatsnew/release_notes.dart';

/// Copy for the note at the foot of the list, kept beside the screen that
/// shows it. It speaks for the release as much as the items above it: it is
/// the one thing a listener should know before switching Smart Play on.
const String _betaNoteTitle = 'A little beta note';
const String _betaNoteBody =
    'Smart Play is still learning, so recommendations may not always match '
    'your taste. Give it a try. It gets better as it learns from what you '
    'play. There\'s more to come!';

/// The release notes, laid over the library once after an update — and again
/// from Settings → About.
///
/// Deliberately not an app-bar screen: it arrives rather than being navigated
/// to, has exactly one way forward, and reads like a note rather than a place.
/// System back dismisses it too. Whether it was shown is already recorded by
/// the time it appears (see `whatsNewPlanProvider`), so no dismissal path has
/// to remember to write anything.
class WhatsNewScreen extends ConsumerWidget {
  const WhatsNewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final release = ref.watch(whatsNewReleaseProvider).value;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
          child: Column(
            children: [
              Expanded(
                // Scrollable for two reasons: system text scaling has to fit,
                // and a long release must never run under the button.
                child: Scrollbar(
                  child: ListView(
                    children: [
                      Center(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: Image.asset(
                            'assets/icons/brand_icon.png',
                            width: 76,
                            height: 76,
                          ),
                        ),
                      ),
                      const SizedBox(height: 26),
                      Text(
                        release == null
                            ? 'You are up to date.'
                            : 'A little something new.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          // Outfit is the brand's display face — headings and
                          // screen titles only, exactly as `appBarTheme`
                          // spells it for the rest of the app.
                          fontFamily: 'Outfit',
                          fontWeight: FontWeight.w600,
                          fontSize: 28,
                          height: 1.2,
                          color: scheme.onSurface,
                        ),
                      ),
                      if (release != null) ...[
                        const SizedBox(height: 10),
                        Text(
                          'Fresh in ${release.displayVersion}.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 15,
                            height: 1.5,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 30),
                        for (final item in release.items)
                          _ReleaseItem(item: item),
                        // The note travels with the list rather than sitting
                        // under it: the button is the one way forward, so the
                        // list is the part that gives way.
                        const SizedBox(height: 6),
                        if (release.beta) ...[
                          const _BetaNote(),
                          const SizedBox(height: 4),
                        ],
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () => Navigator.of(context).maybePop(),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
                child: Text(release == null ? 'Close' : 'Enjoy the update'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One note: an icon, what it is, and a sentence about it. Flat on the
/// background — the list is the structure, so nothing here needs a card.
class _ReleaseItem extends StatelessWidget {
  const _ReleaseItem({required this.item});

  final ReleaseNoteItem item;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(item.icon, size: 22, color: scheme.onPrimaryContainer),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontWeight: FontWeight.w600,
                    fontSize: 17,
                    height: 1.35,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  item.body,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.55,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The one thing the listener is asked to be patient about. Quieter than the
/// items above it on every axis: a wash of the surface instead of the flat
/// background, smaller type, and one dim icon instead of a chip of colour.
class _BetaNote extends StatelessWidget {
  const _BetaNote();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tone = scheme.onSurfaceVariant;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.science_outlined, size: 16, color: tone),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _betaNoteTitle,
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    height: 1.3,
                    color: tone,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            _betaNoteBody,
            style: TextStyle(fontSize: 13.5, height: 1.5, color: tone),
          ),
        ],
      ),
    );
  }
}

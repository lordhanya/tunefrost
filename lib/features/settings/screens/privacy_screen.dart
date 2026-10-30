import 'package:flutter/material.dart';

import 'package:music_player/core/widgets/glass.dart';

import '../../playback/widgets/mini_player.dart';

/// Plain-language privacy policy, kept in step with `PRIVACY.md`.
///
/// Tunefrost has no backend, so this is deliberately short: it states what the
/// app touches and where it stays.
class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top + kToolbarHeight;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;

    return Scaffold(
      extendBody: true,
      extendBodyBehindAppBar: true,
      appBar: glassAppBar(
        context,
        title: const Text('Privacy policy'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: Scrollbar(
        child: ListView(
          padding: EdgeInsets.only(
            top: topInset + 16,
            left: 20,
            right: 20,
            bottom: miniPlayerBottom(context, extra: 24),
          ),
          children: [
            Text(
              'Last updated 14 October 2026',
              style: TextStyle(color: muted, fontSize: 13),
            ),
            const SizedBox(height: 20),
            const _Section(
              title: 'The short version',
              body:
                  'Tunefrost collects no personal data. There are no accounts, '
                  'no analytics, no crash reporters, no advertising, and no '
                  'server run by the developer that receives anything from the '
                  'app. Everything it stores stays on your device, and '
                  'uninstalling removes it.',
            ),
            const _Section(
              title: 'What the app accesses',
              body:
                  '• Your music files, to list and play your library and show '
                  'album art.\n'
                  '• The internet, to search and stream from YouTube Music.\n'
                  '• Search phrases derived from your listening, only while '
                  'Smart Play discovery is on, which it is not by default.',
            ),
            const _Section(
              title: 'What is stored on your device',
              body:
                  '• App settings.\n'
                  '• A small cache that maps YouTube video ids to stream links, '
                  'so replays resolve faster.\n'
                  '• Any audio you choose to download.\n'
                  '• A listening history for Smart Play: how long you '
                  'listened, whether a track finished, and whether you '
                  'skipped it early. Also stored is the taste profile '
                  'computed from it on your device. Neither is ever uploaded '
                  'or shared, and you can delete both from Settings → Data → '
                  'Listening history.',
            ),
            const _Section(
              title: 'What Smart Play sends (off by default)',
              body:
                  'Smart Play discovery is off until you switch it on, in '
                  'Settings → Data → Smart Play discovery or from the switch '
                  'on the Smart Play screen.\n\n'
                  'When it is on, the app turns your taste profile into a '
                  'few search queries, at most four artist names at a time, '
                  'and sends those phrases to the discovery provider.\n\n'
                  '• Sent: the search phrases themselves.\n'
                  '• Never sent: your listening history, play counts, '
                  'favourites, scores, affinities, seed lists, or any other '
                  'part of the taste profile.\n'
                  '• When: the first time you open the screen, and whenever '
                  'you tap refresh. Nothing runs in the background, and '
                  'switching it off stops the requests at once.',
            ),
            const _Section(
              title: 'Third parties',
              body:
                  'When you search for or play a track, the app talks to '
                  'YouTube directly to resolve the stream, and when Smart '
                  'Play discovery is on it also sends the artist-name search '
                  'phrases described above. That traffic goes to Google, not '
                  'to the developer, and is governed by Google\'s own privacy '
                  'policy. None of it carries your listening history or '
                  'taste profile.\n\n'
                  'Those requests read YouTube\'s public web pages rather '
                  'than the official YouTube Data API, so there is no '
                  'authorized API relationship behind them. That is stated '
                  'plainly rather than described as an official '
                  'integration.\n\n'
                  'The "Developed by" entry in Settings opens a website in '
                  'your browser. The app makes no background request to it.',
            ),
            const _Section(
              title: 'Children',
              body:
                  'Tunefrost is not directed at children under 13, and it '
                  'knowingly collects no personal information from anyone.',
            ),
            const _Section(
              title: 'Changes',
              body:
                  'If this policy ever changes, the updated version ships with '
                  'the app.',
            ),
          ],
        ),
      ),
      bottomNavigationBar: const MiniPlayer(),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            body,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 14,
              height: 1.55,
            ),
          ),
        ],
      ),
    );
  }
}

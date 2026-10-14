import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:music_player/core/providers/smartplay_provider.dart';
import 'package:music_player/core/taste/candidate.dart';
import 'package:music_player/core/taste/title_metadata.dart';
import 'package:music_player/core/utils/format.dart';
import 'package:music_player/core/utils/haptics.dart';
import 'package:music_player/core/widgets/glass.dart';

import '../../playback/providers/playback_providers.dart';
import '../../playback/widgets/mini_player.dart';
import '../../playback/widgets/song_artwork.dart';

/// What Smart Play would queue, in order, before anything plays.
///
/// Phase 2 is inspection only: the list is inert. Playback starts from the
/// single explicit button at the bottom and only after a dialog states, in
/// plain words, that the current queue will be replaced. Nothing here ever
/// calls into the queue on its own.
class SmartPlayScreen extends ConsumerStatefulWidget {
  const SmartPlayScreen({super.key});

  @override
  ConsumerState<SmartPlayScreen> createState() => _SmartPlayScreenState();
}

class _SmartPlayScreenState extends ConsumerState<SmartPlayScreen> {
  @override
  void initState() {
    super.initState();
    // First frame only: never refresh on every rebuild, and never refresh
    // when discovery is switched off.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!ref.read(smartPlayDiscoveryEnabledProvider)) return;
      if (ref.read(smartPlayPreviewProvider).status == SmartPlayStatus.idle) {
        unawaited(ref.read(smartPlayPreviewProvider.notifier).refresh());
      }
    });
  }

  Future<void> _confirmPlay() async {
    final preview = ref.read(smartPlayPreviewProvider);
    if (preview.candidates.isEmpty) return;
    final queuedNow = ref.read(playbackStateProvider).value?.queue.length ?? 0;

    final songs = [
      for (final item in preview.candidates)
        item.candidate.toSong(
          artist: item.metadata.hasArtist ? item.metadata.artist : null,
        ),
    ];

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Replace the current queue?'),
        content: Text(
          'Smart Play will play these ${songs.length} songs as a new queue, '
          'replacing ${queuedNow == 0 ? 'your (currently empty) queue' : 'the $queuedNow song${queuedNow == 1 ? '' : 's'} in your queue'}.'
          '\n\nNothing was queued while you browsed, and nothing plays until '
          'you tap Play.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Replace and play'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    context.hapticSelect();
    unawaited(ref.read(audioPlayerProvider).playAll(songs));
  }

  @override
  Widget build(BuildContext context) {
    final enabled = ref.watch(smartPlayDiscoveryEnabledProvider);
    final preview = ref.watch(smartPlayPreviewProvider);
    final scheme = Theme.of(context).colorScheme;
    final topInset = MediaQuery.paddingOf(context).top + kToolbarHeight;

    final ready = enabled && preview.status == SmartPlayStatus.ready;

    return Scaffold(
      extendBody: true,
      extendBodyBehindAppBar: true,
      appBar: glassAppBar(
        context,
        title: const Text('Smart Play'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        actions: [
          if (enabled && preview.status != SmartPlayStatus.idle)
            IconButton(
              tooltip: 'Refresh suggestions',
              onPressed: preview.status == SmartPlayStatus.loading
                  ? null
                  : () {
                      context.hapticSelect();
                      unawaited(
                        ref.read(smartPlayPreviewProvider.notifier).refresh(),
                      );
                    },
              icon: preview.status == SmartPlayStatus.loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh_rounded),
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(20, topInset + 16, 20, 8),
            child: _Header(enabled: enabled, preview: preview, scheme: scheme),
          ),
          Expanded(child: _body(enabled, preview)),
        ],
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (ready)
            _PlayBar(count: preview.candidates.length, onPressed: _confirmPlay),
          const MiniPlayer(),
        ],
      ),
    );
  }

  Widget _body(bool enabled, SmartPlayPreview preview) {
    if (!enabled) {
      return _Panel(
        icon: Icons.lightbulb_outline_rounded,
        title: 'Discovery is off',
        message:
            'Smart Play can suggest songs you have not heard yet, using only '
            'what it knows about your listening. It needs to send searches '
            'based on that listening to do it.',
        actionLabel: 'Turn on discovery',
        onAction: () {
          context.hapticSelect();
          final enabledNotifier = ref.read(
            smartPlayDiscoveryEnabledProvider.notifier,
          );
          final previewNotifier = ref.read(smartPlayPreviewProvider.notifier);
          unawaited(
            enabledNotifier.set(true).then((_) => previewNotifier.refresh()),
          );
        },
      );
    }

    switch (preview.status) {
      case SmartPlayStatus.idle:
      case SmartPlayStatus.loading:
        return const Center(child: CircularProgressIndicator());
      case SmartPlayStatus.error:
        return _Panel(
          icon: Icons.cloud_off_rounded,
          title: 'Could not load suggestions',
          message: preview.message,
          actionLabel: 'Try again',
          onAction: _retry,
        );
      case SmartPlayStatus.empty:
        return _Panel(
          icon: Icons.history_toggle_off_rounded,
          title: 'Nothing to suggest yet',
          message: preview.message,
          actionLabel: 'Try again',
          onAction: _retry,
        );
      case SmartPlayStatus.ready:
        return ListView.builder(
          padding: EdgeInsets.only(bottom: miniPlayerBottom(context, extra: 8)),
          itemCount: preview.candidates.length,
          itemBuilder: (context, index) =>
              _CandidateTile(item: preview.candidates[index]),
        );
    }
  }

  void _retry() {
    context.hapticSelect();
    unawaited(ref.read(smartPlayPreviewProvider.notifier).refresh());
  }
}

class _Header extends ConsumerWidget {
  const _Header({
    required this.enabled,
    required this.preview,
    required this.scheme,
  });

  final bool enabled;
  final SmartPlayPreview preview;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = preview.stats;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.auto_awesome_rounded, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Discovery',
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            Switch(
              value: enabled,
              onChanged: (value) {
                context.hapticSelect();
                final enabledNotifier = ref.read(
                  smartPlayDiscoveryEnabledProvider.notifier,
                );
                final previewNotifier = ref.read(
                  smartPlayPreviewProvider.notifier,
                );
                unawaited(enabledNotifier.set(value));
                if (value) unawaited(previewNotifier.refresh());
              },
            ),
          ],
        ),
        Text(
          enabled
              ? 'Sends searches derived from your listening history to the '
                    'discovery provider. Nothing else about your history or your '
                    'taste profile leaves the device, and switching this off '
                    'stops the requests entirely.'
              : 'No requests are made while this is off.',
          style: TextStyle(
            color: scheme.onSurfaceVariant,
            fontSize: 12.5,
            height: 1.4,
          ),
        ),
        if (enabled && preview.status == SmartPlayStatus.ready) ...[
          const SizedBox(height: 8),
          Text(
            'Searched: ${preview.seeds.join(', ')}',
            style: TextStyle(
              color: scheme.onSurfaceVariant,
              fontSize: 11.5,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _Stat('${stats.seedCount} seeds'),
              _Stat('${stats.rawCount} found'),
              if (stats.excludedCount > 0)
                _Stat('${stats.excludedCount} filtered'),
              if (stats.duplicateCount > 0)
                _Stat('${stats.duplicateCount} duplicates'),
              _Stat(
                '${stats.resolvedArtistCount} by artist, '
                '${preview.candidates.length - stats.resolvedArtistCount} by channel',
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant),
      ),
    );
  }
}

class _CandidateTile extends StatelessWidget {
  const _CandidateTile({required this.item});

  final RankedCandidate item;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final candidate = item.candidate;
    final metadata = item.metadata;
    final artist = metadata.hasArtist ? metadata.artist : candidate.author;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      leading: SongArtwork(
        song: candidate.toSong(
          artist: metadata.hasArtist ? metadata.artist : null,
        ),
        dimension: 46,
        querySize: 120,
      ),
      title: Text(
        candidate.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: scheme.onSurface),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 2),
          Row(
            children: [
              Flexible(
                child: Text(
                  artist,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              _Confidence(confidence: metadata.confidence),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            _reason(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 11.5),
          ),
        ],
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            formatDuration(Duration(milliseconds: candidate.durationMs)),
            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
          ),
          Text(
            _views(candidate.viewCount),
            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 11),
          ),
        ],
      ),
    );
  }

  String _reason() {
    final byArtist = item.metadata.hasArtist;
    final seed = item.signals['seed'] ?? 0;
    final affinity = item.signals['affinity'] ?? 0;

    // At most one preference claim, and never a positive one for an identity
    // the profile records as rejected: querying something and liking it are
    // separate facts.
    var preference = '';
    if (seed > 0 && affinity >= 0) {
      preference = byArtist
          ? 'one of your top artists'
          : 'from a source you keep coming back to';
    } else if (affinity > 0.05) {
      preference = byArtist
          ? 'you keep coming back to this artist'
          : 'you keep coming back to this channel';
    }

    final parts = <String>[
      if (item.metadata.versionMarkers.isNotEmpty)
        _variantLabel(item.metadata.versionMarkers),
      if (preference.isNotEmpty) preference,
    ];
    if (parts.isEmpty) return _views(item.candidate.viewCount);
    return parts.join(' · ');
  }
}

/// Version markers are shown as they were detected, not as an opinion: a
/// listener who wants a live take can see it is one before playing.
String _variantLabel(Set<String> markers) {
  final ordered = markers.toList()..sort();
  return ordered.join(' · ');
}

class _Confidence extends StatelessWidget {
  const _Confidence({required this.confidence});

  final ArtistConfidence confidence;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (label, color, tip) = switch (confidence) {
      ArtistConfidence.high => (
        'artist identified',
        scheme.primary,
        'Confirmed against a name Smart Play already knows or a '
            'YouTube auto-generated artist page.',
      ),
      ArtistConfidence.medium => (
        'artist inferred',
        scheme.tertiary,
        'Derived from the title agreeing with the uploading channel — '
            'likely right, not certain.',
      ),
      ArtistConfidence.none => (
        'channel',
        scheme.outline,
        'No performer could be trusted from the title, so the name shown is '
            'the uploading channel. For streamed music that is the identity '
            'your preferences are actually recorded against, so it is what '
            'ranking matches on.',
      ),
    };

    return Tooltip(
      message: tip,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          border: Border.all(color: color.withValues(alpha: 0.5)),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(label, style: TextStyle(fontSize: 10, color: color)),
      ),
    );
  }
}

class _PlayBar extends StatelessWidget {
  const _PlayBar({required this.count, required this.onPressed});

  final int count;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
        child: FilledButton.icon(
          onPressed: onPressed,
          icon: const Icon(Icons.queue_music_rounded),
          label: Text('Play $count song${count == 1 ? '' : 's'}'),
        ),
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({
    required this.icon,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(32, 0, 32, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 44, color: scheme.onSurfaceVariant),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: scheme.onSurfaceVariant,
                fontSize: 13.5,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 18),
            FilledButton(onPressed: onAction, child: Text(actionLabel)),
          ],
        ),
      ),
    );
  }
}

String _views(int count) {
  if (count <= 0) return 'no view count';
  if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M views';
  if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K views';
  return '$count views';
}

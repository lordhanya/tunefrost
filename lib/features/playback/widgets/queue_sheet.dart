import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:music_player/core/utils/haptics.dart';

import '../providers/playback_providers.dart';

/// Apple-Music-style "Up next" sheet: reorderable queue with jump-to,
/// per-row remove, and a clear action for everything after the current song.
void showQueueSheet(BuildContext context) {
  final scheme = Theme.of(context).colorScheme;
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: scheme.surface,
    isScrollControlled: true,
    showDragHandle: true,
    // Flutter's stock sheet is 250ms of `Easing.legacyDecelerate`, which is at
    // full speed on the very first frame — it reads as a pop rather than a
    // slide. Give it a longer, eased-in curve so the sheet rises and settles.
    sheetAnimationStyle: const AnimationStyle(
      duration: Duration(milliseconds: 400),
      curve: Curves.easeInOutCubic,
      reverseDuration: Duration(milliseconds: 320),
      reverseCurve: Curves.easeInOutCubic,
    ),
    builder: (sheetContext) => SizedBox(
      height: MediaQuery.sizeOf(sheetContext).height * 0.65,
      child: const _QueueSheet(),
    ),
  );
}

class _QueueSheet extends ConsumerWidget {
  const _QueueSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(playbackStateProvider).value;
    final queue = state?.queue ?? const [];
    final current = state?.currentIndex ?? -1;
    final scheme = Theme.of(context).colorScheme;

    if (queue.isEmpty) {
      return Center(
        child: Text(
          'Queue is empty',
          style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 15),
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 16, 8),
          child: Row(
            children: [
              Text('Up next', style: Theme.of(context).textTheme.titleMedium),
              const Spacer(),
              if (current < queue.length - 1)
                TextButton(
                  onPressed: () {
                    context.hapticLight();
                    ref.read(audioPlayerProvider).clearUpcoming();
                  },
                  child: const Text('Clear'),
                ),
            ],
          ),
        ),
        Expanded(
          child: ReorderableListView.builder(
            padding: const EdgeInsets.only(bottom: 16),
            itemCount: queue.length,
            onReorderItem: (from, to) {
              context.hapticMedium();
              ref.read(audioPlayerProvider).moveInQueue(from, to);
            },
            itemBuilder: (context, index) {
              final song = queue[index];
              final isCurrent = index == current;
              return ColoredBox(
                key: ValueKey('queue-$index-${song.id}'),
                color: isCurrent
                    ? scheme.primary.withValues(alpha: 0.08)
                    : Colors.transparent,
                child: ListTile(
                  dense: true,
                  leading: SizedBox(
                    width: 28,
                    child: isCurrent
                        ? Icon(
                            Icons.play_arrow_rounded,
                            color: scheme.primary,
                            size: 22,
                          )
                        : Text(
                            '${index + 1}',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: scheme.onSurfaceVariant,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                  ),
                  title: Text(
                    song.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isCurrent ? scheme.primary : scheme.onSurface,
                    ),
                  ),
                  subtitle: Text(
                    song.artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.remove_circle_outline_rounded,
                          size: 20,
                        ),
                        color: scheme.onSurfaceVariant,
                        visualDensity: VisualDensity.compact,
                        onPressed: () {
                          context.hapticLight();
                          ref.read(audioPlayerProvider).removeFromQueue(index);
                        },
                      ),
                      ReorderableDragStartListener(
                        index: index,
                        child: Icon(
                          Icons.drag_indicator_rounded,
                          color: scheme.onSurfaceVariant,
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                  onTap: () {
                    context.hapticSelect();
                    ref.read(audioPlayerProvider).jumpTo(index);
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

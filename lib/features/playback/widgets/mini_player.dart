import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:music_player/app/transitions.dart';
import 'package:music_player/core/models/queue_state.dart';
import 'package:music_player/core/utils/format.dart';
import 'package:music_player/core/utils/haptics.dart';
import 'package:music_player/core/widgets/marquee_text.dart';

import '../providers/playback_providers.dart';
import 'song_artwork.dart';

/// Height of the frosted mini-player shelf, excluding the system gesture
/// inset (the shelf itself absorbs that below its content). Scroll bodies
/// that extend behind the shelf pad their bottom with [miniPlayerBottom].
const double kMiniPlayerBarHeight = 66;

/// Bottom padding a scroll body needs so its last row never hides under the
/// frosted mini player. Requires the host Scaffold to set `extendBody: true`.
double miniPlayerBottom(BuildContext context, {double extra = 16}) =>
    MediaQuery.paddingOf(context).bottom + kMiniPlayerBarHeight + extra;

/// Persistent slim bar shown at the bottom of the browsing screens.
/// Tapping it opens [NowPlayingScreen]; it disappears when nothing plays.
/// Swiping left/right on it skips tracks.
class MiniPlayer extends ConsumerWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final song = ref.watch(currentSongProvider);
    if (song == null) {
      return const AnimatedSize(
        duration: Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
        child: SizedBox(width: double.infinity),
      );
    }

    return AnimatedSize(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 280),
        switchInCurve: Curves.easeOutCubic,
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.4),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        ),
        child: _MiniPlayerContent(key: ValueKey(song.id)),
      ),
    );
  }
}

class _MiniPlayerContent extends ConsumerWidget {
  const _MiniPlayerContent({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(playbackStateProvider).value;
    final song = state?.currentSong;
    if (state == null || song == null) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    void skip(int direction) {
      context.hapticMedium();
      final player = ref.read(audioPlayerProvider);
      if (direction > 0) {
        player.playNext();
      } else {
        player.playPrevious();
      }
    }

    // Frosted shelf: the body scrolls beneath it (extendBody) and the blur
    // shows it through. The blur lives as a *sibling behind* the controls,
    // never as their parent — when the BackdropFilter wraps the content it
    // can paint its blurred backdrop over the child (a known Flutter
    // pitfall) and the bar renders as an empty solid block.
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      child: Stack(
        children: [
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                decoration: BoxDecoration(
                  color: scheme.surface.withValues(alpha: isDark ? 0.38 : 0.52),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16),
                  ),
                  border: Border.all(
                    color: scheme.outlineVariant.withValues(alpha: 0.45),
                    width: 0.7,
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const _MiniProgress(),
                GestureDetector(
                  onHorizontalDragEnd: (details) {
                    final delta = details.primaryVelocity ?? 0;
                    if (delta.abs() < 150) return;
                    skip(delta < 0 ? 1 : -1);
                  },
                  child: Material(
                    type: MaterialType.transparency,
                    child: InkWell(
                      onTap: () {
                        context.hapticLight();
                        openNowPlaying(context);
                      },
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
                        child: Row(
                          children: [
                            SongArtwork(
                              song: song,
                              dimension: 44,
                              querySize: 120,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  MarqueeText(
                                    song.title,
                                    style: TextStyle(
                                      color: scheme.onSurface,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    song.artist,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: scheme.onSurfaceVariant,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const _MiniPositionLabel(),
                            IconButton(
                              icon: _MiniTransportIcon(
                                state.playbackState,
                                scheme.primary,
                              ),
                              color: scheme.primary,
                              iconSize: 32,
                              onPressed: () {
                                context.hapticMedium();
                                ref.read(audioPlayerProvider).togglePlay();
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
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

/// Play/pause glyph that swaps to a spinner while the track buffers, so a
/// tap that takes a second to start playing doesn't read as "broken".
class _MiniTransportIcon extends StatelessWidget {
  const _MiniTransportIcon(this.playback, this.color);

  final PlaybackState playback;
  final Color color;

  @override
  Widget build(BuildContext context) {
    if (playback == PlaybackState.buffering) {
      return SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(strokeWidth: 2.5, color: color),
      );
    }
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 180),
      switchInCurve: Curves.easeOutCubic,
      transitionBuilder: (child, animation) =>
          ScaleTransition(scale: animation, child: child),
      child: Icon(
        playback == PlaybackState.playing
            ? Icons.pause_rounded
            : Icons.play_arrow_rounded,
        key: ValueKey<bool>(playback == PlaybackState.playing),
        size: 32,
        color: color,
      ),
    );
  }
}

/// 2px hairline across the top of the bar. Isolated so only this sliver
/// rebuilds on the position stream.
class _MiniProgress extends ConsumerWidget {
  const _MiniProgress();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final position = ref.watch(positionProvider).value ?? Duration.zero;
    final duration = ref.watch(durationProvider).value ?? Duration.zero;
    final progress = duration > Duration.zero
        ? (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;

    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: 2,
      child: ColoredBox(
        color: scheme.secondaryContainer,
        child: FractionallySizedBox(
          widthFactor: progress,
          alignment: Alignment.centerLeft,
          child: ColoredBox(color: scheme.primary),
        ),
      ),
    );
  }
}

class _MiniPositionLabel extends ConsumerWidget {
  const _MiniPositionLabel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final position = ref.watch(positionProvider).value ?? Duration.zero;
    return Text(
      formatDuration(position),
      style: TextStyle(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        fontSize: 11,
      ),
    );
  }
}

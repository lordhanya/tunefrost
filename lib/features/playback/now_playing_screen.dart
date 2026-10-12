import 'dart:async';
import 'dart:math' as math;

import 'package:collection/collection.dart';
import 'package:flutter/material.dart' hide RepeatMode;
import 'package:flutter/physics.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:music_player/core/models/queue_state.dart';
import 'package:music_player/core/models/song.dart';
import 'package:music_player/core/providers/play_history_provider.dart';
import 'package:music_player/core/utils/format.dart';
import 'package:music_player/core/utils/haptics.dart';
import 'package:music_player/core/widgets/animated_download_icon.dart';
import 'package:music_player/core/widgets/glass.dart';
import 'package:music_player/core/widgets/lottie_icon.dart';
import 'package:music_player/core/widgets/marquee_text.dart';
import 'package:music_player/core/widgets/press_scale.dart';

import '../library/providers/downloads_provider.dart';
import '../library/widgets/song_actions_sheet.dart';
import 'providers/playback_providers.dart';
import 'widgets/queue_sheet.dart';
import 'widgets/song_artwork.dart';

class NowPlayingScreen extends ConsumerWidget {
  const NowPlayingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playbackAsync = ref.watch(playbackStateProvider);
    final song = ref.watch(currentSongProvider);
    final favoriteIds = ref.watch(favoriteIdsProvider);
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final topInset = MediaQuery.paddingOf(context).top + kToolbarHeight;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: glassAppBar(
        context,
        title: const Text('Now playing'),
        leading: IconButton(
          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 30),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        actions: [
          if (song != null) ...[
            IconButton(
              icon: favoriteIds.contains(song.id)
                  ? const LottieIcon(LottieAssets.heart)
                  : const Icon(Icons.favorite_border_rounded),
              color: favoriteIds.contains(song.id)
                  ? Theme.of(context).colorScheme.primary
                  : null,
              tooltip: favoriteIds.contains(song.id)
                  ? 'Remove from favourites'
                  : 'Add to favourites',
              onPressed: () {
                context.hapticMedium();
                ref.read(favoritesProvider.notifier).toggle(song);
              },
            ),
            _DownloadButton(song: song),
          ],
          IconButton(
            icon: const Icon(Icons.queue_music_rounded),
            tooltip: 'Queue',
            onPressed: () {
              context.hapticLight();
              showQueueSheet(context);
            },
          ),
        ],
      ),
      body: Padding(
        padding: EdgeInsets.only(top: topInset),
        child: playbackAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => Center(
            child: Text(
              'Playback unavailable',
              style: TextStyle(color: muted, fontSize: 15),
            ),
          ),
          data: (state) {
            final current = state.currentSong;
            if (current == null) {
              return Center(
                child: Text(
                  'Nothing is playing',
                  style: TextStyle(color: muted, fontSize: 15),
                ),
              );
            }
            return _NowPlayingBody(state: state);
          },
        ),
      ),
    );
  }
}

/// App-bar action mirroring the song menu's download entry: starts a
/// download for a YouTube song, shows live progress with a tap-to-cancel,
/// retries on failure, and turns into a tap-to-delete once saved. Hidden
/// entirely for plain local-library songs (nothing to download).
///
/// A tap also plays the drop-into-tray animation once. That glyph keeps the
/// slot for the length of the pass and the real download state then takes
/// over — the animation acknowledges the tap, it never claims the download
/// reached any particular state.
class _DownloadButton extends ConsumerStatefulWidget {
  const _DownloadButton({required this.song});

  final Song song;

  @override
  ConsumerState<_DownloadButton> createState() => _DownloadButtonState();
}

class _DownloadButtonState extends ConsumerState<_DownloadButton> {
  /// Bumped to play one pass of the download animation.
  int _plays = 0;

  /// Holds the slot from the tap until that pass settles.
  bool _acknowledging = false;

  /// Fallback if the composition never reports completion (e.g. it failed to
  /// load), so the button can never get stuck on the acknowledgement frame.
  Timer? _ackWatchdog;

  @override
  void didUpdateWidget(covariant _DownloadButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.song.id != widget.song.id) {
      _ackWatchdog?.cancel();
      _ackWatchdog = null;
      _acknowledging = false;
      _plays = 0;
    }
  }

  @override
  void dispose() {
    _ackWatchdog?.cancel();
    super.dispose();
  }

  void _start() {
    if (_acknowledging) return; // a repeat tap must not restart the pass
    setState(() {
      _acknowledging = true;
      _plays++;
    });
    _ackWatchdog?.cancel();
    _ackWatchdog = Timer(const Duration(milliseconds: 1800), _endAcknowledge);
    ref.read(downloadsProvider.notifier).start(widget.song);
  }

  void _endAcknowledge() {
    _ackWatchdog?.cancel();
    _ackWatchdog = null;
    if (!mounted || !_acknowledging) return;
    setState(() => _acknowledging = false);
  }

  @override
  Widget build(BuildContext context) {
    final song = widget.song;
    final downloads = ref.watch(downloadsProvider);
    final scheme = Theme.of(context).colorScheme;
    final videoId = song.videoId;
    if (!song.isDownload && videoId == null) {
      return const SizedBox.shrink();
    }
    final notifier = ref.read(downloadsProvider.notifier);

    if (_acknowledging) {
      return IconButton(
        tooltip: 'Downloading…',
        onPressed: null,
        icon: AnimatedDownloadIcon(
          trigger: _plays,
          color: scheme.primary,
          onCompleted: _endAcknowledge,
        ),
      );
    }

    if (videoId != null && downloads.active.contains(videoId)) {
      return IconButton(
        tooltip: 'Cancel download',
        onPressed: () => notifier.cancel(videoId),
        icon: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            color: scheme.primary,
          ),
        ),
      );
    }

    if (videoId != null && downloads.failed.contains(videoId)) {
      return IconButton(
        tooltip: 'Download failed — try again',
        onPressed: () => notifier.start(song),
        color: scheme.error,
        icon: const Icon(Icons.error_outline_rounded, size: 24),
      );
    }

    final saved =
        song.isDownload ||
        (videoId != null &&
            downloads.songs.any((s) => s.sourceVideoId == videoId));
    if (saved) {
      return IconButton(
        tooltip: 'Delete download',
        onPressed: () async {
          context.hapticMedium();
          final copy = downloads.songs.firstWhereOrNull(
            (s) => s.sourceVideoId == song.sourceVideoId,
          );
          await notifier.remove(copy ?? song);
          if (context.mounted) {
            showAppSnack(context, 'Download deleted');
          }
        },
        color: scheme.primary,
        icon: const Icon(Icons.download_done_rounded, size: 24),
      );
    }

    return IconButton(
      tooltip: 'Download',
      onPressed: () {
        context.hapticLight();
        _start();
      },
      icon: AnimatedDownloadIcon(trigger: _plays),
    );
  }
}

class _NowPlayingBody extends ConsumerWidget {
  const _NowPlayingBody({required this.state});

  final QueueState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final song = state.currentSong!;
    final scheme = Theme.of(context).colorScheme;
    final player = ref.read(audioPlayerProvider);

    return SafeArea(
      top: false,
      child: Column(
        children: [
          const SizedBox(height: 12),
          // The artwork + metadata travel together and respond to a horizontal
          // swipe (see _SwipeSkipPane). The seek row below is deliberately left
          // out so its own drag never contests this one in the gesture arena.
          Expanded(
            child: _SwipeSkipPane(
              trackId: song.id,
              canNext: state.hasNext,
              canPrevious: state.hasPrevious,
              onNext: () => player.playNext(),
              onPrevious: () => player.playPrevious(),
              // Flex slot: the artwork absorbs whatever height the fixed
              // controls leave over, so short windows shrink the cover instead
              // of overflowing the column. It is centred so tall screens stay
              // square.
              child: Column(
                children: [
                  Expanded(
                    child: Center(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final size = math.min(
                            (constraints.maxWidth - 56).clamp(220.0, 340.0),
                            constraints.maxHeight,
                          );
                          return Hero(
                            tag: 'artwork-${song.id}',
                            child: SongArtwork(
                              song: song,
                              dimension: size,
                              radius: 16,
                              querySize: 600,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Column(
                      children: [
                        MarqueeText(
                          song.title,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: scheme.onSurface,
                            fontSize: 22,
                            fontWeight: FontWeight.w500, // Medium: song name
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          song.artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: scheme.primary,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          const _SeekSlider(),
          const SizedBox(height: 4),
          _TransportControls(state: state),
          const _PlaybackModifiers(),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

/// Swipe-to-skip over the artwork and its metadata.
///
/// The pane tracks the finger 1:1 and rubber-bands at the ends of the queue.
/// On release it is handed to a critically damped spring seeded with the
/// finger's real release velocity, so there is no velocity discontinuity at the
/// instant the finger lifts.
///
/// A committed swipe deliberately does *not* spring back to the centre: that
/// would fling the outgoing track home and only then hard-cut to the new one,
/// because [onNext]/[onPrevious] reach the UI through an async seek. Instead
/// the pane exits off-screen in the swipe direction and, once the track
/// actually changes (see [trackId]), the incoming track slides in from the
/// opposite edge.
///
/// Only ever sits above the seek row: wrapping the whole column here would put
/// a horizontal drag recognizer in the same arena as the slider's own and one
/// of the two would silently lose every swipe.
class _SwipeSkipPane extends StatefulWidget {
  const _SwipeSkipPane({
    required this.child,
    required this.trackId,
    required this.canNext,
    required this.canPrevious,
    required this.onNext,
    required this.onPrevious,
  });

  final Widget child;

  /// Identity of the track on screen. A change is the signal that a committed
  /// skip actually landed.
  final String trackId;

  /// Whether there is a track to skip to in each direction.
  final bool canNext;
  final bool canPrevious;

  final VoidCallback onNext;
  final VoidCallback onPrevious;

  @override
  State<_SwipeSkipPane> createState() => _SwipeSkipPaneState();
}

/// Where the pane is in its movement cycle.
enum _SwipePhase {
  /// Parked on centre with nothing running: no ticker, no extra layer.
  idle,

  /// The finger owns the pane.
  following,

  /// Springing back to centre after an abandoned or rejected swipe.
  returning,

  /// Flung off-screen after a committed swipe, waiting for the track change.
  exiting,

  /// The new track arriving from the far edge.
  entering,
}

class _SwipeSkipPaneState extends State<_SwipeSkipPane>
    with SingleTickerProviderStateMixin {
  /// Fraction of the screen width the pane must travel to commit a skip.
  static const double _commitFraction = 0.25;

  /// Horizontal fling speed (px/s) that commits without a long drag.
  static const double _flingVelocity = 700;

  /// Dampens the drag where there's no track to move to, so hitting the end of
  /// the queue feels like pushing against something instead of breaking.
  static const double _rubberBand = 0.25;

  /// Critically damped (ratio 1): reaches its target without overshooting or
  /// bouncing, so the pane feels weighted rather than elastic.
  static final SpringDescription _spring = SpringDescription.withDampingRatio(
    mass: 1,
    stiffness: 300,
    ratio: 1,
  );

  late final Ticker _ticker;

  Simulation? _simulation;
  _SwipePhase _phase = _SwipePhase.idle;

  /// Live offset in logical pixels, and always the value actually on screen —
  /// which is what lets a finger take over mid-flight without jumping.
  double _dx = 0;

  /// Sign of the committed swipe, so the incoming track knows which edge to
  /// arrive from.
  double _commitSign = 0;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
  }

  @override
  void dispose() {
    // SingleTickerProviderStateMixin asserts its ticker is inactive by the time
    // the state is disposed, so a pane animating when the screen closes must
    // stop it explicitly.
    _simulation = null;
    _ticker.stop();
    super.dispose();
  }

  double get _viewportWidth => MediaQuery.sizeOf(context).width;

  void _onTick(Duration elapsed) {
    final sim = _simulation;
    if (sim == null) return;
    final seconds = elapsed.inMicroseconds / Duration.microsecondsPerSecond;
    _dx = sim.x(seconds);
    final done = sim.isDone(seconds);
    if (done) {
      _simulation = null;
      _ticker.stop();
    }
    setState(() {});
    // Kicking off the follow-up spring from inside the tick callback would
    // restart the ticker mid-frame, so defer it to the next microtask.
    if (done) scheduleMicrotask(_onSettled);
  }

  void _onSettled() {
    if (!mounted) return;
    switch (_phase) {
      case _SwipePhase.returning:
      case _SwipePhase.entering:
        // Snap out the sub-pixel remainder so the idle path renders the bare
        // child rather than keeping a Transform layer alive.
        setState(() {
          _dx = 0;
          _phase = _SwipePhase.idle;
        });
      case _SwipePhase.exiting:
        // No track change ever arrived: the skip did not land (the queue was
        // really at its end, or `playPrevious` restarted the current track).
        // Bring the pane back rather than stranding it over a stale track.
        _phase = _SwipePhase.returning;
        _springTo(0, velocity: 0);
      case _SwipePhase.idle:
      case _SwipePhase.following:
        _phase = _SwipePhase.idle;
    }
  }

  void _springTo(double target, {required double velocity}) {
    _ticker.stop();
    _simulation = SpringSimulation(_spring, _dx, target, velocity);
    _ticker.start();
  }

  void _returnToCenter({required double velocity}) {
    if (_dx == 0 && velocity == 0) {
      _phase = _SwipePhase.idle;
      return;
    }
    _phase = _SwipePhase.returning;
    _springTo(0, velocity: velocity);
  }

  void _exitOffScreen(double velocity) {
    _commitSign = _dx < 0 ? -1 : 1;
    _phase = _SwipePhase.exiting;
    _springTo(_commitSign * _viewportWidth, velocity: velocity);
  }

  void _onStart(DragStartDetails d) {
    // Take the pane wherever the spring left it: _dx already holds the on-screen
    // position, so the finger picks it up without a jump.
    _simulation = null;
    _ticker.stop();
    _phase = _SwipePhase.following;
  }

  void _onUpdate(DragUpdateDetails d) {
    var delta = d.primaryDelta ?? 0;
    if ((delta < 0 && !widget.canNext) || (delta > 0 && !widget.canPrevious)) {
      delta *= _rubberBand;
    }
    setState(() => _dx += delta);
  }

  void _onEnd(DragEndDetails d) {
    final velocity = d.primaryVelocity ?? 0;
    final commit = _viewportWidth * _commitFraction;

    // A committed drag wins outright; a fling only counts when the pane
    // wasn't already being pushed the other way.
    final toNext = _dx <= -commit || (velocity <= -_flingVelocity && _dx <= 0);
    final toPrevious = _dx >= commit || (velocity >= _flingVelocity && _dx >= 0);

    if (toNext && widget.canNext) {
      context.hapticMedium();
      widget.onNext();
      _exitOffScreen(velocity);
    } else if (toPrevious && widget.canPrevious) {
      context.hapticMedium();
      widget.onPrevious();
      _exitOffScreen(velocity);
    } else {
      // Rejected, or rubber-banded off the end of the queue: pass the release
      // velocity straight to the spring so it leaves the finger continuously.
      _returnToCenter(velocity: velocity);
    }
  }

  @override
  void didUpdateWidget(covariant _SwipeSkipPane oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.trackId == oldWidget.trackId) return;
    if (_phase != _SwipePhase.exiting) return;
    // The skip landed while the outgoing track was still flying. Park the new
    // track on the far edge and let it spring in, instead of letting it hard-cut
    // into the centre. No setState: this element is mid-rebuild anyway.
    _commitSign = -_commitSign;
    _dx = _commitSign * _viewportWidth;
    _phase = _SwipePhase.entering;
    _springTo(0, velocity: 0);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragStart: _onStart,
      onHorizontalDragUpdate: _onUpdate,
      onHorizontalDragEnd: _onEnd,
      onHorizontalDragCancel: () => _returnToCenter(velocity: 0),
      // Idle renders the bare child: no Transform, no compositing layer.
      child: _dx == 0
          ? widget.child
          : Transform.translate(offset: Offset(_dx, 0), child: widget.child),
    );
  }
}

/// Elapsed / remaining slider. Watches the position and duration streams
/// directly so only this widget rebuilds while a track is playing.
class _SeekSlider extends ConsumerStatefulWidget {
  const _SeekSlider();

  @override
  ConsumerState<_SeekSlider> createState() => _SeekSliderState();
}

class _SeekSliderState extends ConsumerState<_SeekSlider> {
  double? _dragValue;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final position = ref.watch(positionProvider).value ?? Duration.zero;
    final duration = ref.watch(durationProvider).value ?? Duration.zero;
    final timeStyle = TextStyle(
      color: scheme.onSurfaceVariant,
      fontSize: 12,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    final maxMs = duration.inMilliseconds;
    final hasDuration = maxMs > 0;
    final elapsedMs = (_dragValue ?? position.inMilliseconds.toDouble()).clamp(
      0.0,
      hasDuration ? maxMs.toDouble() : 1.0,
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Slider(
          value: hasDuration ? elapsedMs : 0,
          min: 0,
          max: hasDuration ? maxMs.toDouble() : 1,
          onChanged: hasDuration ? (v) => setState(() => _dragValue = v) : null,
          onChangeStart: hasDuration ? (_) => context.hapticLight() : null,
          onChangeEnd: hasDuration
              ? (v) {
                  context.hapticMedium();
                  ref
                      .read(audioPlayerProvider)
                      .seek(Duration(milliseconds: v.round()));
                  setState(() => _dragValue = null);
                }
              : null,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                formatDuration(Duration(milliseconds: elapsedMs.round())),
                style: timeStyle,
              ),
              Text(
                '-${formatDuration(Duration(milliseconds: (maxMs - elapsedMs.round()).clamp(0, maxMs)))}',
                style: timeStyle,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TransportControls extends ConsumerWidget {
  const _TransportControls({required this.state});

  final QueueState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final player = ref.read(audioPlayerProvider);
    final buffering = state.playbackState == PlaybackState.buffering;
    final shuffleOn = state.shuffleMode != ShuffleMode.off;
    final repeatOn = state.repeatMode != RepeatMode.off;
    final position = ref.watch(positionProvider).value ?? Duration.zero;

    final canGoBack =
        state.hasPrevious || repeatOn || position > const Duration(seconds: 3);
    final canGoForward =
        state.hasNext || repeatOn || shuffleOn || state.queue.length > 1;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          PressScale(
            child: IconButton(
              icon: Icon(
                shuffleOn ? Icons.shuffle_on_rounded : Icons.shuffle_rounded,
              ),
              iconSize: 28,
              color: shuffleOn ? scheme.primary : scheme.onSurfaceVariant,
              onPressed: () {
                context.hapticSelect();
                player.toggleShuffle();
              },
            ),
          ),
          PressScale(
            child: IconButton(
              icon: const Icon(Icons.skip_previous_rounded),
              iconSize: 44,
              color: scheme.onSurface.withValues(alpha: canGoBack ? 1 : 0.38),
              onPressed: canGoBack
                  ? () {
                      context.hapticLight();
                      player.playPrevious();
                    }
                  : null,
            ),
          ),
          PressScale(
            scale: 0.9,
            child: Material(
              color: scheme.primary,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () {
                  context.hapticMedium();
                  player.togglePlay();
                },
                child: SizedBox.square(
                  dimension: 64,
                  child: Center(
                    child: buffering
                        ? SizedBox(
                            width: 26,
                            height: 26,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: scheme.onPrimary,
                            ),
                          )
                        : AnimatedSwitcher(
                            duration: const Duration(milliseconds: 180),
                            switchInCurve: Curves.easeOutCubic,
                            transitionBuilder: (child, animation) =>
                                ScaleTransition(
                                  scale: animation,
                                  child: FadeTransition(
                                    opacity: animation,
                                    child: child,
                                  ),
                                ),
                            child: Icon(
                              state.playbackState == PlaybackState.playing
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                              key: ValueKey(
                                state.playbackState == PlaybackState.playing,
                              ),
                              size: 38,
                              color: scheme.onPrimary,
                            ),
                          ),
                  ),
                ),
              ),
            ),
          ),
          PressScale(
            child: IconButton(
              icon: const Icon(Icons.skip_next_rounded),
              iconSize: 44,
              color: scheme.onSurface.withValues(
                alpha: canGoForward ? 1 : 0.38,
              ),
              onPressed: canGoForward
                  ? () {
                      context.hapticLight();
                      player.playNext();
                    }
                  : null,
            ),
          ),
          PressScale(
            child: IconButton(
              icon: Icon(
                state.repeatMode == RepeatMode.one
                    ? Icons.repeat_one_rounded
                    : Icons.repeat_rounded,
              ),
              iconSize: 28,
              color: repeatOn ? scheme.primary : scheme.onSurfaceVariant,
              onPressed: () {
                context.hapticSelect();
                player.cycleRepeat();
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Playback modifiers that aren't transport: speed and the sleep timer.
class _PlaybackModifiers extends ConsumerWidget {
  const _PlaybackModifiers();

  static const _speeds = <double>[0.5, 0.75, 1.0, 1.25, 1.5, 2.0];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final speed = ref.watch(playbackStateProvider).value?.speed ?? 1.0;
    final sleep = ref.watch(sleepTimerProvider);
    final sleepLabel = switch (sleep) {
      SleepTimerOff() => null,
      SleepTimerFor(:final remaining) => formatDuration(remaining),
      SleepTimerEndOfTrack() => 'End of track',
    };
    final player = ref.read(audioPlayerProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 4, 16, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          PopupMenuButton<double>(
            tooltip: 'Playback speed',
            onSelected: (value) {
              context.hapticLight();
              player.setSpeed(value);
            },
            itemBuilder: (_) => [
              for (final value in _speeds)
                PopupMenuItem(value: value, child: Text(formatSpeed(value))),
            ],
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Text(
                formatSpeed(speed),
                style: TextStyle(
                  color: scheme.onSurfaceVariant,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          PopupMenuButton<SleepTimer>(
            tooltip: 'Sleep timer',
            onSelected: (value) {
              context.hapticLight();
              ref.read(sleepTimerProvider.notifier).start(value);
            },
            itemBuilder: (_) => [
              for (final minutes in const [15, 30, 45, 60])
                PopupMenuItem(
                  value: SleepTimerFor(Duration(minutes: minutes)),
                  child: Text('$minutes min'),
                ),
              const PopupMenuItem(
                value: SleepTimerEndOfTrack(),
                child: Text('End of track'),
              ),
              const PopupMenuItem(value: SleepTimerOff(), child: Text('Off')),
            ],
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.bedtime_rounded,
                    size: 18,
                    color: sleepLabel == null
                        ? scheme.onSurfaceVariant
                        : scheme.primary,
                  ),
                  if (sleepLabel != null) ...[
                    const SizedBox(width: 6),
                    Text(
                      sleepLabel,
                      style: TextStyle(
                        color: scheme.primary,
                        fontSize: 13,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

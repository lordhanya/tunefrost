import 'dart:async';

import 'package:flutter/material.dart' hide RepeatMode;
import 'package:flutter/physics.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:music_player/core/models/queue_state.dart';
import 'package:music_player/core/models/song.dart';
import 'package:music_player/core/providers/play_history_provider.dart';
import 'package:music_player/core/utils/format.dart';
import 'package:music_player/core/utils/haptics.dart';
import 'package:music_player/core/widgets/press_scale.dart';

import '../library/providers/downloads_provider.dart';
import '../library/widgets/song_actions_sheet.dart';
import 'providers/playback_providers.dart';
import 'providers/artwork_palette_provider.dart';
import 'widgets/queue_sheet.dart';
import 'widgets/song_artwork.dart';

class NowPlayingScreen extends ConsumerWidget {
  const NowPlayingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playbackAsync = ref.watch(playbackStateProvider);
    final song = ref.watch(currentSongProvider);
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 28),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert_rounded, size: 26),
            onPressed: song == null
                ? null
                : () {
                    context.hapticLight();
                    _showMoreMenu(context, ref, song);
                  },
          ),
        ],
      ),
      extendBodyBehindAppBar: true,
      body: Padding(
        padding: EdgeInsets.only(
          top: MediaQuery.paddingOf(context).top + kToolbarHeight,
        ),
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

  /// Bottom sheet surfacing everything that used to live as app-bar / body
  /// icons: favourite toggle, playlist filing, download, queue, speed,
  /// sleep timer. Keeps the screen itself clean.
  void _showMoreMenu(BuildContext context, WidgetRef ref, Song song) {
    final scheme = Theme.of(context).colorScheme;
    final isFavorite = ref.read(favoriteIdsProvider).contains(song.id);
    final downloads = ref.read(downloadsProvider);
    final videoId = song.videoId;
    final downloaded = videoId != null &&
        downloads.songs.any((s) => s.sourceVideoId == videoId);
    final downloading =
        videoId != null && downloads.active.contains(videoId);
    final failed = videoId != null && downloads.failed.contains(videoId);

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: scheme.surfaceContainerHigh,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      width: 48,
                      height: 48,
                      child: SongArtwork(song: song, dimension: 48, radius: 8),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          song.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: scheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          song.artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            const SizedBox(height: 4),
            ListTile(
              leading: Icon(
                isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                color: isFavorite ? scheme.primary : scheme.onSurfaceVariant,
              ),
              title: Text(isFavorite ? 'Remove from favourites' : 'Add to favourites'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                ref.read(favoritesProvider.notifier).toggle(song);
              },
            ),
            ListTile(
              leading: Icon(Icons.playlist_add_rounded, color: scheme.onSurfaceVariant),
              title: const Text('Add to playlist'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                showAddToPlaylistSheet(context, ref, songs: [song]);
              },
            ),
            if (song.isDownload)
              ListTile(
                leading: Icon(Icons.delete_outline_rounded, color: scheme.error),
                title: Text('Delete download', style: TextStyle(color: scheme.error)),
                onTap: () async {
                  Navigator.of(sheetContext).pop();
                  await ref.read(downloadsProvider.notifier).remove(song);
                },
              )
            else if (videoId != null)
              if (downloading)
                ListTile(
                  leading: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: scheme.primary,
                    ),
                  ),
                  title: const Text('Downloading…'),
                  trailing: TextButton(
                    onPressed: () {
                      ref.read(downloadsProvider.notifier).cancel(videoId);
                      Navigator.of(sheetContext).pop();
                    },
                    child: const Text('Cancel'),
                  ),
                )
              else if (failed)
                ListTile(
                  leading: Icon(Icons.error_outline_rounded, color: scheme.error),
                  title: const Text('Download failed'),
                  trailing: TextButton(
                    onPressed: () {
                      Navigator.of(sheetContext).pop();
                      ensureDownloadDirectory(
                        context,
                        ref,
                        () => ref.read(downloadsProvider.notifier).start(song),
                      );
                    },
                    child: const Text('Retry'),
                  ),
                )
              else if (downloaded)
                ListTile(
                  leading: Icon(Icons.download_done_rounded, color: scheme.primary),
                  title: const Text('Downloaded'),
                  subtitle: const Text('Saved for offline listening'),
                  onTap: () async {
                    Navigator.of(sheetContext).pop();
                    final copy = downloads.songs.firstWhere(
                      (s) => s.sourceVideoId == videoId,
                    );
                    await ref.read(downloadsProvider.notifier).remove(copy);
                  },
                )
              else
                ListTile(
                  leading: Icon(Icons.download_outlined, color: scheme.onSurfaceVariant),
                  title: const Text('Download'),
                  subtitle: const Text('Save for offline listening'),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    ensureDownloadDirectory(
                      context,
                      ref,
                      () => ref.read(downloadsProvider.notifier).start(song),
                    );
                  },
                ),
            ListTile(
              leading: Icon(Icons.queue_music_rounded, color: scheme.onSurfaceVariant),
              title: const Text('View queue'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                showQueueSheet(context);
              },
            ),
            ListTile(
              leading: Icon(Icons.speed_rounded, color: scheme.onSurfaceVariant),
              title: const Text('Playback speed'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _showSpeedPicker(context, ref);
              },
            ),
            ListTile(
              leading: Icon(Icons.bedtime_outlined, color: scheme.onSurfaceVariant),
              title: const Text('Sleep timer'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _showSleepTimerPicker(context, ref);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
      ),
    );
  }

  void _showSpeedPicker(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final speed = ref.read(playbackStateProvider).value?.speed ?? 1.0;
    final speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];
    final player = ref.read(audioPlayerProvider);

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: scheme.surfaceContainerHigh,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                child: Text(
                  'Playback speed',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface,
                  ),
                ),
              ),
              ...speeds.map(
              (s) => ListTile(
                leading: speed == s
                    ? Icon(Icons.check_rounded, color: scheme.primary)
                    : const SizedBox(width: 24),
                title: Text(formatSpeed(s)),
                onTap: () {
                  player.setSpeed(s);
                  Navigator.of(sheetContext).pop();
                },
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
        ),
      ),
    );
  }

  void _showSleepTimerPicker(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final notifier = ref.read(sleepTimerProvider.notifier);

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: scheme.surfaceContainerHigh,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Text(
                'Sleep timer',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurface,
                ),
              ),
            ),
            for (final minutes in [15, 30, 45, 60])
              ListTile(
                title: Text('$minutes minutes'),
                onTap: () {
                  notifier.start(SleepTimerFor(Duration(minutes: minutes)));
                  Navigator.of(sheetContext).pop();
                },
              ),
            ListTile(
              title: const Text('End of track'),
              onTap: () {
                notifier.start(const SleepTimerEndOfTrack());
                Navigator.of(sheetContext).pop();
              },
            ),
            ListTile(
              title: Text('Turn off', style: TextStyle(color: scheme.error)),
              onTap: () {
                notifier.start(const SleepTimerOff());
                Navigator.of(sheetContext).pop();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _NowPlayingBody extends ConsumerWidget {
  const _NowPlayingBody({required this.state});

  final QueueState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final song = state.currentSong!;
    final player = ref.read(audioPlayerProvider);

    return SafeArea(
      top: false,
      child: Stack(
        children: [
          // Ambient glow behind everything — colour is pulled from the
          // current artwork and cross-fades when the song changes.
          _AmbientGlow(song: song),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                const SizedBox(height: 8),
                Expanded(
                  flex: 5,
                  child: Center(
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: _SwipeSkipPane(
                        trackId: song.id,
                        canNext: state.hasNext,
                        canPrevious: state.hasPrevious,
                        onNext: () => player.playNext(),
                        onPrevious: () => player.playPrevious(),
                        child: Hero(
                          tag: 'artwork-${song.id}',
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: SongArtwork(
                              song: song,
                              dimension: double.infinity,
                              radius: 12,
                              querySize: 800,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const Spacer(flex: 1),
                _TrackInfoSection(song: song),
                const Spacer(flex: 1),
                const _SeekSlider(),
                const SizedBox(height: 16),
                _MainControls(state: state),
                const SizedBox(height: 20),
                _SecondaryControls(state: state),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Subtle ambient glow pulled from the current song's cover art.
///
/// Only the dominant/vibrant tone is used, at low alpha, so it reads as a
/// mood wash rather than a busy background. Cross-fades on song change.
class _AmbientGlow extends ConsumerWidget {
  const _AmbientGlow({required this.song});

  final Song song;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(artworkPaletteProvider(song));

    return palette.when(
      data: (palette) {
        if (palette == null) return const SizedBox.shrink();
        return Positioned.fill(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 700),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            child: DecoratedBox(
              key: ValueKey(song.id),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    palette.glowColor.withValues(alpha: 0.16),
                    palette.glowColor.withValues(alpha: 0.05),
                    Colors.transparent,
                    Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0.92),                  ],
                  stops: const [0.0, 0.30, 0.70, 1.0],
                ),
              ),
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}

class _TrackInfoSection extends ConsumerWidget {
  const _TrackInfoSection({required this.song});

  final Song song;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final isFavorite = ref.watch(favoriteIdsProvider).contains(song.id);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                song.title,
                softWrap: true,
                style: TextStyle(
                  color: scheme.onSurface,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                song.artist,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: scheme.onSurfaceVariant,
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        IconButton(
          icon: Icon(
            isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
            size: 28,
          ),
          color: isFavorite ? scheme.primary : scheme.onSurfaceVariant,
          onPressed: () {
            context.hapticMedium();
            ref.read(favoritesProvider.notifier).toggle(song);
          },
        ),
      ],
    );
  }
}

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
  final String trackId;
  final bool canNext;
  final bool canPrevious;
  final VoidCallback onNext;
  final VoidCallback onPrevious;

  @override
  State<_SwipeSkipPane> createState() => _SwipeSkipPaneState();
}

enum _SwipePhase { idle, following, returning, exiting, entering }

class _SwipeSkipPaneState extends State<_SwipeSkipPane>
    with SingleTickerProviderStateMixin {
  static const double _commitFraction = 0.25;
  static const double _flingVelocity = 700;
  static const double _rubberBand = 0.25;

  static final SpringDescription _spring = SpringDescription.withDampingRatio(
    mass: 1,
    stiffness: 300,
    ratio: 1,
  );

  late final Ticker _ticker;

  Simulation? _simulation;
  _SwipePhase _phase = _SwipePhase.idle;

  double _dx = 0;
  double _commitSign = 0;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
  }

  @override
  void dispose() {
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
    if (done) scheduleMicrotask(_onSettled);
  }

  void _onSettled() {
    if (!mounted) return;
    switch (_phase) {
      case _SwipePhase.returning:
      case _SwipePhase.entering:
        setState(() {
          _dx = 0;
          _phase = _SwipePhase.idle;
        });
      case _SwipePhase.exiting:
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
      _returnToCenter(velocity: velocity);
    }
  }

  @override
  void didUpdateWidget(covariant _SwipeSkipPane oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.trackId == oldWidget.trackId) return;
    if (_phase != _SwipePhase.exiting) return;
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
      child: _dx == 0
          ? widget.child
          : Transform.translate(offset: Offset(_dx, 0), child: widget.child),
    );
  }
}

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
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 4,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
            activeTrackColor: scheme.primary,
            inactiveTrackColor: scheme.onSurface.withValues(alpha: 0.15),
            thumbColor: scheme.primary,
            overlayColor: scheme.primary.withValues(alpha: 0.12),
          ),
          child: Slider(
            value: hasDuration ? elapsedMs : 0,
            min: 0,
            max: hasDuration ? maxMs.toDouble() : 1,
            onChanged: hasDuration ? (v) => setState(() => _dragValue = v) : null,
            onChangeStart:
                hasDuration ? (_) => context.hapticLight() : null,
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
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
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

class _MainControls extends ConsumerWidget {
  const _MainControls({required this.state});

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

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        PressScale(
          child: IconButton(
            icon: Icon(
              shuffleOn ? Icons.shuffle_on_rounded : Icons.shuffle_rounded,
              size: 26,
            ),
            color: shuffleOn ? scheme.primary : scheme.onSurfaceVariant,
            onPressed: () {
              context.hapticSelect();
              player.toggleShuffle();
            },
          ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            PressScale(
              child: IconButton(
                icon: const Icon(Icons.skip_previous_rounded),
                iconSize: 42,
                color: scheme.onSurface.withValues(alpha: canGoBack ? 1 : 0.35),
                onPressed: canGoBack
                    ? () {
                        context.hapticLight();
                        player.playPrevious();
                      }
                    : null,
              ),
            ),
            const SizedBox(width: 12),
            PressScale(
              scale: 0.9,
              child: Material(
                color: scheme.primary,
                shape: const CircleBorder(),
                elevation: 2,
                shadowColor: scheme.primary.withValues(alpha: 0.4),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () {
                    context.hapticMedium();
                    player.togglePlay();
                  },
                  child: SizedBox.square(
                    dimension: 72,
                    child: Center(
                      child: buffering
                          ? SizedBox(
                              width: 28,
                              height: 28,
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
                                size: 42,
                                color: scheme.onPrimary,
                              ),
                            ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            PressScale(
              child: IconButton(
                icon: const Icon(Icons.skip_next_rounded),
                iconSize: 42,
                color: scheme.onSurface.withValues(
                  alpha: canGoForward ? 1 : 0.35,
                ),
                onPressed: canGoForward
                    ? () {
                        context.hapticLight();
                        player.playNext();
                      }
                    : null,
              ),
            ),
          ],
        ),
        PressScale(
          child: IconButton(
            icon: Icon(
              state.repeatMode == RepeatMode.one
                  ? Icons.repeat_one_rounded
                  : Icons.repeat_rounded,
              size: 26,
            ),
            color: repeatOn ? scheme.primary : scheme.onSurfaceVariant,
            onPressed: () {
              context.hapticSelect();
              player.cycleRepeat();
            },
          ),
        ),
      ],
    );
  }
}

class _SecondaryControls extends ConsumerWidget {
  const _SecondaryControls({required this.state});

  final QueueState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        TextButton.icon(
          onPressed: () {
            context.hapticLight();
            showQueueSheet(context);
          },
          icon: Icon(
            Icons.queue_music_rounded,
            size: 18,
            color: scheme.onSurfaceVariant,
          ),
          label: Text(
            'Queue',
            style: TextStyle(
              color: scheme.onSurfaceVariant,
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }
}

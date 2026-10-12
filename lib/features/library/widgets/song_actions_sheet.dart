import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:music_player/core/models/song.dart';
import 'package:music_player/core/providers/play_history_provider.dart';
import 'package:music_player/core/widgets/animated_download_icon.dart';
import 'package:music_player/core/widgets/lottie_icon.dart';

import '../../playback/providers/playback_providers.dart';
import '../../playlists/providers/playlist_providers.dart';
import '../providers/downloads_provider.dart';

/// Small floating snackbar with a short confirmation message.
void showAppSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
}

/// Single-line text prompt; resolves with the entered text or null.
Future<String?> showTextPrompt(
  BuildContext context, {
  required String title,
  String? hint,
  String confirmLabel = 'OK',
  String? initial,
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _TextPromptDialog(
      title: title,
      hint: hint,
      confirmLabel: confirmLabel,
      initial: initial,
    ),
  );
}

class _TextPromptDialog extends StatefulWidget {
  const _TextPromptDialog({
    required this.title,
    required this.confirmLabel,
    this.hint,
    this.initial,
  });

  final String title;
  final String? hint;
  final String confirmLabel;
  final String? initial;

  @override
  State<_TextPromptDialog> createState() => _TextPromptDialogState();
}

class _TextPromptDialogState extends State<_TextPromptDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initial);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLength: 60,
        decoration: InputDecoration(hintText: widget.hint, counterText: ''),
        onSubmitted: (value) => Navigator.of(context).pop(value),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}

/// Overflow sheet for a song: queue it, file it into a playlist, or favourite
/// it.
Future<void> showSongActionsSheet(
  BuildContext context,
  WidgetRef ref, {
  required Song song,
  String? playlistId,
  int? playlistIndex,
}) {
  final scheme = Theme.of(context).colorScheme;
  final isFavorite = ref.watch(favoriteIdsProvider).contains(song.id);

  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: scheme.surface,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: Consumer(
        builder: (sheetContext, ref2, _) {
          final downloads = ref2.watch(downloadsProvider);
          final videoId = song.videoId;
          final isDownloadCopy = song.isDownload;
          final downloaded = videoId == null
              ? null
              : downloads.songs.firstWhereOrNull(
                  (s) => s.sourceVideoId == videoId,
                );
          final downloading =
              videoId != null && downloads.active.contains(videoId);
          final progress = videoId == null ? null : downloads.progress[videoId];
          final failed = videoId != null && downloads.failed.contains(videoId);

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Text(
                  song.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(sheetContext).textTheme.titleMedium,
                ),
              ),
              if (playlistId != null && playlistIndex != null)
                ListTile(
                  leading: const Icon(Icons.remove_circle_outline_rounded),
                  title: const Text('Remove from playlist'),
                  onTap: () async {
                    Navigator.of(sheetContext).pop();
                    await ref
                        .read(playlistsProvider.notifier)
                        .removeSong(playlistId, playlistIndex);
                  },
                ),
              ListTile(
                leading: isFavorite
                    ? const LottieIcon(LottieAssets.heart)
                    : const Icon(Icons.favorite_border_rounded),
                title: Text(
                  isFavorite ? 'Remove from favourites' : 'Add to favourites',
                ),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  ref.read(favoritesProvider.notifier).toggle(song);
                  if (context.mounted) {
                    showAppSnack(
                      context,
                      isFavorite
                          ? 'Removed from favourites'
                          : 'Added to favourites',
                    );
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.skip_next_rounded),
                title: const Text('Play next'),
                onTap: () async {
                  Navigator.of(sheetContext).pop();
                  await ref.read(audioPlayerProvider).playNextInQueue([song]);
                  if (context.mounted) {
                    showAppSnack(context, 'Playing next');
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.queue_music_rounded),
                title: const Text('Add to queue'),
                onTap: () async {
                  Navigator.of(sheetContext).pop();
                  await ref.read(audioPlayerProvider).addToQueue([song]);
                  if (context.mounted) {
                    showAppSnack(context, 'Added to queue');
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.playlist_add_rounded),
                title: const Text('Add to playlist'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  showAddToPlaylistSheet(context, ref, songIds: [song.id]);
                },
              ),
              if (isDownloadCopy)
                ListTile(
                  leading: const LottieIcon(LottieAssets.trash),
                  title: const Text('Delete download'),
                  onTap: () async {
                    Navigator.of(sheetContext).pop();
                    await ref2.read(downloadsProvider.notifier).remove(song);
                    if (context.mounted) {
                      showAppSnack(context, 'Download deleted');
                    }
                  },
                )
              else if (videoId != null)
                if (downloading && progress != null)
                  ListTile(
                    leading: const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    ),
                    title: const Text('Downloading…'),
                    subtitle: LinearProgressIndicator(
                      value: progress,
                      minHeight: 3,
                      borderRadius: BorderRadius.circular(2),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.close_rounded),
                      tooltip: 'Cancel download',
                      onPressed: () =>
                          ref2.read(downloadsProvider.notifier).cancel(videoId),
                    ),
                  )
                else if (failed)
                  ListTile(
                    leading: const Icon(Icons.error_outline_rounded),
                    title: const Text('Download failed'),
                    subtitle: const Text('Check your connection and try again'),
                    trailing: FilledButton.tonal(
                      onPressed: () =>
                          ref2.read(downloadsProvider.notifier).start(song),
                      child: const Text('Retry'),
                    ),
                  )
                else if (downloaded != null)
                  ListTile(
                    leading: const Icon(Icons.download_done_rounded),
                    title: const Text('Downloaded'),
                    subtitle: const Text('Saved for offline listening'),
                    onTap: () async {
                      Navigator.of(sheetContext).pop();
                      await ref2
                          .read(downloadsProvider.notifier)
                          .remove(downloaded);
                      if (context.mounted) {
                        showAppSnack(context, 'Download deleted');
                      }
                    },
                  )
                else
                  ListTile(
                    leading: const AnimatedDownloadIcon(
                      trigger: 0,
                      autoPlay: true,
                    ),
                    title: const Text('Download'),
                    subtitle: const Text('Save a copy for offline listening'),
                    onTap: () =>
                        ref2.read(downloadsProvider.notifier).start(song),
                  ),
              const SizedBox(height: 8),
            ],
          );
        },
      ),
    ),
  );
}

/// Pick a playlist (or create one) to file [songIds] into.
Future<void> showAddToPlaylistSheet(
  BuildContext context,
  WidgetRef ref, {
  required List<String> songIds,
}) {
  final scheme = Theme.of(context).colorScheme;

  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: scheme.surface,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: Consumer(
        builder: (context, consumerRef, _) {
          final playlists = consumerRef.watch(playlistsProvider);
          return ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.6,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                  child: Text(
                    'Add to playlist',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Flexible(
                  child: playlists.maybeWhen(
                    data: (items) => ListView(
                      shrinkWrap: true,
                      children: [
                        ListTile(
                          leading: const Icon(Icons.add_rounded),
                          title: const Text('New playlist'),
                          onTap: () async {
                            Navigator.of(sheetContext).pop();
                            final name = await showTextPrompt(
                              context,
                              title: 'New playlist',
                              hint: 'Playlist name',
                              confirmLabel: 'Create',
                            );
                            if (name == null || name.trim().isEmpty) return;
                            final notifier = consumerRef.read(
                              playlistsProvider.notifier,
                            );
                            final playlist = await notifier.create(name);
                            await notifier.addSongs(playlist.id, songIds);
                            if (context.mounted) {
                              showAppSnack(
                                context,
                                'Added to ${playlist.name}',
                              );
                            }
                          },
                        ),
                        const Divider(),
                        for (final playlist in items)
                          ListTile(
                            leading: const Icon(Icons.queue_music_rounded),
                            title: Text(playlist.name),
                            subtitle: Text(
                              '${playlist.songIds.length} songs',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            onTap: () async {
                              Navigator.of(sheetContext).pop();
                              await consumerRef
                                  .read(playlistsProvider.notifier)
                                  .addSongs(playlist.id, songIds);
                              if (context.mounted) {
                                showAppSnack(
                                  context,
                                  'Added to ${playlist.name}',
                                );
                              }
                            },
                          ),
                      ],
                    ),
                    orElse: () => const Padding(
                      padding: EdgeInsets.all(24),
                      child: CircularProgressIndicator(),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          );
        },
      ),
    ),
  );
}

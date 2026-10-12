import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:music_player/core/utils/haptics.dart';
import 'package:music_player/core/widgets/glass.dart';
import 'package:music_player/core/widgets/lottie_icon.dart';
import 'package:music_player/features/library/widgets/song_actions_sheet.dart';

import '../../playback/widgets/mini_player.dart';
import '../providers/playlist_providers.dart';
import 'playlist_detail_screen.dart';

/// All user playlists, with create / rename / delete.
class PlaylistsScreen extends ConsumerWidget {
  const PlaylistsScreen({super.key});

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    final name = await showTextPrompt(
      context,
      title: 'New playlist',
      hint: 'Playlist name',
      confirmLabel: 'Create',
    );
    if (name == null || name.trim().isEmpty || !context.mounted) return;
    final playlist = await ref.read(playlistsProvider.notifier).create(name);
    if (!context.mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PlaylistDetailScreen(playlistId: playlist.id),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playlists = ref.watch(playlistsProvider);
    final scheme = Theme.of(context).colorScheme;
    final topInset = MediaQuery.paddingOf(context).top + kToolbarHeight;

    return Scaffold(
      extendBody: true,
      extendBodyBehindAppBar: true,
      appBar: glassAppBar(
        context,
        title: const Text('Playlists'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            tooltip: 'New playlist',
            onPressed: () => _create(context, ref),
          ),
        ],
      ),
      body: playlists.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text(error.toString())),
        data: (items) {
          if (items.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.queue_music_rounded,
                    size: 56,
                    color: scheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No playlists yet',
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 8),
                  FilledButton.tonal(
                    onPressed: () => _create(context, ref),
                    child: const Text('Create playlist'),
                  ),
                ],
              ),
            );
          }
          return Scrollbar(
            child: ListView.builder(
              padding: EdgeInsets.only(
                top: topInset,
                bottom: miniPlayerBottom(context),
              ),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final playlist = items[index];
                return ListTile(
                  leading: Icon(
                    Icons.queue_music_rounded,
                    color: scheme.primary,
                  ),
                  title: Text(playlist.name),
                  subtitle: Text(
                    '${playlist.songIds.length} songs',
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontSize: 13,
                    ),
                  ),
                  trailing: PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert_rounded),
                    onSelected: (action) async {
                      switch (action) {
                        case 'rename':
                          final name = await showTextPrompt(
                            context,
                            title: 'Rename playlist',
                            initial: playlist.name,
                            confirmLabel: 'Save',
                          );
                          if (name == null || !context.mounted) return;
                          await ref
                              .read(playlistsProvider.notifier)
                              .rename(playlist.id, name);
                        case 'delete':
                          final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (dialogContext) => AlertDialog(
                              title: const Text('Delete playlist?'),
                              content: Text(
                                '"${playlist.name}" will be removed. '
                                'Songs stay in your library.',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.of(dialogContext).pop(false),
                                  child: const Text('Cancel'),
                                ),
                                FilledButton(
                                  onPressed: () =>
                                      Navigator.of(dialogContext).pop(true),
                                  child: const Text('Delete'),
                                ),
                              ],
                            ),
                          );
                          if (confirmed != true || !context.mounted) return;
                          await ref
                              .read(playlistsProvider.notifier)
                              .delete(playlist.id);
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                        value: 'rename',
                        child: ListTile(
                          leading: Icon(Icons.edit_rounded),
                          title: Text('Rename'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: ListTile(
                          leading: LottieIcon(LottieAssets.trash),
                          title: Text('Delete'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ],
                  ),
                  onTap: () {
                    context.hapticLight();
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            PlaylistDetailScreen(playlistId: playlist.id),
                      ),
                    );
                  },
                );
              },
            ),
          );
        },
      ),
      bottomNavigationBar: const MiniPlayer(),
    );
  }
}

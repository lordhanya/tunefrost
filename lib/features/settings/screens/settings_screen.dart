import 'dart:async' show unawaited;
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:music_player/app/theme.dart';
import 'package:music_player/core/providers/haptics_provider.dart';
import 'package:music_player/core/providers/listening_provider.dart';
import 'package:music_player/core/providers/smartplay_provider.dart';
import 'package:music_player/core/providers/theme_provider.dart';
import 'package:music_player/core/utils/haptics.dart';
import 'package:music_player/core/widgets/glass.dart';
import 'package:music_player/core/widgets/lottie_icon.dart';

import '../../playback/widgets/mini_player.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    final hapticsOn = ref.watch(hapticsEnabledProvider);
    final historyCount = ref.watch(listeningEventsProvider).length;
    final discoveryOn = ref.watch(smartPlayDiscoveryEnabledProvider);
    final topInset = MediaQuery.paddingOf(context).top + kToolbarHeight;

    return Scaffold(
      extendBody: true,
      extendBodyBehindAppBar: true,
      appBar: glassAppBar(
        context,
        title: const Text('Settings'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: Scrollbar(
        child: SingleChildScrollView(
          padding: EdgeInsets.only(
            top: topInset + 16,
            left: 16,
            right: 16,
            bottom: miniPlayerBottom(context, extra: 24),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (Platform.isAndroid) ...[
                Text(
                  'Playback',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const LottieIcon(LottieAssets.equalizer),
                  title: const Text('Equalizer'),
                  subtitle: Text(
                    'Boost or cut frequency bands',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 13,
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.of(context).pushNamed('/equalizer'),
                ),
                const Divider(height: 32),
              ],
              Text(
                'Appearance',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              RadioGroup<AppThemeMode>(
                groupValue: mode,
                onChanged: (value) {
                  if (value != null) {
                    context.hapticSelect();
                    ref.read(themeModeProvider.notifier).setMode(value);
                  }
                },
                child: Column(
                  children: AppThemeMode.values.map((m) {
                    return RadioListTile<AppThemeMode>(
                      value: m,
                      title: Text(m.label),
                      secondary: Icon(m.icon),
                    );
                  }).toList(),
                ),
              ),
              const Divider(height: 32),
              Text('Feedback', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Haptic feedback'),
                subtitle: Text(
                  'Vibrate gently on taps and toggles',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 13,
                  ),
                ),
                secondary: const Icon(Icons.vibration_rounded),
                value: hapticsOn,
                onChanged: (value) {
                  context.hapticSelect();
                  ref.read(hapticsEnabledProvider.notifier).setEnabled(value);
                },
              ),
              const Divider(height: 32),
              Text('Data', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.history_rounded),
                title: const Text('Listening history'),
                subtitle: Text(
                  historyCount == 0
                      ? 'Nothing recorded yet'
                      : '$historyCount ${historyCount == 1 ? 'entry' : 'entries'}, kept on this device',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 13,
                  ),
                ),
                trailing: historyCount == 0
                    ? null
                    : TextButton(
                        onPressed: () => _confirmClearHistory(context, ref),
                        child: const Text('Clear'),
                      ),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: discoveryOn,
                onChanged: (value) {
                  context.hapticSelect();
                  unawaited(
                    ref
                        .read(smartPlayDiscoveryEnabledProvider.notifier)
                        .set(value),
                  );
                },
                title: const Text('Smart Play discovery'),
                subtitle: Text(
                  discoveryOn
                      ? 'Sends searches derived from your listening to find music'
                      : 'Off — the app sends nothing about your listening',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 13,
                  ),
                ),
              ),
              const Divider(height: 32),
              Text('About', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              const ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('Tunefrost'),
                subtitle: Text('Version 1.4.0'),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.privacy_tip_outlined),
                title: const Text('Privacy policy'),
                subtitle: Text(
                  'What the app accesses and stores',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 13,
                  ),
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.of(context).pushNamed('/privacy'),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.code_rounded),
                title: const Text('Developed by Ashif'),
                subtitle: Text(
                  'ashifcodes.tech',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 13,
                  ),
                ),
                trailing: const Icon(Icons.open_in_new_rounded, size: 18),
                onTap: () => launchUrl(
                  Uri.parse('https://ashifcodes.tech'),
                  mode: LaunchMode.externalApplication,
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const MiniPlayer(),
    );
  }
}

/// Removes the listening history after a confirmation. It is the only stored
/// data with no other purpose, so it gets a way out and an immediate answer:
/// the file is deleted and the taste profile recomputes on the next frame.
Future<void> _confirmClearHistory(BuildContext context, WidgetRef ref) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Clear listening history?'),
      content: const Text(
        'This removes the history used to personalise what plays next. '
        'Your favourites, play counts and queue are left alone.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('Clear'),
        ),
      ],
    ),
  );
  if (confirmed != true) return;

  await ref.read(listeningEventsProvider.notifier).clear();
  if (!context.mounted) return;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      const SnackBar(
        content: Text('Listening history cleared'),
        behavior: SnackBarBehavior.floating,
      ),
    );
}
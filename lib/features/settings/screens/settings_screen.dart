import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:music_player/app/theme.dart';
import 'package:music_player/core/providers/haptics_provider.dart';
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
              Text('About', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              const ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('Tunefrost'),
                subtitle: Text('Version 1.3.0'),
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
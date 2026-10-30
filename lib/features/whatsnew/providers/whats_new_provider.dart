import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:music_player/core/providers/theme_provider.dart';

import '../release_notes.dart';
import '../whats_new_plan.dart';

/// The installed version as the operating system reports it, or `''` when it
/// cannot be read.
///
/// Version detection failing has to be survivable: an empty string parses to
/// nothing, and [decideWhatsNew] then starts the app in silence instead of
/// guessing at what the listener is running.
final installedVersionProvider = FutureProvider<String>((ref) async {
  try {
    final info = await PackageInfo.fromPlatform();
    return info.version;
  } catch (_) {
    return '';
  }
});

/// Whether `SharedPreferences` held nothing before this launch.
///
/// Read in `main()` before the app can write a single key — afterwards the
/// question is unanswerable, because a first launch and a launch of an updated
/// install both start by writing. Overrides in `main()`.
final freshInstallProvider = Provider<bool>(
  (ref) => throw UnimplementedError('Override in main()'),
);

/// What the current launch does about release notes.
///
/// The acknowledgement is written here rather than where the screen is
/// presented: a launch that decides *not* to show anything still has to record
/// how far it got, or a first install would announce itself on the next run.
/// One place cannot forget the other case.
///
/// This is read for the lifetime of the app, so the plan is made once and the
/// key is written exactly once per launch.
final whatsNewPlanProvider = FutureProvider<WhatsNewPlan>((ref) async {
  final prefs = ref.watch(sharedPreferencesProvider);
  final freshInstall = ref.watch(freshInstallProvider);

  // Every input is read before the first await: holding `ref` across a
  // suspension is what turns a fast startup into a late throw.
  final installed = ref.watch(installedVersionProvider.future);
  final release = ref.watch(whatsNewReleaseProvider.future);

  final plan = decideWhatsNew(
    installedVersion: await installed,
    release: await release,
    lastSeen: prefs.getString(kWhatsNewLastSeenKey),
    freshInstall: freshInstall,
  );

  final record = plan.recordVersion;
  if (record != null) await prefs.setString(kWhatsNewLastSeenKey, record);
  return plan;
});

/// The notes the screen shows, whether it was opened by an update or from
/// Settings → About.
///
/// A separate lookup from [whatsNewPlanProvider] on purpose: revisiting from
/// Settings has to work on a first install, where the plan deliberately holds
/// nothing to present. Both resolve against the same `releaseNotesFor`, so the
/// two can never disagree about what the current version ships.
final whatsNewReleaseProvider = FutureProvider<ReleaseNotes?>(
  (ref) async =>
      releaseNotesFor(await ref.watch(installedVersionProvider.future)),
);

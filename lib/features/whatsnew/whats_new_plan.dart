import 'package:music_player/core/utils/app_version.dart';

import 'release_notes.dart';

/// The only preference this feature writes.
///
/// Dedicated on purpose: acknowledging a release has no business touching any
/// other key, least of all the ones that hold a listener's history.
const String kWhatsNewLastSeenKey = 'mochi_whats_new_last_seen';

/// What this launch does about release notes.
class WhatsNewPlan {
  const WhatsNewPlan({this.release, this.recordVersion});

  /// The notes to put on screen. Null means the app starts normally, with
  /// nothing presented.
  final ReleaseNotes? release;

  /// The version to persist as acknowledged, or null when nothing may be
  /// written: an installed version that did not parse, or a downgrade that
  /// would otherwise pull the marker backwards.
  final String? recordVersion;

  /// Nothing to announce and nothing to write.
  static const silent = WhatsNewPlan();

  /// Whether the listener should be shown [release].
  bool get present => release != null;
}

/// Decides once per launch whether [release] goes on screen.
///
/// [freshInstall] is what keeps an update from being confused with an
/// install. `SharedPreferences` that held nothing before this launch has never
/// been written to, so the app has never run on this device — and telling
/// someone who has never seen the old version "here is what's new" is the one
/// mistake this must not make. A first install records where it started and
/// says nothing; the next release is the one it announces.
///
/// Every other path is an update of an existing install: [lastSeen] says how
/// far the listener has got, and the newest notes at or below the installed
/// version are shown if — and only if — they are newer than that.
///
/// Failures resolve to silence rather than an exception. Version detection
/// ([installedVersion] not parseable) records nothing and shows nothing; an
/// unusable [lastSeen] is repaired by re-acknowledging the current build, so
/// a corrupt marker can neither crash the start nor announce the same version
/// forever.
WhatsNewPlan decideWhatsNew({
  required String installedVersion,
  required ReleaseNotes? release,
  required String? lastSeen,
  required bool freshInstall,
}) {
  final installed = AppVersion.tryParse(installedVersion);
  if (installed == null) return WhatsNewPlan.silent;

  if (freshInstall) return WhatsNewPlan(recordVersion: installedVersion);

  if (lastSeen == null) {
    // An install that predates this feature entirely: it has never been shown
    // anything, so the current notes are news.
    return WhatsNewPlan(release: release, recordVersion: installedVersion);
  }

  final seen = AppVersion.tryParse(lastSeen);
  if (seen == null) {
    // Unreadable marker: heal it to the installed version without putting
    // anything on screen.
    return WhatsNewPlan(recordVersion: installedVersion);
  }

  // A downgrade. Leave the marker where it is, or installing the older build
  // again would replay notes the listener has already read.
  if (seen > installed) return WhatsNewPlan.silent;

  final releaseVersion = release == null
      ? null
      : AppVersion.tryParse(release.version);
  // Nothing newer than what was acknowledged — which also covers a build that
  // ships no notes of its own and a release entry with a malformed version.
  if (releaseVersion == null || releaseVersion <= seen) {
    return WhatsNewPlan(recordVersion: installedVersion);
  }

  return WhatsNewPlan(release: release, recordVersion: installedVersion);
}

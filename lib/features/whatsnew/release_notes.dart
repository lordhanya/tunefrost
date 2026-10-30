import 'package:flutter/material.dart';

import 'package:music_player/core/utils/app_version.dart';

/// One line of a release note: what landed, said plainly.
class ReleaseNoteItem {
  const ReleaseNoteItem({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;
}

/// Everything announced for a single version.
class ReleaseNotes {
  const ReleaseNotes({
    required this.version,
    this.beta = false,
    required this.items,
  });

  /// The version these notes belong to, in the same `X.Y.Z` shape the
  /// installed version reports, so the two compare directly. Kept free of
  /// wording such as "Beta" for that reason: [beta] carries it instead.
  final String version;

  /// True while a release is still finding its feet. It buys the release a
  /// softer name, "1.4.0 Beta", and the listener a short note asking for
  /// patience. Leave it off for a release that has earned its footing.
  final bool beta;

  /// How the release is named to the listener.
  String get displayVersion => beta ? '$version Beta' : version;

  final List<ReleaseNoteItem> items;
}

/// Newest first: put the notes for a release above the previous ones.
///
/// Only claim what actually shipped with the build the listener is running —
/// this screen is the first thing they read after an update, so a note about
/// something that is not there yet costs more trust than it is worth. Write
/// about unfinished work when it ships, not before.
const List<ReleaseNotes> releaseNotes = [
  ReleaseNotes(
    version: '1.4.0',
    beta: true,
    items: [
      ReleaseNoteItem(
        icon: Icons.auto_awesome_rounded,
        title: 'Meet Smart Play',
        body:
            'Discover songs inspired by the music you enjoy. Find it in '
            'Settings and give it a try!',
      ),
      ReleaseNoteItem(
        icon: Icons.queue_music_rounded,
        title: 'Your next listen, your choice',
        body:
            'Preview suggestions before playing. Your queue changes only '
            'when you choose Play.',
      ),
      ReleaseNoteItem(
        icon: Icons.title_rounded,
        title: 'A little visual polish',
        body:
            'We\'ve given titles a fresh new look, making your music space '
            'feel even more at home.',
      ),
    ],
  ),
];

/// The notes that apply to [installedVersion]: the newest entry that is not
/// newer than the build.
///
/// Null when the version does not parse, or when the build ships no notes at
/// or below it. Never throws: a malformed entry is skipped rather than allowed
/// to stand between the app and a normal start.
ReleaseNotes? releaseNotesFor(
  String installedVersion, {
  List<ReleaseNotes> releases = releaseNotes,
}) {
  final installed = AppVersion.tryParse(installedVersion);
  if (installed == null) return null;

  AppVersion? newest;
  ReleaseNotes? match;
  for (final release in releases) {
    final version = AppVersion.tryParse(release.version);
    if (version == null || version > installed) continue;
    if (newest == null || version > newest) {
      newest = version;
      match = release;
    }
  }
  return match;
}

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:music_player/core/utils/app_version.dart';
import 'package:music_player/features/whatsnew/release_notes.dart';
import 'package:music_player/features/whatsnew/whats_new_plan.dart';

void main() {
  ReleaseNotes release(String version) =>
      ReleaseNotes(version: version, items: const []);

  /// Newest first, as the shipped list is kept.
  const fixture = [
    ReleaseNotes(version: '1.7.0', items: []),
    ReleaseNotes(version: '1.5.0', items: []),
    ReleaseNotes(version: '1.4.0', items: []),
  ];

  group('releaseNotesFor', () {
    test('picks the newest notes at or below the installed version', () {
      expect(releaseNotesFor('1.7.0', releases: fixture)?.version, '1.7.0');
      expect(releaseNotesFor('1.6.0', releases: fixture)?.version, '1.5.0');
      expect(releaseNotesFor('1.5.0', releases: fixture)?.version, '1.5.0');
    });

    test('returns null when the build has no notes of its own', () {
      expect(releaseNotesFor('1.3.0', releases: fixture), isNull);
    });

    test('returns null rather than throwing on an unreadable version', () {
      expect(releaseNotesFor('', releases: fixture), isNull);
      expect(releaseNotesFor('next', releases: fixture), isNull);
    });

    test('compares 1.10.0 against 1.2.0 as numbers, not as text', () {
      // Text comparison drops 1.2.0 here: '1.2.0' sorts after '1.10.0'.
      expect(
        releaseNotesFor('1.10.0', releases: [release('1.2.0')])?.version,
        '1.2.0',
      );
      // ...and would wrongly accept 1.10.0 as being below 1.2.0.
      expect(releaseNotesFor('1.2.0', releases: [release('1.10.0')]), isNull);
    });

    test('skips a release entry with a malformed version', () {
      final notes = releaseNotesFor(
        '1.4.0',
        releases: [
          release('soon'),
          ReleaseNotes(version: '1.4.0', items: []),
        ],
      );

      expect(notes?.version, '1.4.0');
    });

    test('the shipped list is newest first, every version parseable', () {
      expect(releaseNotes, isNotEmpty);

      final versions = [
        for (final entry in releaseNotes)
          AppVersion.tryParse(entry.version) ??
              fail('"${entry.version}" must be X.Y.Z'),
      ];
      for (var i = 0; i < versions.length - 1; i++) {
        expect(
          versions[i] > versions[i + 1],
          isTrue,
          reason:
              '${releaseNotes[i].version} belongs above '
              '${releaseNotes[i + 1].version}',
        );
      }

      expect(releaseNotesFor('1.4.0')?.version, '1.4.0');
      expect(releaseNotesFor('1.4.0')?.items, isNotEmpty);
    });

    test('the shipped beta release is named and flagged as one', () {
      final notes = releaseNotesFor('1.4.0');
      expect(notes?.beta, isTrue);
      // The label is for the listener's eyes only: `version` stays the bare
      // X.Y.Z that every comparison in the app uses.
      expect(notes?.displayVersion, '1.4.0 Beta');
    });

    test('a settled release carries no beta label', () {
      const stable = ReleaseNotes(version: '1.5.0', items: []);
      expect(stable.beta, isFalse);
      expect(stable.displayVersion, '1.5.0');
    });

    test('the version being shipped has notes of its own', () {
      // Editing release notes is the whole workflow: this fails at
      // `flutter test` time if a release goes out with nothing to announce,
      // rather than silently showing the listener nothing on update.
      final pubspec = File('pubspec.yaml').readAsStringSync();
      final version = RegExp(
        r'^version:\s*(\S+)',
        multiLine: true,
      ).firstMatch(pubspec)?.group(1);
      expect(version, isNotNull, reason: 'no version: line in pubspec.yaml');

      expect(
        releaseNotesFor(version!)?.version,
        AppVersion.tryParse(version)?.toString(),
        reason: 'add an entry for $version to releaseNotes',
      );
    });
  });

  group('decideWhatsNew', () {
    test('a first installation records the version and shows nothing', () {
      final plan = decideWhatsNew(
        installedVersion: '1.4.0',
        release: release('1.4.0'),
        lastSeen: null,
        freshInstall: true,
      );

      expect(plan.present, isFalse);
      expect(plan.release, isNull);
      expect(plan.recordVersion, '1.4.0');
    });

    test('an install that predates the feature is shown the current notes', () {
      final plan = decideWhatsNew(
        installedVersion: '1.4.0',
        release: release('1.4.0'),
        lastSeen: null,
        freshInstall: false,
      );

      expect(plan.present, isTrue);
      expect(plan.release?.version, '1.4.0');
      expect(plan.recordVersion, '1.4.0');
    });

    test('a new version with unseen notes is announced', () {
      final plan = decideWhatsNew(
        installedVersion: '1.5.0',
        release: release('1.5.0'),
        lastSeen: '1.4.0',
        freshInstall: false,
      );

      expect(plan.release?.version, '1.5.0');
      expect(plan.recordVersion, '1.5.0');
    });

    test('reopening the same version shows nothing again', () {
      final plan = decideWhatsNew(
        installedVersion: '1.4.0',
        release: release('1.4.0'),
        lastSeen: '1.4.0',
        freshInstall: false,
      );

      expect(plan.present, isFalse);
      // The marker stays where it was — no state is lost by a second look.
      expect(plan.recordVersion, '1.4.0');
    });

    test('skipping several versions announces only the latest notes', () {
      final installed = '1.7.0';
      final plan = decideWhatsNew(
        installedVersion: installed,
        release: releaseNotesFor(installed, releases: fixture),
        lastSeen: '1.4.0',
        freshInstall: false,
      );

      // One release object, for the newest version — never 1.5.0, then
      // 1.6.0, then 1.7.0 on the launches in between.
      expect(plan.release?.version, '1.7.0');
      expect(plan.recordVersion, '1.7.0');
    });

    test('an unreadable marker is repaired silently', () {
      final plan = decideWhatsNew(
        installedVersion: '1.4.0',
        release: release('1.4.0'),
        lastSeen: 'build 42',
        freshInstall: false,
      );

      expect(plan.present, isFalse);
      expect(plan.recordVersion, '1.4.0');
    });

    test('an absent marker on an existing install still announces', () {
      final plan = decideWhatsNew(
        installedVersion: '1.4.0',
        release: release('1.4.0'),
        lastSeen: null,
        freshInstall: false,
      );

      expect(plan.release?.version, '1.4.0');
    });

    test(
      'an unreadable installed version shows nothing and records nothing',
      () {
        for (final raw in ['', 'next', '1.4']) {
          final plan = decideWhatsNew(
            installedVersion: raw,
            release: release('1.4.0'),
            lastSeen: '1.3.0',
            freshInstall: false,
          );

          expect(plan.present, isFalse, reason: '"$raw"');
          expect(plan.recordVersion, isNull, reason: '"$raw"');
        }
      },
    );

    test('a downgrade leaves the marker where the upgrade put it', () {
      final plan = decideWhatsNew(
        installedVersion: '1.3.0',
        release: release('1.3.0'),
        lastSeen: '1.4.0',
        freshInstall: false,
      );

      expect(plan.present, isFalse);
      expect(plan.recordVersion, isNull);
    });

    test('a build with no notes of its own is recorded, not presented', () {
      final plan = decideWhatsNew(
        installedVersion: '1.7.0',
        release: null,
        lastSeen: '1.4.0',
        freshInstall: false,
      );

      expect(plan.present, isFalse);
      expect(plan.recordVersion, '1.7.0');
    });

    test('notes for a version already acknowledged are not repeated', () {
      // This build ships no notes newer than what was seen — only an entry
      // from before it.
      final plan = decideWhatsNew(
        installedVersion: '1.7.0',
        release: release('1.4.0'),
        lastSeen: '1.5.0',
        freshInstall: false,
      );

      expect(plan.present, isFalse);
      expect(plan.recordVersion, '1.7.0');
    });
  });
}

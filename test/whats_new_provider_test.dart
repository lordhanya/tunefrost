import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_player/core/models/listening_event.dart';
import 'package:music_player/core/providers/theme_provider.dart';
import 'package:music_player/core/services/listening_event_store.dart';
import 'package:music_player/features/whatsnew/providers/whats_new_provider.dart';
import 'package:music_player/features/whatsnew/whats_new_plan.dart';
import 'package:shared_preferences/shared_preferences.dart';

ListeningEvent _event(String songId) => ListeningEvent(
  songId: songId,
  artist: 'Artist $songId',
  title: 'Title $songId',
  album: 'Album',
  startedAtMs: 1000,
  playedMs: 10000,
  durationMs: 20000,
  completed: true,
  skippedEarly: false,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// One app launch: preferences as they are on disk, plus the version the
  /// OS would report. `freshInstall` is what `main()` derives from an empty
  /// `SharedPreferences`, kept explicit here so each case reads as itself.
  Future<ProviderContainer> launch({
    Map<String, Object> initial = const {},
    bool freshInstall = false,
    String version = '1.4.0',
  }) async {
    SharedPreferences.setMockInitialValues(initial);
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(
          await SharedPreferences.getInstance(),
        ),
        freshInstallProvider.overrideWithValue(freshInstall),
        installedVersionProvider.overrideWithValue(AsyncData(version)),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  SharedPreferences prefsOf(ProviderContainer container) =>
      container.read(sharedPreferencesProvider);

  group('whatsNewPlanProvider', () {
    test('a first install records its version and presents nothing', () async {
      final container = await launch(freshInstall: true);

      final plan = await container.read(whatsNewPlanProvider.future);

      expect(plan.present, isFalse);
      expect(plan.release, isNull);
      expect(prefsOf(container).getString(kWhatsNewLastSeenKey), '1.4.0');
    });

    test(
      'an install updating over an existing one is shown the notes',
      () async {
        final container = await launch(initial: {'theme_mode': 'dark'});

        final plan = await container.read(whatsNewPlanProvider.future);

        expect(plan.present, isTrue);
        expect(plan.release?.version, '1.4.0');
        expect(prefsOf(container).getString(kWhatsNewLastSeenKey), '1.4.0');
      },
    );

    test(
      'the next launch of that same version presents nothing again',
      () async {
        final container = await launch(
          initial: {'theme_mode': 'dark', kWhatsNewLastSeenKey: '1.4.0'},
        );

        final plan = await container.read(whatsNewPlanProvider.future);

        expect(plan.present, isFalse);
        expect(prefsOf(container).getString(kWhatsNewLastSeenKey), '1.4.0');
      },
    );

    test('a skipped version announces only the newest notes', () async {
      final container = await launch(
        initial: {kWhatsNewLastSeenKey: '1.2.0'},
        version: '1.7.0',
      );

      final plan = await container.read(whatsNewPlanProvider.future);

      // One release object — the newest notes that exist — rather than every
      // version passed over on the way here.
      expect(plan.release?.version, '1.4.0');
      expect(prefsOf(container).getString(kWhatsNewLastSeenKey), '1.7.0');
    });

    test('a jump past every note announces nothing new', () async {
      final container = await launch(
        initial: {kWhatsNewLastSeenKey: '1.4.0'},
        version: '1.7.0',
      );

      final plan = await container.read(whatsNewPlanProvider.future);

      // The shipped notes are older than what was already acknowledged, so
      // the launch stays quiet — and still records where the listener is.
      expect(plan.present, isFalse);
      expect(prefsOf(container).getString(kWhatsNewLastSeenKey), '1.7.0');
    });

    test('an unusable stored version cannot crash the start', () async {
      final container = await launch(
        initial: {kWhatsNewLastSeenKey: 'build 42'},
      );

      final plan = await container.read(whatsNewPlanProvider.future);

      expect(plan.present, isFalse);
      expect(prefsOf(container).getString(kWhatsNewLastSeenKey), '1.4.0');
    });

    test(
      'a version that cannot be read records nothing and shows nothing',
      () async {
        final container = await launch(
          initial: {kWhatsNewLastSeenKey: '1.3.0'},
          version: 'not-a-version',
        );

        final plan = await container.read(whatsNewPlanProvider.future);

        expect(plan.present, isFalse);
        expect(plan.recordVersion, isNull);
        // The unusable marker is left exactly as it was found.
        expect(prefsOf(container).getString(kWhatsNewLastSeenKey), '1.3.0');
      },
    );
  });

  group('isolation from everything else the app stores', () {
    test('recording the notes writes one key and disturbs no other', () async {
      const others = <String, Object>{
        'theme_mode': 'dark',
        'mochi_smartplay_discovery': true,
        'recently_played_ids': <String>['yt:one'],
        'queue_v1': '{"currentIndex":0}',
      };
      final container = await launch(initial: {...others});

      final plan = await container.read(whatsNewPlanProvider.future);
      expect(plan.present, isTrue);

      final prefs = prefsOf(container);
      // Exactly one key added: nothing cleared, nothing rewritten.
      expect(prefs.getKeys(), {...others.keys, kWhatsNewLastSeenKey});
      expect(prefs.getString('theme_mode'), 'dark');
      expect(prefs.getBool('mochi_smartplay_discovery'), isTrue);
      expect(prefs.getStringList('recently_played_ids'), ['yt:one']);
      expect(prefs.getString('queue_v1'), '{"currentIndex":0}');
    });

    test('listening history is untouched, being a store of its own', () async {
      final dir = await Directory.systemTemp.createTemp('tunefrost_whatsnew');
      addTearDown(() => dir.delete(recursive: true));
      final store = ListeningEventStore(directory: () async => dir);
      final history = [_event('yt:one'), _event('yt:two')];
      await store.save(history);

      final container = await launch(
        initial: {'theme_mode': 'dark'},
        freshInstall: false,
      );
      await container.read(whatsNewPlanProvider.future);

      final file = File('${dir.path}/${ListeningEventStore.fileName}');
      expect(await file.exists(), isTrue);
      expect(await store.load(), history);
      expect(prefsOf(container).getString(kWhatsNewLastSeenKey), '1.4.0');
    });

    test('a first install does not read history to decide anything', () async {
      final dir = await Directory.systemTemp.createTemp('tunefrost_first');
      addTearDown(() => dir.delete(recursive: true));
      final store = ListeningEventStore(directory: () async => dir);
      await store.save([_event('yt:one')]);

      final container = await launch(freshInstall: true);
      final plan = await container.read(whatsNewPlanProvider.future);

      // The decision rests on preferences alone, so history can be neither
      // required nor altered: it is still there, and the plan is still quiet.
      expect(await store.load(), hasLength(1));
      expect(plan.present, isFalse);
    });
  });
}

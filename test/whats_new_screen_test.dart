import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_player/app/theme.dart';
import 'package:music_player/core/providers/theme_provider.dart';
import 'package:music_player/features/whatsnew/providers/whats_new_provider.dart';
import 'package:music_player/features/whatsnew/release_notes.dart';
import 'package:music_player/features/whatsnew/screens/whats_new_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// The screen as the app presents it, with the version read stubbed out —
  /// `package_info_plus` has no platform channel to answer on a test host.
  Future<void> pump(
    WidgetTester tester, {
    String version = '1.4.0',
    double textScale = 1,
    AsyncValue<ReleaseNotes?>? release,
  }) async {
    SharedPreferences.setMockInitialValues({});
    final overrides = [
      sharedPreferencesProvider.overrideWithValue(
        await SharedPreferences.getInstance(),
      ),
      installedVersionProvider.overrideWithValue(AsyncData(version)),
      if (release != null) whatsNewReleaseProvider.overrideWithValue(release),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides,
        child: MaterialApp(
          theme: AppTheme.light,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: const WhatsNewScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows the notes for the installed version', (tester) async {
    await pump(tester);

    expect(find.text('A little something new.'), findsOneWidget);
    expect(find.text('Fresh in 1.4.0 Beta.'), findsOneWidget);
    expect(find.text('Meet Smart Play'), findsOneWidget);
    expect(find.text('Your next listen, your choice'), findsOneWidget);
    expect(find.text('A little visual polish'), findsOneWidget);
    expect(find.byIcon(Icons.auto_awesome_rounded), findsOneWidget);
    expect(
      find.widgetWithText(FilledButton, 'Enjoy the update'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'sets the heading in Outfit and lets the body stay on the theme',
    (tester) async {
      await pump(tester);

      final heading = tester.widget<Text>(find.text('A little something new.'));
      expect(heading.style?.fontFamily, 'Outfit');
      expect(heading.style?.fontWeight, FontWeight.w600);

      // The description carries no family of its own, so it takes the app's —
      // Zen Maru Gothic, as `AppTheme` declares for every other body text.
      final body = tester.widget<Text>(find.text('Fresh in 1.4.0 Beta.'));
      expect(body.style?.fontFamily, isNull);
      expect(AppTheme.light.textTheme.bodyMedium?.fontFamily, 'ZenMaruGothic');
    },
  );

  testWidgets('keeps the beta note quieter than the features above it', (
    tester,
  ) async {
    await pump(tester);

    // It rides at the end of the list, so scroll it into view first.
    await tester.scrollUntilVisible(find.text('A little beta note'), 200);
    await tester.pumpAndSettle();

    expect(find.text('A little beta note'), findsOneWidget);
    expect(find.textContaining('Smart Play is still learning'), findsOneWidget);

    final noteTitle = tester.widget<Text>(find.text('A little beta note'));
    final featureTitle = tester.widget<Text>(find.text('Meet Smart Play'));

    // Smaller than a feature title, and in the dimmer text colour rather than
    // the one the notes above it use.
    expect(
      (noteTitle.style?.fontSize ?? 0) < (featureTitle.style?.fontSize ?? 0),
      isTrue,
    );
    expect(noteTitle.style?.color, isNot(featureTitle.style?.color));

    // It also sits on a surface of its own, unlike the flat rows above it.
    final containers = find.ancestor(
      of: find.text('A little beta note'),
      matching: find.byType(Container),
    );
    expect(tester.widget<Container>(containers.first).decoration, isNotNull);
  });

  testWidgets('saves the beta note for releases flagged beta only', (
    tester,
  ) async {
    // A settled release needs neither the softer name nor the note.
    const stable = ReleaseNotes(
      version: '1.5.0',
      items: [
        ReleaseNoteItem(
          icon: Icons.music_note_rounded,
          title: 'Something else entirely',
          body: 'It landed quietly.',
        ),
      ],
    );

    await pump(
      tester,
      version: '1.5.0',
      release: const AsyncData<ReleaseNotes?>(stable),
    );

    expect(find.text('Fresh in 1.5.0.'), findsOneWidget);
    expect(find.text('A little beta note'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('holds together at twice the system text size', (tester) async {
    await pump(tester, textScale: 2);

    // A RenderFlex overflow would surface here as the test's exception.
    expect(tester.takeException(), isNull);
    expect(find.text('A little something new.'), findsOneWidget);
    expect(
      find.widgetWithText(FilledButton, 'Enjoy the update'),
      findsOneWidget,
    );
  });

  testWidgets('reads on a small Android screen with the button in reach', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await pump(tester);

    // Nothing overflows at the narrow width; a spill would surface here.
    expect(tester.takeException(), isNull);

    // The beta note sits at the end of the list, so it has to be reachable
    // by scrolling rather than stranded below the fold.
    await tester.scrollUntilVisible(find.text('A little beta note'), 200);
    await tester.pumpAndSettle();
    expect(find.text('A little beta note'), findsOneWidget);

    // The one way forward is pinned below the list and never scrolls away.
    final button = tester.getRect(
      find.widgetWithText(FilledButton, 'Enjoy the update'),
    );
    expect(button.bottom, lessThanOrEqualTo(640));
    expect(button.top, greaterThanOrEqualTo(640 - 20 - 52 - 24));
  });

  testWidgets('says nothing instead of failing when there are no notes', (
    tester,
  ) async {
    await pump(tester, version: '');

    expect(find.text('You are up to date.'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Close'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the button dismisses the screen', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          installedVersionProvider.overrideWithValue(const AsyncData('1.4.0')),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(body: Text('library')),
          routes: {'/whatsnew': (context) => const WhatsNewScreen()},
        ),
      ),
    );
    await tester.pumpAndSettle();

    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    navigator.pushNamed('/whatsnew');
    await tester.pumpAndSettle();
    expect(find.byType(WhatsNewScreen), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Enjoy the update'));
    await tester.pumpAndSettle();

    expect(find.byType(WhatsNewScreen), findsNothing);
    expect(find.text('library'), findsOneWidget);
  });
}

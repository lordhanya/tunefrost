import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Theme selector shown in Settings.
///
/// [frosty] is the brand palette: it keeps the app's frosted-glass identity
/// on both brightnesses and simply follows the system's light/dark
/// preference (the light "Frost" or the deep "Midnight Frost" respectively).
enum AppThemeMode {
  system('System default', Icons.brightness_auto_rounded),
  light('Light', Icons.light_mode_rounded),
  dark('Dark', Icons.dark_mode_rounded),
  frosty('Frosty', Icons.ac_unit_rounded);

  const AppThemeMode(this.label, this.icon);

  final String label;
  final IconData icon;
}

/// Four palettes: charcoal dark, washi-paper light, and the frosty brand pair.
///
/// dark      ["#121212", "#1e1e1e", "#6b7280", "#9ca3af", "#a6e1fa"]
/// light     ["#f4f0ea", "#fcf9f4", "#3f5f87", "#7e9a78", "#bc7e89"]
///   washi paper cream, indigo seed (ai-zome), matcha leaf,
///   muted sakura tertiary — Japanese garden, calm not cutesy
///
/// frost     ["#f3f8fc", "#fbfdff", "#2e6fa8", "#3e7390", "#6e5fb8"]
///   cold snow, glacial blue seed, periwinkle "aurora" shimmer —
///   the frosted-glass aesthetic given a palette to live in.
///
/// midnight  ["#0a1622", "#101f2c", "#8fcbe9", "#a5c5d8", "#c6b8f2"]
///   deep navy, glowing ice, the same aurora glow on dark.
abstract final class AppTheme {
  // Dark palette — charcoal/graphite neutrals with the brand cyan accent.
  static const _darkBackground = Color(0xFF121212); // true charcoal
  static const _darkSurface = Color(0xFF1E1E1E); // raised surface
  static const _darkSurfaceVariant = Color(0xFF2A2A2A); // chips, fields
  static const _darkSeed = Color(0xFF6B7280); // neutral gray seed
  static const _darkPrimary = Color(0xFFA6E1FA); // brand cyan (kept)
  static const _darkSecondary = Color(0xFF9CA3AF);
  static const _darkTertiary = Color(0xFFD4A843); // warm gold
  static const _darkOutline = Color(0xFF3D3D3D);
  static const _darkOutlineVariant = Color(0xFF2D2D2D);

  // Light palette — Japanese garden, calm not cutesy.
  static const _lightBackground = Color(0xFFF4F0EA); // washi cream
  static const _lightSurface = Color(0xFFFCF9F4); // warm paper
  static const _lightSeed = Color(0xFF3F5F87); // indigo (ai-zome)
  static const _lightSecondary = Color(0xFF7E9A78); // matcha leaf
  static const _lightOnSecondary = Color(0xFF1E2A1C);
  static const _lightSecondaryContainer = Color(0xFFE0EBDC);
  static const _lightTertiary = Color(0xFFBC7E89); // muted sakura
  static const _lightOnTertiary = Color(0xFFFFFFFF);

  // Frost palette — glacial light: snow, not white. Every surface carries a
  // faint breath of ice; the ink is slate rather than black; the accent is a
  // glacial blue with a periwinkle "aurora" for the shimmer moments.
  static const _frostBackground = Color(0xFFF3F8FC);
  static const _frostSurface = Color(0xFFFBFDFF);
  static const _frostSeed = Color(0xFF85B9E6);
  static const _frostPrimary = Color(0xFF2E6FA8); // glacial blue
  static const _frostOnPrimary = Color(0xFFFFFFFF);
  static const _frostPrimaryContainer = Color(0xFFD7EBFA); // frosted panel
  static const _frostOnPrimaryContainer = Color(0xFF0B2B40);
  static const _frostSecondary = Color(0xFF3E7390); // icy steel
  static const _frostOnSecondary = Color(0xFFFFFFFF);
  static const _frostSecondaryContainer = Color(0xFFCEE7F2);
  static const _frostOnSecondaryContainer = Color(0xFF0B232E);
  static const _frostTertiary = Color(0xFF6E5FB8); // aurora lavender
  static const _frostOnTertiary = Color(0xFFFFFFFF);
  static const _frostTertiaryContainer = Color(0xFFE3DDF9);
  static const _frostOnTertiaryContainer = Color(0xFF221A4D);
  static const _frostOnSurface = Color(0xFF15222C); // slate ink
  static const _frostOnSurfaceVariant = Color(0xFF44586A);
  static const _frostOutline = Color(0xFF7B93A5);
  static const _frostOutlineVariant = Color(0xFFC4D6E4);

  // Midnight Frost palette — deep navy glass, glowing ice, aurora at night.
  static const _midnightBackground = Color(0xFF0A1622);
  static const _midnightSurface = Color(0xFF101F2C);
  static const _midnightSurfaceLowest = Color(0xFF060D14);
  static const _midnightSurfaceLow = Color(0xFF162736);
  static const _midnightSurfaceContainer = Color(0xFF1B2E3E);
  static const _midnightSurfaceHigh = Color(0xFF213547);
  static const _midnightSurfaceHighest = Color(0xFF263C4F);
  static const _midnightSeed = Color(0xFF9CCFF0);
  static const _midnightPrimary = Color(0xFF8FCBE9); // glowing ice
  static const _midnightOnPrimary = Color(0xFF003349);
  static const _midnightPrimaryContainer = Color(0xFF143A52);
  static const _midnightOnPrimaryContainer = Color(0xFFC8E8F8);
  static const _midnightSecondary = Color(0xFFA5C5D8);
  static const _midnightOnSecondary = Color(0xFF0A2A37);
  static const _midnightSecondaryContainer = Color(0xFF1E3A4A);
  static const _midnightOnSecondaryContainer = Color(0xFFCDE9F7);
  static const _midnightTertiary = Color(0xFFC6B8F2); // aurora glow
  static const _midnightOnTertiary = Color(0xFF2B1B5E);
  static const _midnightTertiaryContainer = Color(0xFF3B2F70);
  static const _midnightOnTertiaryContainer = Color(0xFFEBE4FF);
  static const _midnightOnSurface = Color(0xFFE4EDF5); // snow text
  static const _midnightOnSurfaceVariant = Color(0xFFA9BFCE);
  static const _midnightOutline = Color(0xFF5B7486);
  static const _midnightOutlineVariant = Color(0xFF2C4455);

  static final ThemeData light = _build(
    brightness: Brightness.light,
    scaffold: _lightBackground,
    scheme:
        ColorScheme.fromSeed(
          seedColor: _lightSeed,
          brightness: Brightness.light,
        ).copyWith(
          surface: _lightSurface,
          surfaceContainerHighest: const Color(0xFFEDE8DF), // washi shadow
          secondary: _lightSecondary,
          onSecondary: _lightOnSecondary,
          secondaryContainer: _lightSecondaryContainer,
          onSecondaryContainer: _lightOnSecondary,
          tertiary: _lightTertiary,
          onTertiary: _lightOnTertiary,
        ),
  );

  static final ThemeData dark = _build(
    brightness: Brightness.dark,
    scaffold: _darkBackground,
    scheme:
        ColorScheme.fromSeed(
          seedColor: _darkSeed,
          brightness: Brightness.dark,
        ).copyWith(
          primary: _darkPrimary,
          onPrimary: const Color(0xFF000000),
          primaryContainer: const Color(0xFF0E2431),
          onPrimaryContainer: _darkPrimary,
          surface: _darkSurface,
          surfaceContainerHighest: _darkSurfaceVariant,
          secondary: _darkSecondary,
          secondaryContainer: _darkSurfaceVariant,
          onSecondaryContainer: const Color(0xFFE5E7EB),
          tertiary: _darkTertiary,
          onTertiary: const Color(0xFF000000),
          outline: _darkOutline,
          outlineVariant: _darkOutlineVariant,
        ),
  );

  /// The brand palette: frosted glass in daylight. Brightness-following
  /// pairs with [midnightFrost].
  static final ThemeData frost = _build(
    brightness: Brightness.light,
    scaffold: _frostBackground,
    scheme: _frostScheme(Brightness.light),
  );

  /// The brand palette in the dark: deep navy glass lit from within.
  static final ThemeData midnightFrost = _build(
    brightness: Brightness.dark,
    scaffold: _midnightBackground,
    scheme: _frostScheme(Brightness.dark),
  );

  /// One hand-tuned frost scheme for both brightnesses so the identity —
  /// cold snow, glacial blues, aurora lavender — survives the switch.
  static ColorScheme _frostScheme(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final base = ColorScheme.fromSeed(
      seedColor: dark ? _midnightSeed : _frostSeed,
      brightness: brightness,
    );
    if (dark) {
      return base.copyWith(
        primary: _midnightPrimary,
        onPrimary: _midnightOnPrimary,
        primaryContainer: _midnightPrimaryContainer,
        onPrimaryContainer: _midnightOnPrimaryContainer,
        secondary: _midnightSecondary,
        onSecondary: _midnightOnSecondary,
        secondaryContainer: _midnightSecondaryContainer,
        onSecondaryContainer: _midnightOnSecondaryContainer,
        tertiary: _midnightTertiary,
        onTertiary: _midnightOnTertiary,
        tertiaryContainer: _midnightTertiaryContainer,
        onTertiaryContainer: _midnightOnTertiaryContainer,
        surface: _midnightSurface,
        surfaceContainerLowest: _midnightSurfaceLowest,
        surfaceContainerLow: _midnightSurfaceLow,
        surfaceContainer: _midnightSurfaceContainer,
        surfaceContainerHigh: _midnightSurfaceHigh,
        surfaceContainerHighest: _midnightSurfaceHighest,
        onSurface: _midnightOnSurface,
        onSurfaceVariant: _midnightOnSurfaceVariant,
        outline: _midnightOutline,
        outlineVariant: _midnightOutlineVariant,
      );
    }
    return base.copyWith(
      primary: _frostPrimary,
      onPrimary: _frostOnPrimary,
      primaryContainer: _frostPrimaryContainer,
      onPrimaryContainer: _frostOnPrimaryContainer,
      secondary: _frostSecondary,
      onSecondary: _frostOnSecondary,
      secondaryContainer: _frostSecondaryContainer,
      onSecondaryContainer: _frostOnSecondaryContainer,
      tertiary: _frostTertiary,
      onTertiary: _frostOnTertiary,
      tertiaryContainer: _frostTertiaryContainer,
      onTertiaryContainer: _frostOnTertiaryContainer,
      surface: _frostSurface,
      surfaceContainerLowest: const Color(0xFFFFFFFF),
      surfaceContainerLow: const Color(0xFFF1F7FB),
      surfaceContainer: const Color(0xFFEAF3F9),
      surfaceContainerHigh: const Color(0xFFE4EEF6),
      surfaceContainerHighest: const Color(0xFFDCE9F2),
      onSurface: _frostOnSurface,
      onSurfaceVariant: _frostOnSurfaceVariant,
      outline: _frostOutline,
      outlineVariant: _frostOutlineVariant,
    );
  }

  static ThemeData _build({
    required Brightness brightness,
    required Color scaffold,
    required ColorScheme scheme,
  }) {
    final isDark = brightness == Brightness.dark;

    final theme = ThemeData(
      useMaterial3: true,
      // iOS-style push + edge-swipe-back everywhere (Now Playing overrides
      // this with its own card presentation via CardPageRoute).
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.linux: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: CupertinoPageTransitionsBuilder(),
        },
      ),
      brightness: brightness,
      colorScheme: scheme,
      // Zen Maru Gothic bundled in assets/fonts — no runtime font fetch.
      fontFamily: 'ZenMaruGothic',
      scaffoldBackgroundColor: scaffold,
      appBarTheme: AppBarTheme(
        backgroundColor: scaffold,
        // Bright accent on navy; readable ink on pastel.
        foregroundColor: isDark ? scheme.primary : scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: TextStyle(
          color: scheme.onSurface,
          fontSize: 20,
          fontWeight: FontWeight.w500, // Medium for screen titles
          fontFamily: 'ZenMaruGothic',
        ),
      ),
      // One place keeps every row in the app on the same two weights:
      // Medium for the row's title, Regular for its secondary line.
      listTileTheme: ListTileThemeData(
        titleTextStyle: TextStyle(
          color: scheme.onSurface,
          fontSize: 16,
          height: 1.5,
          fontWeight: FontWeight.w500,
          fontFamily: 'ZenMaruGothic',
        ),
        subtitleTextStyle: TextStyle(
          color: scheme.onSurfaceVariant,
          fontSize: 14,
          height: 1.43,
          fontWeight: FontWeight.w400,
          fontFamily: 'ZenMaruGothic',
        ),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: scheme.primary,
        inactiveTrackColor: scheme.outlineVariant,
        thumbColor: scheme.primary,
        overlayColor: scheme.primary.withValues(alpha: 0.14),
        trackHeight: 3,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
      ),
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.dragged)) return scheme.primary;
          if (states.contains(WidgetState.hovered)) {
            return scheme.primary.withValues(alpha: 0.8);
          }
          return scheme.primary.withValues(alpha: 0.5);
        }),
        trackColor: const WidgetStatePropertyAll(Colors.transparent),
        thickness: const WidgetStatePropertyAll(6),
        radius: const Radius.circular(3),
        crossAxisMargin: 4,
        mainAxisMargin: 8,
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        space: 1,
        thickness: 1,
      ),
    );

    return theme;
  }
}
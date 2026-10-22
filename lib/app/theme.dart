import 'package:flutter/material.dart';

/// Default soft palette from CLAUDE.md.
abstract final class Palette {
  static const sky = Color(0xFFCBF0F8);
  static const blue = Color(0xFFAECBFA);
  static const lilac = Color(0xFFD7AEFB);
  static const pink = Color(0xFFFDCFE8);

  // Gentle amount colours. Measured ≥ 5.2:1 on white and on [sky]; see
  // .claude/skills/tracks-design before changing them.
  static const income = Color(0xFF276B4E);
  static const expense = Color(0xFF9E3F5E);
  static const incomeDark = Color(0xFF8FD8B4);
  static const expenseDark = Color(0xFFF4A7C0);

  // Hero gradients. Ink on them is ≥ 8.8:1 (light) / ≥ 12:1 (dark). Green
  // and pink *text* fail on lilac (3.4:1), so hero amounts use ink and show
  // direction with a coloured arrow (icons need 3:1) and the +/− sign.
  static const heroLight = [sky, lilac];
  static const heroDark = [Color(0xFF1E2A44), Color(0xFF33264A)];
  static const heroInkLight = Color(0xFF1B1F2A);
  static const heroInkDark = Color(0xFFEEF0FA);
  static const heroMutedLight = Color(0xFF3D4255);
  static const heroMutedDark = Color(0xFFB9BED0);
}

/// Design tokens beyond ColorScheme: see .claude/skills/tracks-design.
@immutable
class TracksTokens extends ThemeExtension<TracksTokens> {
  const TracksTokens({
    required this.heroGradient,
    required this.heroInk,
    required this.heroMuted,
    required this.heroTrack,
    required this.heroChip,
    required this.seriesA,
    required this.seriesB,
  });

  final List<Color> heroGradient;
  final Color heroInk;
  final Color heroMuted;

  /// Meter track on a hero: fills stay ≥ 4.3:1 against it.
  final Color heroTrack;

  /// Circle behind hero icons: arrows stay ≥ 4.2:1 against it.
  final Color heroChip;

  /// Two-series chart colours: validated categorical slots 1-2 (dataviz).
  final Color seriesA;
  final Color seriesB;

  static const radiusCard = 24.0;
  static const radiusHero = 28.0;

  @override
  TracksTokens copyWith({
    List<Color>? heroGradient,
    Color? heroInk,
    Color? heroMuted,
    Color? heroTrack,
    Color? heroChip,
    Color? seriesA,
    Color? seriesB,
  }) => TracksTokens(
    heroGradient: heroGradient ?? this.heroGradient,
    heroInk: heroInk ?? this.heroInk,
    heroMuted: heroMuted ?? this.heroMuted,
    heroTrack: heroTrack ?? this.heroTrack,
    heroChip: heroChip ?? this.heroChip,
    seriesA: seriesA ?? this.seriesA,
    seriesB: seriesB ?? this.seriesB,
  );

  @override
  TracksTokens lerp(TracksTokens? other, double t) {
    if (other == null) return this;
    return TracksTokens(
      heroGradient: [
        for (var i = 0; i < heroGradient.length; i++)
          Color.lerp(heroGradient[i], other.heroGradient[i], t)!,
      ],
      heroInk: Color.lerp(heroInk, other.heroInk, t)!,
      heroMuted: Color.lerp(heroMuted, other.heroMuted, t)!,
      heroTrack: Color.lerp(heroTrack, other.heroTrack, t)!,
      heroChip: Color.lerp(heroChip, other.heroChip, t)!,
      seriesA: Color.lerp(seriesA, other.seriesA, t)!,
      seriesB: Color.lerp(seriesB, other.seriesB, t)!,
    );
  }
}

ThemeData buildTheme(Brightness brightness) {
  final light = brightness == Brightness.light;
  var scheme = ColorScheme.fromSeed(
    seedColor: Palette.blue,
    brightness: brightness,
  );
  if (light) {
    scheme = scheme.copyWith(
      primaryContainer: Palette.blue,
      secondaryContainer: Palette.sky,
      tertiaryContainer: Palette.lilac,
      surface: const Color(0xFFF8F9FD),
      surfaceContainerLow: const Color(0xFFF2F5FB),
      surfaceContainer: const Color(0xFFECF0F8),
    );
  }
  final base = ThemeData(colorScheme: scheme, useMaterial3: true);
  // Figures read as the hero of the app: tighter tracking, heavier weight.
  final text = base.textTheme.copyWith(
    displaySmall: base.textTheme.displaySmall?.copyWith(
      fontWeight: FontWeight.w600,
      letterSpacing: -1.2,
    ),
    headlineMedium: base.textTheme.headlineMedium?.copyWith(
      fontWeight: FontWeight.w600,
      letterSpacing: -0.6,
    ),
    headlineSmall: base.textTheme.headlineSmall?.copyWith(
      fontWeight: FontWeight.w600,
      letterSpacing: -0.4,
    ),
    titleLarge: base.textTheme.titleLarge?.copyWith(
      fontWeight: FontWeight.w600,
      letterSpacing: -0.2,
    ),
    titleMedium: base.textTheme.titleMedium?.copyWith(
      fontWeight: FontWeight.w600,
    ),
  );
  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    textTheme: text,
    scaffoldBackgroundColor: scheme.surface,
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: text.titleLarge?.copyWith(color: scheme.onSurface),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: scheme.surfaceContainerLow,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(TracksTokens.radiusCard),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: scheme.surfaceContainerLow,
      indicatorColor: scheme.secondaryContainer,
      labelTextStyle: WidgetStatePropertyAll(text.labelMedium),
    ),
    extensions: [
      TracksTokens(
        heroGradient: light ? Palette.heroLight : Palette.heroDark,
        heroInk: light ? Palette.heroInkLight : Palette.heroInkDark,
        heroMuted: light ? Palette.heroMutedLight : Palette.heroMutedDark,
        heroTrack: light
            ? Colors.white.withValues(alpha: 0.45)
            : Palette.heroInkDark.withValues(alpha: 0.10),
        heroChip: light
            ? Colors.white.withValues(alpha: 0.35)
            : Palette.heroInkDark.withValues(alpha: 0.08),
        seriesA: light ? const Color(0xFF2A78D6) : const Color(0xFF3987E5),
        seriesB: light ? const Color(0xFFEB6834) : const Color(0xFFD95926),
      ),
    ],
    visualDensity: VisualDensity.standard,
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(28),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
    ),
    chipTheme: const ChipThemeData(showCheckmark: false),
  );
}

extension AmountColors on ThemeData {
  Color get incomeColor =>
      brightness == Brightness.light ? Palette.income : Palette.incomeDark;
  Color get expenseColor =>
      brightness == Brightness.light ? Palette.expense : Palette.expenseDark;
}

extension TokensX on ThemeData {
  TracksTokens get tokens => extension<TracksTokens>()!;
}

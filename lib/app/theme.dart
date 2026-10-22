import 'package:flutter/material.dart';

/// "Marigold & chai": warm paper, marigold-to-coral heroes, espresso ink.
/// Owner moved away from the blue/purple pastels on 2026-10-23. Every pair
/// below was measured; see .claude/skills/tracks-design before changing.
abstract final class Palette {
  // Category / account fills (always with dark ink on top).
  static const sand = Color(0xFFF3E3C4);
  static const marigoldSoft = Color(0xFFFBE3A8);
  static const coralSoft = Color(0xFFF8D2C2);
  static const sage = Color(0xFFD6E7D2);
  static const jadeSoft = Color(0xFFC9E7DD);
  static const clay = Color(0xFFE9C9B5);
  static const blush = Color(0xFFF6D5D0);
  static const butter = Color(0xFFF7EBB5);

  // Amount colours: ≥ 5.2:1 on every light surface, ≥ 7.8:1 on dark ones.
  static const income = Color(0xFF1E6B4F);
  static const expense = Color(0xFFA63A2B);
  static const incomeDark = Color(0xFF8FD3B0);
  static const expenseDark = Color(0xFFF2A08A);

  // Hero gradients. Ink ≥ 8:1 on both ends (light), ≥ 10.8:1 (dark).
  static const heroLight = [Color(0xFFF7C35F), Color(0xFFF29E7A)];
  static const heroDark = [Color(0xFF3A2A1E), Color(0xFF183A31)];
  static const heroInkLight = Color(0xFF221C15);
  static const heroInkDark = Color(0xFFF5EFE6);
  static const heroMutedLight = Color(0xFF4A3F33);
  static const heroMutedDark = Color(0xFFC9BFB2);
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

  /// Meter track on a hero.
  final Color heroTrack;

  /// Circle behind hero icons.
  final Color heroChip;

  /// Two-series chart colours, validated with the dataviz script (CVD ΔE
  /// ≥ 8.8, ≥ 3:1 on the surface): jade + saffron.
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

ColorScheme _scheme(Brightness b) {
  final seeded = ColorScheme.fromSeed(
    seedColor: const Color(0xFFB07A2A),
    brightness: b,
  );
  if (b == Brightness.light) {
    return seeded.copyWith(
      primary: const Color(0xFF2B2118),
      onPrimary: const Color(0xFFFBF6EC),
      primaryContainer: Palette.marigoldSoft,
      onPrimaryContainer: const Color(0xFF3A2A10),
      secondary: const Color(0xFF6B5532),
      secondaryContainer: Palette.sand,
      onSecondaryContainer: const Color(0xFF221C15),
      tertiary: const Color(0xFF9A4A2E),
      tertiaryContainer: Palette.coralSoft,
      onTertiaryContainer: const Color(0xFF4A2014),
      surface: const Color(0xFFFBF6EC),
      onSurface: const Color(0xFF221C15),
      onSurfaceVariant: const Color(0xFF5A4E40),
      surfaceContainerLowest: const Color(0xFFFFFCF6),
      surfaceContainerLow: const Color(0xFFF5EEE1),
      surfaceContainer: const Color(0xFFEFE6D5),
      surfaceContainerHigh: const Color(0xFFE9DFCC),
      surfaceContainerHighest: const Color(0xFFE3D8C3),
      outline: const Color(0xFF8A7C6A),
      outlineVariant: const Color(0xFFD9CDB8),
      inverseSurface: const Color(0xFF2B2118),
      onInverseSurface: const Color(0xFFFBF6EC),
    );
  }
  return seeded.copyWith(
    primary: const Color(0xFFF7C35F),
    onPrimary: const Color(0xFF2B1E05),
    primaryContainer: const Color(0xFF4A3A1C),
    onPrimaryContainer: Palette.marigoldSoft,
    secondary: const Color(0xFFE3CFA6),
    secondaryContainer: const Color(0xFF3A3024),
    onSecondaryContainer: Palette.sand,
    tertiary: const Color(0xFFF2A08A),
    tertiaryContainer: const Color(0xFF4A2A20),
    onTertiaryContainer: Palette.coralSoft,
    surface: const Color(0xFF16120E),
    onSurface: const Color(0xFFF5EFE6),
    onSurfaceVariant: const Color(0xFFCBBFAF),
    surfaceContainerLowest: const Color(0xFF110E0B),
    surfaceContainerLow: const Color(0xFF1E1914),
    surfaceContainer: const Color(0xFF261F18),
    surfaceContainerHigh: const Color(0xFF30281F),
    surfaceContainerHighest: const Color(0xFF3A3127),
    outline: const Color(0xFF9A8C7A),
    outlineVariant: const Color(0xFF4A4036),
    inverseSurface: const Color(0xFFF5EFE6),
    onInverseSurface: const Color(0xFF221C15),
  );
}

ThemeData buildTheme(Brightness brightness) {
  final light = brightness == Brightness.light;
  final scheme = _scheme(brightness);
  final base = ThemeData(colorScheme: scheme, useMaterial3: true);
  // Figures are the hero of the app: tighter tracking, heavier weight.
  final text = base.textTheme.copyWith(
    displayMedium: base.textTheme.displayMedium?.copyWith(
      fontWeight: FontWeight.w700,
      letterSpacing: -1.6,
      height: 1.05,
    ),
    displaySmall: base.textTheme.displaySmall?.copyWith(
      fontWeight: FontWeight.w700,
      letterSpacing: -1.2,
    ),
    headlineMedium: base.textTheme.headlineMedium?.copyWith(
      fontWeight: FontWeight.w700,
      letterSpacing: -0.8,
    ),
    headlineSmall: base.textTheme.headlineSmall?.copyWith(
      fontWeight: FontWeight.w700,
      letterSpacing: -0.5,
    ),
    titleLarge: base.textTheme.titleLarge?.copyWith(
      fontWeight: FontWeight.w700,
      letterSpacing: -0.3,
    ),
    titleMedium: base.textTheme.titleMedium?.copyWith(
      fontWeight: FontWeight.w600,
    ),
    labelLarge: base.textTheme.labelLarge?.copyWith(
      fontWeight: FontWeight.w600,
      letterSpacing: 0.1,
    ),
  );
  final pill = RoundedRectangleBorder(borderRadius: BorderRadius.circular(28));
  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    textTheme: text,
    scaffoldBackgroundColor: scheme.surface,
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      // Explicit sizes: theme text styles only get their font size when
      // MaterialApp localizes the theme, and AppBar styles are not.
      titleTextStyle: TextStyle(
        fontSize: 26,
        height: 1.2,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.6,
        color: scheme.onSurface,
      ),
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
      indicatorColor: scheme.primaryContainer,
      labelTextStyle: WidgetStatePropertyAll(
        TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: scheme.onSurface,
        ),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(shape: pill),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: scheme.primary,
      foregroundColor: scheme.onPrimary,
      shape: pill,
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? scheme.primary
              : Colors.transparent,
        ),
        foregroundColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? scheme.onPrimary
              : scheme.onSurface,
        ),
        side: WidgetStatePropertyAll(BorderSide(color: scheme.outline)),
      ),
    ),
    chipTheme: ChipThemeData(
      showCheckmark: false,
      selectedColor: scheme.primaryContainer,
      side: BorderSide(color: scheme.outlineVariant),
    ),
    extensions: [
      TracksTokens(
        heroGradient: light ? Palette.heroLight : Palette.heroDark,
        heroInk: light ? Palette.heroInkLight : Palette.heroInkDark,
        heroMuted: light ? Palette.heroMutedLight : Palette.heroMutedDark,
        heroTrack: light
            ? Colors.white.withValues(alpha: 0.45)
            : Palette.heroInkDark.withValues(alpha: 0.12),
        heroChip: light
            ? Colors.white.withValues(alpha: 0.40)
            : Palette.heroInkDark.withValues(alpha: 0.10),
        seriesA: light ? const Color(0xFF1B8A72) : const Color(0xFF239A7F),
        seriesB: light ? const Color(0xFFD4672A) : const Color(0xFFD9692C),
      ),
    ],
    visualDensity: VisualDensity.standard,
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainer,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(28),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
    ),
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

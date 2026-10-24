import 'package:flutter/material.dart';
import 'package:tracks/app/theme.dart';

/// Hero/accent choices. All warm (owner's decision: no blue or purple);
/// ink and muted text measured ≥ 8:1 and ≥ 4.9:1 on both gradient ends.
enum HeroAccent {
  marigold(
    'Marigold',
    [Color(0xFFF7C35F), Color(0xFFF29E7A)],
    [Color(0xFF3A2A1E), Color(0xFF183A31)],
    Palette.marigoldSoft,
  ),
  jade(
    'Jade',
    [Color(0xFFA8DCC4), Color(0xFFD4E6A8)],
    [Color(0xFF16352C), Color(0xFF1F3A26)],
    Palette.jadeSoft,
  ),
  clay(
    'Clay',
    [Color(0xFFEFC7A8), Color(0xFFE3A98E)],
    [Color(0xFF3A271D), Color(0xFF2C1F1A)],
    Palette.clay,
  ),
  rose(
    'Rose',
    [Color(0xFFF6CBB8), Color(0xFFF0AFA4)],
    [Color(0xFF3A2420), Color(0xFF2E1D1A)],
    Palette.blush,
  );

  const HeroAccent(this.label, this.light, this.dark, this.soft);

  final String label;
  final List<Color> light;
  final List<Color> dark;

  /// Selected chips and the navigation indicator (light theme).
  final Color soft;
}

/// Text size on top of the phone's own setting.
enum TextSize {
  small('Small', 0.9),
  normal('Default', 1.0),
  large('Large', 1.15),
  larger('Larger', 1.3);

  const TextSize(this.label, this.factor);
  final String label;
  final double factor;
}

/// What the user picked in More → Appearance.
@immutable
class Appearance {
  const Appearance({
    this.mode = ThemeMode.system,
    this.accent = HeroAccent.marigold,
    this.textSize = TextSize.normal,
    this.compact = false,
  });

  final ThemeMode mode;
  final HeroAccent accent;
  final TextSize textSize;
  final bool compact;

  static const modeKey = 'appearance.mode';
  static const accentKey = 'appearance.accent';
  static const textKey = 'appearance.text';
  static const compactKey = 'appearance.compact';

  /// From the stored settings; anything unknown falls back to the default.
  factory Appearance.fromSettings(Map<String, String> s) {
    T pick<T extends Enum>(List<T> values, String? name, T fallback) =>
        values.where((v) => v.name == name).firstOrNull ?? fallback;
    return Appearance(
      mode: pick(ThemeMode.values, s[modeKey], ThemeMode.system),
      accent: pick(HeroAccent.values, s[accentKey], HeroAccent.marigold),
      textSize: pick(TextSize.values, s[textKey], TextSize.normal),
      compact: s[compactKey] == '1',
    );
  }
}

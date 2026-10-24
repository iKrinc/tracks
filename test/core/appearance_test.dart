import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tracks/app/appearance.dart';
import 'package:tracks/app/theme.dart';

void main() {
  test('nothing stored gives the defaults', () {
    final a = Appearance.fromSettings(const {});
    expect(a.mode, ThemeMode.system);
    expect(a.accent, HeroAccent.marigold);
    expect(a.textSize, TextSize.normal);
    expect(a.compact, isFalse);
  });

  test('stored choices are read back; unknown values fall back', () {
    final a = Appearance.fromSettings(const {
      Appearance.modeKey: 'dark',
      Appearance.accentKey: 'jade',
      Appearance.textKey: 'large',
      Appearance.compactKey: '1',
    });
    expect(a.mode, ThemeMode.dark);
    expect(a.accent, HeroAccent.jade);
    expect(a.textSize, TextSize.large);
    expect(a.compact, isTrue);
    final b = Appearance.fromSettings(const {
      Appearance.modeKey: 'purple',
      Appearance.accentKey: 'blue',
    });
    expect(b.mode, ThemeMode.system);
    expect(b.accent, HeroAccent.marigold);
  });

  test('every accent builds both themes with its own hero', () {
    for (final accent in HeroAccent.values) {
      for (final b in Brightness.values) {
        final t = buildTheme(b, accent: accent);
        expect(
          t.tokens.heroGradient,
          b == Brightness.light ? accent.light : accent.dark,
        );
      }
    }
  });
}

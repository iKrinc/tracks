import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tracks/app/appearance.dart';
import 'package:tracks/app/providers.dart';
import 'package:tracks/app/theme.dart';
import 'package:tracks/app/widgets/hero.dart';

/// More → Appearance: light/dark, hero colour, text size, density. Each
/// change applies at once; the hero at the top previews it.
class AppearanceScreen extends ConsumerWidget {
  const AppearanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final tokens = theme.tokens;
    final a = ref.watch(appearanceProvider);
    final db = ref.read(appDatabaseProvider);

    Widget label(String text) => Padding(
      padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
      child: Text(text, style: theme.textTheme.titleSmall),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Appearance')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          HeroCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'This month',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: tokens.heroMuted,
                  ),
                ),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '₹12,340.00',
                    style: theme.textTheme.displaySmall?.copyWith(
                      color: tokens.heroInk,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
                Text(
                  'A preview of your choices',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: tokens.heroInk,
                  ),
                ),
              ],
            ),
          ),
          label('Theme'),
          SegmentedButton<ThemeMode>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: ThemeMode.system, label: Text('Phone')),
              ButtonSegment(value: ThemeMode.light, label: Text('Light')),
              ButtonSegment(value: ThemeMode.dark, label: Text('Dark')),
            ],
            selected: {a.mode},
            onSelectionChanged: (s) =>
                db.setSetting(Appearance.modeKey, s.first.name),
          ),
          label('Colour'),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final accent in HeroAccent.values)
                _Swatch(
                  accent: accent,
                  selected: a.accent == accent,
                  onTap: () => db.setSetting(Appearance.accentKey, accent.name),
                ),
            ],
          ),
          label('Text size'),
          SegmentedButton<TextSize>(
            showSelectedIcon: false,
            segments: [
              for (final t in TextSize.values)
                ButtonSegment(value: t, label: Text(t.label)),
            ],
            selected: {a.textSize},
            onSelectionChanged: (s) =>
                db.setSetting(Appearance.textKey, s.first.name),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 6, 4, 0),
            child: Text(
              "On top of your phone's own text size.",
              style: theme.textTheme.bodySmall,
            ),
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 4),
            title: const Text('Compact'),
            subtitle: const Text('Tighter lists and buttons, more on screen'),
            value: a.compact,
            onChanged: (v) =>
                db.setSetting(Appearance.compactKey, v ? '1' : '0'),
          ),
        ],
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.accent,
    required this.selected,
    required this.onTap,
  });

  final HeroAccent accent;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      button: true,
      selected: selected,
      label: '${accent.label} colour',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Column(
          children: [
            Container(
              width: 64,
              height: 48,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                // Always the light gradient: the dark ones are too close
                // to tell apart at swatch size.
                gradient: LinearGradient(colors: accent.light),
                border: Border.all(
                  color: selected
                      ? theme.colorScheme.onSurface
                      : theme.colorScheme.outlineVariant,
                  width: selected ? 3 : 1,
                ),
              ),
              child: selected
                  ? const Icon(Icons.check, color: Palette.heroInkLight)
                  : null,
            ),
            const SizedBox(height: 4),
            Text(accent.label, style: theme.textTheme.labelMedium),
          ],
        ),
      ),
    );
  }
}

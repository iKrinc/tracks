import 'package:flutter/material.dart';
import 'package:tracks/app/theme.dart';
import 'package:tracks/core/money.dart';
import 'package:tracks/features/budgets/domain/budget_math.dart';

/// Budget meter: a same-hue track and fill, plus a status line with an
/// icon and words, so the state never relies on colour alone.
class BudgetMeter extends StatelessWidget {
  const BudgetMeter({super.key, required this.progress, this.onHero = false});

  final BudgetProgress progress;

  /// On a [HeroCard] gradient: use hero ink for text.
  final bool onHero;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final p = progress;
    final (IconData icon, String label, Color fill) = switch (p.level) {
      BudgetLevel.ok => (
        Icons.check_circle_outline,
        '${formatPaise(p.remainingPaise, hideZeroPaise: true)} left',
        scheme.primary,
      ),
      BudgetLevel.warning => (
        Icons.warning_amber_rounded,
        '${p.percent}% used · '
            '${formatPaise(p.remainingPaise, hideZeroPaise: true)} left',
        theme.expenseColor,
      ),
      BudgetLevel.over => (
        Icons.error_outline,
        'Over by ${formatPaise(-p.remainingPaise, hideZeroPaise: true)}',
        theme.expenseColor,
      ),
    };
    final ink = onHero ? theme.tokens.heroInk : scheme.onSurface;
    return Semantics(
      label:
          '${spokenPaise(p.spentPaise)} spent of ${spokenPaise(p.limitPaise)}. '
          '$label',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: p.limitPaise <= 0
                  ? 1
                  : (p.spentPaise / p.limitPaise).clamp(0.0, 1.0),
              minHeight: 10,
              color: fill,
              backgroundColor: onHero
                  ? theme.tokens.heroTrack
                  : scheme.surfaceContainer,
            ),
          ),
          const SizedBox(height: 8),
          // Wrap, so at large text the amounts drop below instead of
          // squeezing the status into a sliver.
          Wrap(
            spacing: 12,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icon,
                    size: 18,
                    color: p.level == BudgetLevel.ok ? ink : theme.expenseColor,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: theme.textTheme.bodyMedium?.copyWith(color: ink),
                  ),
                ],
              ),
              Text(
                '${formatPaise(p.spentPaise, hideZeroPaise: true)} '
                'of ${formatPaise(p.limitPaise, hideZeroPaise: true)}',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: onHero
                      ? theme.tokens.heroMuted
                      : scheme.onSurfaceVariant,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

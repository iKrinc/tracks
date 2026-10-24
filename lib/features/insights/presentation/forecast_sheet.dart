import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tracks/app/providers.dart';
import 'package:tracks/app/theme.dart';
import 'package:tracks/app/widgets/hero.dart';
import 'package:tracks/core/dates.dart';
import 'package:tracks/core/money.dart';

String _day(DateTime d, DateTime today) {
  final n = daysBetween(today, d);
  if (n == 0) return 'Today';
  if (n == 1) return 'Tomorrow';
  return '${weekdayShort(d)}, ${shortDate(d).replaceFirst(' ${d.year}', '')}';
}

/// One line on Home: what's left before payday and a daily allowance.
/// Opens the full forecast.
class ForecastTile extends ConsumerWidget {
  const ForecastTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final f = ref.watch(cashForecastProvider);
    // Nothing to forecast from yet: no bills and no spending history.
    if (f == null || (f.events.isEmpty && f.dailySpendPaise == 0)) {
      return const SizedBox.shrink();
    }
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final short = f.goesNegative;
    final until = f.payday == null
        ? 'in 30 days'
        : 'before payday (${_day(f.payday!, f.today)})';
    final title = short
        ? 'Short by ${formatPaise(-f.lowestPaise, hideZeroPaise: true)} '
              'on ${_day(f.lowestOn, f.today)}'
        : '${formatPaise(f.endPaise, hideZeroPaise: true)} left $until';
    final window = f.payday == null ? 'in the next 30 days' : 'before payday';
    final subtitle = !short
        ? 'Spend up to ${formatPaise(f.dailyAllowancePaise, hideZeroPaise: true)} a day'
        : f.billsExceedMoney
        ? 'Bills due $window are more than you have'
        : 'At your usual ${formatPaise(f.dailySpendPaise, hideZeroPaise: true)} '
              'a day of spending';
    final fg = short ? scheme.onTertiaryContainer : scheme.onSurface;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Material(
        color: short ? scheme.tertiaryContainer : scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        child: Semantics(
          button: true,
          excludeSemantics: true,
          label: '$title. $subtitle. Opens the forecast',
          onTap: () => showForecastSheet(context),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => showForecastSheet(context),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(
                    short ? Icons.warning_amber_rounded : Icons.event_available,
                    color: fg,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: fg,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                        Text(
                          subtitle,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontFeatures: const [FontFeature.tabularFigures()],
                            color: short
                                ? scheme.onTertiaryContainer
                                : scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: fg),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> showForecastSheet(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (_) => const _ForecastSheet(),
    );

class _ForecastSheet extends ConsumerWidget {
  const _ForecastSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final f = ref.watch(cashForecastProvider);
    if (f == null) return const SizedBox(height: 120);
    final theme = Theme.of(context);
    final tokens = theme.tokens;
    final short = f.goesNegative;

    // Running balance after each event, with everyday spending to that day.
    var bills = f.startPaise;
    final rows = [
      for (final e in f.events)
        () {
          bills += e.deltaPaise;
          return (
            event: e,
            name: e.overdue ? '${e.name} (overdue)' : e.name,
            after: bills - f.dailySpendPaise * daysBetween(f.today, e.date),
          );
        }(),
    ];

    final endLabel = f.payday == null
        ? 'Left on ${_day(f.end, f.today)}'
        : 'Left the day before payday (${_day(f.end, f.today)})';

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (context, scroll) => ListView(
        controller: scroll,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
            child: Text(
              f.payday == null ? 'Next 30 days' : 'Until payday',
              style: theme.textTheme.headlineSmall,
            ),
          ),
          HeroCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  endLabel,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: tokens.heroMuted,
                  ),
                ),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: AnimatedAmount(
                    f.endPaise,
                    semanticsPrefix: '$endLabel: ',
                    style: theme.textTheme.displaySmall?.copyWith(
                      color: tokens.heroInk,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 24,
                  runSpacing: 8,
                  children: [
                    _Stat(
                      label: 'Spend up to',
                      value:
                          '${formatPaise(f.dailyAllowancePaise, hideZeroPaise: true)} a day',
                    ),
                    _Stat(
                      label: short ? 'Lowest point' : 'Lowest',
                      value:
                          '${formatPaise(f.lowestPaise, hideZeroPaise: true)}, '
                          '${_day(f.lowestOn, f.today)}',
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (short) ...[
            const SizedBox(height: 12),
            _Banner(
              text:
                  'On ${_day(f.lowestOn, f.today)} you would be '
                  '${formatPaise(-f.lowestPaise)} short. Move money in, '
                  'or pay a bill a little later.',
            ),
          ],
          const SizedBox(height: 16),
          _Row(
            date: 'Today',
            name: 'Cash, bank and wallets',
            amount: formatPaise(f.startPaise),
            amountColor: theme.colorScheme.onSurface,
            spoken: 'You have ${spokenPaise(f.startPaise)} now',
          ),
          for (final r in rows)
            _Row(
              date: _day(r.event.date, f.today),
              name: r.name,
              amount:
                  '${r.event.deltaPaise > 0 ? '+' : '−'}'
                  '${formatPaise(r.event.deltaPaise.abs())}',
              amountColor: r.event.deltaPaise > 0
                  ? theme.incomeColor
                  : theme.expenseColor,
              after: formatPaise(r.after),
              spoken:
                  '${_day(r.event.date, f.today)}, ${r.name}, '
                  '${spokenPaise(r.event.deltaPaise.abs())} '
                  '${r.event.deltaPaise > 0 ? 'income' : 'expense'}, '
                  'leaving ${spokenPaise(r.after)}',
              onTap: r.event.recurringId == null
                  ? null
                  : () {
                      Navigator.pop(context);
                      context.push('/bills');
                    },
            ),
          if (f.events.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'No bills due before then. Add rent, EMIs and salary in '
                'More → Bills & autopay to see them here.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          const SizedBox(height: 16),
          Text(
            [
              if (f.dailySpendPaise > 0)
                'Includes ${formatPaise(f.dailySpendPaise, hideZeroPaise: true)} '
                    'a day of everyday spending, your average over the last '
                    '60 days with bills left out.',
              'Overdue bills are counted today. Card spends count when the '
                  'card bill is due. Salary is the payday when it\'s a bill in '
                  'Bills & autopay.',
            ].join(' '),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(color: tokens.heroMuted),
        ),
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            color: tokens.heroInk,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ExcludeSemantics(
            child: Icon(
              Icons.warning_amber_rounded,
              color: scheme.onTertiaryContainer,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: scheme.onTertiaryContainer),
            ),
          ),
        ],
      ),
    );
  }
}

/// A dated line of the forecast: what moves, and what's left after.
class _Row extends StatelessWidget {
  const _Row({
    required this.date,
    required this.name,
    required this.amount,
    required this.amountColor,
    required this.spoken,
    this.after,
    this.onTap,
  });

  final String date;
  final String name;
  final String amount;
  final Color amountColor;
  final String spoken;
  final String? after;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return Semantics(
      button: onTap != null,
      excludeSemantics: true,
      label: spoken,
      onTap: onTap,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: theme.textTheme.bodyMedium),
                      Text(
                        date,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: muted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      amount,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: amountColor,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    if (after != null)
                      Text(
                        after!,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: muted,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:tracks/app/theme.dart';
import 'package:tracks/core/dates.dart';
import 'package:tracks/core/money.dart';
import 'package:tracks/data/app_database.dart';
import 'package:tracks/features/transactions/domain/summary.dart';
import 'package:tracks/features/transactions/presentation/txn_list.dart';

const _weekdayHeads = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

/// Month grid with each day's income/expense; tapping a day selects it.
class CalendarGrid extends StatelessWidget {
  const CalendarGrid({
    super.key,
    required this.month,
    required this.txns,
    required this.selected,
    required this.onSelect,
  });

  final DateTime month;
  final List<Transaction> txns;
  final DateTime? selected;
  final ValueChanged<DateTime> onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final byDay = <DateTime, List<Transaction>>{};
    for (final t in txns) {
      byDay.putIfAbsent(dateOnly(t.occurredAt), () => []).add(t);
    }
    final today = dateOnly(DateTime.now());
    final cells = calendarCells(month);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        children: [
          Row(
            children: [
              for (final h in _weekdayHeads)
                Expanded(
                  child: Center(
                    child: Text(h, style: theme.textTheme.labelMedium),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          // IntrinsicHeight keeps a week's cells equal when large text makes
          // one of them taller than the 56 dp minimum.
          for (var row = 0; row < cells.length; row += 7)
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final day in cells.sublist(row, row + 7))
                    Expanded(
                      child: day == null
                          ? const SizedBox(height: 56)
                          : _DayCell(
                              day: day,
                              totals: totalsOfTxns(byDay[day] ?? const []),
                              isToday: day == today,
                              isSelected: day == selected,
                              onTap: () => onSelect(day),
                            ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.totals,
    required this.isToday,
    required this.isSelected,
    required this.onTap,
  });

  final DateTime day;
  final Totals totals;
  final bool isToday;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final small = theme.textTheme.labelSmall?.copyWith(
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    final label = [
      '${day.day} ${monthLabel(day)}',
      if (totals.incomePaise > 0) '${spokenPaise(totals.incomePaise)} income',
      if (totals.expensePaise > 0)
        '${spokenPaise(totals.expensePaise)} expense',
    ].join(', ');

    return Semantics(
      button: true,
      selected: isSelected,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 56),
          margin: const EdgeInsets.all(1),
          decoration: BoxDecoration(
            color: isSelected ? scheme.primaryContainer : null,
            borderRadius: BorderRadius.circular(12),
            border: isToday && !isSelected
                ? Border.all(color: scheme.primary)
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${day.day}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: isSelected ? scheme.onPrimaryContainer : null,
                ),
              ),
              if (totals.incomePaise > 0)
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    '+${compactPaise(totals.incomePaise)}',
                    style: small?.copyWith(
                      color: isSelected
                          ? scheme.onPrimaryContainer
                          : theme.incomeColor,
                    ),
                  ),
                ),
              if (totals.expensePaise > 0)
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    '−${compactPaise(totals.expensePaise)}',
                    style: small?.copyWith(
                      color: isSelected
                          ? scheme.onPrimaryContainer
                          : theme.expenseColor,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

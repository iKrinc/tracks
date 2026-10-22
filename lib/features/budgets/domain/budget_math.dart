import 'package:tracks/data/tables.dart';
import 'package:tracks/features/transactions/domain/summary.dart';

enum BudgetLevel { ok, warning, over }

typedef BudgetProgress = ({
  int limitPaise,
  int spentPaise,
  int remainingPaise,
  int percent,
  BudgetLevel level,
});

/// Spending against a limit (plus any rolled-over unspent amount).
/// Warning from 80%, over from 100%.
BudgetProgress budgetProgress({
  required int limitPaise,
  required int spentPaise,
  int rolloverPaise = 0,
}) {
  final limit = limitPaise + rolloverPaise;
  final percent = limit <= 0 ? 100 : spentPaise * 100 ~/ limit;
  return (
    limitPaise: limit,
    spentPaise: spentPaise,
    remainingPaise: limit - spentPaise,
    percent: percent,
    level: limit <= 0 || percent >= 100
        ? BudgetLevel.over
        : percent >= 80
        ? BudgetLevel.warning
        : BudgetLevel.ok,
  );
}

/// Unspent amount carried into the next period; overspending isn't carried.
int rolloverFrom({required int limitPaise, required int spentPaise}) {
  final left = limitPaise - spentPaise;
  return left > 0 ? left : 0;
}

/// What can be spent per day for the rest of the month (today included).
int dailyAllowance({required int remainingPaise, required DateTime today}) {
  if (remainingPaise <= 0) return 0;
  final lastDay = DateTime(today.year, today.month + 1, 0).day;
  return remainingPaise ~/ (lastDay - today.day + 1);
}

/// Expenses in [month] counted against a budget: all of them for an
/// overall budget ([categoryId] null), else that category and its
/// subcategories.
int spentInMonth(
  Iterable<DatedTxn> txns,
  DateTime month,
  int? categoryId, {
  required Map<int, int?> parentOf,
}) {
  var sum = 0;
  for (final t in txns) {
    if (t.type != TxnType.expense ||
        t.occurredAt.year != month.year ||
        t.occurredAt.month != month.month) {
      continue;
    }
    if (categoryId != null) {
      final c = t.categoryId;
      if (c == null || (c != categoryId && parentOf[c] != categoryId)) continue;
    }
    sum += t.amountPaise;
  }
  return sum;
}

import 'package:tracks/core/dates.dart';
import 'package:tracks/data/tables.dart';
import 'package:tracks/features/transactions/domain/summary.dart';

/// One slice of a category chart. [shareBp] is the share of the total in
/// basis points (1/100 of a percent), so it stays an integer.
typedef CategorySlice = ({int? categoryId, int sumPaise, int shareBp});

/// Sums [type] transactions per top-level category (subcategories roll up
/// via [parentOf]), largest first. Uncategorised is a slice with a null id.
List<CategorySlice> categoryBreakdown(
  Iterable<DatedTxn> txns,
  TxnType type, {
  required Map<int, int?> parentOf,
}) {
  final sums = <int?, int>{};
  for (final t in txns) {
    if (t.type != type) continue;
    final id = t.categoryId;
    final top = id == null ? null : (parentOf[id] ?? id);
    sums[top] = (sums[top] ?? 0) + t.amountPaise;
  }
  final total = sums.values.fold(0, (a, b) => a + b);
  final slices = [
    for (final e in sums.entries)
      (
        categoryId: e.key,
        sumPaise: e.value,
        shareBp: total == 0 ? 0 : e.value * 10000 ~/ total,
      ),
  ]..sort((a, b) => b.sumPaise.compareTo(a.sumPaise));
  return slices;
}

/// Running total of [type] (expense by default) for each day of [month]:
/// index 0 is day 1. For the current month, stops at [today] so the line
/// doesn't run flat into the future.
List<int> cumulativeSpend(
  Iterable<DatedTxn> txns,
  DateTime month, {
  DateTime? today,
  TxnType type = TxnType.expense,
}) {
  final days = DateTime(month.year, month.month + 1, 0).day;
  final perDay = List.filled(days, 0);
  for (final t in txns) {
    final d = t.occurredAt;
    if (t.type == type && d.year == month.year && d.month == month.month) {
      perDay[d.day - 1] += t.amountPaise;
    }
  }
  var last = days;
  if (today != null && monthStart(today) == monthStart(month)) {
    last = today.day;
  }
  var run = 0;
  return [for (var i = 0; i < last; i++) run += perDay[i]];
}

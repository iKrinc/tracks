import 'package:tracks/core/dates.dart';
import 'package:tracks/data/tables.dart';

/// Totals in paise. Transfers move money between own accounts, so they
/// count toward neither income nor expense.
class Totals {
  const Totals(this.incomePaise, this.expensePaise);

  final int incomePaise;
  final int expensePaise;
  int get netPaise => incomePaise - expensePaise;
}

Totals totalsOf(Iterable<({TxnType type, int amountPaise})> txns) {
  var income = 0;
  var expense = 0;
  for (final t in txns) {
    switch (t.type) {
      case TxnType.income:
        income += t.amountPaise;
      case TxnType.expense:
        expense += t.amountPaise;
      case TxnType.transfer:
        break;
    }
  }
  return Totals(income, expense);
}

/// Groups items by calendar day, keeping input order inside each day and
/// days in first-seen order (input is expected newest first).
List<(DateTime day, List<T> items)> groupByDay<T>(
  Iterable<T> items,
  DateTime Function(T) dateOf,
) {
  final groups = <DateTime, List<T>>{};
  for (final item in items) {
    groups.putIfAbsent(dateOnly(dateOf(item)), () => []).add(item);
  }
  return [for (final e in groups.entries) (e.key, e.value)];
}

/// The fields period and report maths need, decoupled from drift rows.
typedef DatedTxn = ({
  TxnType type,
  int amountPaise,
  DateTime occurredAt,
  int? categoryId,
});

Totals _totals(Iterable<DatedTxn> txns) =>
    totalsOf(txns.map((t) => (type: t.type, amountPaise: t.amountPaise)));

/// Totals for each of the 12 months of [year] (empty months are zero).
List<(DateTime month, Totals totals)> totalsByMonth(
  Iterable<DatedTxn> txns,
  int year,
) {
  final byMonth = <int, List<DatedTxn>>{};
  for (final t in txns) {
    if (t.occurredAt.year == year) {
      byMonth.putIfAbsent(t.occurredAt.month, () => []).add(t);
    }
  }
  return [
    for (var m = 1; m <= 12; m++)
      (DateTime(year, m), _totals(byMonth[m] ?? const [])),
  ];
}

/// Totals per year that has transactions, newest first.
List<(int year, Totals totals)> totalsByYear(Iterable<DatedTxn> txns) {
  final byYear = <int, List<DatedTxn>>{};
  for (final t in txns) {
    byYear.putIfAbsent(t.occurredAt.year, () => []).add(t);
  }
  final years = byYear.keys.toList()..sort((a, b) => b.compareTo(a));
  return [for (final y in years) (y, _totals(byYear[y]!))];
}

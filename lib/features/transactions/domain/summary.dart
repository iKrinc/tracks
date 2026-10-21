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

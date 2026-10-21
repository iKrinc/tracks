import 'package:tracks/data/tables.dart';

/// Balance in paise per account: opening + income − expense, with transfers
/// leaving [TxnTotal.accountId] and arriving at [TxnTotal.toAccountId].
/// Credit cards and loans naturally go negative (money owed).
Map<int, int> computeBalances({
  required Map<int, int> openings,
  required Iterable<TxnTotal> totals,
}) {
  final b = Map<int, int>.of(openings);
  void add(int? id, int delta) {
    if (id != null && b.containsKey(id)) b[id] = b[id]! + delta;
  }

  for (final t in totals) {
    switch (t.type) {
      case TxnType.income:
        add(t.accountId, t.sum);
      case TxnType.expense:
        add(t.accountId, -t.sum);
      case TxnType.transfer:
        add(t.accountId, -t.sum);
        add(t.toAccountId, t.sum);
    }
  }
  return b;
}

int netWorth(Map<int, int> balances) =>
    balances.values.fold(0, (a, b) => a + b);

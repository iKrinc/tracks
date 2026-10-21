import 'package:flutter_test/flutter_test.dart';
import 'package:tracks/data/tables.dart';
import 'package:tracks/features/transactions/domain/summary.dart';

void main() {
  test('totals ignore transfers', () {
    final t = totalsOf([
      (type: TxnType.income, amountPaise: 5000000),
      (type: TxnType.expense, amountPaise: 2000),
      (type: TxnType.expense, amountPaise: 1200000),
      (type: TxnType.transfer, amountPaise: 500000),
    ]);
    expect(t.incomePaise, 5000000);
    expect(t.expensePaise, 1202000);
    expect(t.netPaise, 3798000);
  });

  test('groupByDay keeps order and splits on calendar day', () {
    final items = [
      DateTime(2026, 10, 21, 22),
      DateTime(2026, 10, 21, 8),
      DateTime(2026, 10, 20, 23, 59),
      DateTime(2026, 10, 18),
    ];
    final groups = groupByDay(items, (d) => d);
    expect(groups.map((g) => g.$1), [
      DateTime(2026, 10, 21),
      DateTime(2026, 10, 20),
      DateTime(2026, 10, 18),
    ]);
    expect(groups.first.$2.length, 2);
  });
}

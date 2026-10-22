import 'package:flutter_test/flutter_test.dart';
import 'package:tracks/data/tables.dart';
import 'package:tracks/features/insights/domain/reports.dart';
import 'package:tracks/features/transactions/domain/summary.dart';

DatedTxn t(TxnType type, int paise, DateTime at, [int? categoryId]) =>
    (type: type, amountPaise: paise, occurredAt: at, categoryId: categoryId);

void main() {
  final txns = [
    t(TxnType.income, 5000000, DateTime(2026, 10, 1), 20),
    t(TxnType.expense, 2000, DateTime(2026, 10, 2), 3), // chai (sub of 1)
    t(TxnType.expense, 25000, DateTime(2026, 10, 2), 4), // swiggy (sub of 1)
    t(TxnType.expense, 50000, DateTime(2026, 10, 20), 2), // fuel
    t(TxnType.transfer, 200000, DateTime(2026, 10, 21)),
    t(TxnType.expense, 100000, DateTime(2026, 9, 5), 2),
    t(TxnType.income, 4000000, DateTime(2025, 3, 1), 20),
  ];

  group('totalsByMonth', () {
    test('12 months of the year, empty months are zero', () {
      final m = totalsByMonth(txns, 2026);
      expect(m.length, 12);
      expect(m.first.$1, DateTime(2026));
      expect(m[9].$2.incomePaise, 5000000);
      expect(m[9].$2.expensePaise, 77000);
      expect(m[8].$2.expensePaise, 100000);
      expect(m[0].$2.netPaise, 0);
    });
  });

  group('totalsByYear', () {
    test('only years with data, newest first', () {
      final y = totalsByYear(txns);
      expect(y.map((e) => e.$1), [2026, 2025]);
      expect(y.first.$2.expensePaise, 177000);
      expect(y.last.$2.incomePaise, 4000000);
    });

    test('empty', () => expect(totalsByYear(const []), isEmpty));
  });

  group('categoryBreakdown', () {
    final parents = {1: null, 2: null, 3: 1, 4: 1, 20: null};

    test('rolls subcategories into their parent, largest first', () {
      final b = categoryBreakdown(
        txns.where((x) => x.occurredAt.month == 10),
        TxnType.expense,
        parentOf: parents,
      );
      expect(b.map((e) => (e.categoryId, e.sumPaise)), [
        (2, 50000),
        (1, 27000),
      ]);
    });

    test('uncategorised gets its own slice with a null id', () {
      final b = categoryBreakdown(
        [t(TxnType.expense, 500, DateTime(2026), null)],
        TxnType.expense,
        parentOf: parents,
      );
      expect(b.single.categoryId, isNull);
    });

    test('share of total, in basis points so it stays integer', () {
      final b = categoryBreakdown(
        txns.where((x) => x.occurredAt.month == 10),
        TxnType.expense,
        parentOf: parents,
      );
      expect(b.first.shareBp, 6493); // 50000 / 77000
      expect(b.fold(0, (a, e) => a + e.shareBp), closeTo(10000, 1));
    });
  });

  group('cumulativeSpend', () {
    test('running expense per day of the month', () {
      final c = cumulativeSpend(txns, DateTime(2026, 10));
      expect(c.length, 31);
      expect(c[0], 0);
      expect(c[1], 27000);
      expect(c[18], 27000);
      expect(c[19], 77000);
      expect(c.last, 77000);
    });

    test('stops at today for the current month', () {
      final c = cumulativeSpend(
        txns,
        DateTime(2026, 10),
        today: DateTime(2026, 10, 21),
      );
      expect(c.length, 21);
    });
  });
}

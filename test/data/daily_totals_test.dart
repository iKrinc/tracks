import 'dart:math';

import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tracks/data/app_database.dart';
import 'package:tracks/features/insights/domain/reports.dart';
import 'package:tracks/features/transactions/domain/summary.dart';

/// Reports read SQL daily sums instead of every row. They must give exactly
/// the same numbers as the rows themselves.
void main() {
  test(
    'daily sums give the same totals, slices and pace as raw rows',
    () async {
      final db = AppDatabase(
        DatabaseConnection(
          NativeDatabase.memory(),
          closeStreamsSynchronously: true,
        ),
      );
      final accounts = [
        (await db.select(db.accounts).get()).first.id,
        await db
            .into(db.accounts)
            .insert(
              AccountsCompanion.insert(
                name: 'HDFC',
                type: AccountType.bank,
                color: 0,
                icon: 'x',
              ),
            ),
      ];
      final cats = [for (final c in await db.select(db.categories).get()) c.id];
      final rng = Random(7);
      final start = DateTime(2025, 1, 1);
      await db.batch((b) {
        for (var i = 0; i < 3000; i++) {
          final type = TxnType.values[rng.nextInt(3)];
          b.insert(
            db.transactions,
            TransactionsCompanion.insert(
              type: type,
              amountPaise: 1 + rng.nextInt(500000),
              accountId: accounts[rng.nextInt(2)],
              toAccountId: Value(type == TxnType.transfer ? accounts[1] : null),
              categoryId: Value(
                type == TxnType.transfer || rng.nextInt(8) == 0
                    ? null
                    : cats[rng.nextInt(cats.length)],
              ),
              // Any minute of the day, including near midnight.
              occurredAt: start.add(
                Duration(minutes: rng.nextInt(60 * 24 * 600)),
              ),
            ),
          );
        }
      });

      final raw = [
        for (final t in await db.watchAllTransactions().first)
          (
            type: t.type,
            amountPaise: t.amountPaise,
            occurredAt: t.occurredAt,
            categoryId: t.categoryId,
          ),
      ];
      final daily = [
        for (final t in await db.watchDailyTotals().first)
          (
            type: t.type,
            amountPaise: t.amountPaise,
            occurredAt: t.occurredAt,
            categoryId: t.categoryId,
          ),
      ];
      expect(daily.length, lessThan(raw.length));
      List<(Object, int, int)> flat(List<(Object, Totals)> l) => [
        for (final (k, t) in l) (k, t.incomePaise, t.expensePaise),
      ];
      for (final year in [2025, 2026]) {
        expect(
          flat(totalsByMonth(daily, year)),
          flat(totalsByMonth(raw, year)),
        );
      }
      expect(flat(totalsByYear(daily)), flat(totalsByYear(raw)));
      for (final type in [TxnType.expense, TxnType.income]) {
        expect(
          categoryBreakdown(daily, type, parentOf: const {}),
          categoryBreakdown(raw, type, parentOf: const {}),
        );
      }
      for (final m in [DateTime(2025, 3), DateTime(2026, 2)]) {
        expect(
          cumulativeSpend(daily, m, today: DateTime(2027)),
          cumulativeSpend(raw, m, today: DateTime(2027)),
        );
      }
      await db.close();
    },
  );
}

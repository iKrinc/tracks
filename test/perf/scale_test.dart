@Tags(['perf'])
library;

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tracks/data/app_database.dart';

/// Five years of heavy use: 50,000 transactions. Prints timings; run with
/// `flutter test --tags perf test/perf`.
void main() {
  test('queries stay fast at 50k transactions', () async {
    final db = AppDatabase(
      DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );
    final cash = (await db.select(db.accounts).get()).first.id;
    final cat = (await db.select(db.categories).get()).first.id;
    final start = DateTime(2021, 10, 1);
    await db.batch((b) {
      for (var i = 0; i < 50000; i++) {
        b.insert(
          db.transactions,
          TransactionsCompanion.insert(
            type: i % 10 == 0 ? TxnType.income : TxnType.expense,
            amountPaise: 1000 + i % 5000,
            accountId: cash,
            categoryId: Value(cat),
            occurredAt: start.add(Duration(minutes: i * 52)),
            refNo: Value('R$i'),
          ),
        );
      }
    });

    Future<int> time(String what, Future<Object?> Function() f) async {
      await f(); // warm up
      final sw = Stopwatch()..start();
      for (var i = 0; i < 5; i++) {
        await f();
      }
      final ms = sw.elapsedMilliseconds ~/ 5;
      // ignore: avoid_print
      print('$what: $ms ms');
      return ms;
    }

    final month = DateTime(2026, 9);
    await time(
      'one month',
      () => db.watchTransactionsBetween(month, DateTime(2026, 10)).first,
    );
    await time('all transactions', () => db.watchAllTransactions().first);
    await time('balances (SQL sums)', () => db.watchTxnTotals().first);
    await time('daily totals (SQL)', () => db.watchDailyTotals().first);
    await time(
      'duplicate check by ref',
      () => db.findPossibleDuplicates(
        amountPaise: 1234,
        day: month,
        refNo: 'R49999',
      ),
    );
    await time(
      'duplicate check by day',
      () => db.findPossibleDuplicates(amountPaise: 1234, day: month),
    );
    await db.close();
  });
}

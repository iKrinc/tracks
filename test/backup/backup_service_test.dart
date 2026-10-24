import 'dart:convert';

import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tracks/data/app_database.dart';
import 'package:tracks/features/backup/data/backup_service.dart';
import 'package:tracks/features/backup/domain/csv_transactions.dart';

AppDatabase memoryDb() => AppDatabase(
  DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true),
);

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late AppDatabase db;
  setUp(() => db = memoryDb());
  tearDown(() => db.close());

  Future<int> cashId(AppDatabase d) async =>
      (await d.select(d.accounts).get()).first.id;

  test('JSON backup restores into a fresh database exactly', () async {
    final cash = await cashId(db);
    final hdfc = await db
        .into(db.accounts)
        .insert(
          AccountsCompanion.insert(
            name: 'HDFC',
            type: AccountType.bank,
            color: 1,
            icon: 'account_balance',
            matchHints: const Value('hdfc,1234'),
          ),
        );
    await db.addTransaction(
      TransactionsCompanion.insert(
        type: TxnType.transfer,
        amountPaise: 200000,
        accountId: hdfc,
        toAccountId: Value(cash),
        occurredAt: DateTime(2026, 10, 20, 9),
        refNo: const Value('629412345678'),
        rawSourceText: const Value('Sent Rs.2000 …'),
        source: const Value(TxnSource.sms),
      ),
    );
    await db.setSetting('lock', 'on');
    await db.saveBudget(BudgetsCompanion.insert(amountPaise: 2000000));
    await db.saveRecurring(
      RecurringsCompanion.insert(
        name: 'Netflix',
        type: TxnType.expense,
        amountPaise: 64900,
        accountId: hdfc,
        startDate: DateTime(2026, 1, 15),
        unit: RepeatUnit.month,
        autopay: const Value(AutopayKind.upiMandate),
        lastPaid: Value(DateTime(2026, 10, 15)),
      ),
    );

    final json = jsonEncode(await buildBackup(db));

    final fresh = memoryDb();
    final summary = await restoreBackup(fresh, jsonDecode(json));
    expect(summary.transactions, 1);
    expect(summary.accounts, 2);

    final t = (await fresh.select(fresh.transactions).get()).single;
    expect(t.amountPaise, 200000);
    expect(t.toAccountId, cash);
    expect(t.occurredAt, DateTime(2026, 10, 20, 9));
    expect(t.source, TxnSource.sms);
    expect(t.rawSourceText, 'Sent Rs.2000 …');
    expect(
      (await fresh.select(fresh.accounts).get()).map((a) => a.matchHints),
      contains('hdfc,1234'),
    );
    expect(
      (await fresh.select(fresh.categories).get()).length,
      (await db.select(db.categories).get()).length,
    );
    expect(await fresh.getSetting('lock'), 'on');
    expect(
      (await fresh.select(fresh.budgets).get()).single.amountPaise,
      2000000,
    );
    final r = (await fresh.select(fresh.recurrings).get()).single;
    expect(r.autopay, AutopayKind.upiMandate);
    expect(r.lastPaid, DateTime(2026, 10, 15));
    await fresh.close();
  });

  test('restore replaces existing data rather than merging', () async {
    final backup = await buildBackup(db);
    await db.addTransaction(
      TransactionsCompanion.insert(
        type: TxnType.expense,
        amountPaise: 1,
        accountId: await cashId(db),
        occurredAt: DateTime(2026),
      ),
    );
    await restoreBackup(db, backup);
    expect(await db.select(db.transactions).get(), isEmpty);
  });

  test('a fund, its account and a tagged spend survive a restore', () async {
    final fund = await db
        .into(db.funds)
        .insert(
          FundsCompanion.insert(
            name: 'Marriage',
            color: 0,
            budgetPaise: const Value(80000000),
          ),
        );
    final pot = await db
        .into(db.accounts)
        .insert(
          AccountsCompanion.insert(
            name: 'Marriage fund',
            type: AccountType.bank,
            color: 0,
            icon: 'savings',
            fundId: Value(fund),
          ),
        );
    await db.addTransaction(
      TransactionsCompanion.insert(
        type: TxnType.expense,
        amountPaise: 500000,
        accountId: await cashId(db),
        occurredAt: DateTime(2026, 10, 1),
        fundId: Value(fund),
      ),
    );
    final json = jsonEncode(await buildBackup(db));
    final fresh = memoryDb();
    await restoreBackup(fresh, jsonDecode(json));
    final f = (await fresh.select(fresh.funds).get()).single;
    expect(f.name, 'Marriage');
    expect(f.budgetPaise, 80000000);
    final a = await (fresh.select(
      fresh.accounts,
    )..where((a) => a.id.equals(pot))).getSingle();
    expect(a.fundId, f.id);
    expect((await fresh.select(fresh.transactions).get()).single.fundId, f.id);
    await fresh.close();
  });

  test('backups from before funds (v6) still restore', () async {
    final old = await buildBackup(db)
      ..remove('funds');
    final s = await restoreBackup(db, old);
    expect(s.accounts, 1);
  });

  test('backups from before budgets/recurring still restore', () async {
    final old = await buildBackup(db)
      ..remove('budgets')
      ..remove('recurrings');
    final s = await restoreBackup(db, old);
    expect(s.accounts, 1);
  });

  test('rejects files that are not Tracks backups', () async {
    expect(
      () => restoreBackup(db, {'hello': 'world'}),
      throwsA(isA<BackupFormatException>()),
    );
    expect(
      () => restoreBackup(db, {'app': 'tracks', 'format': 999}),
      throwsA(isA<BackupFormatException>()),
    );
  });

  test('CSV import creates missing accounts and matches categories', () async {
    final result = await importCsvRows(db, [
      CsvTxnRow(
        date: DateTime(2026, 10, 1),
        type: TxnType.expense,
        amountPaise: 2000,
        account: 'cash',
        category: 'snacks & chai',
        note: 'chai',
      ),
      CsvTxnRow(
        date: DateTime(2026, 10, 2),
        type: TxnType.expense,
        amountPaise: 50000,
        account: 'ICICI Card',
        category: 'Unknown category',
      ),
      CsvTxnRow(
        date: DateTime(2026, 10, 3),
        type: TxnType.transfer,
        amountPaise: 10000,
        account: 'ICICI Card',
        toAccount: 'Cash',
      ),
    ]);
    expect(result.imported, 3);
    expect(result.newAccounts, ['ICICI Card']);

    final txns = await db.select(db.transactions).get();
    expect(txns.every((t) => t.source == TxnSource.import), isTrue);
    final chai = txns.firstWhere((t) => t.note == 'chai');
    final cat = await (db.select(
      db.categories,
    )..where((c) => c.id.equals(chai.categoryId!))).getSingle();
    expect(cat.name, 'Snacks & Chai');
    expect(txns[1].categoryId, isNull);
    expect(txns[2].toAccountId, await cashId(db));
  });

  test('CSV export rows use names', () async {
    await db.addTransaction(
      TransactionsCompanion.insert(
        type: TxnType.expense,
        amountPaise: 2000,
        accountId: await cashId(db),
        occurredAt: DateTime(2026, 10, 1),
        note: const Value('chai'),
      ),
    );
    final rows = await csvExportRows(db);
    expect(rows.single.account, 'Cash');
    expect(rows.single.note, 'chai');
  });
}

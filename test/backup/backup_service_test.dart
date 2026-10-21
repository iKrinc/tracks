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

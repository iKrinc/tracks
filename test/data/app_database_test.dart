import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tracks/data/app_database.dart';
import 'package:tracks/data/default_data.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(DatabaseConnection(
      NativeDatabase.memory(),
      closeStreamsSynchronously: true,
    ));
  });
  tearDown(() => db.close());

  test('fresh database seeds default accounts and categories', () async {
    final accounts = await db.select(db.accounts).get();
    expect(accounts.map((a) => a.name), ['Cash']);
    expect(accounts.single.type, AccountType.cash);

    final expense = await db.watchCategories(CategoryKind.expense).first;
    final topLevel = expense.where((c) => c.parentId == null).toList();
    expect(topLevel.length, defaultExpenseCategories.length);
    expect(topLevel.first.name, 'Food & Dining');

    final groceries = expense.singleWhere((c) => c.name == 'Groceries');
    expect(groceries.parentId, topLevel.first.id);

    final income = await db.watchCategories(CategoryKind.income).first;
    expect(income.map((c) => c.name), contains('Salary'));
  });

  test('transactions store integer paise and filter by date range', () async {
    final cash = (await db.select(db.accounts).get()).single;
    Future<int> add(int paise, DateTime at) => db.addTransaction(
          TransactionsCompanion.insert(
            type: TxnType.expense,
            amountPaise: paise,
            accountId: cash.id,
            occurredAt: at,
            source: const Value(TxnSource.quickText),
            rawSourceText: const Value('chai 20'),
          ),
        );

    await add(2000, DateTime(2026, 10, 1, 9));
    await add(12345678, DateTime(2026, 10, 31, 23, 59));
    await add(500, DateTime(2026, 11, 1));

    final oct = await db
        .watchTransactionsBetween(DateTime(2026, 10), DateTime(2026, 11))
        .first;
    expect(oct.map((t) => t.amountPaise), [12345678, 2000]);
    expect(oct.last.source, TxnSource.quickText);
    expect(oct.last.rawSourceText, 'chai 20');
  });

  test('foreign keys are enforced', () async {
    expect(
      () => db.addTransaction(TransactionsCompanion.insert(
        type: TxnType.expense,
        amountPaise: 100,
        accountId: 999,
        occurredAt: DateTime(2026),
      )),
      throwsA(isA<SqliteException>()),
    );
  });
}

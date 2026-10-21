import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tracks/data/app_database.dart';
import 'package:tracks/data/default_data.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(
      DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );
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

  group('findPossibleDuplicates', () {
    late int cashId;
    setUp(() async {
      cashId = (await db.select(db.accounts).get()).single.id;
      await db.addTransaction(
        TransactionsCompanion.insert(
          type: TxnType.expense,
          amountPaise: 25000,
          accountId: cashId,
          occurredAt: DateTime(2026, 10, 21, 9, 15),
          refNo: const Value('629412345678'),
        ),
      );
      await db.addTransaction(
        TransactionsCompanion.insert(
          type: TxnType.expense,
          amountPaise: 2000,
          accountId: cashId,
          occurredAt: DateTime(2026, 10, 21, 18),
        ),
      );
    });

    test('matches on ref no. regardless of amount or day', () async {
      final d = await db.findPossibleDuplicates(
        amountPaise: 1,
        day: DateTime(2020),
        refNo: '629412345678',
      );
      expect(d.single.amountPaise, 25000);
    });

    test('a different ref no. is not a duplicate', () async {
      final d = await db.findPossibleDuplicates(
        amountPaise: 25000,
        day: DateTime(2026, 10, 21),
        refNo: '000000000000',
      );
      expect(d, isEmpty);
    });

    test('without ref: same amount on the same day', () async {
      final same = await db.findPossibleDuplicates(
        amountPaise: 2000,
        day: DateTime(2026, 10, 21),
      );
      expect(same.length, 1);
      final otherDay = await db.findPossibleDuplicates(
        amountPaise: 2000,
        day: DateTime(2026, 10, 22),
      );
      expect(otherDay, isEmpty);
    });
  });

  group('search and totals', () {
    late int cashId;
    setUp(() async {
      cashId = (await db.select(db.accounts).get()).single.id;
      Future<void> add(TxnType type, int paise, String note, {String? m}) =>
          db.addTransaction(
            TransactionsCompanion.insert(
              type: type,
              amountPaise: paise,
              accountId: cashId,
              occurredAt: DateTime(2026, 10, 21),
              note: Value(note),
              merchant: Value(m),
            ),
          );
      await add(TxnType.expense, 2000, 'Chai at office');
      await add(TxnType.expense, 25000, 'dinner', m: 'SWIGGY');
      await add(TxnType.income, 5000000, 'Salary');
    });

    test('matches every word, case-insensitive, in note or merchant', () async {
      expect((await db.watchSearch(query: 'CHAI office').first).length, 1);
      expect(
        (await db.watchSearch(query: 'swiggy').first).single.note,
        'dinner',
      );
      expect(await db.watchSearch(query: 'chai dinner').first, isEmpty);
    });

    test('filters by type', () async {
      final r = await db.watchSearch(type: TxnType.income).first;
      expect(r.single.note, 'Salary');
    });

    test('totals group by account and type', () async {
      final totals = await db.watchTxnTotals().first;
      final expense = totals.singleWhere((t) => t.type == TxnType.expense);
      expect(expense.sum, 27000);
      expect(expense.accountId, cashId);
    });
  });

  test('foreign keys are enforced', () async {
    expect(
      () => db.addTransaction(
        TransactionsCompanion.insert(
          type: TxnType.expense,
          amountPaise: 100,
          accountId: 999,
          occurredAt: DateTime(2026),
        ),
      ),
      throwsA(isA<SqliteException>()),
    );
  });
}

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

  test('findOrCreatePerson reuses the same IOU account', () async {
    final a = await db.findOrCreatePerson('ravi', lent: true);
    final b = await db.findOrCreatePerson('Ravi ', lent: true);
    expect(a, b);
    final ravi = await (db.select(
      db.accounts,
    )..where((x) => x.id.equals(a))).getSingle();
    expect(ravi.name, 'Ravi');
    expect(ravi.type, AccountType.lent);
    // Borrowing from the same person is a separate "I owe" account.
    expect(await db.findOrCreatePerson('ravi', lent: false), isNot(a));
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

  test('learnRule creates, then updates only what a correction sets', () async {
    final cats = await db.select(db.categories).get();
    final accs = await db.select(db.accounts).get();
    await db.learnRule('swiggy', categoryId: cats[0].id);
    await db.learnRule('swiggy', accountId: accs[0].id);
    var rule = (await db.select(db.rules).get()).single;
    expect(rule.keyword, 'swiggy');
    expect(rule.categoryId, cats[0].id);
    expect(rule.accountId, accs[0].id);

    await db.learnRule('swiggy', categoryId: cats[1].id);
    await db.bumpRule(rule.id);
    rule = (await db.select(db.rules).get()).single;
    expect(rule.categoryId, cats[1].id);
    expect(rule.accountId, accs[0].id);
    expect(rule.hits, 1);

    await db.deleteRule(rule.id);
    expect(await db.select(db.rules).get(), isEmpty);
  });

  test('createFund makes the fund and an account to hold its money', () async {
    final id = await db.createFund(
      name: 'Marriage',
      color: 0xFFF6D5D0,
      icon: 'celebration',
      budgetPaise: 80000000,
      startPaise: 20000000,
    );
    final fund = (await db.select(db.funds).get()).single;
    expect(fund.id, id);
    expect(fund.mode, FundMode.separate);
    expect(fund.budgetPaise, 80000000);
    final pot = await (db.select(
      db.accounts,
    )..where((a) => a.fundId.equals(id))).getSingle();
    expect(pot.name, 'Marriage');
    expect(pot.openingBalancePaise, 20000000);
    expect(pot.matchHints, 'marriage');
  });

  test('closing a fund moves what is left; Undo takes it all back', () async {
    final id = await db.createFund(name: 'Trip', color: 0, startPaise: 500000);
    final pot = await (db.select(
      db.accounts,
    )..where((a) => a.fundId.equals(id))).getSingle();
    final cash = (await db.select(db.accounts).get()).first.id;
    final moved = await db.closeFund(
      id,
      leftPaise: 500000,
      potId: pot.id,
      toAccountId: cash,
    );
    final t = (await db.select(db.transactions).get()).single;
    expect(t.id, moved);
    expect(t.toAccountId, cash);
    expect((await db.select(db.funds).get()).single.archived, isTrue);
    expect(
      (await (db.select(
        db.accounts,
      )..where((a) => a.id.equals(pot.id))).getSingle()).archived,
      isTrue,
    );

    await db.reopenFund(id, undoTransferId: moved);
    expect(await db.select(db.transactions).get(), isEmpty);
    expect((await db.select(db.funds).get()).single.archived, isFalse);
    expect(
      (await (db.select(
        db.accounts,
      )..where((a) => a.id.equals(pot.id))).getSingle()).archived,
      isFalse,
    );
  });
}

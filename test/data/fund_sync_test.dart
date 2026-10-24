import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tracks/data/app_database.dart';

/// The owner's example: Marriage starts with ₹5,00,000; catering ₹50,000 on
/// 28 Sep, others ₹4,00,000 on 28 Oct, gifts ₹20,000 on 29 Oct. ₹70,000 is
/// left. Synced to HDFC, the main timeline shows each entry on its own date,
/// then "Marriage – remaining" ₹70,000 into HDFC.
void main() {
  late AppDatabase db;
  late int hdfc;
  late int fund;
  late int pot;

  setUp(() async {
    db = AppDatabase(
      DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );
    hdfc = await db
        .into(db.accounts)
        .insert(
          AccountsCompanion.insert(
            name: 'HDFC',
            type: AccountType.bank,
            color: 0,
            icon: 'account_balance',
            openingBalancePaise: const Value(10000000),
          ),
        );
    fund = await db.createFund(
      name: 'Marriage',
      color: 0,
      startPaise: 50000000,
      createdAt: DateTime(2026, 9, 1),
    );
    pot = (await (db.select(
      db.accounts,
    )..where((a) => a.fundId.equals(fund))).getSingle()).id;
    Future<void> add(TxnType type, int paise, DateTime at, String note) =>
        db.addTransaction(
          TransactionsCompanion.insert(
            type: type,
            amountPaise: paise,
            accountId: pot,
            occurredAt: at,
            note: Value(note),
          ),
        );
    await add(TxnType.expense, 5000000, DateTime(2026, 9, 28), 'catering');
    await add(TxnType.expense, 40000000, DateTime(2026, 10, 28), 'others');
    await add(TxnType.income, 2000000, DateTime(2026, 10, 29), 'gifts');
  });
  tearDown(() => db.close());

  Future<Fund> theFund() =>
      (db.select(db.funds)..where((f) => f.id.equals(fund))).getSingle();
  Future<List<Transaction>> all() => (db.select(
    db.transactions,
  )..orderBy([(t) => OrderingTerm.asc(t.occurredAt)])).get();

  test('remaining is what the fund has left', () async {
    expect(await db.fundRemaining(fund), 7000000);
  });

  test('sync adds "remaining" into the chosen account, after the last '
      'entry, and marks the fund synced', () async {
    await db.syncFund(fund, toAccountId: hdfc);
    final f = await theFund();
    expect(f.mode, FundMode.merged);
    expect(f.syncAccountId, hdfc);
    final rows = await all();
    expect(rows.map((t) => t.note), [
      'catering',
      'others',
      'gifts',
      'remaining',
    ]);
    final remaining = rows.last;
    expect(remaining.id, f.syncTransferId);
    expect(remaining.type, TxnType.transfer);
    expect(remaining.accountId, pot);
    expect(remaining.toAccountId, hdfc);
    expect(remaining.amountPaise, 7000000);
    expect(remaining.occurredAt.isAfter(DateTime(2026, 10, 29)), isTrue);
  });

  test('a new fund entry while synced updates "remaining"', () async {
    await db.syncFund(fund, toAccountId: hdfc);
    await db.addTransaction(
      TransactionsCompanion.insert(
        type: TxnType.expense,
        amountPaise: 1000000,
        accountId: pot,
        occurredAt: DateTime(2026, 11, 2),
        note: const Value('photos'),
      ),
    );
    final f = await theFund();
    final remaining = (await all()).singleWhere(
      (t) => t.id == f.syncTransferId,
    );
    expect(remaining.amountPaise, 6000000);
    expect(remaining.occurredAt.isAfter(DateTime(2026, 11, 2)), isTrue);
  });

  test('deleting a fund entry while synced updates "remaining"', () async {
    await db.syncFund(fund, toAccountId: hdfc);
    final gifts = (await all()).singleWhere((t) => t.note == 'gifts');
    await db.deleteTransaction(gifts.id);
    final f = await theFund();
    final remaining = (await all()).singleWhere(
      (t) => t.id == f.syncTransferId,
    );
    expect(remaining.amountPaise, 5000000);
  });

  test('unsync removes "remaining" and keeps every real entry', () async {
    await db.syncFund(fund, toAccountId: hdfc);
    await db.unsyncFund(fund);
    final f = await theFund();
    expect(f.mode, FundMode.separate);
    expect(f.syncAccountId, isNull);
    expect(f.syncTransferId, isNull);
    expect((await all()).map((t) => t.note), ['catering', 'others', 'gifts']);
    expect(await db.fundRemaining(fund), 7000000);
  });

  test('an overspent fund syncs its shortfall from the account', () async {
    await db.addTransaction(
      TransactionsCompanion.insert(
        type: TxnType.expense,
        amountPaise: 10000000,
        accountId: pot,
        occurredAt: DateTime(2026, 10, 30),
        note: const Value('band'),
      ),
    );
    await db.syncFund(fund, toAccountId: hdfc);
    final f = await theFund();
    final t = (await all()).singleWhere((t) => t.id == f.syncTransferId);
    expect(t.accountId, hdfc);
    expect(t.toAccountId, pot);
    expect(t.amountPaise, 3000000);
  });

  test(
    'starting money taken from an existing account is a real transfer',
    () async {
      final trip = await db.createFund(
        name: 'Goa',
        color: 0,
        startPaise: 2000000,
        startFromAccountId: hdfc,
        createdAt: DateTime(2026, 10, 1),
      );
      final tripPot = (await (db.select(
        db.accounts,
      )..where((a) => a.fundId.equals(trip))).getSingle());
      expect(tripPot.openingBalancePaise, 0);
      final initial = (await all()).singleWhere((t) => t.note == 'initial');
      expect(initial.type, TxnType.transfer);
      expect(initial.accountId, hdfc);
      expect(initial.toAccountId, tripPot.id);
      expect(initial.amountPaise, 2000000);
      expect(await db.fundRemaining(trip), 2000000);
    },
  );
}

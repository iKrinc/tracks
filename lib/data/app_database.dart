import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:tracks/data/default_data.dart';
import 'package:tracks/data/tables.dart';

export 'package:tracks/data/tables.dart';

part 'app_database.drift.dart';

/// A transaction as period totals and reports read it.
typedef ReportRow = ({
  TxnType type,
  int amountPaise,
  DateTime occurredAt,
  int? categoryId,
  int accountId,
  int? toAccountId,
});

@DriftDatabase(
  tables: [
    Funds,
    Accounts,
    Categories,
    Transactions,
    Rules,
    AppSettings,
    Budgets,
    Recurrings,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _open());

  /// v1: accounts, categories, transactions, rules.
  /// v2: app_settings.
  /// v3: budgets, recurrings.
  /// v4: no schema change; recolours old blue/purple defaults to the warm
  ///     palette (only colours still equal to an old default).
  /// v5: card and loan fields on accounts; recurrings.to_account_id.
  /// v6: funds; accounts.fund_id and transactions.fund_id.
  /// v7: funds.sync_account_id, funds.sync_transfer_id.
  @override
  int get schemaVersion => 7;

  static QueryExecutor _open() => driftDatabase(
    name: 'tracks',
    // Only used by the web preview build; Android uses a native file.
    web: DriftWebOptions(
      sqlite3Wasm: Uri.parse('sqlite3.wasm'),
      driftWorker: Uri.parse('drift_worker.js'),
    ),
  );

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await _seedDefaults();
    },
    onUpgrade: (m, from, to) async {
      if (from < 2) await m.createTable(appSettings);
      if (from < 3) {
        await m.createTable(budgets);
        await m.createTable(recurrings);
      }
      if (from < 4) await _recolourLegacy();
      if (from < 5) {
        for (final c in [
          accounts.creditLimitPaise,
          accounts.statementDay,
          accounts.dueDay,
          accounts.principalPaise,
          accounts.interestRateBp,
          accounts.emiPaise,
          accounts.tenureMonths,
        ]) {
          await m.addColumn(accounts, c);
        }
        // Created with this column already when upgrading from < v3.
        if (from >= 3) {
          await m.addColumn(recurrings, recurrings.toAccountId);
        }
      }
      if (from < 6) {
        await m.createTable(funds);
        await m.addColumn(accounts, accounts.fundId);
        await m.addColumn(transactions, transactions.fundId);
      }
      // Created with these columns already when upgrading from < v6.
      if (from == 6) {
        await m.addColumn(funds, funds.syncAccountId);
        await m.addColumn(funds, funds.syncTransferId);
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  Future<void> _recolourLegacy() async {
    for (final e in legacyCategoryColors.entries) {
      await (update(categories)..where((c) => c.color.equals(e.key))).write(
        CategoriesCompanion(color: Value(e.value)),
      );
    }
    for (final e in legacyAccountColors.entries) {
      await (update(accounts)..where((a) => a.color.equals(e.key))).write(
        AccountsCompanion(color: Value(e.value)),
      );
    }
  }

  Future<void> _seedDefaults() async {
    await batch((b) {
      for (final (i, a) in defaultAccounts.indexed) {
        b.insert(
          accounts,
          AccountsCompanion.insert(
            name: a.name,
            type: a.type,
            color: a.color,
            icon: a.icon,
            matchHints: Value(a.hints),
            sortOrder: Value(i),
          ),
        );
      }
    });
    await _seedCategories(defaultExpenseCategories, CategoryKind.expense);
    await _seedCategories(defaultIncomeCategories, CategoryKind.income);
  }

  Future<void> _seedCategories(
    List<DefaultCategory> defs,
    CategoryKind kind,
  ) async {
    for (final (i, c) in defs.indexed) {
      final parentId = await into(categories).insert(
        CategoriesCompanion.insert(
          name: c.name,
          kind: kind,
          color: c.color,
          icon: c.icon,
          sortOrder: Value(i),
        ),
      );
      await batch((b) {
        for (final (j, sub) in c.subs.indexed) {
          b.insert(
            categories,
            CategoriesCompanion.insert(
              name: sub,
              kind: kind,
              parentId: Value(parentId),
              color: c.color,
              icon: c.icon,
              sortOrder: Value(j),
            ),
          );
        }
      });
    }
  }

  // ---- Queries -----------------------------------------------------------

  Stream<List<Account>> watchAccounts() =>
      (select(accounts)
            ..where((a) => a.archived.equals(false))
            ..orderBy([(a) => OrderingTerm(expression: a.sortOrder)]))
          .watch();

  /// Including archived accounts, which old transactions still refer to.
  Stream<List<Account>> watchAllAccounts() => (select(
    accounts,
  )..orderBy([(a) => OrderingTerm(expression: a.sortOrder)])).watch();

  Stream<List<Category>> watchCategories(CategoryKind kind) =>
      (select(categories)
            ..where((c) => c.kind.equalsValue(kind) & c.archived.equals(false))
            ..orderBy([(c) => OrderingTerm(expression: c.sortOrder)]))
          .watch();

  /// Transactions with `from <= occurredAt < to`, newest first.
  Stream<List<Transaction>> watchTransactionsBetween(
    DateTime from,
    DateTime to,
  ) =>
      (select(transactions)
            ..where(
              (t) =>
                  t.occurredAt.isBiggerOrEqualValue(from) &
                  t.occurredAt.isSmallerThanValue(to),
            )
            ..orderBy([
              (t) => OrderingTerm.desc(t.occurredAt),
              (t) => OrderingTerm.desc(t.id),
            ]))
          .watch();

  Future<int> saveCategory(CategoriesCompanion c) =>
      into(categories).insertOnConflictUpdate(c);

  /// Persists a new order (index = sortOrder) for [ids].
  Future<void> reorderCategories(List<int> ids) => batch((b) {
    for (final (i, id) in ids.indexed) {
      b.update(
        categories,
        CategoriesCompanion(sortOrder: Value(i)),
        where: (c) => c.id.equals(id),
      );
    }
  });

  /// The IOU account for [name] (case-insensitive): "people who owe me"
  /// when [lent], else "money I owe". Created on first use.
  Future<int> findOrCreatePerson(String name, {required bool lent}) async {
    final type = lent ? AccountType.lent : AccountType.loan;
    final trimmed = name.trim();
    final existing =
        await (select(accounts)..where(
              (a) =>
                  a.type.equalsValue(type) &
                  a.name.lower().equals(trimmed.toLowerCase()),
            ))
            .getSingleOrNull();
    if (existing != null) return existing.id;
    final pretty = trimmed[0].toUpperCase() + trimmed.substring(1);
    return into(accounts).insert(
      AccountsCompanion.insert(
        name: pretty,
        type: type,
        color: 0xFFF6D5D0,
        icon: 'person',
        matchHints: Value(trimmed.toLowerCase()),
      ),
    );
  }

  /// Everything that moved money in or out of [accountId], oldest first.
  Stream<List<Transaction>> watchAccountTxns(int accountId) =>
      (select(transactions)
            ..where(
              (t) =>
                  t.accountId.equals(accountId) |
                  t.toAccountId.equals(accountId),
            )
            ..orderBy([(t) => OrderingTerm(expression: t.occurredAt)]))
          .watch();

  /// Every transaction, for yearly views and reports.
  /// Sums per local day, type, category and account(s). Every period
  /// total, category slice and daily pace line is a sum of these, so Home
  /// and Reports read a few thousand rows instead of every transaction.
  Stream<List<ReportRow>> watchDailyTotals() =>
      customSelect(
        "SELECT date(occurred_at, 'unixepoch', 'localtime') AS day, type, "
        'category_id, account_id, to_account_id, SUM(amount_paise) AS total '
        'FROM transactions '
        'GROUP BY day, type, category_id, account_id, to_account_id',
        readsFrom: {transactions},
      ).watch().map(
        (rows) => [
          for (final r in rows)
            (
              type: TxnType.values.byName(r.read<String>('type')),
              amountPaise: r.read<int>('total'),
              occurredAt: DateTime.parse(r.read<String>('day')),
              categoryId: r.readNullable<int>('category_id'),
              accountId: r.read<int>('account_id'),
              toAccountId: r.readNullable<int>('to_account_id'),
            ),
        ],
      );

  Stream<List<Transaction>> watchAllTransactions() => (select(
    transactions,
  )..orderBy([(t) => OrderingTerm.desc(t.occurredAt)])).watch();

  /// Saves a transaction; a synced fund it touches gets its "remaining"
  /// brought up to date.
  Future<int> addTransaction(TransactionsCompanion entry) =>
      transaction(() async {
        final id = await into(transactions).insert(entry);
        await _refreshSyncsFor([
          entry.accountId.present ? entry.accountId.value : null,
          entry.toAccountId.present ? entry.toAccountId.value : null,
        ]);
        return id;
      });

  /// Transactions that look like the one about to be saved: the same bank
  /// ref no. if there is one, otherwise the same amount on the same day.
  Future<List<Transaction>> findPossibleDuplicates({
    required int amountPaise,
    required DateTime day,
    String? refNo,
  }) {
    final q = select(transactions);
    if (refNo != null && refNo.isNotEmpty) {
      q.where((t) => t.refNo.equals(refNo));
    } else {
      final start = DateTime(day.year, day.month, day.day);
      final end = DateTime(day.year, day.month, day.day + 1);
      q.where(
        (t) =>
            t.amountPaise.equals(amountPaise) &
            t.occurredAt.isBiggerOrEqualValue(start) &
            t.occurredAt.isSmallerThanValue(end),
      );
    }
    return q.get();
  }

  Stream<List<Fund>> watchFunds() =>
      (select(funds)..orderBy([(f) => OrderingTerm.asc(f.createdAt)])).watch();

  Future<int> saveFund(FundsCompanion f) =>
      into(funds).insertOnConflictUpdate(f);

  /// Creates a fund with one account to hold its money (opening [startPaise]
  /// counts as money already set aside). Returns the fund id.
  /// Creates a fund with one account to hold its money. Its starting
  /// [startPaise] is either new money typed in (the account's opening
  /// balance) or, with [startFromAccountId], a real "initial" transfer out
  /// of that account. Returns the fund id.
  Future<int> createFund({
    required String name,
    required int color,
    String icon = 'savings',
    int? budgetPaise,
    int startPaise = 0,
    int? startFromAccountId,
    DateTime? createdAt,
  }) => transaction(() async {
    final at = createdAt ?? DateTime.now();
    final id = await into(funds).insert(
      FundsCompanion.insert(
        name: name,
        color: color,
        icon: Value(icon),
        budgetPaise: Value(budgetPaise),
        createdAt: Value(at),
      ),
    );
    final fromAccount = startFromAccountId != null && startPaise > 0;
    final pot = await into(accounts).insert(
      AccountsCompanion.insert(
        name: name,
        type: AccountType.bank,
        color: color,
        icon: icon,
        openingBalancePaise: Value(fromAccount ? 0 : startPaise),
        // So "catering 50000 marriage" goes to the fund.
        matchHints: Value(name.toLowerCase()),
        fundId: Value(id),
      ),
    );
    if (fromAccount) {
      await into(transactions).insert(
        TransactionsCompanion.insert(
          type: TxnType.transfer,
          amountPaise: startPaise,
          accountId: startFromAccountId,
          toAccountId: Value(pot),
          note: const Value('initial'),
          occurredAt: at,
        ),
      );
    }
    return id;
  });

  Future<List<int>> _fundAccountIds(int fundId) async => [
    for (final a in await (select(
      accounts,
    )..where((a) => a.fundId.equals(fundId))).get())
      a.id,
  ];

  Future<List<Transaction>> _fundTxns(List<int> pots) => (select(
    transactions,
  )..where((t) => t.accountId.isIn(pots) | t.toAccountId.isIn(pots))).get();

  /// What fund [fundId] has left: its starting money, plus money in, minus
  /// money out, not counting its own "remaining" sync transfer.
  Future<int> fundRemaining(int fundId) async {
    final fund = await (select(
      funds,
    )..where((f) => f.id.equals(fundId))).getSingle();
    final pots = await _fundAccountIds(fundId);
    var left = 0;
    for (final a in await (select(
      accounts,
    )..where((a) => a.id.isIn(pots))).get()) {
      left += a.openingBalancePaise;
    }
    for (final t in await _fundTxns(pots)) {
      if (t.id == fund.syncTransferId) continue;
      final from = pots.contains(t.accountId);
      final to = t.toAccountId != null && pots.contains(t.toAccountId);
      switch (t.type) {
        case TxnType.income:
          if (from) left += t.amountPaise;
        case TxnType.expense:
          if (from) left -= t.amountPaise;
        case TxnType.transfer:
          if (to && !from) left += t.amountPaise;
          if (from && !to) left -= t.amountPaise;
      }
    }
    return left;
  }

  /// Syncs fund [fundId] into main account [toAccountId]: its entries show
  /// in the main timeline on their own dates, and what's left moves into
  /// that account as "Marriage – remaining", right after the last entry.
  Future<void> syncFund(int fundId, {required int toAccountId}) =>
      transaction(() async {
        await (update(funds)..where((f) => f.id.equals(fundId))).write(
          FundsCompanion(
            mode: const Value(FundMode.merged),
            syncAccountId: Value(toAccountId),
          ),
        );
        await _refreshSync(fundId);
      });

  /// Keeps fund [fundId] separate again: "remaining" goes; every real
  /// entry stays.
  Future<void> unsyncFund(int fundId) => transaction(() async {
    final fund = await (select(
      funds,
    )..where((f) => f.id.equals(fundId))).getSingle();
    if (fund.syncTransferId != null) {
      await (delete(
        transactions,
      )..where((t) => t.id.equals(fund.syncTransferId!))).go();
    }
    await (update(funds)..where((f) => f.id.equals(fundId))).write(
      const FundsCompanion(
        mode: Value(FundMode.separate),
        syncAccountId: Value(null),
        syncTransferId: Value(null),
      ),
    );
  });

  /// Brings a synced fund's "remaining" transfer up to date: amount (either
  /// way: an overspend is covered from the account) and date.
  Future<void> _refreshSync(int fundId) async {
    final fund = await (select(
      funds,
    )..where((f) => f.id.equals(fundId))).getSingle();
    final target = fund.syncAccountId;
    if (fund.mode != FundMode.merged || target == null) return;
    final pots = await _fundAccountIds(fundId);
    if (pots.isEmpty) return;
    final left = await fundRemaining(fundId);
    var last = fund.createdAt;
    for (final t in await _fundTxns(pots)) {
      if (t.id != fund.syncTransferId && t.occurredAt.isAfter(last)) {
        last = t.occurredAt;
      }
    }
    final row = TransactionsCompanion(
      type: const Value(TxnType.transfer),
      amountPaise: Value(left.abs()),
      accountId: Value(left >= 0 ? pots.first : target),
      toAccountId: Value(left >= 0 ? target : pots.first),
      note: const Value('remaining'),
      occurredAt: Value(last.add(const Duration(minutes: 1))),
    );
    final existing = fund.syncTransferId;
    int? id = existing;
    if (left == 0) {
      if (existing != null) {
        await (delete(transactions)..where((t) => t.id.equals(existing))).go();
      }
      id = null;
    } else if (existing != null &&
        await (update(
              transactions,
            )..where((t) => t.id.equals(existing))).write(row) >
            0) {
      // Updated in place.
    } else {
      id = await into(transactions).insert(row);
    }
    if (id != existing) {
      await (update(funds)..where((f) => f.id.equals(fundId))).write(
        FundsCompanion(syncTransferId: Value(id)),
      );
    }
  }

  /// Refreshes every synced fund whose accounts are among [accountIds].
  Future<void> _refreshSyncsFor(Iterable<int?> accountIds) async {
    final ids = accountIds.nonNulls.toList();
    if (ids.isEmpty) return;
    final fundIds = {
      for (final a in await (select(
        accounts,
      )..where((a) => a.id.isIn(ids) & a.fundId.isNotNull())).get())
        a.fundId!,
    };
    for (final f in fundIds) {
      await _refreshSync(f);
    }
  }

  /// Closes fund [fundId]: moves [leftPaise] from [potId] to [toAccountId]
  /// (when both are given) and archives the fund and its accounts. Returns
  /// the leftover transfer's id, so Undo can take it back.
  Future<int?> closeFund(
    int fundId, {
    int leftPaise = 0,
    int? potId,
    int? toAccountId,
    String? note,
  }) => transaction(() async {
    await unsyncFund(fundId);
    int? moved;
    if (leftPaise > 0 && potId != null && toAccountId != null) {
      moved = await into(transactions).insert(
        TransactionsCompanion.insert(
          type: TxnType.transfer,
          amountPaise: leftPaise,
          accountId: potId,
          toAccountId: Value(toAccountId),
          note: Value(note ?? ''),
          occurredAt: DateTime.now(),
        ),
      );
    }
    await (update(accounts)..where((a) => a.fundId.equals(fundId))).write(
      const AccountsCompanion(archived: Value(true)),
    );
    await (update(funds)..where((f) => f.id.equals(fundId))).write(
      const FundsCompanion(archived: Value(true)),
    );
    return moved;
  });

  /// Reopens a closed fund; [undoTransferId] also takes back the leftover
  /// transfer made when it was closed.
  Future<void> reopenFund(int fundId, {int? undoTransferId}) =>
      transaction(() async {
        if (undoTransferId != null) await deleteTransaction(undoTransferId);
        await (update(accounts)..where((a) => a.fundId.equals(fundId))).write(
          const AccountsCompanion(archived: Value(false)),
        );
        await (update(funds)..where((f) => f.id.equals(fundId))).write(
          const FundsCompanion(archived: Value(false)),
        );
      });

  Stream<List<Rule>> watchRules() =>
      (select(rules)..orderBy([(r) => OrderingTerm.asc(r.keyword)])).watch();

  /// Remembers a correction for [keyword]. Updating an existing rule keeps
  /// whichever of category/account this correction doesn't set.
  Future<void> learnRule(String keyword, {int? categoryId, int? accountId}) =>
      into(rules).insert(
        RulesCompanion.insert(
          keyword: keyword,
          categoryId: Value(categoryId),
          accountId: Value(accountId),
        ),
        onConflict: DoUpdate(
          (_) => RulesCompanion(
            categoryId: categoryId == null
                ? const Value.absent()
                : Value(categoryId),
            accountId: accountId == null
                ? const Value.absent()
                : Value(accountId),
          ),
          target: [rules.keyword],
        ),
      );

  /// Counts a capture the rule filled in and the user kept.
  Future<void> bumpRule(int id) => customUpdate(
    'UPDATE rules SET hits = hits + 1 WHERE id = ?',
    variables: [Variable.withInt(id)],
    updates: {rules},
  );

  Future<int> deleteRule(int id) =>
      (delete(rules)..where((r) => r.id.equals(id))).go();

  /// Puts back a deleted rule (Undo).
  Future<void> restoreRule(Rule r) => into(rules).insertOnConflictUpdate(r);

  /// Sums per (account, to-account, type), for balances.
  Stream<List<TxnTotal>> watchTxnTotals() =>
      customSelect(
        'SELECT account_id, to_account_id, type, SUM(amount_paise) AS total '
        'FROM transactions GROUP BY account_id, to_account_id, type',
        readsFrom: {transactions},
      ).watch().map(
        (rows) => [
          for (final r in rows)
            (
              accountId: r.read<int>('account_id'),
              toAccountId: r.readNullable<int>('to_account_id'),
              type: TxnType.values.byName(r.read<String>('type')),
              sum: r.read<int>('total'),
            ),
        ],
      );

  Future<void> saveAccount(AccountsCompanion a) =>
      into(accounts).insertOnConflictUpdate(a);

  /// Search notes, merchants and raw text, newest first. Null filters are
  /// ignored; [to] is exclusive.
  Stream<List<Transaction>> watchSearch({
    String query = '',
    TxnType? type,
    int? accountId,
    int? categoryId,
    DateTime? from,
    DateTime? to,
    int limit = 500,
  }) {
    final q = select(transactions);
    final words = query
        .trim()
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty);
    q.where((t) {
      Expression<bool> e = const Constant(true);
      for (final w in words) {
        final like = '%$w%';
        e &=
            t.note.lower().like(like) |
            t.merchant.lower().like(like) |
            t.tags.lower().like(like);
      }
      if (type != null) e &= t.type.equalsValue(type);
      if (accountId != null) {
        e &= t.accountId.equals(accountId) | t.toAccountId.equals(accountId);
      }
      if (categoryId != null) e &= t.categoryId.equals(categoryId);
      if (from != null) e &= t.occurredAt.isBiggerOrEqualValue(from);
      if (to != null) e &= t.occurredAt.isSmallerThanValue(to);
      return e;
    });
    q
      ..orderBy([
        (t) => OrderingTerm.desc(t.occurredAt),
        (t) => OrderingTerm.desc(t.id),
      ])
      ..limit(limit);
    return q.watch();
  }

  // ---- Budgets & recurring ---------------------------------------------

  Stream<List<Budget>> watchBudgets() => select(budgets).watch();

  Future<void> saveBudget(BudgetsCompanion b) =>
      into(budgets).insertOnConflictUpdate(b);

  Future<int> deleteBudget(int id) =>
      (delete(budgets)..where((b) => b.id.equals(id))).go();

  Stream<List<Recurring>> watchRecurrings() =>
      (select(recurrings)
            ..where((r) => r.status.equalsValue(RecurringStatus.ended).not())
            ..orderBy([(r) => OrderingTerm(expression: r.name)]))
          .watch();

  Future<int> saveRecurring(RecurringsCompanion r) =>
      into(recurrings).insertOnConflictUpdate(r);

  Future<int> deleteRecurring(int id) =>
      (delete(recurrings)..where((r) => r.id.equals(id))).go();

  /// Records that the occurrence around [paidOn] was paid.
  Future<void> markRecurringPaid(int id, DateTime paidOn) =>
      (update(recurrings)..where((r) => r.id.equals(id))).write(
        RecurringsCompanion(lastPaid: Value(paidOn)),
      );

  // ---- Settings ----------------------------------------------------------

  Stream<String?> watchSetting(String key) => (select(
    appSettings,
  )..where((s) => s.key.equals(key))).watchSingleOrNull().map((s) => s?.value);

  Future<String?> getSetting(String key) => (select(
    appSettings,
  )..where((s) => s.key.equals(key))).getSingleOrNull().then((s) => s?.value);

  Future<void> setSetting(String key, String value) =>
      into(appSettings)
          .insertOnConflictUpdate(AppSetting(key: key, value: value));

  Future<int> deleteTransaction(int id) => transaction(() async {
    final t = await (select(
      transactions,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    final n = await (delete(transactions)..where((t) => t.id.equals(id))).go();
    if (t != null) await _refreshSyncsFor([t.accountId, t.toAccountId]);
    return n;
  });
}

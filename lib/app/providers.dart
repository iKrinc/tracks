import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:tracks/core/dates.dart';
import 'package:tracks/data/app_database.dart';
import 'package:tracks/features/accounts/domain/balances.dart';
import 'package:tracks/features/accounts/domain/credit_card.dart';
import 'package:tracks/features/budgets/domain/budget_math.dart';
import 'package:tracks/features/capture/domain/rules.dart';
import 'package:tracks/features/funds/domain/fund_math.dart';
import 'package:tracks/features/insights/domain/forecast.dart';
import 'package:tracks/features/recurring/domain/reminder_plan.dart';
import 'package:tracks/features/recurring/domain/schedule.dart';
import 'package:tracks/features/transactions/domain/summary.dart';

part 'providers.g.dart';

@Riverpod(keepAlive: true)
AppDatabase appDatabase(Ref ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
}

@riverpod
Stream<List<Account>> accounts(Ref ref) =>
    ref.watch(appDatabaseProvider).watchAccounts();

/// Active and archived accounts: for naming accounts on transaction rows
/// and for balances (archiving hides an account, it doesn't erase money).
@riverpod
Stream<List<Account>> allAccounts(Ref ref) =>
    ref.watch(appDatabaseProvider).watchAllAccounts();

@riverpod
Stream<List<Rule>> rules(Ref ref) =>
    ref.watch(appDatabaseProvider).watchRules();

/// Rules in the shape the pure matcher takes.
List<RuleLike> ruleLikes(List<Rule> rules) => [
  for (final r in rules)
    (
      id: r.id,
      keyword: r.keyword,
      categoryId: r.categoryId,
      accountId: r.accountId,
    ),
];

@riverpod
Stream<List<Category>> categories(Ref ref, CategoryKind kind) =>
    ref.watch(appDatabaseProvider).watchCategories(kind);

@riverpod
class SelectedMonth extends _$SelectedMonth {
  @override
  DateTime build() => monthStart(DateTime.now());

  void previous() => state = DateTime(state.year, state.month - 1);
  void next() => state = DateTime(state.year, state.month + 1);
  void previousYear() => state = DateTime(state.year - 1, state.month);
  void nextYear() => state = DateTime(state.year + 1, state.month);
  void set(DateTime month) => state = monthStart(month);
}

@riverpod
Stream<List<Transaction>> monthTransactions(Ref ref) {
  final month = ref.watch(selectedMonthProvider);
  final separate = ref.watch(separateFundAccountsProvider);
  return ref
      .watch(appDatabaseProvider)
      .watchTransactionsBetween(month, nextMonthStart(month))
      .map((rows) => mainOnly(rows, separate));
}

@riverpod
Stream<List<Fund>> funds(Ref ref) =>
    ref.watch(appDatabaseProvider).watchFunds();

/// Accounts of funds kept separate; their money stays out of main views.
@riverpod
Set<int> separateFundAccounts(Ref ref) => separateAccountIds(
  accounts: [
    for (final a in ref.watch(allAccountsProvider).value ?? const <Account>[])
      (id: a.id, fundId: a.fundId),
  ],
  funds: [
    for (final f in ref.watch(fundsProvider).value ?? const <Fund>[])
      (id: f.id, mode: f.mode),
  ],
);

FundTxn fundTxnOf(Transaction t) => (
  type: t.type,
  accountId: t.accountId,
  toAccountId: t.toAccountId,
  fundId: t.fundId,
  paise: t.amountPaise,
  categoryId: t.categoryId,
);

/// [rows] without what belongs only to separate funds.
List<Transaction> mainOnly(List<Transaction> rows, Set<int> separate) =>
    separate.isEmpty
    ? rows
    : [
        for (final t in rows)
          if (countsInMain(fundTxnOf(t), separate)) t,
      ];

@riverpod
Stream<List<TxnTotal>> txnTotals(Ref ref) =>
    ref.watch(appDatabaseProvider).watchTxnTotals();

/// Current balance in paise per account (archived ones included).
@riverpod
Map<int, int> balances(Ref ref) {
  final accounts = ref.watch(allAccountsProvider).value ?? const <Account>[];
  final totals = ref.watch(txnTotalsProvider).value ?? const <TxnTotal>[];
  return computeBalances(
    openings: {for (final a in accounts) a.id: a.openingBalancePaise},
    totals: totals,
  );
}

@riverpod
Stream<String?> setting(Ref ref, String key) =>
    ref.watch(appDatabaseProvider).watchSetting(key);

/// How the Transactions tab groups things.
enum PeriodView { daily, monthly, yearly }

@riverpod
class ViewMode extends _$ViewMode {
  @override
  PeriodView build() => PeriodView.daily;

  void set(PeriodView v) => state = v;
}

/// All transactions as plain records, for period totals and reports.
@riverpod
Stream<List<DatedTxn>> allDatedTxns(Ref ref) {
  final separate = ref.watch(separateFundAccountsProvider);
  return ref
      .watch(appDatabaseProvider)
      .watchAllTransactions()
      .map(
        (rows) => [
          for (final t in mainOnly(rows, separate))
            (
              type: t.type,
              amountPaise: t.amountPaise,
              occurredAt: t.occurredAt,
              categoryId: t.categoryId,
            ),
        ],
      );
}

/// Category id → parent id, for rolling subcategories up.
@riverpod
Map<int, int?> categoryParents(Ref ref) => {
  for (final kind in CategoryKind.values)
    for (final c in ref.watch(categoriesProvider(kind)).value ?? const [])
      c.id: c.parentId,
};

@riverpod
Stream<List<Budget>> budgets(Ref ref) =>
    ref.watch(appDatabaseProvider).watchBudgets();

typedef BudgetView = ({Budget budget, BudgetProgress progress});

/// Budgets measured against the current calendar month (not the month being
/// browsed), overall first, then the tightest.
@riverpod
List<BudgetView> budgetViews(Ref ref) {
  final all = ref.watch(allDatedTxnsProvider).value ?? const <DatedTxn>[];
  final parents = ref.watch(categoryParentsProvider);
  final now = DateTime.now();
  final prev = DateTime(now.year, now.month - 1);
  final views = [
    for (final b in ref.watch(budgetsProvider).value ?? const <Budget>[])
      (
        budget: b,
        progress: budgetProgress(
          limitPaise: b.amountPaise,
          spentPaise: spentInMonth(all, now, b.categoryId, parentOf: parents),
          rolloverPaise: b.rollover
              ? rolloverFrom(
                  limitPaise: b.amountPaise,
                  spentPaise: spentInMonth(
                    all,
                    prev,
                    b.categoryId,
                    parentOf: parents,
                  ),
                )
              : 0,
        ),
      ),
  ];
  views.sort((a, b) {
    if (a.budget.categoryId == null) return -1;
    if (b.budget.categoryId == null) return 1;
    return b.progress.percent.compareTo(a.progress.percent);
  });
  return views;
}

@riverpod
Stream<List<Recurring>> recurrings(Ref ref) =>
    ref.watch(appDatabaseProvider).watchRecurrings();

typedef DueItem = ({Recurring item, DateTime due, DueStatus status});

/// Active recurring items by next due date, soonest first.
@riverpod
List<DueItem> dueItems(Ref ref) {
  final now = DateTime.now();
  final items = [
    for (final r in ref.watch(recurringsProvider).value ?? const <Recurring>[])
      if (r.status == RecurringStatus.active)
        () {
          final due = nextDue(
            start: r.startDate,
            unit: r.unit,
            interval: r.interval,
            lastPaid: r.lastPaid,
          );
          return (item: r, due: due, status: dueStatus(due, now));
        }(),
  ]..sort((a, b) => a.due.compareTo(b.due));
  return items;
}

/// Reminder notifications to schedule: active bills, plus each credit
/// card's due date (ids offset so they never clash with bill ids).
@riverpod
List<PlannedReminder> reminderPlan(Ref ref) => planReminders([
  for (final a in ref.watch(accountsProvider).value ?? const <Account>[])
    if (a.type == AccountType.creditCard &&
        a.statementDay != null &&
        a.dueDay != null)
      (
        id: cardReminderIdBase + a.id,
        name: '${a.name} bill',
        amountPaise: 0,
        variableAmount: true,
        type: TxnType.expense,
        due: cardCycle(
          statementDay: a.statementDay!,
          dueDay: a.dueDay!,
          today: DateTime.now(),
        ).due,
        daysBefore: 3,
        autopay: AutopayKind.none,
      ),
  for (final d in ref.watch(dueItemsProvider))
    (
      id: d.item.id,
      name: d.item.name,
      amountPaise: d.item.amountPaise,
      variableAmount: d.item.variableAmount,
      type: d.item.type,
      due: d.due,
      daysBefore: d.item.remindDaysBefore,
      autopay: d.item.autopay,
    ),
], DateTime.now());

@riverpod
Stream<List<Transaction>> accountTxns(Ref ref, int accountId) =>
    ref.watch(appDatabaseProvider).watchAccountTxns(accountId);

/// Every transaction, newest first.
@riverpod
Stream<List<Transaction>> allTransactions(Ref ref) =>
    ref.watch(appDatabaseProvider).watchAllTransactions();

/// Accounts whose money you can spend today; cards and loans are owed.
const spendableAccountTypes = {
  AccountType.cash,
  AccountType.bank,
  AccountType.wallet,
};

/// What's left before payday: spendable balances run forward through bills,
/// EMIs, card dues and typical everyday spending. Null while loading or
/// without a spendable account.
@riverpod
CashForecast? cashForecast(Ref ref) {
  final accounts = ref.watch(accountsProvider).value;
  final txns = ref.watch(allTransactionsProvider).value;
  final recurrings = ref.watch(recurringsProvider).value;
  if (accounts == null || txns == null || recurrings == null) return null;
  final balances = ref.watch(balancesProvider);
  // A fund's money is earmarked (even when merged into the totals), so it
  // is never counted as there to spend before payday.
  final liquid = {
    for (final a in accounts)
      if (spendableAccountTypes.contains(a.type) && a.fundId == null) a.id,
  };
  if (liquid.isEmpty) return null;
  final today = DateTime.now();
  final fundAccounts = {
    for (final a in accounts)
      if (a.fundId != null) a.id,
  };
  final active = recurrings.where((r) => r.status == RecurringStatus.active);
  // A card already paid by a bill (standing instruction) isn't counted twice.
  final paidByBill = {for (final r in active) ?r.toAccountId};

  int signed(Transaction t, int id) => switch (t.type) {
    TxnType.income => t.amountPaise,
    TxnType.expense => -t.amountPaise,
    TxnType.transfer => t.toAccountId == id ? t.amountPaise : -t.amountPaise,
  };

  final cardDues = <ForecastOneOff>[];
  for (final a in accounts) {
    if (a.type != AccountType.creditCard ||
        a.statementDay == null ||
        paidByBill.contains(a.id)) {
      continue;
    }
    final cycle = cardCycle(
      statementDay: a.statementDay!,
      dueDay: a.dueDay ?? a.statementDay!,
      today: today,
    );
    final status = cardStatus(
      moves: [
        for (final t in txns)
          if (t.accountId == a.id || t.toAccountId == a.id)
            (at: t.occurredAt, paise: signed(t, a.id)),
      ],
      openingPaise: a.openingBalancePaise,
      cycle: cycle,
      limitPaise: a.creditLimitPaise ?? 0,
    );
    if (status.dueNowPaise > 0) {
      cardDues.add((
        date: cycle.due,
        name: '${a.name} bill',
        paise: status.dueNowPaise,
      ));
    }
  }

  return forecastCashflow(
    today: today,
    liquidPaise: liquid.fold(0, (sum, id) => sum + (balances[id] ?? 0)),
    liquidAccounts: liquid,
    bills: [
      for (final r in active)
        (
          id: r.id,
          name: r.name,
          type: r.type,
          amountPaise: r.amountPaise,
          accountId: r.accountId,
          toAccountId: r.toAccountId,
          start: r.startDate,
          unit: r.unit,
          interval: r.interval,
          lastPaid: r.lastPaid,
        ),
    ],
    oneOffs: cardDues,
    dailySpendPaise: averageDailySpend(
      [
        for (final t in txns)
          (
            type: t.type,
            accountId: t.accountId,
            paise: t.amountPaise,
            at: t.occurredAt,
            // Bills are forecast on their own; a fund's spends are one-off
            // event costs, not what a usual day costs.
            notEveryday:
                t.linkedRecurringId != null ||
                t.source == TxnSource.recurring ||
                t.fundId != null ||
                fundAccounts.contains(t.accountId),
          ),
      ],
      today: today,
      liquidAccounts: liquid,
    ),
  );
}

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:tracks/core/dates.dart';
import 'package:tracks/data/app_database.dart';
import 'package:tracks/features/accounts/domain/balances.dart';
import 'package:tracks/features/accounts/domain/credit_card.dart';
import 'package:tracks/features/budgets/domain/budget_math.dart';
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
  return ref
      .watch(appDatabaseProvider)
      .watchTransactionsBetween(month, nextMonthStart(month));
}

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
Stream<List<DatedTxn>> allDatedTxns(Ref ref) => ref
    .watch(appDatabaseProvider)
    .watchAllTransactions()
    .map(
      (rows) => [
        for (final t in rows)
          (
            type: t.type,
            amountPaise: t.amountPaise,
            occurredAt: t.occurredAt,
            categoryId: t.categoryId,
          ),
      ],
    );

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

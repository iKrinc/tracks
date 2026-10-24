// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(appDatabase)
final appDatabaseProvider = AppDatabaseProvider._();

final class AppDatabaseProvider
    extends $FunctionalProvider<AppDatabase, AppDatabase, AppDatabase>
    with $Provider<AppDatabase> {
  AppDatabaseProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appDatabaseProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appDatabaseHash();

  @$internal
  @override
  $ProviderElement<AppDatabase> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AppDatabase create(Ref ref) {
    return appDatabase(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AppDatabase value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AppDatabase>(value),
    );
  }
}

String _$appDatabaseHash() => r'59cce38d45eeaba199eddd097d8e149d66f9f3e1';

@ProviderFor(accounts)
final accountsProvider = AccountsProvider._();

final class AccountsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Account>>,
          List<Account>,
          Stream<List<Account>>
        >
    with $FutureModifier<List<Account>>, $StreamProvider<List<Account>> {
  AccountsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'accountsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$accountsHash();

  @$internal
  @override
  $StreamProviderElement<List<Account>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<Account>> create(Ref ref) {
    return accounts(ref);
  }
}

String _$accountsHash() => r'b3f110a176b8f57a0de153b0ea0d530685f00f94';

/// Active and archived accounts: for naming accounts on transaction rows
/// and for balances (archiving hides an account, it doesn't erase money).

@ProviderFor(allAccounts)
final allAccountsProvider = AllAccountsProvider._();

/// Active and archived accounts: for naming accounts on transaction rows
/// and for balances (archiving hides an account, it doesn't erase money).

final class AllAccountsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Account>>,
          List<Account>,
          Stream<List<Account>>
        >
    with $FutureModifier<List<Account>>, $StreamProvider<List<Account>> {
  /// Active and archived accounts: for naming accounts on transaction rows
  /// and for balances (archiving hides an account, it doesn't erase money).
  AllAccountsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'allAccountsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$allAccountsHash();

  @$internal
  @override
  $StreamProviderElement<List<Account>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<Account>> create(Ref ref) {
    return allAccounts(ref);
  }
}

String _$allAccountsHash() => r'45fa61c515e23fcfbdb502b1b275f55fc19a48f4';

@ProviderFor(rules)
final rulesProvider = RulesProvider._();

final class RulesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Rule>>,
          List<Rule>,
          Stream<List<Rule>>
        >
    with $FutureModifier<List<Rule>>, $StreamProvider<List<Rule>> {
  RulesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'rulesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$rulesHash();

  @$internal
  @override
  $StreamProviderElement<List<Rule>> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<List<Rule>> create(Ref ref) {
    return rules(ref);
  }
}

String _$rulesHash() => r'16d91af3ab37db64ec19ec7b922a984a5f8f30e1';

@ProviderFor(categories)
final categoriesProvider = CategoriesFamily._();

final class CategoriesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Category>>,
          List<Category>,
          Stream<List<Category>>
        >
    with $FutureModifier<List<Category>>, $StreamProvider<List<Category>> {
  CategoriesProvider._({
    required CategoriesFamily super.from,
    required CategoryKind super.argument,
  }) : super(
         retry: null,
         name: r'categoriesProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$categoriesHash();

  @override
  String toString() {
    return r'categoriesProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<List<Category>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<Category>> create(Ref ref) {
    final argument = this.argument as CategoryKind;
    return categories(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is CategoriesProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$categoriesHash() => r'3c2274678f5d6fcc0d0483a2b3f441db2b0a0316';

final class CategoriesFamily extends $Family
    with $FunctionalFamilyOverride<Stream<List<Category>>, CategoryKind> {
  CategoriesFamily._()
    : super(
        retry: null,
        name: r'categoriesProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  CategoriesProvider call(CategoryKind kind) =>
      CategoriesProvider._(argument: kind, from: this);

  @override
  String toString() => r'categoriesProvider';
}

@ProviderFor(SelectedMonth)
final selectedMonthProvider = SelectedMonthProvider._();

final class SelectedMonthProvider
    extends $NotifierProvider<SelectedMonth, DateTime> {
  SelectedMonthProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'selectedMonthProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$selectedMonthHash();

  @$internal
  @override
  SelectedMonth create() => SelectedMonth();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DateTime value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DateTime>(value),
    );
  }
}

String _$selectedMonthHash() => r'3928b7288ef4984ae37786607e45178f62b8f5d7';

abstract class _$SelectedMonth extends $Notifier<DateTime> {
  DateTime build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<DateTime, DateTime>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<DateTime, DateTime>,
              DateTime,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

@ProviderFor(monthTransactions)
final monthTransactionsProvider = MonthTransactionsProvider._();

final class MonthTransactionsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Transaction>>,
          List<Transaction>,
          Stream<List<Transaction>>
        >
    with
        $FutureModifier<List<Transaction>>,
        $StreamProvider<List<Transaction>> {
  MonthTransactionsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'monthTransactionsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$monthTransactionsHash();

  @$internal
  @override
  $StreamProviderElement<List<Transaction>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<Transaction>> create(Ref ref) {
    return monthTransactions(ref);
  }
}

String _$monthTransactionsHash() => r'890e920840fc6f30d11ee3019908578cb712e262';

@ProviderFor(funds)
final fundsProvider = FundsProvider._();

final class FundsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Fund>>,
          List<Fund>,
          Stream<List<Fund>>
        >
    with $FutureModifier<List<Fund>>, $StreamProvider<List<Fund>> {
  FundsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'fundsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$fundsHash();

  @$internal
  @override
  $StreamProviderElement<List<Fund>> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<List<Fund>> create(Ref ref) {
    return funds(ref);
  }
}

String _$fundsHash() => r'87af48840c0c8d9f5f93cd62b08d2278558d4d07';

/// Accounts of funds kept separate; their money stays out of main views.

@ProviderFor(separateFundAccounts)
final separateFundAccountsProvider = SeparateFundAccountsProvider._();

/// Accounts of funds kept separate; their money stays out of main views.

final class SeparateFundAccountsProvider
    extends $FunctionalProvider<Set<int>, Set<int>, Set<int>>
    with $Provider<Set<int>> {
  /// Accounts of funds kept separate; their money stays out of main views.
  SeparateFundAccountsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'separateFundAccountsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$separateFundAccountsHash();

  @$internal
  @override
  $ProviderElement<Set<int>> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  Set<int> create(Ref ref) {
    return separateFundAccounts(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Set<int> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Set<int>>(value),
    );
  }
}

String _$separateFundAccountsHash() =>
    r'68b270c7b91af8527fad8fa9c159cc8d3cb337bc';

@ProviderFor(txnTotals)
final txnTotalsProvider = TxnTotalsProvider._();

final class TxnTotalsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<TxnTotal>>,
          List<TxnTotal>,
          Stream<List<TxnTotal>>
        >
    with $FutureModifier<List<TxnTotal>>, $StreamProvider<List<TxnTotal>> {
  TxnTotalsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'txnTotalsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$txnTotalsHash();

  @$internal
  @override
  $StreamProviderElement<List<TxnTotal>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<TxnTotal>> create(Ref ref) {
    return txnTotals(ref);
  }
}

String _$txnTotalsHash() => r'f20993b35710cf49992f4919de96567d234affbf';

/// Current balance in paise per account (archived ones included).

@ProviderFor(balances)
final balancesProvider = BalancesProvider._();

/// Current balance in paise per account (archived ones included).

final class BalancesProvider
    extends $FunctionalProvider<Map<int, int>, Map<int, int>, Map<int, int>>
    with $Provider<Map<int, int>> {
  /// Current balance in paise per account (archived ones included).
  BalancesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'balancesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$balancesHash();

  @$internal
  @override
  $ProviderElement<Map<int, int>> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  Map<int, int> create(Ref ref) {
    return balances(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Map<int, int> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Map<int, int>>(value),
    );
  }
}

String _$balancesHash() => r'4685d1178a460188aa1260e86e97bc2a8ae95412';

@ProviderFor(setting)
final settingProvider = SettingFamily._();

final class SettingProvider
    extends $FunctionalProvider<AsyncValue<String?>, String?, Stream<String?>>
    with $FutureModifier<String?>, $StreamProvider<String?> {
  SettingProvider._({
    required SettingFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'settingProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$settingHash();

  @override
  String toString() {
    return r'settingProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<String?> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<String?> create(Ref ref) {
    final argument = this.argument as String;
    return setting(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is SettingProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$settingHash() => r'e18732dc15dded8ff88383dad489a063d078a463';

final class SettingFamily extends $Family
    with $FunctionalFamilyOverride<Stream<String?>, String> {
  SettingFamily._()
    : super(
        retry: null,
        name: r'settingProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  SettingProvider call(String key) =>
      SettingProvider._(argument: key, from: this);

  @override
  String toString() => r'settingProvider';
}

@ProviderFor(ViewMode)
final viewModeProvider = ViewModeProvider._();

final class ViewModeProvider extends $NotifierProvider<ViewMode, PeriodView> {
  ViewModeProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'viewModeProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$viewModeHash();

  @$internal
  @override
  ViewMode create() => ViewMode();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PeriodView value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PeriodView>(value),
    );
  }
}

String _$viewModeHash() => r'e974bd99f7a9480d0a7ae5dccd03cb3f1d4336a5';

abstract class _$ViewMode extends $Notifier<PeriodView> {
  PeriodView build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<PeriodView, PeriodView>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<PeriodView, PeriodView>,
              PeriodView,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// All transactions as plain records, for period totals and reports.

@ProviderFor(allDatedTxns)
final allDatedTxnsProvider = AllDatedTxnsProvider._();

/// All transactions as plain records, for period totals and reports.

final class AllDatedTxnsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<DatedTxn>>,
          List<DatedTxn>,
          Stream<List<DatedTxn>>
        >
    with $FutureModifier<List<DatedTxn>>, $StreamProvider<List<DatedTxn>> {
  /// All transactions as plain records, for period totals and reports.
  AllDatedTxnsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'allDatedTxnsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$allDatedTxnsHash();

  @$internal
  @override
  $StreamProviderElement<List<DatedTxn>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<DatedTxn>> create(Ref ref) {
    return allDatedTxns(ref);
  }
}

String _$allDatedTxnsHash() => r'1134089581e6cbf34d6404026df50a65971d1043';

/// Category id → parent id, for rolling subcategories up.

@ProviderFor(categoryParents)
final categoryParentsProvider = CategoryParentsProvider._();

/// Category id → parent id, for rolling subcategories up.

final class CategoryParentsProvider
    extends $FunctionalProvider<Map<int, int?>, Map<int, int?>, Map<int, int?>>
    with $Provider<Map<int, int?>> {
  /// Category id → parent id, for rolling subcategories up.
  CategoryParentsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'categoryParentsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$categoryParentsHash();

  @$internal
  @override
  $ProviderElement<Map<int, int?>> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  Map<int, int?> create(Ref ref) {
    return categoryParents(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Map<int, int?> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Map<int, int?>>(value),
    );
  }
}

String _$categoryParentsHash() => r'bef947e6735502a9039d1f97e03fd77c599c0782';

@ProviderFor(budgets)
final budgetsProvider = BudgetsProvider._();

final class BudgetsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Budget>>,
          List<Budget>,
          Stream<List<Budget>>
        >
    with $FutureModifier<List<Budget>>, $StreamProvider<List<Budget>> {
  BudgetsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'budgetsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$budgetsHash();

  @$internal
  @override
  $StreamProviderElement<List<Budget>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<Budget>> create(Ref ref) {
    return budgets(ref);
  }
}

String _$budgetsHash() => r'd7d2bd6d5c8ca2bd435474b67322f7a82c1b102a';

/// Budgets measured against the current calendar month (not the month being
/// browsed), overall first, then the tightest.

@ProviderFor(budgetViews)
final budgetViewsProvider = BudgetViewsProvider._();

/// Budgets measured against the current calendar month (not the month being
/// browsed), overall first, then the tightest.

final class BudgetViewsProvider
    extends
        $FunctionalProvider<
          List<BudgetView>,
          List<BudgetView>,
          List<BudgetView>
        >
    with $Provider<List<BudgetView>> {
  /// Budgets measured against the current calendar month (not the month being
  /// browsed), overall first, then the tightest.
  BudgetViewsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'budgetViewsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$budgetViewsHash();

  @$internal
  @override
  $ProviderElement<List<BudgetView>> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  List<BudgetView> create(Ref ref) {
    return budgetViews(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(List<BudgetView> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<List<BudgetView>>(value),
    );
  }
}

String _$budgetViewsHash() => r'ec7394b6d2a6798bf50dc78d8f58568ceb1abda9';

@ProviderFor(recurrings)
final recurringsProvider = RecurringsProvider._();

final class RecurringsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Recurring>>,
          List<Recurring>,
          Stream<List<Recurring>>
        >
    with $FutureModifier<List<Recurring>>, $StreamProvider<List<Recurring>> {
  RecurringsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'recurringsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$recurringsHash();

  @$internal
  @override
  $StreamProviderElement<List<Recurring>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<Recurring>> create(Ref ref) {
    return recurrings(ref);
  }
}

String _$recurringsHash() => r'7e6a8b719d9ce4177a609a832b47c402a2a0a78c';

/// Active recurring items by next due date, soonest first.

@ProviderFor(dueItems)
final dueItemsProvider = DueItemsProvider._();

/// Active recurring items by next due date, soonest first.

final class DueItemsProvider
    extends $FunctionalProvider<List<DueItem>, List<DueItem>, List<DueItem>>
    with $Provider<List<DueItem>> {
  /// Active recurring items by next due date, soonest first.
  DueItemsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'dueItemsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$dueItemsHash();

  @$internal
  @override
  $ProviderElement<List<DueItem>> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  List<DueItem> create(Ref ref) {
    return dueItems(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(List<DueItem> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<List<DueItem>>(value),
    );
  }
}

String _$dueItemsHash() => r'ad2d5376a4b311dcb758ca409197a28747568b48';

/// Reminder notifications to schedule: active bills, plus each credit
/// card's due date (ids offset so they never clash with bill ids).

@ProviderFor(reminderPlan)
final reminderPlanProvider = ReminderPlanProvider._();

/// Reminder notifications to schedule: active bills, plus each credit
/// card's due date (ids offset so they never clash with bill ids).

final class ReminderPlanProvider
    extends
        $FunctionalProvider<
          List<PlannedReminder>,
          List<PlannedReminder>,
          List<PlannedReminder>
        >
    with $Provider<List<PlannedReminder>> {
  /// Reminder notifications to schedule: active bills, plus each credit
  /// card's due date (ids offset so they never clash with bill ids).
  ReminderPlanProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'reminderPlanProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$reminderPlanHash();

  @$internal
  @override
  $ProviderElement<List<PlannedReminder>> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  List<PlannedReminder> create(Ref ref) {
    return reminderPlan(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(List<PlannedReminder> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<List<PlannedReminder>>(value),
    );
  }
}

String _$reminderPlanHash() => r'b820a2c7a471a703a195338a9188188e2a632caa';

@ProviderFor(accountTxns)
final accountTxnsProvider = AccountTxnsFamily._();

final class AccountTxnsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Transaction>>,
          List<Transaction>,
          Stream<List<Transaction>>
        >
    with
        $FutureModifier<List<Transaction>>,
        $StreamProvider<List<Transaction>> {
  AccountTxnsProvider._({
    required AccountTxnsFamily super.from,
    required int super.argument,
  }) : super(
         retry: null,
         name: r'accountTxnsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$accountTxnsHash();

  @override
  String toString() {
    return r'accountTxnsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<List<Transaction>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<Transaction>> create(Ref ref) {
    final argument = this.argument as int;
    return accountTxns(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is AccountTxnsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$accountTxnsHash() => r'78cc01edae3ef1bdf11a2162fdbeeb9ba0ff1cad';

final class AccountTxnsFamily extends $Family
    with $FunctionalFamilyOverride<Stream<List<Transaction>>, int> {
  AccountTxnsFamily._()
    : super(
        retry: null,
        name: r'accountTxnsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  AccountTxnsProvider call(int accountId) =>
      AccountTxnsProvider._(argument: accountId, from: this);

  @override
  String toString() => r'accountTxnsProvider';
}

/// Every transaction, newest first.

@ProviderFor(allTransactions)
final allTransactionsProvider = AllTransactionsProvider._();

/// Every transaction, newest first.

final class AllTransactionsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Transaction>>,
          List<Transaction>,
          Stream<List<Transaction>>
        >
    with
        $FutureModifier<List<Transaction>>,
        $StreamProvider<List<Transaction>> {
  /// Every transaction, newest first.
  AllTransactionsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'allTransactionsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$allTransactionsHash();

  @$internal
  @override
  $StreamProviderElement<List<Transaction>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<Transaction>> create(Ref ref) {
    return allTransactions(ref);
  }
}

String _$allTransactionsHash() => r'ec3d04d45798be82bc6202e99593144b4c931fd2';

/// What's left before payday: spendable balances run forward through bills,
/// EMIs, card dues and typical everyday spending. Null while loading or
/// without a spendable account.

@ProviderFor(cashForecast)
final cashForecastProvider = CashForecastProvider._();

/// What's left before payday: spendable balances run forward through bills,
/// EMIs, card dues and typical everyday spending. Null while loading or
/// without a spendable account.

final class CashForecastProvider
    extends $FunctionalProvider<CashForecast?, CashForecast?, CashForecast?>
    with $Provider<CashForecast?> {
  /// What's left before payday: spendable balances run forward through bills,
  /// EMIs, card dues and typical everyday spending. Null while loading or
  /// without a spendable account.
  CashForecastProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'cashForecastProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$cashForecastHash();

  @$internal
  @override
  $ProviderElement<CashForecast?> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  CashForecast? create(Ref ref) {
    return cashForecast(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CashForecast? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CashForecast?>(value),
    );
  }
}

String _$cashForecastHash() => r'de13bd4e638758dbf5a233a4593ee20659090c99';

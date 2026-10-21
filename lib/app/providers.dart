import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:tracks/core/dates.dart';
import 'package:tracks/data/app_database.dart';
import 'package:tracks/features/accounts/domain/balances.dart';

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

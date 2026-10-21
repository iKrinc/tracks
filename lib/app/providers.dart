import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:tracks/core/dates.dart';
import 'package:tracks/data/app_database.dart';

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

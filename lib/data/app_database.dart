import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:tracks/data/default_data.dart';
import 'package:tracks/data/tables.dart';

export 'package:tracks/data/tables.dart';

part 'app_database.drift.dart';

@DriftDatabase(tables: [Accounts, Categories, Transactions, Rules])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _open());

  @override
  int get schemaVersion => 1;

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
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

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

  Future<int> addTransaction(TransactionsCompanion entry) =>
      into(transactions).insert(entry);

  Future<int> deleteTransaction(int id) =>
      (delete(transactions)..where((t) => t.id.equals(id))).go();
}

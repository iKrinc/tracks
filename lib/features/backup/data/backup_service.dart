import 'package:drift/drift.dart';
import 'package:tracks/data/app_database.dart';
import 'package:tracks/data/default_data.dart';
import 'package:tracks/features/backup/domain/csv_transactions.dart';

/// Bump when the backup JSON layout changes; keep reading older formats.
const backupFormat = 1;

class BackupFormatException implements Exception {
  const BackupFormatException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Everything in the database as plain JSON. Restoring it on any device
/// gives back exactly this state.
Future<Map<String, Object?>> buildBackup(AppDatabase db) async => {
  'app': 'tracks',
  'format': backupFormat,
  'schemaVersion': db.schemaVersion,
  'exportedAt': DateTime.now().toUtc().toIso8601String(),
  'funds': [for (final r in await db.select(db.funds).get()) r.toJson()],
  'accounts': [for (final r in await db.select(db.accounts).get()) r.toJson()],
  'categories': [
    for (final r in await db.select(db.categories).get()) r.toJson(),
  ],
  'transactions': [
    for (final r in await db.select(db.transactions).get()) r.toJson(),
  ],
  'rules': [for (final r in await db.select(db.rules).get()) r.toJson()],
  'settings': [
    for (final r in await db.select(db.appSettings).get()) r.toJson(),
  ],
  'budgets': [for (final r in await db.select(db.budgets).get()) r.toJson()],
  'recurrings': [
    for (final r in await db.select(db.recurrings).get()) r.toJson(),
  ],
};

typedef RestoreSummary = ({int accounts, int categories, int transactions});

/// Replaces all data with [json] from [buildBackup], atomically: on any
/// error nothing changes.
Future<RestoreSummary> restoreBackup(
  AppDatabase db,
  Map<String, dynamic> json,
) async {
  if (json['app'] != 'tracks') {
    throw const BackupFormatException('This is not a Tracks backup file.');
  }
  final format = json['format'];
  if (format is! int || format > backupFormat) {
    throw const BackupFormatException(
      'This backup was made by a newer version of Tracks. Update the app '
      'first.',
    );
  }
  List<Map<String, dynamic>> list(String key) =>
      ((json[key] as List?) ?? const []).cast<Map<String, dynamic>>();

  // Absent in backups from before schema v6.
  final funds = list('funds').map(Fund.fromJson).toList();
  final accounts = list('accounts').map(Account.fromJson).toList();
  // Parents before subcategories, for the foreign key.
  final categories = list('categories').map(Category.fromJson).toList()
    ..sort(
      (a, b) => (a.parentId == null ? 0 : 1) - (b.parentId == null ? 0 : 1),
    );
  final transactions = list('transactions').map(Transaction.fromJson).toList();
  final rules = list('rules').map(Rule.fromJson).toList();
  final settings = list('settings').map(AppSetting.fromJson).toList();
  // Absent in backups from before schema v3.
  final budgets = list('budgets').map(Budget.fromJson).toList();
  final recurrings = list('recurrings').map(Recurring.fromJson).toList();

  await db.transaction(() async {
    await db.delete(db.budgets).go();
    await db.delete(db.recurrings).go();
    await db.delete(db.rules).go();
    await db.delete(db.transactions).go();
    await db.delete(db.categories).go();
    await db.delete(db.accounts).go();
    await db.delete(db.funds).go();
    await db.delete(db.appSettings).go();
    await db.batch((b) {
      b.insertAll(db.funds, funds);
      b.insertAll(db.accounts, accounts);
      b.insertAll(db.categories, categories);
      b.insertAll(db.transactions, transactions);
      b.insertAll(db.rules, rules);
      b.insertAll(db.appSettings, settings);
      b.insertAll(db.budgets, budgets);
      b.insertAll(db.recurrings, recurrings);
    });
  });
  return (
    accounts: accounts.length,
    categories: categories.length,
    transactions: transactions.length,
  );
}

/// All transactions as CSV rows with account/category names, oldest first.
Future<List<CsvTxnRow>> csvExportRows(AppDatabase db) async {
  final accounts = {
    for (final a in await db.select(db.accounts).get()) a.id: a.name,
  };
  final categories = {
    for (final c in await db.select(db.categories).get()) c.id: c.name,
  };
  final txns = await (db.select(
    db.transactions,
  )..orderBy([(t) => OrderingTerm(expression: t.occurredAt)])).get();
  return [
    for (final t in txns)
      CsvTxnRow(
        date: t.occurredAt,
        type: t.type,
        amountPaise: t.amountPaise,
        account: accounts[t.accountId] ?? '',
        toAccount: t.toAccountId == null ? null : accounts[t.toAccountId],
        category: t.categoryId == null ? null : categories[t.categoryId],
        note: t.note,
        merchant: t.merchant,
        tags: t.tags,
        ref: t.refNo,
      ),
  ];
}

typedef CsvImportResult = ({int imported, List<String> newAccounts});

/// Adds parsed CSV rows. Accounts are matched by name (case-insensitive)
/// and created when missing; categories are matched by name and kind and
/// left empty when unknown, so nothing is invented.
Future<CsvImportResult> importCsvRows(
  AppDatabase db,
  List<CsvTxnRow> rows,
) async {
  final newAccounts = <String>[];
  await db.transaction(() async {
    final accounts = {
      for (final a in await db.select(db.accounts).get())
        a.name.toLowerCase(): a.id,
    };
    final categories = await db.select(db.categories).get();

    Future<int> accountId(String name) async {
      final key = name.trim().toLowerCase();
      final existing = accounts[key];
      if (existing != null) return existing;
      final id = await db
          .into(db.accounts)
          .insert(
            AccountsCompanion.insert(
              name: name.trim(),
              type: key == 'cash' ? AccountType.cash : AccountType.bank,
              color: defaultAccountColor,
              icon: key == 'cash' ? 'payments' : 'account_balance',
              matchHints: Value(key),
            ),
          );
      accounts[key] = id;
      newAccounts.add(name.trim());
      return id;
    }

    int? categoryId(String? name, TxnType type) {
      if (name == null || type == TxnType.transfer) return null;
      final kind = type == TxnType.income
          ? CategoryKind.income
          : CategoryKind.expense;
      final key = name.trim().toLowerCase();
      for (final c in categories) {
        if (c.kind == kind && c.name.toLowerCase() == key) return c.id;
      }
      return null;
    }

    for (final r in rows) {
      await db.addTransaction(
        TransactionsCompanion.insert(
          type: r.type,
          amountPaise: r.amountPaise,
          accountId: await accountId(r.account),
          toAccountId: Value(
            r.toAccount == null ? null : await accountId(r.toAccount!),
          ),
          categoryId: Value(categoryId(r.category, r.type)),
          note: Value(r.note),
          merchant: Value(r.merchant),
          occurredAt: r.date,
          tags: Value(r.tags),
          refNo: Value(r.ref),
          source: const Value(TxnSource.import),
        ),
      );
    }
  });
  return (imported: rows.length, newAccounts: newAccounts);
}

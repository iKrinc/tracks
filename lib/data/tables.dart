import 'package:drift/drift.dart';

// Enums are stored by name (text) so JSON/CSV backups stay readable and
// reordering an enum can never corrupt data.

enum AccountType { cash, bank, wallet, creditCard, loan }

enum CategoryKind { expense, income }

enum TxnType { expense, income, transfer }

enum TxnSource { manual, sms, screenshot, quickText, recurring, import }

enum RepeatUnit { week, month, year }

/// How a recurring payment is collected, if automatically.
enum AutopayKind { none, upiMandate, cardStandingInstruction, nach }

enum RecurringStatus { active, paused, ended }

/// One aggregated row: the sum of all transactions sharing these keys.
typedef TxnTotal = ({int accountId, int? toAccountId, TxnType type, int sum});

class Accounts extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 60)();
  TextColumn get type => textEnum<AccountType>()();
  IntColumn get openingBalancePaise =>
      integer().withDefault(const Constant(0))();
  TextColumn get currency => text().withDefault(const Constant('INR'))();
  IntColumn get color => integer()();
  TextColumn get icon => text()();

  /// Words that map quick-add/SMS hints to this account, e.g. "hdfc,xx1234".
  TextColumn get matchHints => text().withDefault(const Constant(''))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  BoolColumn get archived => boolean().withDefault(const Constant(false))();
}

class Categories extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 60)();
  TextColumn get kind => textEnum<CategoryKind>()();

  /// Null for a top-level category; set for a subcategory.
  IntColumn get parentId => integer().nullable().references(Categories, #id)();
  IntColumn get color => integer()();
  TextColumn get icon => text()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  BoolColumn get archived => boolean().withDefault(const Constant(false))();
}

@TableIndex(name: 'txn_occurred_at', columns: {#occurredAt})
class Transactions extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get type => textEnum<TxnType>()();

  /// Always positive; [type] gives the direction.
  IntColumn get amountPaise => integer()();
  @ReferenceName('outgoingTransactions')
  IntColumn get accountId => integer().references(Accounts, #id)();

  /// Destination account for transfers.
  @ReferenceName('incomingTransfers')
  IntColumn get toAccountId => integer().nullable().references(Accounts, #id)();
  IntColumn get categoryId =>
      integer().nullable().references(Categories, #id)();
  TextColumn get note => text().withDefault(const Constant(''))();
  TextColumn get merchant => text().nullable()();
  DateTimeColumn get occurredAt => dateTime()();

  /// Comma-separated tags.
  TextColumn get tags => text().withDefault(const Constant(''))();
  TextColumn get attachmentPath => text().nullable()();
  TextColumn get source =>
      textEnum<TxnSource>().withDefault(Constant(TxnSource.manual.name))();

  /// Original SMS / OCR / quick-add text, kept for audit.
  TextColumn get rawSourceText => text().nullable()();

  /// Bank reference / UPI ref no., used for dedupe.
  TextColumn get refNo => text().nullable()();
  IntColumn get linkedRecurringId => integer().nullable()();
  IntColumn get linkedDebtId => integer().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

/// Merchant/keyword → category/account mapping learned from corrections.
class Rules extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// Lowercased keyword matched against merchant / description.
  TextColumn get keyword => text().unique()();
  IntColumn get categoryId =>
      integer().nullable().references(Categories, #id)();
  IntColumn get accountId => integer().nullable().references(Accounts, #id)();
  IntColumn get hits => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// Small key/value store for preferences (app lock, etc.). Added in v2.
class AppSettings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

/// Monthly spending limit for a category, or overall when [categoryId] is
/// null. Added in v3.
class Budgets extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get categoryId =>
      integer().nullable().unique().references(Categories, #id)();
  IntColumn get amountPaise => integer()();

  /// Carry last month's unspent amount into this month.
  BoolColumn get rollover => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// A bill, subscription, EMI or income that repeats. Added in v3.
class Recurrings extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 60)();
  TextColumn get type => textEnum<TxnType>()();

  /// Expected amount; for variable bills (electricity) the last amount.
  IntColumn get amountPaise => integer()();
  BoolColumn get variableAmount =>
      boolean().withDefault(const Constant(false))();
  IntColumn get accountId => integer().references(Accounts, #id)();
  IntColumn get categoryId =>
      integer().nullable().references(Categories, #id)();
  DateTimeColumn get startDate => dateTime()();
  TextColumn get unit => textEnum<RepeatUnit>()();
  IntColumn get interval => integer().withDefault(const Constant(1))();
  TextColumn get autopay =>
      textEnum<AutopayKind>().withDefault(Constant(AutopayKind.none.name))();
  IntColumn get remindDaysBefore => integer().withDefault(const Constant(1))();
  TextColumn get status => textEnum<RecurringStatus>().withDefault(
    Constant(RecurringStatus.active.name),
  )();

  /// Date of the last occurrence marked paid; null = none yet.
  DateTimeColumn get lastPaid => dateTime().nullable()();
  TextColumn get note => text().withDefault(const Constant(''))();
}

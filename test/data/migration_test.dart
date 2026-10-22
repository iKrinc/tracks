import 'package:drift/drift.dart' hide isNull;
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tracks/data/app_database.dart';

import 'generated/schema.dart';

// Regenerate helpers after a schema change:
//   dart run drift_dev schema dump lib/data/app_database.dart drift_schemas/
//   dart run drift_dev schema generate drift_schemas/ test/data/generated/
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late SchemaVerifier verifier;

  setUpAll(() => verifier = SchemaVerifier(GeneratedHelper()));

  test('every version upgrades to the latest schema', () async {
    for (var from = 1; from < 3; from++) {
      final connection = await verifier.startAt(from);
      final db = AppDatabase(connection);
      await verifier.migrateAndValidate(db, 3);
      await db.close();
    }
  });

  test('v2 → v3 adds budgets and recurring, keeping data', () async {
    final schema = await verifier.schemaAt(2);
    schema.rawDatabase
      ..execute(
        "INSERT INTO accounts (id, name, type, color, icon) "
        "VALUES (1, 'Cash', 'cash', 0, 'payments')",
      )
      ..execute(
        "INSERT INTO app_settings (key, value) VALUES ('appLock', 'on')",
      );
    final db = AppDatabase(schema.newConnection());
    await verifier.migrateAndValidate(db, 3);
    expect(await db.getSetting('appLock'), 'on');
    await db.saveRecurring(
      RecurringsCompanion.insert(
        name: 'Rent',
        type: TxnType.expense,
        amountPaise: 1200000,
        accountId: 1,
        startDate: DateTime(2026, 1, 5),
        unit: RepeatUnit.month,
      ),
    );
    expect((await db.watchRecurrings().first).single.autopay, AutopayKind.none);
    await db.close();
  });

  test('v1 → v2 keeps existing accounts and transactions', () async {
    final schema = await verifier.schemaAt(1);
    schema.rawDatabase
      ..execute(
        "INSERT INTO accounts (id, name, type, color, icon) "
        "VALUES (1, 'Cash', 'cash', 0, 'payments')",
      )
      ..execute(
        'INSERT INTO transactions (type, amount_paise, account_id, occurred_at) '
        "VALUES ('expense', 2000, 1, 1792540800)",
      );

    final db = AppDatabase(schema.newConnection());
    await verifier.migrateAndValidate(db, 3);

    final txns = await db.select(db.transactions).get();
    expect(txns.single.amountPaise, 2000);
    expect((await db.select(db.accounts).get()).single.name, 'Cash');

    // The new table works.
    await db.setSetting('lock', 'on');
    expect(await db.getSetting('lock'), 'on');
    await db.close();
  });
}

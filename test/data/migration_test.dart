import 'package:drift/drift.dart' hide isNull;
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tracks/data/app_database.dart';
import 'package:tracks/data/default_data.dart';

import 'generated/schema.dart';

// Regenerate helpers after a schema change:
//   dart run drift_dev schema dump lib/data/app_database.dart drift_schemas/
//   dart run drift_dev schema generate drift_schemas/ test/data/generated/
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late SchemaVerifier verifier;

  setUpAll(() => verifier = SchemaVerifier(GeneratedHelper()));

  test('every version upgrades to the latest schema', () async {
    for (var from = 1; from < 6; from++) {
      final connection = await verifier.startAt(from);
      final db = AppDatabase(connection);
      await verifier.migrateAndValidate(db, 6);
      await db.close();
    }
  });

  test(
    'v5 → v6 adds funds; accounts and transactions keep their data',
    () async {
      final schema = await verifier.schemaAt(5);
      schema.rawDatabase
        ..execute(
          "INSERT INTO accounts (id, name, type, color, icon) "
          "VALUES (1, 'HDFC', 'bank', 0, 'account_balance')",
        )
        ..execute(
          "INSERT INTO transactions (id, type, amount_paise, account_id, "
          "occurred_at, source) VALUES (1, 'expense', 2000, 1, 1761300000, 'manual')",
        );
      final db = AppDatabase(schema.newConnection());
      await verifier.migrateAndValidate(db, 6);
      final a = (await db.select(db.accounts).get()).single;
      final t = (await db.select(db.transactions).get()).single;
      expect(a.fundId, isNull);
      expect(t.amountPaise, 2000);
      expect(t.fundId, isNull);
      final fund = await db
          .into(db.funds)
          .insert(FundsCompanion.insert(name: 'Marriage', color: 0));
      final f = (await db.select(db.funds).get()).single;
      expect(f.id, fund);
      expect(f.mode, FundMode.separate);
      await db.close();
    },
  );

  test('v4 → v5 adds card/loan fields, existing accounts untouched', () async {
    final schema = await verifier.schemaAt(4);
    schema.rawDatabase.execute(
      "INSERT INTO accounts (id, name, type, color, icon) "
      "VALUES (1, 'HDFC', 'bank', 0, 'account_balance')",
    );
    final db = AppDatabase(schema.newConnection());
    await verifier.migrateAndValidate(db, 6);
    final a = (await db.select(db.accounts).get()).single;
    expect(a.name, 'HDFC');
    expect(a.creditLimitPaise, isNull);
    await db.saveAccount(
      AccountsCompanion.insert(
        name: 'Ravi',
        type: AccountType.lent,
        color: 0,
        icon: 'person',
        principalPaise: const Value(200000),
      ),
    );
    expect((await db.select(db.accounts).get()).last.type, AccountType.lent);
    await db.close();
  });

  test('v3 → v4 recolours old default pastels, keeps custom colours', () async {
    final schema = await verifier.schemaAt(3);
    schema.rawDatabase
      ..execute(
        "INSERT INTO accounts (id, name, type, color, icon) VALUES "
        "(1, 'Cash', 'cash', ${0xFFCCF2DD}, 'payments'), "
        "(2, 'HDFC', 'bank', ${0xFFAECBFA}, 'account_balance'), "
        "(3, 'Mine', 'bank', ${0xFF123456}, 'account_balance')",
      )
      ..execute(
        "INSERT INTO categories (id, name, kind, color, icon) VALUES "
        "(1, 'Transport', 'expense', ${0xFFAECBFA}, 'directions_car')",
      );
    final db = AppDatabase(schema.newConnection());
    await verifier.migrateAndValidate(db, 6);
    final colours = {
      for (final a in await db.select(db.accounts).get()) a.name: a.color,
    };
    expect(colours['Cash'], 0xFFD6E7D2);
    expect(colours['HDFC'], defaultAccountColor);
    expect(colours['Mine'], 0xFF123456);
    final transport = (await db.select(db.categories).get()).single;
    expect(transport.color, 0xFFC9E7DD);
    await db.close();
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
    await verifier.migrateAndValidate(db, 6);
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
    await verifier.migrateAndValidate(db, 6);

    final txns = await db.select(db.transactions).get();
    expect(txns.single.amountPaise, 2000);
    expect((await db.select(db.accounts).get()).single.name, 'Cash');

    // The new table works.
    await db.setSetting('lock', 'on');
    expect(await db.getSetting('lock'), 'on');
    await db.close();
  });
}

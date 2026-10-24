import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tracks/app/providers.dart';
import 'package:tracks/app/theme.dart';
import 'package:tracks/data/app_database.dart';
import 'package:tracks/features/capture/domain/capture_draft.dart';
import 'package:tracks/features/capture/presentation/confirm_sheet.dart';

/// A learned rule must win over the keyword guess, even though rules load
/// a moment after the sheet opens.
void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(
      DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );
  });
  tearDown(() => db.close());

  Future<void> pumpSheet(WidgetTester tester, CaptureDraft draft) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          theme: buildTheme(Brightness.light),
          home: Scaffold(body: ConfirmSheet(draft: draft)),
        ),
      ),
    );
    // Let drift's streams deliver, then rebuild.
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump();
    }
  }

  bool chipSelected(WidgetTester tester, String label) => tester
      .widget<ChoiceChip>(
        find.ancestor(of: find.text(label), matching: find.byType(ChoiceChip)),
      )
      .selected;

  const draft = CaptureDraft(
    type: TxnType.expense,
    source: TxnSource.sms,
    amountPaise: 18000,
    note: 'CHAI POINT',
    merchant: 'CHAI POINT',
  );

  testWidgets('without a rule the keyword guess is used', (tester) async {
    await pumpSheet(tester, draft);
    expect(chipSelected(tester, 'Snacks & Chai'), isTrue);
    expect(find.textContaining('Always for'), findsNothing);
  });

  testWidgets('a learned rule fills category and account', (tester) async {
    late Category restaurants;
    late Account hdfc;
    await tester.runAsync(() async {
      restaurants = await (db.select(
        db.categories,
      )..where((c) => c.name.equals('Restaurants'))).getSingle();
      final id = await db
          .into(db.accounts)
          .insert(
            AccountsCompanion.insert(
              name: 'HDFC',
              type: AccountType.bank,
              color: 0xFFE8D9B5,
              icon: 'account_balance',
            ),
          );
      hdfc = await (db.select(
        db.accounts,
      )..where((a) => a.id.equals(id))).getSingle();
      await db.learnRule(
        'chai point',
        categoryId: restaurants.id,
        accountId: hdfc.id,
      );
    });
    await pumpSheet(tester, draft);
    expect(chipSelected(tester, 'Restaurants'), isTrue);
    expect(chipSelected(tester, 'HDFC'), isTrue);
  });
}

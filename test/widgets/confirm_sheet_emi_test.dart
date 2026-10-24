import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tracks/app/providers.dart';
import 'package:tracks/app/theme.dart';
import 'package:tracks/data/app_database.dart';
import 'package:tracks/features/capture/domain/capture_draft.dart';
import 'package:tracks/features/capture/presentation/confirm_sheet.dart';

/// Paying an EMI books the interest as spending and only the principal
/// against the loan.
void main() {
  late AppDatabase db;
  late int cash;
  late int loan;

  setUp(() async {
    db = AppDatabase(
      DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );
  });
  tearDown(() => db.close());

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump();
    }
  }

  Future<void> open(WidgetTester tester, {int paymentPaise = 1050090}) async {
    await tester.runAsync(() async {
      cash = (await db.select(db.accounts).get()).first.id;
      loan = await db
          .into(db.accounts)
          .insert(
            AccountsCompanion.insert(
              name: 'Home loan',
              type: AccountType.loan,
              color: 0xFFE8D9B5,
              icon: 'account_balance',
              // ₹5,00,000 owed at 9.5%.
              openingBalancePaise: const Value(-50000000),
              interestRateBp: const Value(950),
            ),
          );
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          theme: buildTheme(Brightness.light),
          home: Scaffold(
            body: ConfirmSheet(
              draft: CaptureDraft(
                type: TxnType.transfer,
                source: TxnSource.manual,
                amountPaise: paymentPaise,
                accountId: cash,
                toAccountId: loan,
              ),
            ),
          ),
        ),
      ),
    );
    await settle(tester);
  }

  Future<List<Transaction>> saveAndRead(WidgetTester tester) async {
    await tester.ensureVisible(find.text('Save'));
    await tester.tap(find.text('Save'));
    await settle(tester);
    return (await tester.runAsync(() => db.select(db.transactions).get()))!;
  }

  testWidgets('interest becomes an expense, principal a transfer', (
    tester,
  ) async {
    await open(tester);
    expect(find.textContaining('interest at 9.5%'), findsOneWidget);
    final saved = await saveAndRead(tester);
    final interest = saved.singleWhere((t) => t.type == TxnType.expense);
    final principal = saved.singleWhere((t) => t.type == TxnType.transfer);
    expect(interest.amountPaise, 395833);
    expect(interest.categoryId, isNotNull);
    expect(principal.amountPaise, 1050090 - 395833);
    expect(principal.toAccountId, loan);
    expect(interest.amountPaise + principal.amountPaise, 1050090);
  });

  testWidgets('a payment smaller than the interest is all interest', (
    tester,
  ) async {
    await open(tester, paymentPaise: 100000);
    final saved = await saveAndRead(tester);
    expect(saved.single.type, TxnType.expense);
    expect(saved.single.amountPaise, 100000);
  });

  testWidgets('turning the split off books it all against the loan', (
    tester,
  ) async {
    await open(tester);
    await tester.ensureVisible(find.text('Split out interest'));
    await tester.tap(find.text('Split out interest'));
    await tester.pump();
    final saved = await saveAndRead(tester);
    expect(saved.single.type, TxnType.transfer);
    expect(saved.single.amountPaise, 1050090);
  });
}

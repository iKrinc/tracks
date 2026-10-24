import 'package:flutter_test/flutter_test.dart';
import 'package:tracks/data/tables.dart';
import 'package:tracks/features/funds/domain/fund_math.dart';

const cash = 1;
const bank = 2;
const weddingPot = 10; // Marriage fund's account
const tripPot = 20; // Goa trip fund's account
const marriage = 100;
const trip = 200;

FundTxn t(
  TxnType type,
  int paise, {
  int account = bank,
  int? to,
  int? fund,
  int? category,
}) => (
  type: type,
  accountId: account,
  toAccountId: to,
  fundId: fund,
  paise: paise,
  categoryId: category,
);

void main() {
  group('separateAccountIds', () {
    test('only accounts of funds kept separate', () {
      final ids = separateAccountIds(
        accounts: [
          (id: cash, fundId: null),
          (id: weddingPot, fundId: marriage),
          (id: tripPot, fundId: trip),
        ],
        funds: [
          (id: marriage, mode: FundMode.separate),
          (id: trip, mode: FundMode.merged),
        ],
      );
      expect(ids, {weddingPot});
    });
  });

  group('countsInMain', () {
    const separate = {weddingPot};

    test('spending and income on a separate fund stay out', () {
      expect(
        countsInMain(t(TxnType.expense, 1, account: weddingPot), separate),
        isFalse,
      );
      expect(
        countsInMain(t(TxnType.income, 1, account: weddingPot), separate),
        isFalse,
      );
    });

    test('moving money in or out of a fund shows in main as a transfer', () {
      expect(
        countsInMain(
          t(TxnType.transfer, 1, account: bank, to: weddingPot),
          separate,
        ),
        isTrue,
      );
      expect(
        countsInMain(
          t(TxnType.transfer, 1, account: weddingPot, to: bank),
          separate,
        ),
        isTrue,
      );
    });

    test('moves inside the fund stay in the fund', () {
      expect(
        countsInMain(
          t(TxnType.transfer, 1, account: weddingPot, to: weddingPot + 1),
          {weddingPot, weddingPot + 1},
        ),
        isFalse,
      );
    });

    test('a main-account spend tagged to the fund is still main money', () {
      expect(
        countsInMain(
          t(TxnType.expense, 1, account: bank, fund: marriage),
          separate,
        ),
        isTrue,
      );
    });

    test('a merged fund counts everywhere', () {
      expect(
        countsInMain(t(TxnType.expense, 1, account: tripPot), separate),
        isTrue,
      );
    });
  });

  group('summarizeFund', () {
    final txns = [
      // Set aside ₹2,00,000 from the bank.
      t(TxnType.transfer, 20000000, account: bank, to: weddingPot),
      // Gifts received straight into the fund.
      t(TxnType.income, 5000000, account: weddingPot),
      // Catering and hall from the fund.
      t(TxnType.expense, 9000000, account: weddingPot, category: 1),
      t(TxnType.expense, 6000000, account: weddingPot, category: 2),
      // Leftover partly moved back.
      t(TxnType.transfer, 1000000, account: weddingPot, to: bank),
      // Unrelated.
      t(TxnType.expense, 999, account: cash),
      t(TxnType.expense, 888, account: tripPot),
    ];

    test('money in, money out and what is left against the budget', () {
      final s = summarizeFund(
        fundId: marriage,
        fundAccounts: {weddingPot},
        txns: txns,
        inFundPaise: 9000000,
        budgetPaise: 25000000,
      );
      expect(s.spentPaise, 15000000);
      expect(s.receivedPaise, 5000000);
      expect(s.movedInPaise, 20000000);
      expect(s.movedOutPaise, 1000000);
      expect(s.inFundPaise, 9000000);
      expect(s.budgetLeftPaise, 10000000);
      expect(s.percentOfBudget, 60);
      expect(s.count, 5);
    });

    test('no budget: nothing left to compare', () {
      final s = summarizeFund(
        fundId: marriage,
        fundAccounts: {weddingPot},
        txns: txns,
        inFundPaise: 0,
      );
      expect(s.budgetLeftPaise, isNull);
      expect(s.percentOfBudget, isNull);
    });

    test('belongsToFund picks its own accounts only', () {
      final mine = txns
          .where((x) => belongsToFund(x, marriage, {weddingPot}))
          .length;
      expect(mine, 5);
    });
  });
}

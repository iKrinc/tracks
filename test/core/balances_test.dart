import 'package:flutter_test/flutter_test.dart';
import 'package:tracks/data/tables.dart';
import 'package:tracks/features/accounts/domain/balances.dart';

void main() {
  test('opening + income − expense, transfers move between accounts', () {
    final b = computeBalances(
      openings: {1: 100000, 2: 5000000, 3: 0},
      totals: const [
        (accountId: 1, toAccountId: null, type: TxnType.expense, sum: 2000),
        (accountId: 2, toAccountId: null, type: TxnType.income, sum: 5000000),
        (accountId: 2, toAccountId: 1, type: TxnType.transfer, sum: 200000),
        (accountId: 3, toAccountId: null, type: TxnType.expense, sum: 149900),
        (accountId: 2, toAccountId: 3, type: TxnType.transfer, sum: 149900),
      ],
    );
    expect(b[1], 100000 - 2000 + 200000);
    expect(b[2], 5000000 + 5000000 - 200000 - 149900);
    // A credit card goes negative when spent on and back to 0 when paid.
    expect(b[3], 0);
  });

  test('accounts without transactions keep their opening balance', () {
    expect(computeBalances(openings: {7: 1234}, totals: const []), {7: 1234});
  });

  test('totals for unknown (deleted/archived) accounts are ignored', () {
    final b = computeBalances(
      openings: {1: 0},
      totals: const [
        (accountId: 9, toAccountId: 1, type: TxnType.transfer, sum: 500),
      ],
    );
    expect(b, {1: 500});
  });

  test('net worth sums balances', () {
    expect(netWorth({1: 1000, 2: -400}), 600);
  });
}

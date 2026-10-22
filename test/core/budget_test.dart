import 'package:flutter_test/flutter_test.dart';
import 'package:tracks/data/tables.dart';
import 'package:tracks/features/budgets/domain/budget_math.dart';

void main() {
  test('levels at 80% and 100%', () {
    expect(
      budgetProgress(limitPaise: 1000000, spentPaise: 500000).level,
      BudgetLevel.ok,
    );
    expect(
      budgetProgress(limitPaise: 1000000, spentPaise: 800000).level,
      BudgetLevel.warning,
    );
    expect(
      budgetProgress(limitPaise: 1000000, spentPaise: 1000000).level,
      BudgetLevel.over,
    );
  });

  test('remaining can go negative; percent is integer', () {
    final p = budgetProgress(limitPaise: 1000000, spentPaise: 1234500);
    expect(p.remainingPaise, -234500);
    expect(p.percent, 123);
  });

  test('rollover adds last period unspent, never debt', () {
    expect(
      budgetProgress(
        limitPaise: 1000000,
        spentPaise: 1100000,
        rolloverPaise: 200000,
      ).level,
      BudgetLevel.warning,
    );
    expect(rolloverFrom(limitPaise: 1000000, spentPaise: 700000), 300000);
    expect(rolloverFrom(limitPaise: 1000000, spentPaise: 1300000), 0);
  });

  test('daily allowance for the rest of the month', () {
    // ₹6,000 left, 10 days left including today → ₹600 a day.
    expect(
      dailyAllowance(remainingPaise: 600000, today: DateTime(2026, 10, 22)),
      60000,
    );
    expect(
      dailyAllowance(remainingPaise: -5, today: DateTime(2026, 10, 22)),
      0,
    );
  });

  test('zero limit never divides by zero', () {
    expect(
      budgetProgress(limitPaise: 0, spentPaise: 100).level,
      BudgetLevel.over,
    );
  });

  group('spentInMonth', () {
    final m = DateTime(2026, 10);
    final txns = [
      (
        type: TxnType.expense,
        amountPaise: 2000,
        occurredAt: DateTime(2026, 10, 2),
        categoryId: 3,
      ),
      (
        type: TxnType.expense,
        amountPaise: 25000,
        occurredAt: DateTime(2026, 10, 3),
        categoryId: 1,
      ),
      (
        type: TxnType.expense,
        amountPaise: 50000,
        occurredAt: DateTime(2026, 10, 4),
        categoryId: 2,
      ),
      (
        type: TxnType.expense,
        amountPaise: 99999,
        occurredAt: DateTime(2026, 9, 30),
        categoryId: 1,
      ),
      (
        type: TxnType.income,
        amountPaise: 5000000,
        occurredAt: DateTime(2026, 10, 1),
        categoryId: 20,
      ),
      (
        type: TxnType.transfer,
        amountPaise: 1000,
        occurredAt: DateTime(2026, 10, 1),
        categoryId: null,
      ),
    ];
    const parents = {1: null, 2: null, 3: 1, 20: null};

    test('overall budget: every expense this month', () {
      expect(spentInMonth(txns, m, null, parentOf: parents), 77000);
    });

    test('category budget includes its subcategories', () {
      expect(spentInMonth(txns, m, 1, parentOf: parents), 27000);
      expect(spentInMonth(txns, m, 2, parentOf: parents), 50000);
    });

    test('other months are excluded', () {
      expect(
        spentInMonth(txns, DateTime(2026, 9), 1, parentOf: parents),
        99999,
      );
    });
  });
}

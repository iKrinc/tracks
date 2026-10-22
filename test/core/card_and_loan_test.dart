import 'package:flutter_test/flutter_test.dart';
import 'package:tracks/features/accounts/domain/credit_card.dart';
import 'package:tracks/features/accounts/domain/loan.dart';

void main() {
  group('cardCycle', () {
    test('statement on the 15th, due on the 5th of next month', () {
      final c = cardCycle(
        statementDay: 15,
        dueDay: 5,
        today: DateTime(2026, 10, 22),
      );
      expect(c.lastStatement, DateTime(2026, 10, 15));
      expect(c.nextStatement, DateTime(2026, 11, 15));
      expect(c.due, DateTime(2026, 11, 5));
    });

    test('on statement day the new statement is today', () {
      final c = cardCycle(
        statementDay: 15,
        dueDay: 5,
        today: DateTime(2026, 10, 15),
      );
      expect(c.lastStatement, DateTime(2026, 10, 15));
    });

    test('before statement day the last statement was last month', () {
      final c = cardCycle(
        statementDay: 15,
        dueDay: 5,
        today: DateTime(2026, 10, 10),
      );
      expect(c.lastStatement, DateTime(2026, 9, 15));
      expect(c.due, DateTime(2026, 10, 5));
    });

    test('due later in the same month as the statement', () {
      final c = cardCycle(
        statementDay: 1,
        dueDay: 20,
        today: DateTime(2026, 10, 22),
      );
      expect(c.lastStatement, DateTime(2026, 10, 1));
      expect(c.due, DateTime(2026, 10, 20));
    });

    test('statement day 31 clamps in short months', () {
      final c = cardCycle(
        statementDay: 31,
        dueDay: 20,
        today: DateTime(2026, 3, 1),
      );
      expect(c.lastStatement, DateTime(2026, 2, 28));
      expect(c.nextStatement, DateTime(2026, 3, 31));
    });
  });

  group('cardStatus', () {
    final cycle = cardCycle(
      statementDay: 15,
      dueDay: 5,
      today: DateTime(2026, 10, 22),
    );
    // Card balance movements: negative = spend, positive = payment/refund.
    final moves = [
      (at: DateTime(2026, 9, 20), paise: -300000), // last cycle spend
      (at: DateTime(2026, 10, 10), paise: -200000), // last cycle spend
      (at: DateTime(2026, 10, 18), paise: -50000), // this cycle (unbilled)
      (at: DateTime(2026, 10, 20), paise: 100000), // payment after statement
    ];

    test('billed, unbilled, paid and what is still due', () {
      final s = cardStatus(
        moves: moves,
        openingPaise: 0,
        cycle: cycle,
        limitPaise: 10000000,
      );
      expect(s.billedPaise, 500000);
      expect(s.paidSinceStatementPaise, 100000);
      expect(s.dueNowPaise, 400000);
      expect(s.unbilledPaise, 50000);
      expect(s.outstandingPaise, 450000);
      expect(s.utilisationBp, 450); // 4.5% of ₹1 lakh
      expect(s.minimumDuePaise, 20000); // 5% of what's due, at least ₹200
    });

    test('fully paid statement owes nothing now', () {
      final s = cardStatus(
        moves: [...moves, (at: DateTime(2026, 10, 21), paise: 400000)],
        openingPaise: 0,
        cycle: cycle,
        limitPaise: 10000000,
      );
      expect(s.dueNowPaise, 0);
      expect(s.minimumDuePaise, 0);
    });
  });

  group('loan', () {
    test('EMI for a standard reducing-balance loan', () {
      // ₹5,00,000 at 9.5% for 60 months → ₹10,500.93 (calculators show 10,501).
      expect(
        emiPaise(principalPaise: 50000000, rateBp: 950, months: 60),
        1050093,
      );
      // Zero interest: principal / months.
      expect(emiPaise(principalPaise: 1200000, rateBp: 0, months: 12), 100000);
    });

    test('progress and months left from what is still owed', () {
      final p = loanProgress(
        principalPaise: 50000000,
        outstandingPaise: 30000000,
        emiPaise: 1050090,
        rateBp: 950,
      );
      expect(p.paidPaise, 20000000);
      expect(p.percentPaid, 40);
      expect(p.monthsLeft, 33);
    });

    test('IOUs without EMI still show progress', () {
      final p = loanProgress(principalPaise: 200000, outstandingPaise: 50000);
      expect(p.percentPaid, 75);
      expect(p.monthsLeft, isNull);
    });
  });
}

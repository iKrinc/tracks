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

    test('a fresh loan paid by its exact EMI has its full tenure left', () {
      // Floating-point drift made 24.0000001 ceil to 25.
      final emi = emiPaise(principalPaise: 12000000, rateBp: 1050, months: 24);
      final p = loanProgress(
        principalPaise: 12000000,
        outstandingPaise: 12000000,
        emiPaise: emi,
        rateBp: 1050,
      );
      expect(p.monthsLeft, 24);
    });

    test('IOUs without EMI still show progress', () {
      final p = loanProgress(principalPaise: 200000, outstandingPaise: 50000);
      expect(p.percentPaid, 75);
      expect(p.monthsLeft, isNull);
    });
  });

  group('splitEmi', () {
    test(
      'a month of interest on what is still owed, the rest is principal',
      () {
        // ₹5,00,000 at 9.5%: interest ₹3,958.33, EMI ₹10,500.90.
        final s = splitEmi(
          paymentPaise: 1050090,
          outstandingPaise: 50000000,
          rateBp: 950,
        );
        expect(s.interestPaise, 395833);
        expect(s.principalPaise, 1050090 - 395833);
      },
    );

    test('interest falls as the loan is repaid', () {
      final early = splitEmi(
        paymentPaise: 1050090,
        outstandingPaise: 50000000,
        rateBp: 950,
      );
      final late = splitEmi(
        paymentPaise: 1050090,
        outstandingPaise: 5000000,
        rateBp: 950,
      );
      expect(late.interestPaise, lessThan(early.interestPaise));
      expect(late.principalPaise, greaterThan(early.principalPaise));
    });

    test('no rate (or nothing owed) means it is all principal', () {
      expect(splitEmi(paymentPaise: 500000, outstandingPaise: 9000000), (
        principalPaise: 500000,
        interestPaise: 0,
      ));
      expect(
        splitEmi(paymentPaise: 500000, outstandingPaise: 0, rateBp: 1200),
        (principalPaise: 500000, interestPaise: 0),
      );
    });

    test('a payment below the interest is all interest', () {
      final s = splitEmi(
        paymentPaise: 100000,
        outstandingPaise: 50000000,
        rateBp: 1200,
      );
      expect(s, (principalPaise: 0, interestPaise: 100000));
    });

    test('parts always add up to the payment', () {
      for (final owed in [1, 999, 123456789, 50000000000]) {
        for (final bp in [1, 799, 950, 3600]) {
          final s = splitEmi(
            paymentPaise: 777777,
            outstandingPaise: owed,
            rateBp: bp,
          );
          expect(s.principalPaise + s.interestPaise, 777777);
          expect(s.principalPaise, greaterThanOrEqualTo(0));
        }
      }
    });
  });
}

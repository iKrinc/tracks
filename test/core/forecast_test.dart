import 'package:flutter_test/flutter_test.dart';
import 'package:tracks/data/tables.dart';
import 'package:tracks/features/insights/domain/forecast.dart';

const cash = 1;
const bank = 2;
const card = 3;
const loan = 4;
const liquid = {cash, bank};

ForecastBill bill(
  String name,
  TxnType type,
  int paise,
  DateTime start, {
  int account = bank,
  int? to,
  RepeatUnit unit = RepeatUnit.month,
  DateTime? lastPaid,
}) => (
  id: name.hashCode,
  name: name,
  type: type,
  amountPaise: paise,
  accountId: account,
  toAccountId: to,
  start: start,
  unit: unit,
  interval: 1,
  lastPaid: lastPaid,
);

void main() {
  final today = DateTime(2026, 10, 24);

  group('forecastCashflow', () {
    test('runs to the day before payday and says what is left', () {
      final f = forecastCashflow(
        today: today,
        liquidPaise: 3000000, // ₹30,000
        liquidAccounts: liquid,
        bills: [
          bill('Salary', TxnType.income, 8000000, DateTime(2026, 11, 1)),
          bill('Rent', TxnType.expense, 1200000, DateTime(2026, 10, 28)),
          bill('Netflix', TxnType.expense, 64900, DateTime(2026, 10, 26)),
        ],
      );
      expect(f.payday, DateTime(2026, 11, 1));
      expect(f.end, DateTime(2026, 10, 31));
      expect(f.days, 7);
      expect(f.events.map((e) => e.name), ['Netflix', 'Rent']);
      expect(f.endPaise, 3000000 - 64900 - 1200000);
    });

    test('daily spending comes off every day, and sets the allowance', () {
      final f = forecastCashflow(
        today: today,
        liquidPaise: 1000000,
        liquidAccounts: liquid,
        dailySpendPaise: 50000,
        bills: [
          bill('Salary', TxnType.income, 8000000, DateTime(2026, 11, 1)),
          bill('Rent', TxnType.expense, 600000, DateTime(2026, 10, 28)),
        ],
      );
      // 7 days to payday: ₹10,000 − ₹6,000 rent − 7 × ₹500.
      expect(f.endPaise, 1000000 - 600000 - 7 * 50000);
      // ₹4,000 free after bills, over 7 days.
      expect(f.dailyAllowancePaise, 400000 ~/ 7);
      expect(f.billsExceedMoney, isFalse);
    });

    test('finds the lowest point and when it happens', () {
      final f = forecastCashflow(
        today: today,
        liquidPaise: 500000,
        liquidAccounts: liquid,
        bills: [
          bill('Salary', TxnType.income, 8000000, DateTime(2026, 11, 5)),
          bill('Rent', TxnType.expense, 900000, DateTime(2026, 10, 28)),
          bill(
            'Refund',
            TxnType.income,
            100000,
            DateTime(2026, 10, 30),
            account: cash,
          ),
        ],
      );
      expect(f.lowestPaise, 500000 - 900000);
      expect(f.lowestOn, DateTime(2026, 10, 28));
      expect(f.goesNegative, isTrue);
      expect(f.dailyAllowancePaise, 0);
      expect(f.billsExceedMoney, isTrue);
    });

    test('without a salary bill it looks 30 days ahead', () {
      final f = forecastCashflow(
        today: today,
        liquidPaise: 100000,
        liquidAccounts: liquid,
        bills: [bill('Gym', TxnType.expense, 150000, DateTime(2026, 11, 10))],
      );
      expect(f.payday, isNull);
      expect(f.end, DateTime(2026, 11, 23));
      expect(f.events.single.date, DateTime(2026, 11, 10));
    });

    test('weekly bills repeat inside the window', () {
      final f = forecastCashflow(
        today: today,
        liquidPaise: 0,
        liquidAccounts: liquid,
        bills: [
          bill(
            'Milk',
            TxnType.expense,
            30000,
            DateTime(2026, 10, 25),
            unit: RepeatUnit.week,
          ),
        ],
      );
      expect(f.events.length, 5); // 25 Oct, 1, 8, 15, 22 Nov
    });

    test('an overdue bill is counted today and flagged', () {
      final f = forecastCashflow(
        today: today,
        liquidPaise: 100000,
        liquidAccounts: liquid,
        bills: [
          bill(
            'Electricity',
            TxnType.expense,
            180000,
            DateTime(2026, 1, 20),
            lastPaid: DateTime(2026, 9, 20),
          ),
        ],
      );
      final first = f.events.first;
      expect(first.date, today);
      expect(first.overdue, isTrue);
    });

    test('an overdue income is not counted (it may have arrived already)', () {
      final f = forecastCashflow(
        today: today,
        liquidPaise: 100000,
        liquidAccounts: liquid,
        bills: [
          bill(
            'Rent in',
            TxnType.income,
            1500000,
            DateTime(2026, 1, 10),
            lastPaid: DateTime(2026, 9, 10),
          ),
        ],
      );
      // Next one, 10 Nov, is the payday; nothing before it.
      expect(f.payday, DateTime(2026, 11, 10));
      expect(f.events, isEmpty);
      expect(f.endPaise, 100000);
    });

    test('only money leaving or entering cash/bank counts', () {
      final f = forecastCashflow(
        today: today,
        liquidPaise: 1000000,
        liquidAccounts: liquid,
        bills: [
          // EMI from the bank into a loan: money leaves.
          bill(
            'Bike EMI',
            TxnType.transfer,
            556512,
            DateTime(2026, 11, 5),
            to: loan,
          ),
          // Bank to cash: still your money.
          bill(
            'ATM',
            TxnType.transfer,
            200000,
            DateTime(2026, 11, 1),
            to: cash,
          ),
          // Charged to the card: paid later through the card bill.
          bill(
            'Spotify',
            TxnType.expense,
            11900,
            DateTime(2026, 11, 2),
            account: card,
          ),
        ],
      );
      expect(f.events.map((e) => e.name), ['Bike EMI']);
      expect(f.events.single.deltaPaise, -556512);
    });

    test('one-off dues such as a card bill are included', () {
      final f = forecastCashflow(
        today: today,
        liquidPaise: 5000000,
        liquidAccounts: liquid,
        bills: const [],
        oneOffs: [
          (
            date: DateTime(2026, 11, 5),
            name: 'ICICI Card bill',
            paise: 2500000,
          ),
        ],
      );
      expect(f.events.single.deltaPaise, -2500000);
      expect(f.endPaise, 2500000);
    });

    test('a payday more than 45 days away is not used', () {
      final f = forecastCashflow(
        today: today,
        liquidPaise: 0,
        liquidAccounts: liquid,
        bills: [
          bill(
            'Bonus',
            TxnType.income,
            9000000,
            DateTime(2027, 3, 1),
            unit: RepeatUnit.year,
          ),
        ],
      );
      expect(f.payday, isNull);
    });
  });

  group('averageDailySpend', () {
    test('everyday spending only: no bills, transfers, income or cards', () {
      final avg = averageDailySpend(
        [
          (
            type: TxnType.expense,
            accountId: cash,
            paise: 30000,
            at: DateTime(2026, 10, 20),
            notEveryday: false,
          ),
          (
            type: TxnType.expense,
            accountId: bank,
            paise: 30000,
            at: DateTime(2026, 9, 1),
            notEveryday: false,
          ),
          (
            type: TxnType.expense,
            accountId: bank,
            paise: 1200000,
            at: DateTime(2026, 10, 1),
            notEveryday: true,
          ),
          (
            type: TxnType.income,
            accountId: bank,
            paise: 8000000,
            at: DateTime(2026, 10, 1),
            notEveryday: false,
          ),
          (
            type: TxnType.transfer,
            accountId: bank,
            paise: 50000,
            at: DateTime(2026, 10, 2),
            notEveryday: false,
          ),
          (
            type: TxnType.expense,
            accountId: card,
            paise: 99900,
            at: DateTime(2026, 10, 3),
            notEveryday: false,
          ),
          // Older than the window.
          (
            type: TxnType.expense,
            accountId: cash,
            paise: 999999,
            at: DateTime(2026, 6, 1),
            notEveryday: false,
          ),
        ],
        today: today,
        liquidAccounts: liquid,
      );
      expect(avg, 60000 ~/ 60);
    });

    test('a new user with a few days of history averages over those days', () {
      final avg = averageDailySpend(
        [
          (
            type: TxnType.expense,
            accountId: cash,
            paise: 40000,
            at: DateTime(2026, 10, 21),
            notEveryday: false,
          ),
        ],
        today: today,
        liquidAccounts: liquid,
      );
      expect(avg, 40000 ~/ 4); // 21 → 24 Oct
    });

    test('no history, no estimate', () {
      expect(
        averageDailySpend(const [], today: today, liquidAccounts: liquid),
        0,
      );
    });
  });
}

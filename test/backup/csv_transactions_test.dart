import 'package:flutter_test/flutter_test.dart';
import 'package:tracks/data/tables.dart';
import 'package:tracks/features/backup/domain/csv_transactions.dart';

void main() {
  group('export', () {
    test('header + rows, plain rupee amounts, quoted when needed', () {
      final csv = transactionsToCsv([
        CsvTxnRow(
          date: DateTime(2026, 10, 21, 9, 5),
          type: TxnType.expense,
          amountPaise: 123450,
          account: 'HDFC',
          category: 'Food & Dining',
          note: 'lunch, with team',
          merchant: 'SWIGGY',
          tags: 'work',
          ref: '629412345678',
        ),
        CsvTxnRow(
          date: DateTime(2026, 10, 20),
          type: TxnType.transfer,
          amountPaise: 200000,
          account: 'SBI',
          toAccount: 'Cash',
        ),
      ]);
      final lines = csv.trim().split('\n');
      expect(lines[0], csvHeaders.join(','));
      expect(
        lines[1],
        '2026-10-21 09:05,expense,1234.50,HDFC,,Food & Dining,'
        '"lunch, with team",SWIGGY,work,629412345678',
      );
      expect(lines[2], '2026-10-20 00:00,transfer,2000.00,SBI,Cash,,,,,');
    });

    test('export then parse round-trips', () {
      final rows = [
        CsvTxnRow(
          date: DateTime(2026, 1, 2, 3, 4),
          type: TxnType.income,
          amountPaise: 5000000,
          account: 'HDFC',
          category: 'Salary',
          note: 'Oct "bonus" incl.',
        ),
      ];
      final table = decodeCsv(transactionsToCsv(rows));
      final mapping = guessMapping(table.first);
      final parsed = parseCsvRows(table, mapping);
      expect(parsed.errors, isEmpty);
      final r = parsed.rows.single;
      expect(r.date, DateTime(2026, 1, 2, 3, 4));
      expect(r.type, TxnType.income);
      expect(r.amountPaise, 5000000);
      expect(r.note, 'Oct "bonus" incl.');
      expect(r.category, 'Salary');
    });
  });

  group('guessMapping', () {
    test('own headers', () {
      final m = guessMapping(csvHeaders);
      expect(m[CsvField.date], 0);
      expect(m[CsvField.toAccount], 4);
      expect(m[CsvField.ref], 9);
    });

    test('Money Manager style headers', () {
      final m = guessMapping([
        'Period',
        'Accounts',
        'Category',
        'Subcategory',
        'Note',
        'INR',
        'Income/Expense',
        'Description',
      ]);
      expect(m[CsvField.date], 0);
      expect(m[CsvField.account], 1);
      expect(m[CsvField.category], 2);
      expect(m[CsvField.note], 4);
      expect(m[CsvField.amount], 5);
      expect(m[CsvField.type], 6);
    });

    test('bank statement style headers', () {
      final m = guessMapping(['Txn Date', 'Narration', 'Withdrawal Amt']);
      expect(m[CsvField.date], 0);
      expect(m[CsvField.note], 1);
      expect(m[CsvField.amount], 2);
    });
  });

  group('parseCsvRows', () {
    final mapping = {
      CsvField.date: 0,
      CsvField.amount: 1,
      CsvField.type: 2,
      CsvField.note: 3,
    };

    test('date formats', () {
      for (final (s, d) in [
        ('2026-10-21', DateTime(2026, 10, 21)),
        ('2026-10-21 18:30', DateTime(2026, 10, 21, 18, 30)),
        ('21/10/2026', DateTime(2026, 10, 21)),
        ('21-10-2026 07:05', DateTime(2026, 10, 21, 7, 5)),
        ('21/10/26', DateTime(2026, 10, 21)),
        ('21 Oct 2026', DateTime(2026, 10, 21)),
      ]) {
        expect(parseFlexibleDate(s), d, reason: s);
      }
      expect(parseFlexibleDate('31/02/2026'), isNull);
      expect(parseFlexibleDate('yesterday'), isNull);
    });

    test('type words and amount signs', () {
      final r = parseCsvRows([
        ['Date', 'Amount', 'Type', 'Note'],
        ['2026-10-01', '₹1,500.00', 'Exp.', 'a'],
        ['2026-10-01', '50000', 'Income', 'b'],
        ['2026-10-01', '-250', '', 'c'],
        ['2026-10-01', '300', '', 'd'],
        ['2026-10-01', '(99.50)', 'debit', 'e'],
      ], mapping);
      expect(r.errors, isEmpty);
      expect(r.rows.map((x) => x.type), [
        TxnType.expense,
        TxnType.income,
        TxnType.expense,
        TxnType.income,
        TxnType.expense,
      ]);
      expect(r.rows.map((x) => x.amountPaise), [
        150000,
        5000000,
        25000,
        30000,
        9950,
      ]);
    });

    test('bad rows are skipped with a reason, good ones kept', () {
      final r = parseCsvRows([
        ['Date', 'Amount', 'Type', 'Note'],
        ['not a date', '10', 'expense', 'x'],
        ['2026-10-01', 'ten', 'expense', 'y'],
        ['2026-10-01', '0', 'expense', 'z'],
        ['2026-10-01', '10', 'expense', 'ok'],
      ], mapping);
      expect(r.rows.single.note, 'ok');
      expect(r.errors, [
        'Row 2: date "not a date" not recognised',
        'Row 3: amount "ten" is not a number',
        'Row 4: amount is zero',
      ]);
    });

    test('missing account uses the default', () {
      final r = parseCsvRows(
        [
          ['Date', 'Amount', 'Type', 'Note'],
          ['2026-10-01', '10', 'expense', 'x'],
        ],
        mapping,
        defaultAccount: 'Cash',
      );
      expect(r.rows.single.account, 'Cash');
    });
  });
}

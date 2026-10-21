import 'package:flutter_test/flutter_test.dart';
import 'package:tracks/features/capture/domain/quick_add_parser.dart';

void main() {
  // Wednesday, 21 Oct 2026, mid-afternoon.
  final now = DateTime(2026, 10, 21, 15, 30);
  QuickAddResult? p(String s) => parseQuickAdd(s, now: now);

  group('CLAUDE.md examples', () {
    test('chai 20', () {
      final r = p('chai 20')!;
      expect(r.kind, QuickAddKind.expense);
      expect(r.amountPaise, 2000);
      expect(r.description, 'chai');
      expect(r.accountHint, isNull);
      expect(r.date, DateTime(2026, 10, 21));
    });

    test('chai 20 gpay', () {
      final r = p('chai 20 gpay')!;
      expect(r.amountPaise, 2000);
      expect(r.description, 'chai');
      expect(r.accountHint, 'gpay');
    });

    test('petrol 500 card', () {
      final r = p('petrol 500 card')!;
      expect(r.kind, QuickAddKind.expense);
      expect(r.amountPaise, 50000);
      expect(r.description, 'petrol');
      expect(r.accountHint, 'card');
    });

    test('salary 50000 income', () {
      final r = p('salary 50000 income')!;
      expect(r.kind, QuickAddKind.income);
      expect(r.amountPaise, 5000000);
      expect(r.description, 'salary');
    });

    test('lent 2000 to ravi', () {
      final r = p('lent 2000 to ravi')!;
      expect(r.kind, QuickAddKind.lent);
      expect(r.amountPaise, 200000);
      expect(r.person, 'ravi');
      expect(r.description, isEmpty);
    });

    test('rent 12000 hdfc yesterday', () {
      final r = p('rent 12000 hdfc yesterday')!;
      expect(r.kind, QuickAddKind.expense);
      expect(r.amountPaise, 1200000);
      expect(r.description, 'rent');
      expect(r.accountHint, 'hdfc');
      expect(r.date, DateTime(2026, 10, 20));
    });
  });

  group('kinds', () {
    test('borrowed from a person', () {
      final r = p('borrowed 500 from Asha')!;
      expect(r.kind, QuickAddKind.borrowed);
      expect(r.person, 'Asha');
    });

    test('income keywords', () {
      expect(p('received 300 from client')!.kind, QuickAddKind.income);
      expect(p('refund 199 amazon')!.kind, QuickAddKind.income);
      expect(p('cashback 25 paytm')!.kind, QuickAddKind.income);
    });

    test('received from a person keeps the person', () {
      final r = p('received 300 from ravi')!;
      expect(r.person, 'ravi');
    });

    test('transfer between accounts', () {
      final r = p('transfer 5000 hdfc to cash')!;
      expect(r.kind, QuickAddKind.transfer);
      expect(r.amountPaise, 500000);
      expect(r.accountHint, 'hdfc');
      expect(r.toAccountHint, 'cash');
    });

    test('atm withdrawal is a transfer to cash', () {
      final r = p('atm 2000 sbi')!;
      expect(r.kind, QuickAddKind.transfer);
      expect(r.accountHint, 'sbi');
      expect(r.toAccountHint, 'cash');
    });
  });

  group('amounts', () {
    test('rupee symbol, decimals and grouping', () {
      expect(p('lunch ₹249.50')!.amountPaise, 24950);
      expect(p('lunch rs.250')!.amountPaise, 25000);
      expect(p('phone 1,24,999 card')!.amountPaise, 12499900);
    });

    test('amount can come first', () {
      final r = p('20 chai')!;
      expect(r.amountPaise, 2000);
      expect(r.description, 'chai');
    });

    test('k suffix', () {
      expect(p('rent 12k')!.amountPaise, 1200000);
      expect(p('bonus 1.5k income')!.amountPaise, 150000);
    });

    test('several numbers: the last one is the amount', () {
      final r = p('2 samosa 40')!;
      expect(r.amountPaise, 4000);
      expect(r.description, '2 samosa');
    });

    test('no amount gives null', () {
      expect(p('chai'), isNull);
      expect(p(''), isNull);
      expect(p('   '), isNull);
    });

    test('zero amount gives null', () {
      expect(p('chai 0'), isNull);
    });
  });

  group('dates', () {
    test('today and yesterday', () {
      expect(p('chai 20 today')!.date, DateTime(2026, 10, 21));
      expect(p('chai 20 yesterday')!.date, DateTime(2026, 10, 20));
      expect(p('chai 20 yday')!.date, DateTime(2026, 10, 20));
    });

    test('weekday means the most recent one, today included', () {
      expect(p('movie 400 sunday')!.date, DateTime(2026, 10, 18));
      expect(p('movie 400 mon')!.date, DateTime(2026, 10, 19));
      expect(p('movie 400 wed')!.date, DateTime(2026, 10, 21));
      expect(p('movie 400 thursday')!.date, DateTime(2026, 10, 15));
    });

    test('dd/mm and dd-mm in the past', () {
      expect(p('gift 1000 12/10')!.date, DateTime(2026, 10, 12));
      expect(p('gift 1000 5-9')!.date, DateTime(2026, 9, 5));
    });

    test('dd/mm later than today means last year', () {
      expect(p('gift 1000 25/12')!.date, DateTime(2025, 12, 25));
    });

    test('dd/mm/yyyy', () {
      expect(p('gift 1000 01/02/2026')!.date, DateTime(2026, 2, 1));
      expect(p('gift 1000 01/02/26')!.date, DateTime(2026, 2, 1));
    });

    test('invalid dates are left in the description', () {
      final r = p('gift 1000 31/02')!;
      expect(r.date, DateTime(2026, 10, 21));
      expect(r.description, 'gift 31/02');
    });
  });

  test('custom account keywords', () {
    final r = parseQuickAdd(
      'groceries 800 kotak',
      now: now,
      accountKeywords: {'kotak'},
    );
    expect(r!.accountHint, 'kotak');
    expect(r.description, 'groceries');
  });

  test('case and extra spaces', () {
    final r = p('  Petrol   500   CARD ')!;
    expect(r.description, 'Petrol');
    expect(r.accountHint, 'card');
  });
}

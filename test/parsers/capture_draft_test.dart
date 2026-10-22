import 'package:flutter_test/flutter_test.dart';
import 'package:tracks/data/tables.dart';
import 'package:tracks/features/capture/domain/capture_draft.dart';

void main() {
  final now = DateTime(2026, 10, 21, 15, 30);
  CaptureOutcome share(String text) =>
      captureFromSharedText(text, now: now, accountKeywords: const {});

  CaptureDraft draftOf(CaptureOutcome o) {
    expect(o, isA<CaptureReady>());
    return (o as CaptureReady).draft;
  }

  group('shared SMS', () {
    test('UPI debit becomes an expense with merchant, ref and hints', () {
      const sms =
          'Sent Rs.250.00\nFrom HDFC Bank A/C *1234\nTo SWIGGY\nOn 21/10/26\n'
          'Ref 629412345678';
      final d = draftOf(share(sms));
      expect(d.type, TxnType.expense);
      expect(d.amountPaise, 25000);
      expect(d.merchant, 'SWIGGY');
      expect(d.note, 'SWIGGY');
      expect(d.accountLast4, '1234');
      expect(d.bankHint, 'hdfc');
      expect(d.refNo, '629412345678');
      expect(d.date, DateTime(2026, 10, 21));
      expect(d.source, TxnSource.sms);
      expect(d.rawText, sms);
      expect(d.categoryText, contains('SWIGGY'));
    });

    test('credit becomes income', () {
      final d = draftOf(
        share(
          'Your A/c XX1234 is credited with INR 50,000.00 on 01-10-2026 by NEFT '
          'from ACME TECHNOLOGIES PVT LTD. -HDFC Bank',
        ),
      );
      expect(d.type, TxnType.income);
      expect(d.amountPaise, 5000000);
    });

    test('ATM withdrawal is a transfer to cash', () {
      final d = draftOf(
        share(
          'INR 2000.00 withdrawn from A/c no. XX3456 on 18-10-2026 at ATM BLR. '
          '-Axis Bank',
        ),
      );
      expect(d.type, TxnType.transfer);
      expect(d.accountLast4, '3456');
      expect(d.toAccountHint, 'cash');
    });

    test('credit card bill payment is a transfer into the card', () {
      final d = draftOf(
        share(
          'Payment of Rs 10,000.00 received towards your Credit Card XX9012 on '
          '10-Oct-26. -ICICI Bank',
        ),
      );
      expect(d.type, TxnType.transfer);
      expect(d.accountLast4, isNull);
      expect(d.toAccountLast4, '9012');
    });

    test('refund is income guessed as refund', () {
      final d = draftOf(
        share(
          'Refund of Rs.199.00 for your transaction at FLIPKART has been '
          'credited to your ICICI Bank Credit Card XX9012 on 16-Oct-26.',
        ),
      );
      expect(d.type, TxnType.income);
      expect(d.categoryText, contains('refund'));
    });

    test('autopay and EMI become tags', () {
      final d = draftOf(
        share(
          'Dear Customer, EMI of Rs.12,345 for Loan A/c XX4321 has been debited '
          'from your A/c XX1234 on 05-10-2026 via NACH. -HDFC Bank',
        ),
      );
      expect(d.tags, 'emi');
      expect(d.categoryText, contains('emi'));
    });

    test('OTP is ignored with a reason', () {
      final o = share('123456 is your OTP for INR 1,499.00 at AMAZON.');
      expect(o, isA<CaptureIgnored>());
      expect((o as CaptureIgnored).message, contains('OTP'));
    });

    test('debit with no amount opens an empty sheet keeping the raw text', () {
      const sms = 'Your A/c XX1234 has been debited. -HDFC Bank';
      final d = draftOf(share(sms));
      expect(d.amountPaise, isNull);
      expect(d.type, TxnType.expense);
      expect(d.rawText, sms);
      expect(d.accountLast4, isNull); // parser bailed out before hints
    });
  });

  group('shared plain text falls back to quick-add', () {
    test('"chai 20 gpay" shared from notes', () {
      final d = draftOf(share('chai 20 gpay'));
      expect(d.type, TxnType.expense);
      expect(d.amountPaise, 2000);
      expect(d.accountHint, 'gpay');
      expect(d.source, TxnSource.quickText);
    });

    test('text with no transaction at all is ignored', () {
      expect(
        share('Are we meeting today? Call me when you are free'),
        isA<CaptureIgnored>(),
      );
    });
  });

  group('draftFromQuickAdd', () {
    test('lent keeps the person in the note and tags it', () {
      final d = draftOf(
        captureFromQuickAdd(
          'lent 2000 to ravi',
          now: now,
          accountKeywords: const {},
        ),
      );
      expect(d.type, TxnType.expense);
      expect(d.note, 'Lent to ravi');
      expect(d.tags, 'lent');
    });

    test('no amount is ignored', () {
      expect(
        captureFromQuickAdd('chai', now: now, accountKeywords: const {}),
        isA<CaptureIgnored>(),
      );
    });
  });

  group('screenshots', () {
    test('GPay receipt becomes an expense from the screenshot source', () {
      final o = captureFromScreenshotText(
        '₹250\nPaid to SWIGGY\n21 Oct 2026, 8:42 pm\nUPI transaction ID\n'
        '629412345678\nTo: SWIGGY\nswiggy@icici\nFrom: HDFC Bank •••• 1234',
      );
      final d = (o as CaptureReady).draft;
      expect(d.source, TxnSource.screenshot);
      expect(d.amountPaise, 25000);
      expect(d.note, 'SWIGGY');
      expect(d.accountLast4, '1234');
      expect(d.refNo, '629412345678');
    });

    test('a screenshot of a bank SMS still works', () {
      final o = captureFromScreenshotText(
        'Dear UPI user A/C X5678 debited by 120.0 on date 20Oct26 trf to '
        'RAVI KUMAR Refno 629398765432. -SBI',
      );
      expect((o as CaptureReady).draft.source, TxnSource.screenshot);
    });

    test('a random picture is ignored with a reason', () {
      expect(
        captureFromScreenshotText('Happy birthday!'),
        isA<CaptureIgnored>(),
      );
    });
  });
}

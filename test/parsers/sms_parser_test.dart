import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tracks/features/capture/domain/sms_parser.dart';

void main() {
  final fixtures = (jsonDecode(
    File('test/parsers/fixtures/bank_sms.json').readAsStringSync(),
  ) as List).cast<Map<String, dynamic>>();

  group('bank SMS fixtures', () {
    for (final f in fixtures) {
      test(f['id'], () {
        final r = parseBankSms(f['text'] as String);
        final e = f['expect'] as Map<String, dynamic>;

        expect(r.kind.name, e['kind'], reason: 'kind');
        if (r.kind == SmsKind.ignore) {
          expect(r.ignoreReason?.name, e['ignoreReason'], reason: 'reason');
          expect(r.amountPaise, isNull);
          return;
        }
        expect(r.amountPaise, e['amountPaise'], reason: 'amount');
        expect(r.accountLast4, e['account'], reason: 'account');
        expect(r.bankHint, e['bank'], reason: 'bank');
        expect(r.merchant, e['merchant'], reason: 'merchant');
        expect(
          r.date,
          e['date'] == null ? isNull : DateTime.parse(e['date'] as String),
          reason: 'date',
        );
        expect(r.refNo, e['ref'], reason: 'ref');
        expect(r.channel.name, e['channel'], reason: 'channel');
        expect(
          r.flags.map((f) => f.name).toSet(),
          ((e['flags'] as List?) ?? const []).toSet(),
          reason: 'flags',
        );
      });
    }
  });

  group('edge cases', () {
    test('balance amount is never taken as the transaction amount', () {
      final r = parseBankSms(
        'Avl Bal INR 9,999.00. A/c XX1111 debited Rs 50.00 on 01-01-26.',
      );
      expect(r.amountPaise, 5000);
    });

    test('debit without any amount is ignored', () {
      final r = parseBankSms('Your A/c XX1234 has been debited. -HDFC Bank');
      expect(r.kind, SmsKind.ignore);
      expect(r.ignoreReason, SmsIgnoreReason.noAmount);
    });

    test('empty and junk text', () {
      expect(parseBankSms('').kind, SmsKind.ignore);
      expect(parseBankSms('hello there').kind, SmsKind.ignore);
    });

    test('invalid dates become null rather than wrong', () {
      final r = parseBankSms('Rs 10 debited from A/c XX1234 on 31-02-26');
      expect(r.kind, SmsKind.debit);
      expect(r.date, isNull);
    });

    test('verification code counts as OTP', () {
      final r = parseBankSms(
        'Your verification code is 4821 for payment of Rs 99 to SWIGGY',
      );
      expect(r.ignoreReason, SmsIgnoreReason.otp);
    });
  });
}

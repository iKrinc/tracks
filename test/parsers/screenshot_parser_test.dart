import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tracks/features/capture/domain/screenshot_parser.dart';
import 'package:tracks/features/capture/domain/sms_parser.dart';

String _hm(({int hour, int minute})? t) => t == null
    ? 'none'
    : '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

void main() {
  final fixtures = (jsonDecode(
    File('test/parsers/fixtures/payment_screenshots.json').readAsStringSync(),
  ) as List).cast<Map<String, dynamic>>();

  for (final f in fixtures) {
    test(f['id'], () {
      final r = parsePaymentScreenshot(f['text'] as String);
      final e = f['expect'] as Map<String, dynamic>;
      if (e['kind'] == 'none') {
        expect(r, isNull);
        return;
      }
      expect(r, isNotNull);
      expect(r!.kind.name, e['kind'], reason: 'kind');
      expect(r.amountPaise, e['amountPaise'], reason: 'amount');
      expect(r.merchant, e['merchant'], reason: 'merchant');
      expect(r.vpa, e['vpa'], reason: 'vpa');
      expect(r.accountLast4, e['account'], reason: 'account');
      expect(r.bankHint, e['bank'], reason: 'bank');
      expect(r.refNo, e['ref'], reason: 'ref');
      expect(r.date, DateTime.parse(e['date'] as String), reason: 'date');
      if (e.containsKey('time')) {
        expect(_hm(r.time), e['time'], reason: 'time');
      }
    });
  }

  test('maps to the same kinds the SMS pipeline uses', () {
    final r = parsePaymentScreenshot('Paid to X\n₹10\n1 Oct 2026')!;
    expect(r.kind, SmsKind.debit);
  });
}

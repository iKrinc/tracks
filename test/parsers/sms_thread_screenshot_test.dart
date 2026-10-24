import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tracks/features/capture/domain/capture_draft.dart';

void main() {
  final fixtures = (jsonDecode(
    File('test/parsers/fixtures/sms_thread_screenshots.json')
        .readAsStringSync(),
  ) as List).cast<Map<String, dynamic>>();

  for (final f in fixtures) {
    test('${f['id']}: every message in the screenshot becomes a draft', () {
      final blocks = (f['blocks'] as List).cast<String>();
      final o = captureFromScreenshotBlocks(blocks);
      expect(o, isA<CaptureMany>());
      final drafts = (o as CaptureMany).drafts;
      final expected = (f['expect'] as List).cast<Map<String, dynamic>>();
      expect(drafts.length, expected.length);
      for (var i = 0; i < expected.length; i++) {
        expect(drafts[i].amountPaise, expected[i]['amountPaise']);
        expect(drafts[i].merchant, expected[i]['merchant']);
        expect(drafts[i].refNo, expected[i]['ref']);
        expect(drafts[i].source.name, 'screenshot');
      }
    });
  }

  test('one receipt among blocks is a single draft', () {
    final o = captureFromScreenshotBlocks([
      'To Swiggy',
      '₹248',
      'Completed',
      '15 Oct 2026, 1:31 pm',
      'Kotak Mahindra Bank 4455',
      'UPI transaction ID\n600000000012',
    ]);
    expect(o, isA<CaptureReady>());
  });

  test('the same SMS twice in one screenshot is kept once', () {
    const sms =
        'Rs.12.00 paid thru A/C XX3388 on 06-12-25 15:59:28 to Mrs Lakshmi '
        'Dev, UPI Ref 570000000002. -Canara Bank';
    final o = captureFromScreenshotBlocks([sms, sms]);
    expect(o, isA<CaptureReady>());
  });

  test('a bubble OCR split into two blocks is rejoined', () {
    final o = captureFromScreenshotBlocks([
      'Rs.120.00 paid thru A/C XX3388 on 20-10-26 09:14:02 to ARJUN TEST, '
          'UPI Ref 600000000101. -Canara Bank',
      'An amount of INR 2,000.00 has been CREDITED to',
      'your account XX3388 on 22-10-26 18:02:45. UPI Ref 600000000103. '
          '-Canara Bank',
    ]);
    expect(o, isA<CaptureMany>());
    final drafts = (o as CaptureMany).drafts;
    expect(drafts.map((d) => d.amountPaise), [12000, 200000]);
    expect(drafts.last.refNo, '600000000103');
  });

  test('a bubble split into three blocks keeps its date and ref', () {
    final o = captureFromScreenshotBlocks([
      'Rs.120.00 paid thru A/C XX3388 on 20-10-26 09:14:02 to ARJUN TEST, '
          'UPI Ref 600000000101. -Canara Bank',
      'An amount of INR 2,000.00 has been CREDITED to',
      'your account XX3388',
      'on 22-10-26 18:02:45. UPI Ref 600000000103. -Canara Bank',
    ]);
    final last = (o as CaptureMany).drafts.last;
    expect(last.date, DateTime(2026, 10, 22));
    expect(last.refNo, '600000000103');
  });

  test('blocks as ML Kit really split a Canara credit bubble', () {
    final o = captureFromScreenshotBlocks([
      'Rs.450.00 paid thru A/C XX3388 on 21-10-26\n13:40:11 to SWIGGY, UPI '
          'Ref 600000000102.\n-Canara Bank',
      'An amount of INR 2,000.00 has been',
      'CREDITED to your account XX3388 on 22-10-\n26 18:02:45. UPI Ref '
          '600000000103. -Canara\nBank',
    ]);
    final last = (o as CaptureMany).drafts.last;
    expect(last.amountPaise, 200000);
    expect(last.date, DateTime(2026, 10, 22));
    expect(last.time, (hour: 18, minute: 2));
  });

  test('nothing useful gives a reason, not an error', () {
    expect(
      captureFromScreenshotBlocks(['11:08', 'Hello']),
      isA<CaptureIgnored>(),
    );
    expect(captureFromScreenshotBlocks(const []), isA<CaptureIgnored>());
  });
}

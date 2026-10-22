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

  test('nothing useful gives a reason, not an error', () {
    expect(
      captureFromScreenshotBlocks(['11:08', 'Hello']),
      isA<CaptureIgnored>(),
    );
    expect(captureFromScreenshotBlocks(const []), isA<CaptureIgnored>());
  });
}

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:tracks/features/capture/domain/capture_draft.dart';
import 'package:tracks/features/capture/domain/quick_add_parser.dart';
import 'package:tracks/features/capture/domain/screenshot_parser.dart';
import 'package:tracks/features/capture/domain/sms_parser.dart';

/// Parsers see whatever other apps and OCR hand them. None may throw.
void main() {
  final rng = Random(20261022);
  final now = DateTime(2026, 10, 22, 9);

  List<String> texts(String file, String key) => [
    for (final f in (jsonDecode(
      File('test/parsers/fixtures/$file').readAsStringSync(),
    ) as List).cast<Map<String, dynamic>>())
      f[key],
  ].whereType<String>().toList();

  final seeds = [
    ...texts('bank_sms.json', 'text'),
    ...texts('payment_screenshots.json', 'text'),
    'chai 20 gpay',
    'rent 12000 hdfc yesterday',
  ];
  const alphabet =
      'abcxyzRrsINR₹%z0123456789 .,:;-/@*•\n\t()#+XxAaPpMm'
      'debitedcreditedpaidtofromon';
  final chunks = [
    'Rs.',
    'INR ',
    '₹',
    ' on ',
    '31-02-26',
    '99:99',
    '12:00 pm',
    ' to ',
    'From ',
    'To ',
    'XX',
    '@ybl',
    'UPI Ref',
    '\n',
    '9' * 30,
    '.',
    ',',
    'debited',
    'credited',
    'Completed',
    '',
  ];

  String randomText() => String.fromCharCodes([
    for (var i = 0; i < rng.nextInt(200); i++)
      alphabet.codeUnitAt(rng.nextInt(alphabet.length)),
  ]);

  String mutate(String s) {
    final b = StringBuffer();
    var i = 0;
    while (i < s.length) {
      switch (rng.nextInt(12)) {
        case 0: // drop a run
          i += rng.nextInt(6) + 1;
        case 1: // insert a chunk
          b.write(chunks[rng.nextInt(chunks.length)]);
        case 2: // swap a char
          b.write(alphabet[rng.nextInt(alphabet.length)]);
          i++;
        default:
          b.write(s[i]);
          i++;
      }
    }
    return b.toString();
  }

  final inputs = [
    '',
    ' ',
    '\n\n\n',
    '₹',
    'Rs.',
    'Rs. 99999999999999999999',
    'To ',
    'From x\n\n',
    for (var i = 0; i < 600; i++) randomText(),
    for (var i = 0; i < 1500; i++) mutate(seeds[rng.nextInt(seeds.length)]),
  ];

  test('SMS parser never throws', () {
    for (final t in inputs) {
      expect(() => parseBankSms(t), returnsNormally, reason: t);
    }
  });

  test('screenshot parser never throws', () {
    for (final t in inputs) {
      expect(() => parsePaymentScreenshot(t), returnsNormally, reason: t);
    }
  });

  test('quick-add parser never throws', () {
    for (final t in inputs) {
      expect(
        () => parseQuickAdd(t, now: now, accountKeywords: {'hdfc', 'gpay'}),
        returnsNormally,
        reason: t,
      );
    }
  });

  test('parsed amounts are positive and dates real', () {
    for (final t in inputs) {
      final sms = parseBankSms(t);
      if (sms.kind != SmsKind.ignore) {
        expect(sms.amountPaise, greaterThan(0), reason: t);
      }
      final shot = parsePaymentScreenshot(t);
      if (shot != null) expect(shot.amountPaise, greaterThan(0), reason: t);
      final time = sms.time ?? shot?.time;
      if (time != null) {
        expect(time.hour, inInclusiveRange(0, 23), reason: t);
        expect(time.minute, inInclusiveRange(0, 59), reason: t);
      }
    }
  });

  test('block capture never throws', () {
    for (var i = 0; i < 300; i++) {
      final blocks = [
        for (var j = 0; j < rng.nextInt(8); j++)
          inputs[rng.nextInt(inputs.length)],
      ];
      expect(() => captureFromScreenshotBlocks(blocks), returnsNormally);
    }
  });
}

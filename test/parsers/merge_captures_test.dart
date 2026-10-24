import 'package:flutter_test/flutter_test.dart';
import 'package:tracks/data/tables.dart';
import 'package:tracks/features/capture/domain/capture_draft.dart';

CaptureDraft _d(int paise, {String? ref}) => CaptureDraft(
  type: TxnType.expense,
  source: TxnSource.screenshot,
  amountPaise: paise,
  refNo: ref,
);

void main() {
  test('drafts from several screenshots become one batch', () {
    final o = mergeCaptures([
      CaptureReady(_d(100, ref: '1')),
      CaptureMany([_d(200, ref: '2'), _d(300, ref: '3')]),
    ]);
    expect(o, isA<CaptureMany>());
    expect((o as CaptureMany).drafts.map((d) => d.amountPaise), [
      100,
      200,
      300,
    ]);
  });

  test('the same receipt shared twice is kept once', () {
    final o = mergeCaptures([
      CaptureReady(_d(100, ref: '1')),
      CaptureReady(_d(100, ref: '1')),
    ]);
    expect(o, isA<CaptureReady>());
  });

  test('a single outcome passes through unchanged', () {
    const ignored = CaptureIgnored('nope');
    expect(mergeCaptures([ignored]), same(ignored));
  });

  test('ignored images are skipped when others have payments', () {
    final o = mergeCaptures([
      const CaptureIgnored('nope'),
      CaptureReady(_d(100)),
    ]);
    expect(o, isA<CaptureReady>());
  });

  test('all ignored gives one message', () {
    expect(
      mergeCaptures([const CaptureIgnored('a'), const CaptureIgnored('b')]),
      isA<CaptureIgnored>(),
    );
    expect(mergeCaptures(const []), isA<CaptureIgnored>());
  });
}

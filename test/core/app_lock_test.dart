import 'package:flutter_test/flutter_test.dart';
import 'package:tracks/features/settings/domain/app_lock_policy.dart';

void main() {
  final t0 = DateTime(2026, 10, 21, 12);

  test('never locks when disabled', () {
    expect(
      shouldRelock(
        enabled: false,
        leftAt: t0,
        now: t0.add(const Duration(hours: 1)),
      ),
      isFalse,
    );
  });

  test(
    'a quick switch away (or the biometric prompt itself) does not relock',
    () {
      expect(
        shouldRelock(
          enabled: true,
          leftAt: t0,
          now: t0.add(const Duration(seconds: 10)),
        ),
        isFalse,
      );
    },
  );

  test('relocks after the grace period', () {
    expect(
      shouldRelock(
        enabled: true,
        leftAt: t0,
        now: t0.add(const Duration(seconds: 31)),
      ),
      isTrue,
    );
  });

  test('no record of leaving means nothing to relock', () {
    expect(shouldRelock(enabled: true, leftAt: null, now: t0), isFalse);
  });
}

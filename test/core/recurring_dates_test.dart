import 'package:flutter_test/flutter_test.dart';
import 'package:tracks/data/tables.dart';
import 'package:tracks/features/recurring/domain/schedule.dart';

void main() {
  group('occurrence', () {
    test('monthly on the 31st clamps to month end, then recovers', () {
      final s = DateTime(2026, 1, 31);
      expect(occurrence(s, RepeatUnit.month, 1, 0), DateTime(2026, 1, 31));
      expect(occurrence(s, RepeatUnit.month, 1, 1), DateTime(2026, 2, 28));
      expect(occurrence(s, RepeatUnit.month, 1, 2), DateTime(2026, 3, 31));
      expect(occurrence(s, RepeatUnit.month, 1, 3), DateTime(2026, 4, 30));
    });

    test('leap years', () {
      expect(
        occurrence(DateTime(2028, 1, 30), RepeatUnit.month, 1, 1),
        DateTime(2028, 2, 29),
      );
      // Yearly on 29 Feb falls on 28 Feb in common years.
      final leap = DateTime(2028, 2, 29);
      expect(occurrence(leap, RepeatUnit.year, 1, 1), DateTime(2029, 2, 28));
      expect(occurrence(leap, RepeatUnit.year, 1, 4), DateTime(2032, 2, 29));
    });

    test('quarterly and yearly cross year boundaries', () {
      final s = DateTime(2026, 11, 15);
      expect(occurrence(s, RepeatUnit.month, 3, 1), DateTime(2027, 2, 15));
      expect(occurrence(s, RepeatUnit.year, 1, 1), DateTime(2027, 11, 15));
    });

    test('weekly and fortnightly', () {
      final s = DateTime(2026, 10, 19); // Monday
      expect(occurrence(s, RepeatUnit.week, 1, 2), DateTime(2026, 11, 2));
      expect(occurrence(s, RepeatUnit.week, 2, 1), DateTime(2026, 11, 2));
    });
  });

  group('nextDue', () {
    final rent = DateTime(2026, 1, 5);

    test('first occurrence when nothing paid yet', () {
      expect(
        nextDue(start: rent, unit: RepeatUnit.month, interval: 1),
        DateTime(2026, 1, 5),
      );
    });

    test('the occurrence after the last one paid', () {
      expect(
        nextDue(
          start: rent,
          unit: RepeatUnit.month,
          interval: 1,
          lastPaid: DateTime(2026, 10, 5),
        ),
        DateTime(2026, 11, 5),
      );
    });

    test('paying early (before the due date) still counts for that one', () {
      expect(
        nextDue(
          start: rent,
          unit: RepeatUnit.month,
          interval: 1,
          lastPaid: DateTime(2026, 10, 3),
        ),
        DateTime(2026, 11, 5),
      );
    });

    test('a 31st schedule paid on 28 Feb moves to 31 Mar', () {
      expect(
        nextDue(
          start: DateTime(2026, 1, 31),
          unit: RepeatUnit.month,
          interval: 1,
          lastPaid: DateTime(2026, 2, 28),
        ),
        DateTime(2026, 3, 31),
      );
    });
  });

  group('dueStatus', () {
    final today = DateTime(2026, 10, 22);
    test('overdue, due today, due soon, later', () {
      expect(dueStatus(DateTime(2026, 10, 20), today), DueStatus.overdue);
      expect(dueStatus(DateTime(2026, 10, 22), today), DueStatus.today);
      expect(dueStatus(DateTime(2026, 10, 25), today), DueStatus.soon);
      expect(dueStatus(DateTime(2026, 11, 5), today), DueStatus.later);
    });

    test('daysUntil ignores time of day', () {
      expect(daysUntil(DateTime(2026, 10, 25), DateTime(2026, 10, 22, 23)), 3);
    });
  });
}

import 'package:tracks/core/dates.dart';
import 'package:tracks/data/tables.dart';

/// The [k]th occurrence (0 = [start]) of a schedule repeating every
/// [interval] [unit]s. Month/year schedules keep [start]'s day and clamp to
/// the month end (31 Jan → 28 Feb → 31 Mar), never drifting.
DateTime occurrence(DateTime start, RepeatUnit unit, int interval, int k) {
  final s = dateOnly(start);
  switch (unit) {
    case RepeatUnit.week:
      return DateTime(s.year, s.month, s.day + 7 * interval * k);
    case RepeatUnit.month:
    case RepeatUnit.year:
      final months = (unit == RepeatUnit.month ? 1 : 12) * interval * k;
      final first = DateTime(s.year, s.month + months);
      final lastDay = DateTime(first.year, first.month + 1, 0).day;
      return DateTime(
        first.year,
        first.month,
        s.day > lastDay ? lastDay : s.day,
      );
  }
}

/// The next date this schedule is due: the first occurrence when nothing
/// has been paid, else the first occurrence after the one [lastPaid]
/// settled. A payment counts for the nearest occurrence on or after it
/// minus half a period, so paying a few days early still settles that one.
DateTime nextDue({
  required DateTime start,
  required RepeatUnit unit,
  required int interval,
  DateTime? lastPaid,
}) {
  if (lastPaid == null) return dateOnly(start);
  final paid = dateOnly(lastPaid);
  // Find the occurrence closest to the payment.
  var k = 0;
  while (occurrence(start, unit, interval, k + 1).isBefore(paid) ||
      occurrence(start, unit, interval, k + 1) == paid) {
    k++;
  }
  final settled = _closer(
    paid,
    occurrence(start, unit, interval, k),
    occurrence(start, unit, interval, k + 1),
  );
  return occurrence(start, unit, interval, settled == 0 ? k + 1 : k + 2);
}

/// 0 if [a] is at least as close to [x] as [b], else 1.
int _closer(DateTime x, DateTime a, DateTime b) =>
    x.difference(a).abs() <= b.difference(x).abs() ? 0 : 1;

enum DueStatus { overdue, today, soon, later }

int daysUntil(DateTime due, DateTime now) =>
    dateOnly(due).difference(dateOnly(now)).inDays;

/// "Soon" is within the next 3 days.
DueStatus dueStatus(DateTime due, DateTime now) {
  final d = daysUntil(due, now);
  if (d < 0) return DueStatus.overdue;
  if (d == 0) return DueStatus.today;
  if (d <= 3) return DueStatus.soon;
  return DueStatus.later;
}

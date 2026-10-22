import 'package:tracks/core/dates.dart';
import 'package:tracks/core/money.dart';
import 'package:tracks/data/tables.dart';

/// What the planner needs about one active recurring item.
typedef ReminderInput = ({
  int id,
  String name,
  int amountPaise,
  bool variableAmount,
  TxnType type,
  DateTime due,
  int daysBefore,
  AutopayKind autopay,
});

typedef PlannedReminder = ({int id, DateTime at, String title, String body});

/// Card bill reminders use ids above this (bill ids are small integers).
const cardReminderIdBase = 1000000;

/// Android caps pending alarms per app; stay far below it.
const maxPendingReminders = 50;

const _autopayNames = {
  AutopayKind.upiMandate: 'UPI autopay',
  AutopayKind.cardStandingInstruction: 'card autopay',
  AutopayKind.nach: 'NACH',
};

/// One reminder per item, at [hour] on the day [ReminderInput.daysBefore]
/// before it's due. Times already past are skipped (the Home strip shows
/// those). Soonest first, capped at [maxPendingReminders].
List<PlannedReminder> planReminders(
  Iterable<ReminderInput> items,
  DateTime now, {
  int hour = 9,
}) {
  final plan = <PlannedReminder>[];
  for (final i in items) {
    final day = dateOnly(i.due);
    final at = DateTime(day.year, day.month, day.day - i.daysBefore, hour);
    if (!at.isAfter(now)) continue;
    final when = switch (i.daysBefore) {
      0 => 'today',
      1 => 'tomorrow',
      final n => 'in $n days',
    };
    final verb = i.type == TxnType.income ? 'expected' : 'due';
    final amount = i.amountPaise == 0
        ? 'Check the statement amount'
        : '${i.variableAmount ? 'About ' : ''}'
              '${formatPaise(i.amountPaise, hideZeroPaise: true)}';
    final auto = _autopayNames[i.autopay];
    plan.add((
      id: i.id,
      at: at,
      title: '${i.name} $verb $when',
      body: auto == null
          ? '$amount · tap to mark it ${i.type == TxnType.income ? 'received' : 'paid'}'
          : '$amount via $auto · check it went through',
    ));
  }
  plan.sort((a, b) => a.at.compareTo(b.at));
  return plan.take(maxPendingReminders).toList();
}

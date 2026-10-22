import 'package:flutter_test/flutter_test.dart';
import 'package:tracks/data/tables.dart';
import 'package:tracks/features/recurring/domain/reminder_plan.dart';

void main() {
  final now = DateTime(2026, 10, 22, 15, 0);
  ReminderInput bill(
    int id,
    DateTime due, {
    int before = 1,
    AutopayKind autopay = AutopayKind.none,
    TxnType type = TxnType.expense,
  }) => (
    id: id,
    name: 'Bill $id',
    amountPaise: 1200000,
    variableAmount: false,
    type: type,
    due: due,
    daysBefore: before,
    autopay: autopay,
  );

  test('fires at 9 am the chosen days before', () {
    final plan = planReminders([bill(1, DateTime(2026, 11, 5))], now);
    expect(plan.single.at, DateTime(2026, 11, 4, 9));
    expect(plan.single.id, 1);
  });

  test('on the day means 9 am on the due date', () {
    final plan = planReminders([
      bill(1, DateTime(2026, 11, 5), before: 0),
    ], now);
    expect(plan.single.at, DateTime(2026, 11, 5, 9));
  });

  test('reminder time already passed: skipped, the in-app strip covers it', () {
    expect(planReminders([bill(1, DateTime(2026, 10, 23))], now), isEmpty);
    expect(planReminders([bill(2, DateTime(2026, 10, 1))], now), isEmpty);
  });

  test('wording says when, how much, and whether autopay handles it', () {
    final p = planReminders([
      bill(1, DateTime(2026, 11, 5)),
      bill(
        2,
        DateTime(2026, 11, 10),
        before: 0,
        autopay: AutopayKind.upiMandate,
      ),
    ], now);
    expect(p[0].title, 'Bill 1 due tomorrow');
    expect(p[0].body, '₹12,000 · tap to mark it paid');
    expect(p[1].title, 'Bill 2 due today');
    expect(p[1].body, '₹12,000 via UPI autopay · check it went through');
  });

  test('income items read as expected, not due', () {
    final p = planReminders([
      bill(3, DateTime(2026, 11, 1), before: 0, type: TxnType.income),
    ], now);
    expect(p.single.title, 'Bill 3 expected today');
  });

  test('at most 50, soonest first (Android limits pending alarms)', () {
    final many = [
      for (var i = 0; i < 60; i++) bill(i, DateTime(2026, 12, 1 + i % 28)),
    ];
    final p = planReminders(many, now);
    expect(p.length, 50);
    expect(p.map((r) => r.at).toList(), [...p.map((r) => r.at)]..sort());
  });
}

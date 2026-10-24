import 'package:tracks/core/dates.dart';
import 'package:tracks/data/tables.dart';
import 'package:tracks/features/recurring/domain/schedule.dart';

/// A recurring item as the forecast needs it.
typedef ForecastBill = ({
  int id,
  String name,
  TxnType type,
  int amountPaise,
  int accountId,
  int? toAccountId,
  DateTime start,
  RepeatUnit unit,
  int interval,
  DateTime? lastPaid,
});

/// Something due once, e.g. this month's credit-card bill.
typedef ForecastOneOff = ({DateTime date, String name, int paise});

/// One movement of spendable money. [deltaPaise] is signed: + comes in.
typedef ForecastEvent = ({
  DateTime date,
  String name,
  int deltaPaise,
  int? recurringId,
  bool overdue,
});

/// A spend the history estimate is made from. [notEveryday] marks bills
/// and one-off event (fund) costs, which a usual day doesn't include.
typedef SpendSample = ({
  TxnType type,
  int accountId,
  int paise,
  DateTime at,
  bool notEveryday,
});

class CashForecast {
  const CashForecast({
    required this.today,
    required this.end,
    required this.payday,
    required this.startPaise,
    required this.events,
    required this.dailySpendPaise,
    required this.endPaise,
    required this.lowestPaise,
    required this.lowestOn,
    required this.dailyAllowancePaise,
    required this.lowestBillsOnlyPaise,
  });

  final DateTime today;

  /// Last day forecast: the day before [payday], or 30 days out.
  final DateTime end;

  /// The next salary/income date, when there is one within 45 days.
  final DateTime? payday;

  /// Cash + bank + wallet balances now.
  final int startPaise;
  final List<ForecastEvent> events;

  /// Typical everyday spending (not bills) per day, from history.
  final int dailySpendPaise;

  /// What's left on [end], after bills and everyday spending.
  final int endPaise;
  final int lowestPaise;
  final DateTime lowestOn;

  /// How much can go on everyday spending per day without bills bouncing.
  final int dailyAllowancePaise;

  /// The lowest balance from bills alone, without everyday spending.
  final int lowestBillsOnlyPaise;

  /// Bills by themselves are more than there is (not just spending).
  bool get billsExceedMoney => lowestBillsOnlyPaise < 0;

  int get days => daysBetween(today, end);
  bool get goesNegative => lowestPaise < 0;
}

const _maxPaydayDays = 45;
const _noPaydayDays = 30;
const _historyDays = 60;

/// What spendable money (cash, bank, wallet) does from [today] until the
/// day before the next payday: every bill, EMI, income and [oneOffs] due,
/// plus [dailySpendPaise] of everyday spending each day after today.
///
/// Cautious by design: an overdue bill is counted today, an overdue income
/// isn't (it may have arrived without being marked). Bills charged to a
/// card don't count here; the card bill does.
CashForecast forecastCashflow({
  required DateTime today,
  required int liquidPaise,
  required Set<int> liquidAccounts,
  required List<ForecastBill> bills,
  List<ForecastOneOff> oneOffs = const [],
  int dailySpendPaise = 0,
}) {
  final day0 = dateOnly(today);

  int effect(ForecastBill b) {
    final fromLiquid = liquidAccounts.contains(b.accountId);
    switch (b.type) {
      case TxnType.expense:
        return fromLiquid ? -b.amountPaise : 0;
      case TxnType.income:
        return fromLiquid ? b.amountPaise : 0;
      case TxnType.transfer:
        final toLiquid =
            b.toAccountId != null && liquidAccounts.contains(b.toAccountId);
        if (fromLiquid == toLiquid) return 0;
        return fromLiquid ? -b.amountPaise : b.amountPaise;
    }
  }

  /// Due dates of [b] from its next due date on, up to [until].
  Iterable<(DateTime, bool)> dates(ForecastBill b, DateTime until) sync* {
    final due = nextDue(
      start: b.start,
      unit: b.unit,
      interval: b.interval,
      lastPaid: b.lastPaid,
    );
    var k = 0;
    while (occurrence(b.start, b.unit, b.interval, k).isBefore(due)) {
      k++;
    }
    if (due.isBefore(day0)) {
      yield (day0, true);
      // Skip the other missed occurrences: one overdue is enough to flag.
      while (occurrence(b.start, b.unit, b.interval, k).isBefore(day0)) {
        k++;
      }
      if (occurrence(b.start, b.unit, b.interval, k) == day0) k++;
    }
    for (; ; k++) {
      final d = occurrence(b.start, b.unit, b.interval, k);
      if (d.isAfter(until)) return;
      yield (d, false);
    }
  }

  // Payday: the first income into spendable money after today.
  final paydayLimit = addDays(day0, _maxPaydayDays);
  DateTime? payday;
  for (final b in bills) {
    if (b.type != TxnType.income || effect(b) <= 0) continue;
    for (final (d, overdue) in dates(b, paydayLimit)) {
      if (overdue || !d.isAfter(day0)) continue;
      if (payday == null || d.isBefore(payday)) payday = d;
      break;
    }
  }
  final end = payday == null
      ? addDays(day0, _noPaydayDays)
      : addDays(payday, -1);

  final events = <ForecastEvent>[];
  for (final b in bills) {
    final delta = effect(b);
    if (delta == 0) continue;
    for (final (d, overdue) in dates(b, end)) {
      if (overdue && delta > 0) continue;
      events.add((
        date: d,
        name: b.name,
        deltaPaise: delta,
        recurringId: b.id,
        overdue: overdue,
      ));
    }
  }
  for (final o in oneOffs) {
    final d = dateOnly(o.date);
    if (d.isAfter(end) || o.paise <= 0) continue;
    final late = d.isBefore(day0);
    events.add((
      date: late ? day0 : d,
      name: o.name,
      deltaPaise: -o.paise,
      recurringId: null,
      overdue: late,
    ));
  }
  events.sort((a, b) => a.date.compareTo(b.date));

  // Walk day by day: committed (bills only) and expected (with spending).
  final days = daysBetween(day0, end);
  var committed = liquidPaise;
  var lowestCommitted = liquidPaise;
  var expected = liquidPaise;
  var lowest = liquidPaise;
  var lowestOn = day0;
  var e = 0;
  for (var i = 0; i <= days; i++) {
    final d = addDays(day0, i);
    while (e < events.length && !events[e].date.isAfter(d)) {
      committed += events[e].deltaPaise;
      expected += events[e].deltaPaise;
      e++;
    }
    if (i > 0) expected -= dailySpendPaise;
    if (committed < lowestCommitted) lowestCommitted = committed;
    if (expected < lowest) {
      lowest = expected;
      lowestOn = d;
    }
  }
  final free = lowestCommitted < 0 ? 0 : lowestCommitted;

  return CashForecast(
    today: day0,
    end: end,
    payday: payday,
    startPaise: liquidPaise,
    events: events,
    dailySpendPaise: dailySpendPaise,
    endPaise: expected,
    lowestPaise: lowest,
    lowestOn: lowestOn,
    dailyAllowancePaise: days <= 0 ? free : free ~/ days,
    lowestBillsOnlyPaise: lowestCommitted,
  );
}

/// Typical everyday spending per day: expenses from spendable accounts over
/// the last 60 days, leaving out bills (they're forecast on their own).
/// With less history, it averages over the days there are.
int averageDailySpend(
  Iterable<SpendSample> txns, {
  required DateTime today,
  required Set<int> liquidAccounts,
}) {
  final day0 = dateOnly(today);
  final from = addDays(day0, -(_historyDays - 1));
  DateTime? earliest;
  var total = 0;
  for (final t in txns) {
    final d = dateOnly(t.at);
    if (d.isAfter(day0)) continue;
    if (earliest == null || d.isBefore(earliest)) earliest = d;
    if (d.isBefore(from) ||
        t.type != TxnType.expense ||
        t.notEveryday ||
        !liquidAccounts.contains(t.accountId)) {
      continue;
    }
    total += t.paise;
  }
  if (earliest == null) return 0;
  final span = daysBetween(earliest, day0) + 1;
  return total ~/ (span < _historyDays ? span : _historyDays);
}

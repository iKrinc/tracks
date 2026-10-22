import 'package:tracks/core/dates.dart';

typedef CardCycle = ({
  DateTime lastStatement,
  DateTime nextStatement,
  DateTime due,
});

DateTime _onDay(int year, int month, int day) {
  final last = DateTime(year, month + 1, 0).day;
  return DateTime(year, month, day > last ? last : day);
}

/// The billing cycle around [today] for a card whose statement is generated
/// on [statementDay] and paid by [dueDay] (the first such day after the
/// statement). Days past a month's end clamp to its last day.
CardCycle cardCycle({
  required int statementDay,
  required int dueDay,
  required DateTime today,
}) {
  final t = dateOnly(today);
  var last = _onDay(t.year, t.month, statementDay);
  if (last.isAfter(t)) last = _onDay(t.year, t.month - 1, statementDay);
  final next = _onDay(last.year, last.month + 1, statementDay);
  var due = _onDay(last.year, last.month, dueDay);
  if (!due.isAfter(last)) due = _onDay(last.year, last.month + 1, dueDay);
  return (lastStatement: last, nextStatement: next, due: due);
}

/// A balance movement on the card: negative = spend, positive = payment or
/// refund.
typedef CardMove = ({DateTime at, int paise});

typedef CardStatus = ({
  int billedPaise,
  int paidSinceStatementPaise,
  int dueNowPaise,
  int unbilledPaise,
  int outstandingPaise,
  int utilisationBp,
  int minimumDuePaise,
});

/// Where a card stands. "Billed" is what was owed when the last statement
/// was generated; payments after it reduce what's due now; spends after it
/// are unbilled (they land on the next statement). Minimum due is an
/// estimate (5%, at least ₹200): banks vary, the statement is the truth.
CardStatus cardStatus({
  required Iterable<CardMove> moves,
  required int openingPaise,
  required CardCycle cycle,
  required int limitPaise,
}) {
  var atStatement = openingPaise; // balance at end of statement day
  var paidAfter = 0;
  var spentAfter = 0;
  var balance = openingPaise;
  for (final m in moves) {
    balance += m.paise;
    if (!dateOnly(m.at).isAfter(cycle.lastStatement)) {
      atStatement += m.paise;
    } else if (m.paise > 0) {
      paidAfter += m.paise;
    } else {
      spentAfter += -m.paise;
    }
  }
  final billed = atStatement < 0 ? -atStatement : 0;
  final dueNow = (billed - paidAfter).clamp(0, billed);
  final outstanding = balance < 0 ? -balance : 0;
  final minimum = dueNow == 0
      ? 0
      : (dueNow * 5 ~/ 100).clamp(dueNow < 20000 ? dueNow : 20000, dueNow);
  return (
    billedPaise: billed,
    paidSinceStatementPaise: paidAfter,
    dueNowPaise: dueNow,
    unbilledPaise: spentAfter,
    outstandingPaise: outstanding,
    utilisationBp: limitPaise <= 0 ? 0 : outstanding * 10000 ~/ limitPaise,
    minimumDuePaise: minimum,
  );
}

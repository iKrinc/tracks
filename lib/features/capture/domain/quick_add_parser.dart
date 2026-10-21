import 'package:tracks/core/money.dart';

/// What a one-line quick-add entry describes.
enum QuickAddKind { expense, income, transfer, lent, borrowed }

/// Parsed quick-add line, ready to pre-fill a Confirm Card.
///
/// Hints are raw words (lowercased) still to be matched against the user's
/// accounts; [description] is what's left after removing amount, date,
/// account and keyword tokens, and feeds category Rules.
class QuickAddResult {
  const QuickAddResult({
    required this.kind,
    required this.amountPaise,
    required this.description,
    required this.date,
    this.accountHint,
    this.toAccountHint,
    this.person,
  });

  final QuickAddKind kind;
  final int amountPaise;
  final String description;

  /// Date only (midnight); the caller attaches a time.
  final DateTime date;
  final String? accountHint;
  final String? toAccountHint;
  final String? person;

  @override
  String toString() =>
      'QuickAddResult($kind, $amountPaise, "$description", $date, '
      'account: $accountHint, to: $toAccountHint, person: $person)';
}

/// Words treated as account hints out of the box. User account names are
/// added via `accountKeywords`.
const defaultAccountKeywords = {
  'cash',
  'card',
  'credit',
  'debit',
  'upi',
  'gpay',
  'phonepe',
  'paytm',
  'bhim',
  'amazonpay',
  'hdfc',
  'sbi',
  'icici',
  'axis',
  'kotak',
  'yes',
  'idfc',
  'pnb',
  'bob',
};

const _weekdays = {
  'mon': DateTime.monday,
  'monday': DateTime.monday,
  'tue': DateTime.tuesday,
  'tues': DateTime.tuesday,
  'tuesday': DateTime.tuesday,
  'wed': DateTime.wednesday,
  'wednesday': DateTime.wednesday,
  'thu': DateTime.thursday,
  'thur': DateTime.thursday,
  'thurs': DateTime.thursday,
  'thursday': DateTime.thursday,
  'fri': DateTime.friday,
  'friday': DateTime.friday,
  'sat': DateTime.saturday,
  'saturday': DateTime.saturday,
  'sun': DateTime.sunday,
  'sunday': DateTime.sunday,
};

/// Words that mark income but also describe it, so they stay in the
/// description (e.g. "salary", "refund").
const _incomeWords = {'salary', 'refund', 'cashback', 'interest', 'bonus'};

final _numericDate = RegExp(r'^(\d{1,2})[/-](\d{1,2})(?:[/-](\d{2}|\d{4}))?$');

/// Parses lines like `chai 20 gpay`, `rent 12000 hdfc yesterday` or
/// `lent 2000 to ravi`. Returns `null` when no positive amount is found.
QuickAddResult? parseQuickAdd(
  String input, {
  required DateTime now,
  Set<String> accountKeywords = const {},
}) {
  final accounts = {
    ...defaultAccountKeywords,
    ...accountKeywords.map((k) => k.toLowerCase()),
  };
  final tokens = input.trim().split(RegExp(r'\s+'))
    ..removeWhere((t) => t.isEmpty);
  if (tokens.isEmpty) return null;

  var kind = QuickAddKind.expense;
  String? accountHint;
  String? toAccountHint;
  String? person;
  final today = DateTime(now.year, now.month, now.day);
  var date = today;

  // 1. Kind keywords.
  final rest = <String>[];
  for (final t in tokens) {
    switch (t.toLowerCase()) {
      case 'lent':
        kind = QuickAddKind.lent;
      case 'borrowed':
        kind = QuickAddKind.borrowed;
      case 'transfer' || 'trf':
        kind = QuickAddKind.transfer;
      case 'atm':
        kind = QuickAddKind.transfer;
        toAccountHint = 'cash';
      case 'income' || 'received':
        kind = QuickAddKind.income;
      default:
        if (_incomeWords.contains(t.toLowerCase())) {
          kind = QuickAddKind.income;
        }
        rest.add(t);
    }
  }

  // 2. "to X" / "from X": an account for transfers, otherwise a person.
  final afterLinks = <String>[];
  for (var i = 0; i < rest.length; i++) {
    final word = rest[i].toLowerCase();
    if ((word == 'to' || word == 'from') && i + 1 < rest.length) {
      final target = rest[i + 1];
      if (accounts.contains(target.toLowerCase())) {
        if (word == 'to') {
          toAccountHint = target.toLowerCase();
        } else {
          accountHint = target.toLowerCase();
        }
      } else {
        person = target;
      }
      i++;
      continue;
    }
    afterLinks.add(rest[i]);
  }

  // 3. Dates, then 4. account words.
  final remaining = <String>[];
  var dateFound = false;
  for (final t in afterLinks) {
    final lower = t.toLowerCase();
    if (!dateFound) {
      final d = _parseDateToken(lower, today);
      if (d != null) {
        date = d;
        dateFound = true;
        continue;
      }
    }
    if (accounts.contains(lower)) {
      if (accountHint == null) {
        accountHint = lower;
        continue;
      }
      if (kind == QuickAddKind.transfer && toAccountHint == null) {
        toAccountHint = lower;
        continue;
      }
    }
    remaining.add(t);
  }

  // 5. Amount: the last token that reads as money.
  int? amount;
  for (var i = remaining.length - 1; i >= 0; i--) {
    final a = _parseAmountToken(remaining[i]);
    if (a != null) {
      amount = a;
      remaining.removeAt(i);
      break;
    }
  }
  if (amount == null || amount <= 0) return null;

  return QuickAddResult(
    kind: kind,
    amountPaise: amount,
    description: remaining.join(' '),
    date: date,
    accountHint: accountHint,
    toAccountHint: toAccountHint,
    person: person,
  );
}

int? _parseAmountToken(String token) {
  final lower = token.toLowerCase();
  if (lower.endsWith('k') && lower.length > 1) {
    final base = parseRupeesToPaise(lower.substring(0, lower.length - 1));
    return base == null ? null : base * 1000;
  }
  return parseRupeesToPaise(token);
}

DateTime? _parseDateToken(String lower, DateTime today) {
  if (lower == 'today') return today;
  if (lower == 'yesterday' || lower == 'yday') {
    return DateTime(today.year, today.month, today.day - 1);
  }
  final weekday = _weekdays[lower];
  if (weekday != null) {
    final back = (today.weekday - weekday + 7) % 7;
    return DateTime(today.year, today.month, today.day - back);
  }
  final m = _numericDate.firstMatch(lower);
  if (m == null) return null;
  final day = int.parse(m.group(1)!);
  final month = int.parse(m.group(2)!);
  final yearStr = m.group(3);
  var year = yearStr == null
      ? today.year
      : (yearStr.length == 2 ? 2000 + int.parse(yearStr) : int.parse(yearStr));
  var d = _validDate(year, month, day);
  if (d == null) return null;
  if (yearStr == null && d.isAfter(today)) {
    year -= 1;
    d = _validDate(year, month, day);
  }
  return d;
}

DateTime? _validDate(int y, int m, int d) {
  if (m < 1 || m > 12 || d < 1) return null;
  final dt = DateTime(y, m, d);
  return (dt.year == y && dt.month == m && dt.day == d) ? dt : null;
}

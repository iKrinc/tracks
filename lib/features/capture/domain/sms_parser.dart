import 'package:tracks/core/money.dart';

/// Direction of a bank/UPI SMS, or `ignore` for OTPs, promos and alerts.
enum SmsKind { debit, credit, ignore }

enum SmsIgnoreReason { otp, noTransaction, noAmount }

enum SmsChannel { upi, card, atm, netbanking, nach, unknown }

enum SmsFlag { refund, autopay, emi, cardPayment }

/// Fields pulled out of one shared SMS. Hints still need matching against
/// the user's accounts; [date] is null when the SMS doesn't carry one.
class SmsParseResult {
  const SmsParseResult({
    required this.kind,
    this.ignoreReason,
    this.amountPaise,
    this.accountLast4,
    this.bankHint,
    this.merchant,
    this.date,
    this.refNo,
    this.channel = SmsChannel.unknown,
    this.flags = const {},
  });

  const SmsParseResult.ignored(SmsIgnoreReason reason)
    : this(kind: SmsKind.ignore, ignoreReason: reason);

  final SmsKind kind;
  final SmsIgnoreReason? ignoreReason;
  final int? amountPaise;
  final String? accountLast4;

  /// Lowercase bank key, e.g. `hdfc`, `sbi`.
  final String? bankHint;

  /// Payee/payer name or UPI VPA.
  final String? merchant;
  final DateTime? date;
  final String? refNo;
  final SmsChannel channel;
  final Set<SmsFlag> flags;

  @override
  String toString() =>
      'SmsParseResult($kind, $amountPaise, a/c $accountLast4, $bankHint, '
      '"$merchant", $date, ref $refNo, $channel, $flags'
      '${ignoreReason == null ? '' : ', $ignoreReason'})';
}

const _ci = false; // caseSensitive: false, kept short for the patterns below.

final _otp = RegExp(
  r'\bOTP\b|one[- ]time password|verification code',
  caseSensitive: _ci,
);
final _debitVerb = RegExp(
  r'\b(debited|debit|spent|sent|paid|withdrawn|executed|purchase)\b',
  caseSensitive: _ci,
);
final _creditVerb = RegExp(
  r'\b(credited|received|refund(?:ed)?|deposited|reversed)\b',
  caseSensitive: _ci,
);

const _num = r'(\d[\d,]*(?:\.\d{1,2})?)';
final _currencyAmount = RegExp('(?:rs\\.?|inr|₹)\\s*$_num', caseSensitive: _ci);
// SBI style: "debited by 120.0" with no currency marker.
final _verbAmount = RegExp(
  '(?:debited|credited)\\s+(?:by|with|for)\\s+(?:rs\\.?|inr|₹)?\\s*$_num',
  caseSensitive: _ci,
);
final _notTxnAmount = RegExp(r'(bal|limit|lmt|up ?to)\W*$', caseSensitive: _ci);

final _account = RegExp(
  r'(?:a/?c|acct|account|card)(?:\s*no\.?)?\s*[:\-]?\s*[*xX.]*\s*(\d{3,6})\b',
  caseSensitive: _ci,
);
final _fromAccount = RegExp(
  r'from\s+(?:your\s+)?(?:[a-z]+\s+bank\s+)?(?:a/?c|acct|account)(?:\s*no\.?)?\s*[*xX.]*\s*(\d{3,6})\b',
  caseSensitive: _ci,
);

const _banks = {
  'hdfc': 'hdfc',
  'sbi': 'sbi',
  'icici': 'icici',
  'axis': 'axis',
  'kotak': 'kotak',
  'idfc': 'idfc',
  'pnb': 'pnb',
  'canara': 'canara',
  'indusind': 'indusind',
  'federal': 'federal',
  'bob': 'bob',
  'bank of baroda': 'bob',
  'yes bank': 'yes',
  'au bank': 'au',
};
final _bank = RegExp(
  '\\b(${_banks.keys.map(RegExp.escape).join('|')})\\b',
  caseSensitive: _ci,
);

final _ref = RegExp(
  r'(?:utr|ref(?:erence)?)(?:\s*no\.?|no)?\s*[:.#-]?\s*(\d{6,})',
  caseSensitive: _ci,
);

const _months = {
  'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'may': 5, 'jun': 6, //
  'jul': 7, 'aug': 8, 'sep': 9, 'oct': 10, 'nov': 11, 'dec': 12,
};
final _numericDate = RegExp(r'\b(\d{1,2})[-/](\d{1,2})[-/](\d{4}|\d{2})\b');
final _namedDate = RegExp(
  r'\b(\d{1,2})[- ]?(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)[a-z]*[- ,]?(\d{4}|\d{2})\b',
  caseSensitive: _ci,
);

// Merchant patterns. A name starts with a letter (so dates, phone numbers
// and "9XXXX" are skipped) and stops before a connector word or sentence end.
const _name = r"([A-Za-z][A-Za-z0-9 &*._'-]*?)";
const _stop =
    r"(?=\s+(?:via|on|ref\w*|upi|avl|a/c|has|is|was|towards)\b|[.;]\s|[.;]?$|\n)";
const _title = r'(?:(?:mr|ms|mrs|shri|smt)\.?\s+)?';
RegExp _m(String p) => RegExp(p, caseSensitive: _ci, multiLine: true);

final _vpa = RegExp(r'\b[a-z0-9][\w.\-]*@[a-z]{2,}\b', caseSensitive: _ci);
final _debitMerchant = [
  _m('^to\\s+$_title$_name\\s*\$'), // HDFC line format: "To SWIGGY"
  _m('\\b(?:trf|transferred|paid|sent)\\s+to\\s+$_title$_name$_stop'),
  _m(';\\s*$_name\\s+credited\\b'), // "...; ZOMATO credited"
  _m('\\bfor\\s+$_name\\s+(?:has|was|is)\\b'), // "AutoPay ... for NETFLIX has"
  _m('\\bat\\s+$_name$_stop'),
  _m('\\bon\\s+$_name$_stop'),
  _m('\\bto\\s+$_title$_name$_stop'),
];
final _creditMerchant = [
  _m('\\bfrom\\s+$_title$_name$_stop'),
  _m('\\bat\\s+$_name$_stop'),
  _m('\\bby\\s+$_title$_name$_stop'),
];
const _notMerchant = {
  'your', 'you', 'the', 'date', 'a', 'an', 'account', 'card', 'neft', //
  'imps', 'rtgs', 'upi', 'nach', 'loan',
};

/// Parses a bank / UPI / card SMS (shared into the app) into transaction
/// fields. Pure and side-effect free.
SmsParseResult parseBankSms(String text) {
  final t = text.trim();
  if (t.isEmpty) {
    return const SmsParseResult.ignored(SmsIgnoreReason.noTransaction);
  }
  if (_otp.hasMatch(t)) {
    return const SmsParseResult.ignored(SmsIgnoreReason.otp);
  }

  final debit = _debitVerb.firstMatch(t);
  final credit = _creditVerb.firstMatch(t);
  final SmsKind kind;
  if (debit == null && credit == null) {
    return const SmsParseResult.ignored(SmsIgnoreReason.noTransaction);
  } else if (credit == null || (debit != null && debit.start < credit.start)) {
    kind = SmsKind.debit;
  } else {
    kind = SmsKind.credit;
  }

  final amount = _amount(t);
  if (amount == null || amount <= 0) {
    return const SmsParseResult.ignored(SmsIgnoreReason.noAmount);
  }

  return SmsParseResult(
    kind: kind,
    amountPaise: amount,
    accountLast4: _accountLast4(t, kind),
    bankHint: _banks[_bank.firstMatch(t)?.group(1)?.toLowerCase()],
    merchant: _merchant(t, kind),
    date: _date(t),
    refNo: _ref.firstMatch(t)?.group(1),
    channel: _channel(t),
    flags: _flags(t),
  );
}

int? _amount(String t) {
  final candidates = [
    ..._currencyAmount.allMatches(t),
    ..._verbAmount.allMatches(t),
  ]..sort((a, b) => a.start.compareTo(b.start));
  for (final m in candidates) {
    final before = t.substring(m.start < 20 ? 0 : m.start - 20, m.start);
    if (_notTxnAmount.hasMatch(before)) continue;
    final paise = parseRupeesToPaise(m.group(1)!);
    if (paise != null) return paise;
  }
  return null;
}

String? _accountLast4(String t, SmsKind kind) {
  final digits =
      (kind == SmsKind.debit ? _fromAccount.firstMatch(t) : null)?.group(1) ??
      _account.firstMatch(t)?.group(1);
  if (digits == null) return null;
  return digits.length <= 4 ? digits : digits.substring(digits.length - 4);
}

String? _merchant(String t, SmsKind kind) {
  final vpa = _vpa.firstMatch(t)?.group(0);
  if (vpa != null) return vpa;
  for (final re in kind == SmsKind.debit ? _debitMerchant : _creditMerchant) {
    for (final m in re.allMatches(t)) {
      final name = m.group(1)!.trim().replaceAll(RegExp(r'\s+'), ' ');
      final first = name.split(' ').first.toLowerCase();
      if (name.isEmpty || _notMerchant.contains(first)) continue;
      return name;
    }
  }
  return null;
}

DateTime? _date(String t) {
  final n = _numericDate.firstMatch(t);
  final w = _namedDate.firstMatch(t);
  final useNamed = w != null && (n == null || w.start < n.start);
  final RegExpMatch m;
  final int month;
  if (useNamed) {
    m = w;
    month = _months[m.group(2)!.toLowerCase()]!;
  } else if (n != null) {
    m = n;
    month = int.parse(m.group(2)!);
  } else {
    return null;
  }
  final day = int.parse(m.group(1)!);
  final y = m.group(3)!;
  final year = y.length == 2 ? 2000 + int.parse(y) : int.parse(y);
  if (month < 1 || month > 12 || day < 1) return null;
  final d = DateTime(year, month, day);
  return (d.month == month && d.day == day) ? d : null;
}

SmsChannel _channel(String t) {
  bool has(String p) => RegExp(p, caseSensitive: _ci).hasMatch(t);
  if (has(r'\batm\b|withdrawn')) return SmsChannel.atm;
  if (has(r'\bupi\b|\bvpa\b') || _vpa.hasMatch(t)) return SmsChannel.upi;
  if (has(r'\bcard\b')) return SmsChannel.card;
  if (has(r'\b(nach|ecs)\b')) return SmsChannel.nach;
  if (has(r'\b(neft|imps|rtgs)\b')) return SmsChannel.netbanking;
  return SmsChannel.unknown;
}

Set<SmsFlag> _flags(String t) {
  bool has(String p) => RegExp(p, caseSensitive: _ci).hasMatch(t);
  return {
    if (has(r'\brefund|\breversal|\breversed')) SmsFlag.refund,
    if (has(r'autopay|standing instruction|\bmandate\b')) SmsFlag.autopay,
    if (has(r'\bemi\b')) SmsFlag.emi,
    if (has(r'payment of .* received|received towards your credit card'))
      SmsFlag.cardPayment,
  };
}

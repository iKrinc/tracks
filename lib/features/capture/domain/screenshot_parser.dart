import 'package:tracks/core/money.dart';
import 'package:tracks/features/capture/domain/sms_parser.dart';

/// Fields read from the OCR text of a GPay / PhonePe / Paytm (or bank app)
/// payment screenshot.
class ScreenshotParse {
  const ScreenshotParse({
    required this.kind,
    required this.amountPaise,
    this.merchant,
    this.vpa,
    this.accountLast4,
    this.bankHint,
    this.refNo,
    this.date,
    this.time,
  });

  final SmsKind kind;
  final int amountPaise;
  final String? merchant;
  final String? vpa;
  final String? accountLast4;
  final String? bankHint;
  final String? refNo;
  final DateTime? date;
  final ClockTime? time;
}

const _ci = false;
final _received = RegExp(
  r'received from|money received|credited to',
  caseSensitive: _ci,
);
final _paid = RegExp(
  r'paid to|paid successfully|payment successful|debited from|sent to|transaction successful',
  caseSensitive: _ci,
);
// A line that is just an amount. OCR often reads ₹ as %, z or 2-with-no-space
// is too ambiguous, so only symbol-like prefixes are accepted.
final _amountLine = RegExp(
  r'^\s*(?:₹|rs\.?|inr|%|z)\s*([\d,]+(?:\.\d{1,2})?)\s*$',
  caseSensitive: _ci,
);
final _trailing4 = RegExp(r'(?<![\d.,])(\d{4})\s*$');
final _header = RegExp(r'^(to|from)\s+(?![:\s])(.{2,60})$', caseSensitive: _ci);
final _completed = RegExp(
  r'completed|successful|success|paid',
  caseSensitive: _ci,
);
final _bareAmount = RegExp(r'^\s*([\d,]{1,9}(?:\.\d{1,2})?)\s*$');
final _vpa = RegExp(r'\b[a-z0-9][\w.\-]*@[a-z]{2,}\b', caseSensitive: _ci);
final _last4 = RegExp(r'(?:•{2,}|[xX*]{2,}|\s-)\s*(\d{4})\b');
final _ref = RegExp(
  r'(?:utr|upi transaction id|upi ref\.?\s*no|ref\.?\s*no)\.?\s*[:#]?\s*(\d{9,})',
  caseSensitive: _ci,
);
final _date = RegExp(
  r'\b(\d{1,2})\s+(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)[a-z]*\.?,?\s+(\d{4})\b',
  caseSensitive: _ci,
);
const _months = {
  'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'may': 5, 'jun': 6, //
  'jul': 7, 'aug': 8, 'sep': 9, 'oct': 10, 'nov': 11, 'dec': 12,
};
const _banks = {
  'state bank of india': 'sbi',
  'sbi': 'sbi',
  'hdfc': 'hdfc',
  'icici': 'icici',
  'axis': 'axis',
  'kotak': 'kotak',
  'idfc': 'idfc',
  'yes bank': 'yes',
  'bank of baroda': 'bob',
  'punjab national': 'pnb',
  'canara': 'canara',
};

/// Reads a payment screenshot's OCR text. Returns null when it doesn't look
/// like a completed payment (so the caller can try the SMS parser instead).
ScreenshotParse? parsePaymentScreenshot(String text) {
  final lines = [
    for (final l in text.split('\n'))
      if (l.trim().isNotEmpty) l.trim(),
  ];
  final all = lines.join('\n');
  // GPay (2025+) leads with "To NAME" / "From NAME" (no colon) above the
  // amount; older layouts and other apps say "Paid to" / "Received from".
  int? headerAt;
  SmsKind? headerKind;
  String? headerName;
  for (var i = 0; i < lines.length && i < 6; i++) {
    final m = _header.firstMatch(lines[i]);
    if (m != null) {
      headerAt = i;
      headerKind = m.group(1)!.toLowerCase() == 'to'
          ? SmsKind.debit
          : SmsKind.credit;
      headerName = m.group(2)!.trim();
      break;
    }
  }
  final SmsKind kind;
  if (_received.hasMatch(all)) {
    kind = SmsKind.credit;
  } else if (_paid.hasMatch(all)) {
    kind = SmsKind.debit;
  } else if (headerKind != null && _completed.hasMatch(all)) {
    kind = headerKind;
  } else {
    return null;
  }

  int? amount;
  for (final l in lines) {
    final m = _amountLine.firstMatch(l);
    if (m != null) {
      amount = parseRupeesToPaise(m.group(1)!);
      if (amount != null && amount > 0) break;
    }
  }
  // OCR sometimes drops the big ₹: accept a bare number right below the
  // header (never a year, time or 6+ digit reference).
  if ((amount == null || amount <= 0) && headerAt != null) {
    for (var i = headerAt + 1; i < lines.length && i <= headerAt + 3; i++) {
      final m = _bareAmount.firstMatch(lines[i]);
      if (m != null) {
        amount = parseRupeesToPaise(m.group(1)!);
        break;
      }
    }
  }
  if (amount == null || amount <= 0) return null;

  // Merchant / person: "Paid to X" (same or next line), "Received from X",
  // then "To: X" / "From: X" as a fallback.
  String? clean(String s) {
    final v = s.replaceAll(_vpa, '').trim();
    return v.isEmpty ? null : v;
  }

  String? merchant = headerName == null ? null : clean(headerName);

  for (var i = 0; i < lines.length && merchant == null; i++) {
    final m = RegExp(
      r'^(?:paid to|received from|sent to)\s*(.*)$',
      caseSensitive: _ci,
    ).firstMatch(lines[i]);
    if (m == null) continue;
    final rest = m.group(1)!.trim();
    merchant = rest.isNotEmpty
        ? clean(rest)
        : (i + 1 < lines.length ? clean(lines[i + 1]) : null);
  }
  final counterpartLabel = kind == SmsKind.debit ? 'to' : 'from';
  for (final l in lines) {
    if (merchant != null) break;
    final m = RegExp(
      '^$counterpartLabel\\s*:\\s*(.+)\$',
      caseSensitive: _ci,
    ).firstMatch(l);
    if (m != null && !_isBankLine(m.group(1)!)) merchant = clean(m.group(1)!);
  }

  // Own account: the bank line with masked digits ("From: HDFC •••• 1234",
  // "Debited from XXXX5678", "To: Kotak •••• 7890" when receiving).
  String? last4;
  String? bank;
  for (final l in lines) {
    final m = _last4.firstMatch(l);
    if (m != null) {
      last4 = m.group(1);
      bank = _bankIn(l);
      break;
    }
  }
  // OCR often garbles or drops the mask ("*** * 1234", "Bank 1234"): fall
  // back to the bank line's trailing four digits.
  if (last4 == null) {
    for (final l in lines) {
      // A UPI id like zomato@hdfcbank names the payee's bank, not yours.
      if (_vpa.hasMatch(l)) continue;
      final b = _bankIn(l);
      if (b == null) continue;
      bank = b;
      last4 = _trailing4.firstMatch(l)?.group(1);
      break;
    }
  }

  DateTime? date;
  ClockTime? time;
  final dm = _date.firstMatch(all);
  if (dm != null) {
    final d = int.parse(dm.group(1)!);
    final mo = _months[dm.group(2)!.toLowerCase()]!;
    final y = int.parse(dm.group(3)!);
    final dt = DateTime(y, mo, d);
    if (dt.month == mo && dt.day == d) {
      date = dt;
      time = timeAfter(all, dm.end);
    }
  }
  // PhonePe puts the time first: "09:15 pm on 20 Oct 2026".
  if (time == null && dm != null) {
    final before = all.substring(0, dm.start);
    final t = RegExp(
      r'(\d{1,2}:\d{2}\s*[ap]\.?m\.?)\s+on\s*$',
      caseSensitive: false,
    ).firstMatch(before);
    if (t != null) time = timeAfter(t.group(1)!, 0);
  }

  return ScreenshotParse(
    kind: kind,
    amountPaise: amount,
    merchant: merchant,
    vpa: _fullVpa(all),
    accountLast4: last4,
    bankHint: bank,
    refNo: _ref.firstMatch(all)?.group(1),
    date: date,
    time: time,
  );
}

/// The first UPI id that isn't masked ("••••29-2@ybl" is useless).
String? _fullVpa(String text) {
  for (final m in _vpa.allMatches(text)) {
    final before = m.start == 0 ? '' : text[m.start - 1];
    if (before == '•' || before == '*' || before == '.') continue;
    return m.group(0);
  }
  return null;
}

bool _isBankLine(String s) => _bankIn(s) != null || _last4.hasMatch(s);

String? _bankIn(String s) {
  final lower = s.toLowerCase();
  for (final e in _banks.entries) {
    if (lower.contains(e.key)) return e.value;
  }
  return null;
}

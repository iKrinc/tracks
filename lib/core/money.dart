/// Money helpers. Amounts are always integer paise — never `double`.
library;

final _prefix = RegExp(r'^(?:₹|rs\.?|inr)\s*', caseSensitive: false);
final _digits = RegExp(r'^\d*$');

/// Parses a rupee string such as `"1,23,456.78"`, `"Rs.500"`, `"₹ 99.99"` or
/// `"500/-"` into paise. Returns `null` for anything that isn't a
/// non-negative amount with at most two decimals.
int? parseRupeesToPaise(String input) {
  var s = input.trim().replaceFirst(_prefix, '').trim();
  if (s.endsWith('/-')) s = s.substring(0, s.length - 2).trim();
  s = s.replaceAll(',', '');
  if (s.isEmpty) return null;

  final parts = s.split('.');
  if (parts.length > 2) return null;
  final whole = parts[0];
  final frac = parts.length == 2 ? parts[1] : '';
  if (whole.isEmpty && frac.isEmpty) return null;
  if (!_digits.hasMatch(whole) || !_digits.hasMatch(frac)) return null;
  if (frac.length > 2) return null;

  final rupees = whole.isEmpty ? 0 : int.parse(whole);
  final paise = frac.isEmpty ? 0 : int.parse(frac.padRight(2, '0'));
  return rupees * 100 + paise;
}

/// Formats paise with Indian digit grouping, e.g. `12345678` → `₹1,23,456.78`.
String formatPaise(
  int paise, {
  bool symbol = true,
  bool hideZeroPaise = false,
}) {
  final negative = paise < 0;
  final abs = paise.abs();
  final rupees = abs ~/ 100;
  final rem = abs % 100;

  final buf = StringBuffer();
  if (negative) buf.write('-');
  if (symbol) buf.write('₹');
  buf.write(_groupIndian(rupees.toString()));
  if (!(hideZeroPaise && rem == 0)) {
    buf.write('.');
    buf.write(rem.toString().padLeft(2, '0'));
  }
  return buf.toString();
}

/// Groups digits as 1,23,45,678: last three, then pairs.
String _groupIndian(String digits) {
  if (digits.length <= 3) return digits;
  final last3 = digits.substring(digits.length - 3);
  var head = digits.substring(0, digits.length - 3);
  final groups = <String>[];
  while (head.length > 2) {
    groups.insert(0, head.substring(head.length - 2));
    head = head.substring(0, head.length - 2);
  }
  if (head.isNotEmpty) groups.insert(0, head);
  return '${groups.join(',')},$last3';
}

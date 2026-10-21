/// The bits of an account needed for matching (keeps this pure).
typedef MatchableAccount = ({int id, String name, String matchHints});

/// Picks the account a capture refers to: by card/account last 4 digits,
/// then by keyword (hints and name words), then by bank. Null if unsure.
int? matchAccount(
  Iterable<MatchableAccount> accounts, {
  String? hint,
  String? last4,
  String? bank,
}) {
  List<String> hintsOf(MatchableAccount a) => [
    for (final h in a.matchHints.toLowerCase().split(','))
      if (h.trim().isNotEmpty) h.trim(),
  ];

  if (last4 != null) {
    for (final a in accounts) {
      if (hintsOf(a).any((h) => h.endsWith(last4) && _isDigitsTail(h))) {
        return a.id;
      }
    }
  }
  if (hint != null) {
    final h = hint.toLowerCase();
    for (final a in accounts) {
      if (hintsOf(a).contains(h) ||
          a.name.toLowerCase().split(' ').contains(h)) {
        return a.id;
      }
    }
  }
  if (bank != null) {
    for (final a in accounts) {
      if (hintsOf(a).contains(bank) ||
          a.name.toLowerCase().split(' ').contains(bank)) {
        return a.id;
      }
    }
  }
  return null;
}

/// Hints to store on an account created from a capture, so the next SMS
/// for it matches automatically.
String suggestedHints({String? last4, String? bank}) =>
    [?bank, ?last4].join(',');

bool _isDigitsTail(String h) => RegExp(r'^(?:x*|\*+)\d{3,6}$').hasMatch(h);

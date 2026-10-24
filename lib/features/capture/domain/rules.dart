/// Rules learned from corrections: "always put SWIGGY in Food delivery".
/// Pure functions; the Rules table stores the keyword this produces.
library;

typedef RuleLike = ({int id, String keyword, int? categoryId, int? accountId});

const _maxKey = 40;
final _nonWord = RegExp(r'[^a-z0-9]+');

/// Lowercased words only, digit-only words dropped.
String _words(String s) => s
    .toLowerCase()
    .split(_nonWord)
    .where((w) => w.isNotEmpty && !RegExp(r'^\d+$').hasMatch(w))
    .join(' ');

/// The keyword a correction is remembered under: the merchant (a UPI id's
/// name part, so zomato@hdfcbank → "zomato"), else the note. Null when
/// there's nothing meaningful to key on.
String? ruleKey({required String? merchant, required String note}) {
  var source = (merchant ?? '').trim();
  if (source.isEmpty) source = note.trim();
  final at = source.indexOf('@');
  if (at > 0) source = source.substring(0, at).split('.').first;
  final key = _words(source);
  if (key.length < 3) return null;
  return key.length <= _maxKey ? key : key.substring(0, _maxKey).trim();
}

/// The rule for a capture: an exact key match, else the longest keyword
/// found as whole words in the merchant or note.
RuleLike? findRule(
  Iterable<RuleLike> rules, {
  required String? merchant,
  required String note,
}) {
  final key = ruleKey(merchant: merchant, note: note);
  final haystack = ' ${_words('${merchant ?? ''} $note')} ';
  if (haystack.trim().isEmpty) return null;
  RuleLike? best;
  for (final r in rules) {
    if (r.keyword == key) return r;
    if (haystack.contains(' ${r.keyword} ') &&
        (best == null || r.keyword.length > best.keyword.length)) {
      best = r;
    }
  }
  return best;
}

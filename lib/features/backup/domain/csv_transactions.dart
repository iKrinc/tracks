import 'package:csv/csv.dart';
import 'package:tracks/core/money.dart';
import 'package:tracks/data/tables.dart';

/// Columns of Tracks' own CSV export, in order.
const csvHeaders = [
  'Date',
  'Type',
  'Amount',
  'Account',
  'To account',
  'Category',
  'Note',
  'Merchant',
  'Tags',
  'Ref',
];

enum CsvField {
  date,
  type,
  amount,
  account,
  toAccount,
  category,
  note,
  merchant,
  tags,
  ref,
}

/// Field → column index.
typedef CsvMapping = Map<CsvField, int>;

/// One transaction as plain text names (accounts/categories unresolved).
class CsvTxnRow {
  const CsvTxnRow({
    required this.date,
    required this.type,
    required this.amountPaise,
    required this.account,
    this.toAccount,
    this.category,
    this.note = '',
    this.merchant,
    this.tags = '',
    this.ref,
  });

  final DateTime date;
  final TxnType type;
  final int amountPaise;
  final String account;
  final String? toAccount;
  final String? category;
  final String note;
  final String? merchant;
  final String tags;
  final String? ref;
}

final _csv = Csv(lineDelimiter: '\n');

List<List<String>> decodeCsv(String text) => [
  for (final row in _csv.decode(text))
    [for (final cell in row) '${cell ?? ''}'],
];

String transactionsToCsv(Iterable<CsvTxnRow> rows) =>
    '${_csv.encode([
      csvHeaders,
      for (final r in rows) [_formatDate(r.date), r.type.name, _plainRupees(r.amountPaise), r.account, r.toAccount ?? '', r.category ?? '', r.note, r.merchant ?? '', r.tags, r.ref ?? ''],
    ])}\n';

String _two(int n) => n.toString().padLeft(2, '0');

String _formatDate(DateTime d) =>
    '${d.year}-${_two(d.month)}-${_two(d.day)} ${_two(d.hour)}:${_two(d.minute)}';

/// `123450` → `1234.50`: no symbol, no grouping, for spreadsheets.
String _plainRupees(int paise) {
  final sign = paise < 0 ? '-' : '';
  final abs = paise.abs();
  return '$sign${abs ~/ 100}.${_two(abs % 100)}';
}

const _aliases = <CsvField, List<String>>{
  CsvField.date: [
    'date',
    'period',
    'txn date',
    'transaction date',
    'value date',
    'time',
  ],
  CsvField.type: ['type', 'income/expense', 'dr/cr', 'kind'],
  CsvField.amount: [
    'amount',
    'inr',
    'amount (inr)',
    'withdrawal amt',
    'debit',
    'value',
  ],
  CsvField.account: ['account', 'accounts', 'from account', 'wallet'],
  CsvField.toAccount: ['to account', 'to'],
  CsvField.category: ['category'],
  CsvField.note: ['note', 'notes', 'narration', 'remarks', 'memo'],
  CsvField.merchant: ['merchant', 'description', 'payee'],
  CsvField.tags: ['tags', 'tag', 'labels'],
  CsvField.ref: [
    'ref',
    'reference',
    'ref no',
    'ref no.',
    'utr',
    'chq./ref.no.',
  ],
};

/// Best guess of which column holds what, from the header row.
CsvMapping guessMapping(List<String> headers) {
  final norm = [for (final h in headers) h.trim().toLowerCase()];
  final mapping = <CsvField, int>{};
  final used = <int>{};
  for (final field in CsvField.values) {
    for (final alias in _aliases[field]!) {
      final i = norm.indexOf(alias);
      if (i >= 0 && !used.contains(i)) {
        mapping[field] = i;
        used.add(i);
        break;
      }
    }
  }
  return mapping;
}

const _months = {
  'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'may': 5, 'jun': 6, //
  'jul': 7, 'aug': 8, 'sep': 9, 'oct': 10, 'nov': 11, 'dec': 12,
};
final _iso = RegExp(
  r'^(\d{4})-(\d{1,2})-(\d{1,2})(?:[ T](\d{1,2}):(\d{2})(?::\d{2})?)?',
);
final _dmy = RegExp(
  r'^(\d{1,2})[/.-](\d{1,2})[/.-](\d{4}|\d{2})(?:\s+(\d{1,2}):(\d{2})(?::\d{2})?)?',
);
final _dMonY = RegExp(
  r'^(\d{1,2})[ -]([a-z]{3})[a-z]*[ -,]+(\d{4}|\d{2})',
  caseSensitive: false,
);

/// Parses the date formats people actually export: ISO, dd/mm/yyyy (Indian
/// order, never US), dd-mm-yy and "21 Oct 2026", with optional HH:mm.
DateTime? parseFlexibleDate(String input) {
  final s = input.trim();
  int y(String v) => v.length == 2 ? 2000 + int.parse(v) : int.parse(v);
  int? opt(String? v) => v == null ? null : int.parse(v);

  RegExpMatch? m;
  int year, month, day;
  int? hour, minute;
  if ((m = _iso.firstMatch(s)) != null) {
    year = int.parse(m!.group(1)!);
    month = int.parse(m.group(2)!);
    day = int.parse(m.group(3)!);
    hour = opt(m.group(4));
    minute = opt(m.group(5));
  } else if ((m = _dmy.firstMatch(s)) != null) {
    day = int.parse(m!.group(1)!);
    month = int.parse(m.group(2)!);
    year = y(m.group(3)!);
    hour = opt(m.group(4));
    minute = opt(m.group(5));
  } else if ((m = _dMonY.firstMatch(s)) != null) {
    final mon = _months[m!.group(2)!.toLowerCase()];
    if (mon == null) return null;
    day = int.parse(m.group(1)!);
    month = mon;
    year = y(m.group(3)!);
  } else {
    return null;
  }
  if (month < 1 || month > 12 || day < 1) return null;
  final d = DateTime(year, month, day, hour ?? 0, minute ?? 0);
  return (d.month == month && d.day == day) ? d : null;
}

TxnType? _typeWord(String raw) {
  final s = raw.trim().toLowerCase().replaceAll('.', '');
  if (s.isEmpty) return null;
  if (const {'income', 'inc', 'credit', 'cr', 'deposit'}.contains(s)) {
    return TxnType.income;
  }
  if (const {'expense', 'exp', 'debit', 'dr', 'withdrawal'}.contains(s)) {
    return TxnType.expense;
  }
  if (s.startsWith('transfer') || s == 'trf') return TxnType.transfer;
  return null;
}

/// Turns a decoded table (header row first) into rows. Bad rows are skipped
/// and explained in `errors` (1-based row numbers, header = row 1). Without
/// a type column, a negative amount is an expense and a positive one income.
({List<CsvTxnRow> rows, List<String> errors}) parseCsvRows(
  List<List<String>> table,
  CsvMapping mapping, {
  String defaultAccount = 'Cash',
}) {
  final rows = <CsvTxnRow>[];
  final errors = <String>[];
  String? cell(List<String> row, CsvField f) {
    final i = mapping[f];
    if (i == null || i >= row.length) return null;
    final v = row[i].trim();
    return v.isEmpty ? null : v;
  }

  for (var r = 1; r < table.length; r++) {
    final row = table[r];
    final n = r + 1;
    final dateText = cell(row, CsvField.date) ?? '';
    final date = parseFlexibleDate(dateText);
    if (date == null) {
      errors.add('Row $n: date "$dateText" not recognised');
      continue;
    }
    var amountText = cell(row, CsvField.amount) ?? '';
    var negative = false;
    if (amountText.startsWith('-') || amountText.startsWith('−')) {
      negative = true;
      amountText = amountText.substring(1);
    } else if (amountText.startsWith('(') && amountText.endsWith(')')) {
      negative = true;
      amountText = amountText.substring(1, amountText.length - 1);
    }
    final paise = parseRupeesToPaise(amountText);
    if (paise == null) {
      errors.add(
        'Row $n: amount "${cell(row, CsvField.amount) ?? ''}" is not a number',
      );
      continue;
    }
    if (paise == 0) {
      errors.add('Row $n: amount is zero');
      continue;
    }
    final type =
        _typeWord(cell(row, CsvField.type) ?? '') ??
        (negative ? TxnType.expense : TxnType.income);
    rows.add(
      CsvTxnRow(
        date: date,
        type: type,
        amountPaise: paise,
        account: cell(row, CsvField.account) ?? defaultAccount,
        toAccount: cell(row, CsvField.toAccount),
        category: cell(row, CsvField.category),
        note: cell(row, CsvField.note) ?? '',
        merchant: cell(row, CsvField.merchant),
        tags: cell(row, CsvField.tags) ?? '',
        ref: cell(row, CsvField.ref),
      ),
    );
  }
  return (rows: rows, errors: errors);
}

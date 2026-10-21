const _months = [
  'January', 'February', 'March', 'April', 'May', 'June', //
  'July', 'August', 'September', 'October', 'November', 'December',
];
const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

DateTime monthStart(DateTime d) => DateTime(d.year, d.month);

/// First instant of the month after [d]'s month.
DateTime nextMonthStart(DateTime d) => DateTime(d.year, d.month + 1);

/// Cells for a month grid: leading nulls up to the first day, then every
/// day of the month, padded with nulls to whole weeks.
List<DateTime?> calendarCells(
  DateTime month, {
  int firstWeekday = DateTime.monday,
}) {
  final first = DateTime(month.year, month.month);
  final days = DateTime(month.year, month.month + 1, 0).day;
  final lead = (first.weekday - firstWeekday + 7) % 7;
  final cells = <DateTime?>[
    for (var i = 0; i < lead; i++) null,
    for (var d = 1; d <= days; d++) DateTime(month.year, month.month, d),
  ];
  while (cells.length % 7 != 0) {
    cells.add(null);
  }
  return cells;
}

/// "October 2026"
String monthLabel(DateTime d) => '${_months[d.month - 1]} ${d.year}';

/// "Wed"
String weekdayShort(DateTime d) => _weekdays[d.weekday - 1];

/// "21 Oct 2026"
String shortDate(DateTime d) =>
    '${d.day} ${_months[d.month - 1].substring(0, 3)} ${d.year}';

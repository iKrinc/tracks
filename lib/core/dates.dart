const _months = [
  'January', 'February', 'March', 'April', 'May', 'June', //
  'July', 'August', 'September', 'October', 'November', 'December',
];
const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

DateTime monthStart(DateTime d) => DateTime(d.year, d.month);

/// First instant of the month after [d]'s month.
DateTime nextMonthStart(DateTime d) => DateTime(d.year, d.month + 1);

/// "October 2026"
String monthLabel(DateTime d) => '${_months[d.month - 1]} ${d.year}';

/// "Wed"
String weekdayShort(DateTime d) => _weekdays[d.weekday - 1];

/// "21 Oct 2026"
String shortDate(DateTime d) =>
    '${d.day} ${_months[d.month - 1].substring(0, 3)} ${d.year}';

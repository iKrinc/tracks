import 'package:flutter_test/flutter_test.dart';
import 'package:tracks/core/dates.dart';

void main() {
  test('October 2026 starts on Thursday: 3 blanks in a Monday-first grid', () {
    final cells = calendarCells(DateTime(2026, 10));
    expect(cells.take(3), [null, null, null]);
    expect(cells[3], DateTime(2026, 10, 1));
    expect(cells.whereType<DateTime>().length, 31);
    expect(cells.length % 7, 0);
  });

  test('a month starting on Monday has no leading blanks', () {
    // 1 June 2026 is a Monday.
    expect(calendarCells(DateTime(2026, 6)).first, DateTime(2026, 6, 1));
  });

  test('Sunday-first grids', () {
    final cells = calendarCells(
      DateTime(2026, 10),
      firstWeekday: DateTime.sunday,
    );
    expect(cells.take(4), [null, null, null, null]);
  });

  test('February in a leap year', () {
    expect(calendarCells(DateTime(2028, 2)).whereType<DateTime>().length, 29);
  });
}

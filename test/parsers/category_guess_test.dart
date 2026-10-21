import 'package:flutter_test/flutter_test.dart';
import 'package:tracks/features/capture/domain/category_guess.dart';

void main() {
  const names = [
    'Snacks & Chai',
    'Fuel',
    'Rent',
    'Salary',
    'Cab & Auto',
    'Food delivery',
    'Mobile recharge',
    'Groceries',
    'Movies',
  ];

  String? g(String d) => guessCategoryName(d, names);

  test('built-in keywords', () {
    expect(g('chai'), 'Snacks & Chai');
    expect(g('petrol'), 'Fuel');
    expect(g('Uber to office'), 'Cab & Auto');
    expect(g('swiggy dinner'), 'Food delivery');
    expect(g('jio recharge'), 'Mobile recharge');
    expect(g('salary'), 'Salary');
  });

  test('falls back to category name words', () {
    expect(g('rent'), 'Rent');
    expect(g('movies with friends'), 'Movies');
    expect(g('groceries'), 'Groceries');
  });

  test('keyword only counts if that category exists', () {
    expect(guessCategoryName('petrol', ['Rent']), isNull);
  });

  test('no match', () {
    expect(g('random thing'), isNull);
    expect(g(''), isNull);
  });

  test('matches whole words, not substrings', () {
    expect(g('autograph'), isNull);
  });
}

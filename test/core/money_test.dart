import 'package:flutter_test/flutter_test.dart';
import 'package:tracks/core/money.dart';

void main() {
  group('parseRupeesToPaise', () {
    test('whole rupees', () {
      expect(parseRupeesToPaise('20'), 2000);
      expect(parseRupeesToPaise('0'), 0);
      expect(parseRupeesToPaise('50000'), 5000000);
      expect(parseRupeesToPaise('999999999999'), 99999999999900);
      expect(parseRupeesToPaise('9999999999999'), isNull);
      expect(parseRupeesToPaise('9' * 30), isNull);
    });

    test('decimals are exact, never via double', () {
      expect(parseRupeesToPaise('20.5'), 2050);
      expect(parseRupeesToPaise('20.50'), 2050);
      expect(parseRupeesToPaise('0.01'), 1);
      expect(parseRupeesToPaise('.75'), 75);
      expect(parseRupeesToPaise('10.'), 1000);
      // 0.1 + 0.2 style traps
      expect(parseRupeesToPaise('0.29'), 29);
      expect(parseRupeesToPaise('1.15'), 115);
    });

    test('more than two decimals is rejected', () {
      expect(parseRupeesToPaise('1.234'), isNull);
    });

    test('Indian and western grouping', () {
      expect(parseRupeesToPaise('1,23,456.78'), 12345678);
      expect(parseRupeesToPaise('123,456.78'), 12345678);
      expect(parseRupeesToPaise('1,000'), 100000);
    });

    test('currency prefixes and spacing', () {
      expect(parseRupeesToPaise('Rs.500'), 50000);
      expect(parseRupeesToPaise('Rs 500'), 50000);
      expect(parseRupeesToPaise('rs. 1,500.00'), 150000);
      expect(parseRupeesToPaise('INR 1,000.00'), 100000);
      expect(parseRupeesToPaise('₹500'), 50000);
      expect(parseRupeesToPaise(' ₹ 99.99 '), 9999);
      expect(parseRupeesToPaise('500/-'), 50000);
    });

    test('garbage is rejected', () {
      expect(parseRupeesToPaise(''), isNull);
      expect(parseRupeesToPaise('abc'), isNull);
      expect(parseRupeesToPaise('12a'), isNull);
      expect(parseRupeesToPaise('-5'), isNull);
      expect(parseRupeesToPaise('.'), isNull);
      expect(parseRupeesToPaise(',,'), isNull);
    });
  });

  group('compactPaise', () {
    test('Indian short units for tight spaces', () {
      expect(compactPaise(2000), '20');
      expect(compactPaise(99999), '999');
      expect(compactPaise(120000), '1.2k');
      expect(compactPaise(1000000), '10k');
      expect(compactPaise(15000000), '1.5L');
      expect(compactPaise(230000000), '23L');
      expect(compactPaise(2300000000), '2.3Cr');
      expect(compactPaise(-120000), '-1.2k');
    });
  });

  group('spokenPaise', () {
    test('reads as words for screen readers', () {
      expect(spokenPaise(12000), '120 rupees');
      expect(spokenPaise(12050), '120 rupees 50 paise');
      expect(spokenPaise(100), '1 rupee');
      expect(spokenPaise(5), '5 paise');
      expect(spokenPaise(0), '0 rupees');
      expect(spokenPaise(-2000), 'minus 20 rupees');
    });
  });

  group('formatPaise', () {
    test('Indian grouping', () {
      expect(formatPaise(0), '₹0.00');
      expect(formatPaise(5), '₹0.05');
      expect(formatPaise(2000), '₹20.00');
      expect(formatPaise(100000), '₹1,000.00');
      expect(formatPaise(12345678), '₹1,23,456.78');
      expect(formatPaise(1000000000), '₹1,00,00,000.00');
    });

    test('negative amounts', () {
      expect(formatPaise(-12345678), '-₹1,23,456.78');
      expect(formatPaise(-5), '-₹0.05');
    });

    test('options', () {
      expect(formatPaise(2000, symbol: false), '20.00');
      expect(formatPaise(2000, hideZeroPaise: true), '₹20');
      expect(formatPaise(2050, hideZeroPaise: true), '₹20.50');
    });

    test('round trips with parse', () {
      for (final p in [0, 1, 99, 100, 123456, 987654321]) {
        expect(parseRupeesToPaise(formatPaise(p)), p);
      }
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:tracks/features/capture/domain/rules.dart';

RuleLike _r(int id, String k, {int? cat, int? acc}) =>
    (id: id, keyword: k, categoryId: cat, accountId: acc);

void main() {
  group('ruleKey', () {
    test('merchant wins over note, lowercased', () {
      expect(ruleKey(merchant: 'SWIGGY', note: 'lunch'), 'swiggy');
    });

    test('a UPI id keys on its name part', () {
      expect(ruleKey(merchant: 'zomato@hdfcbank', note: ''), 'zomato');
      expect(ruleKey(merchant: 'bharatpe.90012@icici', note: ''), 'bharatpe');
    });

    test('punctuation and numbers are dropped', () {
      expect(
        ruleKey(merchant: 'Mrs. Lakshmi Dev', note: ''),
        'mrs lakshmi dev',
      );
      expect(ruleKey(merchant: 'AMAZON PAY 12345', note: ''), 'amazon pay');
    });

    test('falls back to the note (quick-add "chai 20")', () {
      expect(ruleKey(merchant: null, note: 'Chai'), 'chai');
      expect(ruleKey(merchant: '  ', note: 'Petrol'), 'petrol');
    });

    test('too short or empty gives no key', () {
      expect(ruleKey(merchant: null, note: ''), isNull);
      expect(ruleKey(merchant: 'X1', note: ''), isNull);
      expect(ruleKey(merchant: '1234567890', note: ''), isNull);
    });

    test('long names are capped', () {
      expect(ruleKey(merchant: 'a' * 100, note: '')!.length, 40);
    });
  });

  group('findRule', () {
    final rules = [
      _r(1, 'swiggy', cat: 10),
      _r(2, 'swiggy instamart', cat: 11),
      _r(3, 'chai', cat: 12),
      _r(4, 'ola', cat: 13),
    ];

    test('exact key match', () {
      expect(findRule(rules, merchant: 'SWIGGY', note: '')?.id, 1);
    });

    test('the longest whole-word keyword wins', () {
      expect(
        findRule(rules, merchant: 'Swiggy Instamart Bangalore', note: '')?.id,
        2,
      );
    });

    test('matches inside the note too', () {
      expect(findRule(rules, merchant: null, note: 'chai with ravi')?.id, 3);
    });

    test('only whole words: "ola" is not in "cola" or "olam"', () {
      expect(findRule(rules, merchant: 'Coca cola', note: ''), isNull);
      expect(findRule(rules, merchant: 'OLAM traders', note: ''), isNull);
      expect(findRule(rules, merchant: 'OLA CABS', note: '')?.id, 4);
    });

    test('no rules, no text: no match', () {
      expect(findRule(const [], merchant: 'swiggy', note: ''), isNull);
      expect(findRule(rules, merchant: null, note: ''), isNull);
    });
  });
}

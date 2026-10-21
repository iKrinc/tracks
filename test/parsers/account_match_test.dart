import 'package:flutter_test/flutter_test.dart';
import 'package:tracks/features/capture/domain/account_match.dart';

void main() {
  const accounts = [
    (id: 1, name: 'Cash', matchHints: 'cash'),
    (id: 2, name: 'HDFC Savings', matchHints: 'hdfc,xx1234'),
    (id: 3, name: 'SBI', matchHints: 'sbi,5678'),
    (id: 4, name: 'ICICI Card', matchHints: 'icici,card,9012'),
  ];

  int? m({String? hint, String? last4, String? bank}) =>
      matchAccount(accounts, hint: hint, last4: last4, bank: bank);

  test('last 4 digits win, with or without an XX prefix in hints', () {
    expect(m(last4: '1234'), 2);
    expect(m(last4: '5678', bank: 'hdfc'), 3);
    expect(m(last4: '9012'), 4);
  });

  test('keyword hint matches hints and name words', () {
    expect(m(hint: 'cash'), 1);
    expect(m(hint: 'savings'), 2);
    expect(m(hint: 'card'), 4);
  });

  test('bank is the last resort', () {
    expect(m(last4: '0000', bank: 'sbi'), 3);
    expect(m(bank: 'hdfc'), 2);
  });

  test('no match is null', () {
    expect(m(), isNull);
    expect(m(last4: '0000', bank: 'axis'), isNull);
    expect(m(hint: 'gpay'), isNull);
  });

  test('suggested hints for a new account', () {
    expect(suggestedHints(last4: '1234', bank: 'hdfc'), 'hdfc,1234');
    expect(suggestedHints(last4: '1234'), '1234');
    expect(suggestedHints(), '');
  });
}

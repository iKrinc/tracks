import 'package:tracks/data/tables.dart';

/// A default category with optional subcategories. Icons are Material icon
/// keys resolved in the UI (see `app/icons.dart`).
class DefaultCategory {
  const DefaultCategory(
    this.name,
    this.icon,
    this.color, [
    this.subs = const [],
  ]);

  final String name;
  final String icon;
  final int color;
  final List<String> subs;
}

// Warm "marigold & chai" fills (see lib/app/theme.dart Palette); dark ink
// on all of them. Each named after what it replaced, for the v4 recolour.
const _sky = 0xFFF3E3C4; // sand
const _blue = 0xFFC9E7DD; // jade
const _lilac = 0xFFE9C9B5; // clay
const _pink = 0xFFF6D5D0; // blush
const _mint = 0xFFD6E7D2; // sage
const _peach = 0xFFF8D2C2; // coral
const _lemon = 0xFFF7EBB5; // butter

/// Fill for new accounts.
const defaultAccountColor = 0xFFFBE3A8; // marigold

/// v4 recolour: the old blue/purple pastels → their warm replacements.
/// Old blue was also the default for user-created accounts.
const legacyCategoryColors = {
  0xFFCBF0F8: _sky,
  0xFFAECBFA: _blue,
  0xFFD7AEFB: _lilac,
  0xFFFDCFE8: _pink,
  0xFFCCF2DD: _mint,
  0xFFFDE2C8: _peach,
  0xFFFFF4B8: _lemon,
};
const legacyAccountColors = {
  0xFFCBF0F8: _sky,
  0xFFAECBFA: defaultAccountColor,
  0xFFD7AEFB: _lilac,
  0xFFFDCFE8: _pink,
  0xFFCCF2DD: _mint,
  0xFFFDE2C8: _peach,
  0xFFFFF4B8: _lemon,
};

const defaultExpenseCategories = [
  DefaultCategory('Food & Dining', 'restaurant', _peach, [
    'Groceries',
    'Restaurants',
    'Snacks & Chai',
    'Food delivery',
  ]),
  DefaultCategory('Transport', 'directions_car', _blue, [
    'Fuel',
    'Cab & Auto',
    'Metro & Bus',
    'Train & Flight',
    'Parking & Toll',
  ]),
  DefaultCategory('Bills & Utilities', 'receipt_long', _sky, [
    'Electricity',
    'Mobile recharge',
    'Internet',
    'Water',
    'Gas / LPG',
    'DTH',
  ]),
  DefaultCategory('Rent', 'home', _lilac),
  DefaultCategory('Shopping', 'shopping_bag', _pink, [
    'Clothes',
    'Electronics',
    'Online shopping',
  ]),
  DefaultCategory('Health', 'medical_services', _mint, [
    'Medicines',
    'Doctor',
    'Insurance',
  ]),
  DefaultCategory('Education', 'school', _blue, ['Fees', 'Books & Courses']),
  DefaultCategory('Entertainment', 'movie', _lilac, [
    'Movies',
    'OTT subscriptions',
    'Outings',
  ]),
  DefaultCategory('Personal care', 'spa', _pink),
  DefaultCategory('Household', 'cleaning_services', _sky, [
    'House help',
    'Repairs',
    'Supplies',
  ]),
  DefaultCategory('Family & Gifts', 'card_giftcard', _peach),
  DefaultCategory('Travel', 'luggage', _blue),
  DefaultCategory('EMI & Loans', 'account_balance', _lemon),
  DefaultCategory('Fees & Charges', 'request_quote', _lemon),
  DefaultCategory('Donations', 'volunteer_activism', _mint),
  DefaultCategory('Other', 'more_horiz', _sky),
];

const defaultIncomeCategories = [
  DefaultCategory('Salary', 'payments', _mint),
  DefaultCategory('Business', 'storefront', _blue),
  DefaultCategory('Interest', 'savings', _lemon),
  DefaultCategory('Refunds & Cashback', 'currency_exchange', _sky),
  DefaultCategory('Gifts received', 'redeem', _pink),
  DefaultCategory('Rental income', 'apartment', _lilac),
  DefaultCategory('Other income', 'more_horiz', _peach),
];

class DefaultAccount {
  const DefaultAccount(this.name, this.type, this.icon, this.color, this.hints);

  final String name;
  final AccountType type;
  final String icon;
  final int color;
  final String hints;
}

const defaultAccounts = [
  DefaultAccount('Cash', AccountType.cash, 'payments', _mint, 'cash'),
];

import 'package:flutter/material.dart';

/// Icon keys stored in the database → Material icons. Keys are strings so
/// backups never depend on icon code points.
const _icons = <String, IconData>{
  'restaurant': Icons.restaurant,
  'directions_car': Icons.directions_car,
  'receipt_long': Icons.receipt_long,
  'home': Icons.home,
  'shopping_bag': Icons.shopping_bag,
  'medical_services': Icons.medical_services,
  'school': Icons.school,
  'movie': Icons.movie,
  'spa': Icons.spa,
  'cleaning_services': Icons.cleaning_services,
  'card_giftcard': Icons.card_giftcard,
  'luggage': Icons.luggage,
  'account_balance': Icons.account_balance,
  'request_quote': Icons.request_quote,
  'volunteer_activism': Icons.volunteer_activism,
  'more_horiz': Icons.more_horiz,
  'payments': Icons.payments,
  'storefront': Icons.storefront,
  'savings': Icons.savings,
  'currency_exchange': Icons.currency_exchange,
  'redeem': Icons.redeem,
  'apartment': Icons.apartment,
  'credit_card': Icons.credit_card,
  'account_balance_wallet': Icons.account_balance_wallet,
  'swap_horiz': Icons.swap_horiz,
};

IconData iconFor(String key) => _icons[key] ?? Icons.label_outline;

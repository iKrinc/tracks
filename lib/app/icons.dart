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
  'person': Icons.person_outline,
  'local_cafe': Icons.local_cafe,
  'local_gas_station': Icons.local_gas_station,
  'fitness_center': Icons.fitness_center,
  'pets': Icons.pets,
  'child_care': Icons.child_care,
  'phone_android': Icons.phone_android,
  'wifi': Icons.wifi,
  'bolt': Icons.bolt,
  'flight': Icons.flight,
  'train': Icons.train,
  'local_hospital': Icons.local_hospital,
  'celebration': Icons.celebration,
  'sports_esports': Icons.sports_esports,
  'checkroom': Icons.checkroom,
  'local_grocery_store': Icons.local_grocery_store,
  'trending_up': Icons.trending_up,
};

/// Icons offered when creating or editing a category.
List<String> get categoryIconKeys => _icons.keys.toList();

IconData iconFor(String key) => _icons[key] ?? Icons.label_outline;

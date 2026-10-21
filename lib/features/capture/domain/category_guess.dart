/// Common Indian spend words → default category names. User-learned Rules
/// take priority over this; it only gives a sensible first guess.
const _keywordToCategory = {
  'chai': 'Snacks & Chai',
  'tea': 'Snacks & Chai',
  'coffee': 'Snacks & Chai',
  'samosa': 'Snacks & Chai',
  'snacks': 'Snacks & Chai',
  'petrol': 'Fuel',
  'diesel': 'Fuel',
  'fuel': 'Fuel',
  'cng': 'Fuel',
  'uber': 'Cab & Auto',
  'ola': 'Cab & Auto',
  'rapido': 'Cab & Auto',
  'auto': 'Cab & Auto',
  'cab': 'Cab & Auto',
  'metro': 'Metro & Bus',
  'bus': 'Metro & Bus',
  'swiggy': 'Food delivery',
  'zomato': 'Food delivery',
  'blinkit': 'Groceries',
  'zepto': 'Groceries',
  'bigbasket': 'Groceries',
  'vegetables': 'Groceries',
  'milk': 'Groceries',
  'kirana': 'Groceries',
  'lunch': 'Restaurants',
  'dinner': 'Restaurants',
  'breakfast': 'Restaurants',
  'recharge': 'Mobile recharge',
  'jio': 'Mobile recharge',
  'airtel': 'Mobile recharge',
  'wifi': 'Internet',
  'broadband': 'Internet',
  'electricity': 'Electricity',
  'eb': 'Electricity',
  'bescom': 'Electricity',
  'lpg': 'Gas / LPG',
  'cylinder': 'Gas / LPG',
  'medicine': 'Medicines',
  'medicines': 'Medicines',
  'pharmacy': 'Medicines',
  'doctor': 'Doctor',
  'netflix': 'OTT subscriptions',
  'hotstar': 'OTT subscriptions',
  'prime': 'OTT subscriptions',
  'movie': 'Movies',
  'amazon': 'Online shopping',
  'flipkart': 'Online shopping',
  'myntra': 'Clothes',
  'maid': 'House help',
  'salary': 'Salary',
  'interest': 'Interest',
  'refund': 'Refunds & Cashback',
  'cashback': 'Refunds & Cashback',
  'emi': 'EMI & Loans',
  'haircut': 'Personal care',
  'salon': 'Personal care',
};

final _wordSplit = RegExp(r'[^a-z0-9]+');

/// Returns the name from [categoryNames] that best fits [description], or
/// null. Tries the keyword table first, then whole words of category names.
String? guessCategoryName(String description, Iterable<String> categoryNames) {
  final words = description
      .toLowerCase()
      .split(_wordSplit)
      .where((w) => w.isNotEmpty);
  if (words.isEmpty) return null;
  final byLower = {for (final n in categoryNames) n.toLowerCase(): n};

  for (final w in words) {
    final mapped = _keywordToCategory[w];
    if (mapped != null && byLower.containsKey(mapped.toLowerCase())) {
      return byLower[mapped.toLowerCase()];
    }
  }
  for (final w in words) {
    for (final entry in byLower.entries) {
      if (entry.key.split(_wordSplit).contains(w)) return entry.value;
    }
  }
  return null;
}

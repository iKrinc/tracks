import 'package:tracks/data/tables.dart';

/// A transaction as the fund maths needs it.
typedef FundTxn = ({
  TxnType type,
  int accountId,
  int? toAccountId,
  int? fundId,
  int paise,
  int? categoryId,
});

/// Accounts holding money of a fund that is kept separate: their spending,
/// income and balance stay out of the main totals. Merged funds count as
/// main money.
Set<int> separateAccountIds({
  required Iterable<({int id, int? fundId})> accounts,
  required Iterable<({int id, FundMode mode})> funds,
}) {
  final separate = {
    for (final f in funds)
      if (f.mode == FundMode.separate) f.id,
  };
  return {
    for (final a in accounts)
      if (a.fundId != null && separate.contains(a.fundId)) a.id,
  };
}

/// Whether [t] belongs in the main views (Home, Reports, budgets).
///
/// Spending or income on a separate fund's account stays in the fund.
/// Moving money between main and a fund shows in main as a transfer, so
/// main balances stay right. A main-account spend tagged to a fund is still
/// main money and stays in main (it also counts towards the fund's budget).
bool countsInMain(FundTxn t, Set<int> separateAccounts) {
  final fromFund = separateAccounts.contains(t.accountId);
  if (t.type != TxnType.transfer) return !fromFund;
  final toFund =
      t.toAccountId != null && separateAccounts.contains(t.toAccountId);
  return !(fromFund && toFund);
}

/// Whether [t] shows in fund [fundId]'s own view.
bool belongsToFund(FundTxn t, int fundId, Set<int> fundAccounts) =>
    t.fundId == fundId ||
    fundAccounts.contains(t.accountId) ||
    (t.toAccountId != null && fundAccounts.contains(t.toAccountId));

typedef FundSummary = ({
  int inFundPaise,
  int spentPaise,
  int spentFromMainPaise,
  int receivedPaise,
  int movedInPaise,
  int movedOutPaise,
  int? budgetLeftPaise,
  int? percentOfBudget,
  Map<int?, int> byCategory,
  int count,
});

/// Where a fund stands: what's in it, what the event has cost (from the
/// fund and from main), gifts/income received, and money moved in or out.
FundSummary summarizeFund({
  required int fundId,
  required Set<int> fundAccounts,
  required Iterable<FundTxn> txns,
  required int inFundPaise,
  int? budgetPaise,
}) {
  var spent = 0;
  var fromMain = 0;
  var received = 0;
  var movedIn = 0;
  var movedOut = 0;
  var count = 0;
  final byCategory = <int?, int>{};
  for (final t in txns) {
    if (!belongsToFund(t, fundId, fundAccounts)) continue;
    count++;
    final inFund = fundAccounts.contains(t.accountId);
    switch (t.type) {
      case TxnType.expense:
        spent += t.paise;
        if (!inFund) fromMain += t.paise;
        byCategory[t.categoryId] = (byCategory[t.categoryId] ?? 0) + t.paise;
      case TxnType.income:
        received += t.paise;
      case TxnType.transfer:
        final toFund =
            t.toAccountId != null && fundAccounts.contains(t.toAccountId);
        if (toFund && !inFund) movedIn += t.paise;
        if (inFund && !toFund) movedOut += t.paise;
    }
  }
  final budget = budgetPaise;
  return (
    inFundPaise: inFundPaise,
    spentPaise: spent,
    spentFromMainPaise: fromMain,
    receivedPaise: received,
    movedInPaise: movedIn,
    movedOutPaise: movedOut,
    budgetLeftPaise: budget == null ? null : budget - spent,
    percentOfBudget: budget == null || budget <= 0
        ? null
        : spent * 100 ~/ budget,
    byCategory: byCategory,
    count: count,
  );
}

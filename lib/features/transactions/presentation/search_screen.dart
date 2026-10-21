import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tracks/app/icons.dart';
import 'package:tracks/app/providers.dart';
import 'package:tracks/core/dates.dart';
import 'package:tracks/data/app_database.dart';
import 'package:tracks/features/transactions/presentation/txn_list.dart';

/// Initial filters, e.g. from tapping a total ("honest numbers").
class SearchArgs {
  const SearchArgs({this.type, this.accountId, this.month});

  final TxnType? type;
  final int? accountId;

  /// Limit to this month (first day).
  final DateTime? month;
}

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key, this.args = const SearchArgs()});

  final SearchArgs args;

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _query = TextEditingController();
  late TxnType? _type = widget.args.type;
  late int? _accountId = widget.args.accountId;
  late DateTime? _month = widget.args.month;
  String? _resultsKey;
  late Stream<List<Transaction>> _results;
  List<Transaction>? _last;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Widget _accountChip(Account a) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: ChoiceChip(
      avatar: Icon(iconFor(a.icon), size: 18),
      label: Text(a.name),
      selected: _accountId == a.id,
      onSelected: (on) => setState(() => _accountId = on ? a.id : null),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lookup = watchTxnLookup(ref);
    final db = ref.watch(appDatabaseProvider);
    final month = _month;
    // Re-query only when a filter changes, so typing doesn't flash a spinner.
    final key = '${_query.text}|$_type|$_accountId|$month';
    if (key != _resultsKey) {
      _resultsKey = key;
      _results = db.watchSearch(
        query: _query.text,
        type: _type,
        accountId: _accountId,
        from: month,
        to: month == null ? null : nextMonthStart(month),
      );
    }
    final results = _results;

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _query,
          autofocus: widget.args.type == null && widget.args.accountId == null,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
            hintText: 'Search notes, merchants, tags',
            prefixIcon: Icon(Icons.search),
          ),
        ),
      ),
      body: Column(
        children: [
          SizedBox(
            height: 56,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              children: [
                if (month != null) ...[
                  InputChip(
                    label: Text(monthLabel(month)),
                    onDeleted: () => setState(() => _month = null),
                  ),
                  const SizedBox(width: 8),
                ],
                // Selected filters lead, so one applied from another screen
                // (e.g. tapping an account) is visible without scrolling.
                for (final a in lookup.accounts.values.where(
                  (a) => a.id == _accountId,
                ))
                  _accountChip(a),
                for (final t in TxnType.values) ...[
                  ChoiceChip(
                    label: Text(switch (t) {
                      TxnType.expense => 'Expense',
                      TxnType.income => 'Income',
                      TxnType.transfer => 'Transfer',
                    }),
                    selected: _type == t,
                    onSelected: (on) => setState(() => _type = on ? t : null),
                  ),
                  const SizedBox(width: 8),
                ],
                for (final a in lookup.accounts.values.where(
                  (a) => a.id != _accountId,
                ))
                  _accountChip(a),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<List<Transaction>>(
              stream: results,
              builder: (context, snap) {
                final list = snap.data ?? _last;
                _last = list;
                if (list == null) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (list.isEmpty) {
                  return Center(
                    child: Text(
                      'No matching transactions',
                      style: theme.textTheme.bodyLarge,
                    ),
                  );
                }
                final totals = totalsOfTxns(list);
                return CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                        child: Wrap(
                          spacing: 16,
                          children: [
                            Text('${list.length} found'),
                            if (totals.incomePaise > 0)
                              SignedAmountText(
                                TxnType.income,
                                totals.incomePaise,
                              ),
                            if (totals.expensePaise > 0)
                              SignedAmountText(
                                TxnType.expense,
                                totals.expensePaise,
                              ),
                          ],
                        ),
                      ),
                    ),
                    ...dayGroupSlivers(list, lookup),
                    const SliverPadding(padding: EdgeInsets.only(bottom: 16)),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

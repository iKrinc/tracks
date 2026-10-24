import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tracks/app/icons.dart';
import 'package:tracks/app/providers.dart';
import 'package:tracks/app/theme.dart';
import 'package:tracks/app/widgets/confirm.dart';
import 'package:tracks/core/dates.dart';
import 'package:tracks/core/money.dart';
import 'package:tracks/data/app_database.dart';
import 'package:tracks/features/transactions/domain/summary.dart';

/// Accounts and categories by id, for rendering transaction rows.
typedef TxnLookup = ({
  Map<int, Account> accounts,
  Map<int, Category> categories,
  Map<int, Fund> funds,
});

TxnLookup watchTxnLookup(WidgetRef ref) => (
  accounts: {
    for (final a in ref.watch(allAccountsProvider).value ?? const <Account>[])
      a.id: a,
  },
  categories: {
    for (final kind in CategoryKind.values)
      for (final c
          in ref.watch(categoriesProvider(kind)).value ?? const <Category>[])
        c.id: c,
  },
  funds: {
    for (final f in ref.watch(fundsProvider).value ?? const <Fund>[]) f.id: f,
  },
);

Totals totalsOfTxns(Iterable<Transaction> txns) =>
    totalsOf(txns.map((t) => (type: t.type, amountPaise: t.amountPaise)));

/// "+₹500.00" / "−₹20.00" / "₹1,000.00": direction never by colour alone.
String signedAmount(TxnType type, int paise) => switch (type) {
  TxnType.income => '+${formatPaise(paise)}',
  TxnType.expense => '−${formatPaise(paise)}',
  TxnType.transfer => formatPaise(paise),
};

/// A signed, direction-coloured amount with tabular digits and a spoken
/// label ("250 rupees expense").
class SignedAmountText extends StatelessWidget {
  const SignedAmountText(this.type, this.paise, {super.key, this.style});

  final TxnType type;
  final int paise;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = switch (type) {
      TxnType.income => theme.incomeColor,
      TxnType.expense => theme.expenseColor,
      TxnType.transfer => theme.colorScheme.onSurfaceVariant,
    };
    return Semantics(
      label: '${spokenPaise(paise)} ${type.name}',
      excludeSemantics: true,
      child: Text(
        signedAmount(type, paise),
        style: (style ?? const TextStyle()).copyWith(
          color: color,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

/// Day header + rows, as slivers, for a newest-first list. Inside a fund's
/// own screen, [inFund] drops the "Marriage –" prefix.
List<Widget> dayGroupSlivers(
  List<Transaction> txns,
  TxnLookup lookup, {
  bool inFund = false,
}) {
  // A list spanning months (a fund, search) needs the month on each day.
  final months = {for (final t in txns) monthStart(t.occurredAt)};
  return [
    for (final (day, items) in groupByDay(txns, (t) => t.occurredAt)) ...[
      SliverToBoxAdapter(
        child: DayHeader(day: day, items: items, showMonth: months.length > 1),
      ),
      SliverList.list(
        children: [
          for (final t in items)
            TxnTile(txn: t, lookup: lookup, inFund: inFund),
        ],
      ),
    ],
  ];
}

class DayHeader extends StatelessWidget {
  const DayHeader({
    super.key,
    required this.day,
    required this.items,
    this.showMonth = false,
  });

  final DateTime day;
  final List<Transaction> items;

  /// "28 Wed · Oct 2026" instead of "28 Wed", for lists across months.
  final bool showMonth;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = totalsOfTxns(items);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
      child: Row(
        children: [
          Text('${day.day}', style: theme.textTheme.titleLarge),
          const SizedBox(width: 8),
          Text(
            showMonth
                ? '${weekdayShort(day)} · '
                      '${shortDate(day).replaceFirst('${day.day} ', '')}'
                : weekdayShort(day),
            style: theme.textTheme.labelLarge,
          ),
          const Spacer(),
          if (t.incomePaise > 0)
            SignedAmountText(TxnType.income, t.incomePaise),
          if (t.incomePaise > 0 && t.expensePaise > 0)
            const SizedBox(width: 12),
          if (t.expensePaise > 0)
            SignedAmountText(TxnType.expense, t.expensePaise),
        ],
      ),
    );
  }
}

class TxnTile extends ConsumerWidget {
  const TxnTile({
    super.key,
    required this.txn,
    required this.lookup,
    this.inFund = false,
  });

  final Transaction txn;
  final TxnLookup lookup;

  /// Shown on its fund's own screen, where the fund name is redundant.
  final bool inFund;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final account = lookup.accounts[txn.accountId];
    final toAccount = txn.toAccountId == null
        ? null
        : lookup.accounts[txn.toAccountId];
    final category = txn.categoryId == null
        ? null
        : lookup.categories[txn.categoryId];
    final transfer = txn.type == TxnType.transfer;
    // A fund's money in and out: the fund is its category. Moves into or
    // out of a fund ("initial", "remaining") carry its name too.
    final fundId = account?.fundId ?? (transfer ? toAccount?.fundId : null);
    final fund = fundId == null ? null : lookup.funds[fundId];
    final String title;
    final String subtitle;
    if (fund != null) {
      final what = txn.note.isNotEmpty
          ? txn.note
          : switch (txn.type) {
              TxnType.income => 'Money in',
              TxnType.expense => 'Money out',
              TxnType.transfer => 'moved',
            };
      title = inFund ? what : '${fund.name} – $what';
      subtitle = transfer
          ? '${account?.name ?? '?'} → ${toAccount?.name ?? '?'}'
          : '';
    } else {
      title = txn.note.isNotEmpty
          ? txn.note
          : (transfer ? 'Transfer' : category?.name ?? 'Uncategorised');
      subtitle = transfer
          ? '${account?.name ?? '?'} → ${toAccount?.name ?? '?'}'
          : [category?.name, account?.name].nonNulls.join(' · ');
    }
    final color = switch (txn.type) {
      TxnType.income => theme.incomeColor,
      TxnType.expense => theme.expenseColor,
      TxnType.transfer => theme.colorScheme.onSurfaceVariant,
    };

    // A synced fund's "remaining" is kept by the app: sync off removes it.
    final syncedFrom = lookup.funds.values
        .where((f) => f.syncTransferId == txn.id)
        .firstOrNull;

    return Dismissible(
      key: ValueKey(txn.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        if (syncedFrom != null) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(
                content: Text(
                  'Turn off sync on ${syncedFrom.name} to remove this',
                ),
              ),
            );
          return false;
        }
        return confirmDestructive(
          context,
          title: 'Delete this transaction?',
          message:
              '$title, ${formatPaise(txn.amountPaise)} on '
              '${shortDate(txn.occurredAt)}.',
        );
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        color: theme.colorScheme.errorContainer,
        child: Icon(
          Icons.delete_outline,
          color: theme.colorScheme.onErrorContainer,
        ),
      ),
      onDismissed: (_) async {
        final db = ref.read(appDatabaseProvider);
        final messenger = ScaffoldMessenger.of(context);
        await db.deleteTransaction(txn.id);
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: const Text('Deleted'),
              action: SnackBarAction(
                label: 'Undo',
                onPressed: () => db.addTransaction(txn.toCompanion(true)),
              ),
            ),
          );
      },
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: fund != null
              ? Color(fund.color)
              : category == null
              ? Palette.sand
              : Color(category.color),
          foregroundColor: Colors.black87,
          child: Icon(
            transfer
                ? Icons.swap_horiz
                : iconFor(fund?.icon ?? category?.icon ?? ''),
            size: 20,
          ),
        ),
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: subtitle.isEmpty
            ? null
            : Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: Semantics(
          label: '${spokenPaise(txn.amountPaise)} ${txn.type.name}',
          excludeSemantics: true,
          child: Text(
            signedAmount(txn.type, txn.amountPaise),
            style: theme.textTheme.titleSmall?.copyWith(
              color: color,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ),
    );
  }
}

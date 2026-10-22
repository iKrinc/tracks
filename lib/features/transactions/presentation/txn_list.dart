import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tracks/app/icons.dart';
import 'package:tracks/app/providers.dart';
import 'package:tracks/app/theme.dart';
import 'package:tracks/core/dates.dart';
import 'package:tracks/core/money.dart';
import 'package:tracks/data/app_database.dart';
import 'package:tracks/features/transactions/domain/summary.dart';

/// Accounts and categories by id, for rendering transaction rows.
typedef TxnLookup = ({
  Map<int, Account> accounts,
  Map<int, Category> categories,
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

/// Day header + rows, as slivers, for a newest-first list.
List<Widget> dayGroupSlivers(List<Transaction> txns, TxnLookup lookup) => [
  for (final (day, items) in groupByDay(txns, (t) => t.occurredAt)) ...[
    SliverToBoxAdapter(
      child: DayHeader(day: day, items: items),
    ),
    SliverList.list(
      children: [for (final t in items) TxnTile(txn: t, lookup: lookup)],
    ),
  ],
];

class DayHeader extends StatelessWidget {
  const DayHeader({super.key, required this.day, required this.items});

  final DateTime day;
  final List<Transaction> items;

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
          Text(weekdayShort(day), style: theme.textTheme.labelLarge),
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
  const TxnTile({super.key, required this.txn, required this.lookup});

  final Transaction txn;
  final TxnLookup lookup;

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
    final title = txn.note.isNotEmpty
        ? txn.note
        : (transfer ? 'Transfer' : category?.name ?? 'Uncategorised');
    final subtitle = transfer
        ? '${account?.name ?? '?'} → ${toAccount?.name ?? '?'}'
        : [category?.name, account?.name].nonNulls.join(' · ');
    final color = switch (txn.type) {
      TxnType.income => theme.incomeColor,
      TxnType.expense => theme.expenseColor,
      TxnType.transfer => theme.colorScheme.onSurfaceVariant,
    };

    return Dismissible(
      key: ValueKey(txn.id),
      direction: DismissDirection.endToStart,
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
          backgroundColor: category == null
              ? Palette.sand
              : Color(category.color),
          foregroundColor: Colors.black87,
          child: Icon(
            transfer ? Icons.swap_horiz : iconFor(category?.icon ?? ''),
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

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tracks/app/icons.dart';
import 'package:tracks/app/providers.dart';
import 'package:tracks/app/theme.dart';
import 'package:tracks/core/dates.dart';
import 'package:tracks/core/money.dart';
import 'package:tracks/data/app_database.dart';
import 'package:tracks/features/capture/domain/capture_draft.dart';
import 'package:tracks/features/capture/presentation/confirm_sheet.dart';
import 'package:tracks/features/capture/presentation/share_intake.dart';
import 'package:tracks/features/transactions/domain/summary.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final month = ref.watch(selectedMonthProvider);
    final txns = ref.watch(monthTransactionsProvider);
    final accounts = {
      for (final a in ref.watch(accountsProvider).value ?? const <Account>[])
        a.id: a,
    };
    final categories = {
      for (final kind in CategoryKind.values)
        for (final c
            in ref.watch(categoriesProvider(kind)).value ?? const <Category>[])
          c.id: c,
    };
    final monthCtl = ref.read(selectedMonthProvider.notifier);

    return ShareIntake(
      child: Scaffold(
        appBar: AppBar(
          centerTitle: true,
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: 'Previous month',
                icon: const Icon(Icons.chevron_left),
                onPressed: monthCtl.previous,
              ),
              Text(monthLabel(month)),
              IconButton(
                tooltip: 'Next month',
                icon: const Icon(Icons.chevron_right),
                onPressed: monthCtl.next,
              ),
            ],
          ),
        ),
        body: SafeArea(
          top: false,
          child: Column(
            children: [
              Expanded(
                child: txns.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('Could not load: $e')),
                  data: (list) => _MonthBody(
                    txns: list,
                    accounts: accounts,
                    categories: categories,
                  ),
                ),
              ),
              const _QuickAddBar(),
            ],
          ),
        ),
      ),
    );
  }
}

class _MonthBody extends StatelessWidget {
  const _MonthBody({
    required this.txns,
    required this.accounts,
    required this.categories,
  });

  final List<Transaction> txns;
  final Map<int, Account> accounts;
  final Map<int, Category> categories;

  @override
  Widget build(BuildContext context) {
    final totals = totalsOf(
      txns.map((t) => (type: t.type, amountPaise: t.amountPaise)),
    );
    final days = groupByDay(txns, (t) => t.occurredAt);

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: _SummaryCard(totals: totals)),
        if (txns.isEmpty)
          const SliverFillRemaining(hasScrollBody: false, child: _EmptyState()),
        for (final (day, items) in days) ...[
          SliverToBoxAdapter(
            child: _DayHeader(day: day, items: items),
          ),
          SliverList.list(
            children: [
              for (final t in items)
                _TxnTile(
                  txn: t,
                  account: accounts[t.accountId],
                  toAccount: t.toAccountId == null
                      ? null
                      : accounts[t.toAccountId],
                  category: t.categoryId == null
                      ? null
                      : categories[t.categoryId],
                ),
            ],
          ),
        ],
        const SliverPadding(padding: EdgeInsets.only(bottom: 12)),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.totals});

  final Totals totals;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget cell(String label, int paise, Color color) => Expanded(
      child: Column(
        children: [
          Text(label, style: theme.textTheme.labelMedium),
          const SizedBox(height: 4),
          FittedBox(
            child: Text(
              formatPaise(paise),
              style: theme.textTheme.titleMedium?.copyWith(color: color),
            ),
          ),
        ],
      ),
    );

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      elevation: 0,
      color: theme.colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        child: Row(
          children: [
            cell('Income', totals.incomePaise, theme.incomeColor),
            cell('Expense', totals.expensePaise, theme.expenseColor),
            cell('Total', totals.netPaise, theme.colorScheme.onSurface),
          ],
        ),
      ),
    );
  }
}

class _DayHeader extends StatelessWidget {
  const _DayHeader({required this.day, required this.items});

  final DateTime day;
  final List<Transaction> items;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = totalsOf(
      items.map((t) => (type: t.type, amountPaise: t.amountPaise)),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
      child: Row(
        children: [
          Text('${day.day}', style: theme.textTheme.titleLarge),
          const SizedBox(width: 8),
          Text(weekdayShort(day), style: theme.textTheme.labelLarge),
          const Spacer(),
          if (t.incomePaise > 0)
            Text(
              formatPaise(t.incomePaise),
              style: TextStyle(color: theme.incomeColor),
            ),
          if (t.incomePaise > 0 && t.expensePaise > 0)
            const SizedBox(width: 12),
          if (t.expensePaise > 0)
            Text(
              formatPaise(t.expensePaise),
              style: TextStyle(color: theme.expenseColor),
            ),
        ],
      ),
    );
  }
}

class _TxnTile extends ConsumerWidget {
  const _TxnTile({
    required this.txn,
    required this.account,
    required this.toAccount,
    required this.category,
  });

  final Transaction txn;
  final Account? account;
  final Account? toAccount;
  final Category? category;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
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
          backgroundColor: Color(category?.color ?? 0xFFCBF0F8),
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
        trailing: Text(
          formatPaise(txn.amountPaise),
          style: theme.textTheme.titleSmall?.copyWith(color: color),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.bolt, size: 48, color: theme.colorScheme.primary),
          const SizedBox(height: 12),
          Text('Nothing here yet', style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            'Type "chai 20" or "petrol 500 card" below',
            style: theme.textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _QuickAddBar extends ConsumerStatefulWidget {
  const _QuickAddBar();

  @override
  ConsumerState<_QuickAddBar> createState() => _QuickAddBarState();
}

class _QuickAddBarState extends ConsumerState<_QuickAddBar> {
  final _ctl = TextEditingController();

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final text = _ctl.text.trim();
    if (text.isEmpty) {
      await showConfirmSheet(context);
      return;
    }
    final accounts = ref.read(accountsProvider).value ?? const <Account>[];
    final saved = await presentCapture(
      context,
      captureFromQuickAdd(
        text,
        now: DateTime.now(),
        accountKeywords: accountKeywordsOf(accounts),
      ),
    );
    if (saved) _ctl.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
      child: Row(
        children: [
          IconButton.filledTonal(
            tooltip: 'Add with form',
            icon: const Icon(Icons.add),
            onPressed: () => showConfirmSheet(context),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _ctl,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                hintText: 'chai 20 gpay',
                prefixIcon: const Icon(Icons.bolt),
                suffixIcon: IconButton(
                  tooltip: 'Add',
                  icon: const Icon(Icons.arrow_upward),
                  onPressed: _submit,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

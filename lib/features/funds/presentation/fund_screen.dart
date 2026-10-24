import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tracks/app/icons.dart';
import 'package:tracks/app/providers.dart';
import 'package:tracks/app/theme.dart';
import 'package:tracks/app/widgets/hero.dart';
import 'package:tracks/app/widgets/meter.dart';
import 'package:tracks/core/money.dart';
import 'package:tracks/data/app_database.dart';
import 'package:tracks/features/budgets/domain/budget_math.dart';
import 'package:tracks/features/capture/domain/capture_draft.dart';
import 'package:tracks/features/capture/presentation/confirm_sheet.dart';
import 'package:tracks/features/funds/domain/fund_math.dart';
import 'package:tracks/features/funds/presentation/funds_screen.dart';
import 'package:tracks/features/transactions/presentation/txn_list.dart';

/// One fund: what's in it, what the event has cost against its budget,
/// whether it counts in main, and every transaction that belongs to it.
class FundScreen extends ConsumerWidget {
  const FundScreen({super.key, required this.fundId});

  final int fundId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final tokens = theme.tokens;
    final fund = (ref.watch(fundsProvider).value ?? const <Fund>[])
        .where((f) => f.id == fundId)
        .firstOrNull;
    final accounts = ref.watch(allAccountsProvider).value ?? const <Account>[];
    final txns = ref.watch(allTransactionsProvider).value ?? const [];
    if (fund == null) {
      return Scaffold(appBar: AppBar());
    }
    final view = fundViewOf(fund, accounts, txns, ref.watch(balancesProvider));
    final s = view.summary;
    final ids = {for (final a in view.accounts) a.id};
    final mine = [
      for (final t in txns)
        if (belongsToFund(fundTxnOf(t), fund.id, ids)) t,
    ];
    final categories = {
      for (final c
          in ref.watch(categoriesProvider(CategoryKind.expense)).value ??
              const <Category>[])
        c.id: c,
    };
    final pot = view.accounts.where((a) => !a.archived).firstOrNull;
    final mainAccounts = [
      for (final a in ref.watch(accountsProvider).value ?? const <Account>[])
        if (a.fundId == null && spendableAccountTypes.contains(a.type)) a,
    ];
    final separate = fund.mode == FundMode.separate;
    final ranked = s.byCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    Future<void> capture(CaptureDraft d) => showConfirmSheet(context, draft: d);

    return Scaffold(
      appBar: AppBar(
        title: Text(fund.name),
        actions: [
          if (fund.archived)
            TextButton(
              onPressed: () =>
                  ref.read(appDatabaseProvider).reopenFund(fund.id),
              child: const Text('Reopen'),
            )
          else
            PopupMenuButton<String>(
              tooltip: 'More',
              onSelected: (v) {
                if (v == 'edit') _editBudget(context, fund);
                if (v == 'close') {
                  _closeFund(context, ref, fund, pot, s.inFundPaise);
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'edit', child: Text('Edit budget')),
                PopupMenuItem(value: 'close', child: Text('Close fund')),
              ],
            ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            sliver: SliverList.list(
              children: [
                HeroCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'In the fund',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: tokens.heroMuted,
                        ),
                      ),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: AnimatedAmount(
                          s.inFundPaise,
                          semanticsPrefix: 'In the fund ',
                          style: theme.textTheme.displaySmall?.copyWith(
                            color: tokens.heroInk,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (fund.budgetPaise != null) ...[
                        BudgetMeter(
                          onHero: true,
                          progress: budgetProgress(
                            limitPaise: fund.budgetPaise!,
                            spentPaise: s.spentPaise,
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      Wrap(
                        spacing: 24,
                        runSpacing: 8,
                        children: [
                          _Stat('Spent', s.spentPaise),
                          if (s.receivedPaise > 0)
                            _Stat('Gifts & income', s.receivedPaise),
                          if (s.spentFromMainPaise > 0)
                            _Stat('Paid from main', s.spentFromMainPaise),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                if (!fund.archived)
                  SwitchListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                    isThreeLine: true,
                    value: separate,
                    title: const Text('Keep separate from my main money'),
                    subtitle: Text(
                      separate
                          ? 'Its money and spending stay out of Home, Reports, '
                                'budgets, net worth and the payday forecast.'
                          : 'Counted in Home, Reports, budgets and net worth, '
                                'and still tracked here. The payday forecast '
                                'never spends it.',
                    ),
                    onChanged: (v) => ref
                        .read(appDatabaseProvider)
                        .saveFund(
                          fund
                              .copyWith(
                                mode: v ? FundMode.separate : FundMode.merged,
                              )
                              .toCompanion(true),
                        ),
                  ),
                if (!fund.archived && pot != null) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton.icon(
                        onPressed: () => capture(
                          CaptureDraft(
                            type: TxnType.expense,
                            source: TxnSource.manual,
                            accountId: pot.id,
                            fundId: fund.id,
                          ),
                        ),
                        icon: const Icon(Icons.remove),
                        label: const Text('Add spend'),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: mainAccounts.isEmpty
                            ? null
                            : () => capture(
                                CaptureDraft(
                                  type: TxnType.transfer,
                                  source: TxnSource.manual,
                                  note: 'Set aside for ${fund.name}',
                                  accountId: mainAccounts.first.id,
                                  toAccountId: pot.id,
                                ),
                              ),
                        icon: const Icon(Icons.add),
                        label: const Text('Add money'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => capture(
                          CaptureDraft(
                            type: TxnType.income,
                            source: TxnSource.manual,
                            note: 'Gift',
                            accountId: pot.id,
                            fundId: fund.id,
                          ),
                        ),
                        icon: const Icon(Icons.redeem),
                        label: const Text('Gift received'),
                      ),
                    ],
                  ),
                ],
                if (ranked.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Text('Where it went', style: theme.textTheme.titleSmall),
                  const SizedBox(height: 8),
                  for (final e in ranked)
                    _CategoryBar(
                      category: categories[e.key],
                      paise: e.value,
                      of: s.spentPaise,
                    ),
                ],
                const SizedBox(height: 12),
                if (mine.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Text(
                      'Nothing yet. Add money, then spends like "catering '
                      '50000 ${fund.name.toLowerCase()}" from Home go '
                      'straight here.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          ...dayGroupSlivers(mine, watchTxnLookup(ref)),
          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }

  Future<void> _editBudget(BuildContext context, Fund fund) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useRootNavigator: true,
        showDragHandle: true,
        useSafeArea: true,
        builder: (_) => _BudgetSheet(fund: fund),
      );

  /// Moves what's left to a main account, then archives the fund and its
  /// accounts. Its history stays under Closed; Undo or Reopen bring it back.
  Future<void> _closeFund(
    BuildContext context,
    WidgetRef ref,
    Fund fund,
    Account? pot,
    int left,
  ) async {
    final main = [
      for (final a in ref.read(accountsProvider).value ?? const <Account>[])
        if (a.fundId == null && spendableAccountTypes.contains(a.type)) a,
    ];
    final moveLeft = left > 0 && pot != null;
    final messenger = ScaffoldMessenger.of(context);
    // Returns the chosen account, or the fund's own account when nothing
    // moves; null when dismissed.
    final target = await showModalBottomSheet<Account>(
      context: context,
      useRootNavigator: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Close ${fund.name}',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              !moveLeft
                  ? 'Nothing is left to move. Its history stays under Closed, '
                        'and you can reopen it.'
                  : main.isEmpty
                  ? 'Add a main account first, to move the '
                        '${formatPaise(left)} left into it.'
                  : 'Move the ${formatPaise(left)} left to:',
            ),
            const SizedBox(height: 12),
            if (moveLeft)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final a in main)
                    ActionChip(
                      avatar: Icon(iconFor(a.icon), size: 18),
                      label: Text(a.name),
                      onPressed: () => Navigator.pop(context, a),
                    ),
                ],
              )
            else if (pot != null)
              FilledButton(
                onPressed: () => Navigator.pop(context, pot),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
                child: const Text('Close fund'),
              ),
          ],
        ),
      ),
    );
    if (target == null) return;
    final db = ref.read(appDatabaseProvider);
    final moved = await db.closeFund(
      fund.id,
      leftPaise: moveLeft ? left : 0,
      potId: pot?.id,
      toAccountId: moveLeft ? target.id : null,
      note: 'Left over from ${fund.name}',
    );
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            moved == null
                ? '${fund.name} closed'
                : '${fund.name} closed, ${formatPaise(left)} moved to '
                      '${target.name}',
          ),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () => db.reopenFund(fund.id, undoTransferId: moved),
          ),
        ),
      );
  }
}

class _BudgetSheet extends ConsumerStatefulWidget {
  const _BudgetSheet({required this.fund});

  final Fund fund;

  @override
  ConsumerState<_BudgetSheet> createState() => _BudgetSheetState();
}

class _BudgetSheetState extends ConsumerState<_BudgetSheet> {
  late final _budget = TextEditingController(
    text: widget.fund.budgetPaise == null
        ? ''
        : formatPaise(
            widget.fund.budgetPaise!,
            symbol: false,
            hideZeroPaise: true,
          ),
  );
  String? _error;

  @override
  void dispose() {
    _budget.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final text = _budget.text.trim();
    final budget = text.isEmpty ? null : parseRupeesToPaise(text);
    if (text.isNotEmpty && budget == null) {
      setState(() => _error = 'Amounts look like 8,00,000 or 50000');
      return;
    }
    await ref
        .read(appDatabaseProvider)
        .saveFund(
          widget.fund.copyWith(budgetPaise: Value(budget)).toCompanion(true),
        );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Budget for ${widget.fund.name}',
            style: theme.textTheme.headlineSmall,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _budget,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              prefixText: '₹ ',
              labelText: 'Budget in all',
              hintText: 'Blank for no budget',
            ),
          ),
          if (_error != null)
            Semantics(
              liveRegion: true,
              child: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _error!,
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ),
            ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.check),
            label: const Text('Save'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.paise);

  final String label;
  final int paise;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.tokens;
    return Semantics(
      label: '$label ${spokenPaise(paise)}',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: tokens.heroMuted,
            ),
          ),
          Text(
            formatPaise(paise, hideZeroPaise: true),
            style: theme.textTheme.titleMedium?.copyWith(
              color: tokens.heroInk,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

/// A ranked bar: one hue, direct label (dataviz part-to-whole rule).
class _CategoryBar extends StatelessWidget {
  const _CategoryBar({
    required this.category,
    required this.paise,
    required this.of,
  });

  final Category? category;
  final int paise;
  final int of;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = category?.name ?? 'Uncategorised';
    final share = of <= 0 ? 0.0 : paise / of;
    return Semantics(
      label: '$name ${spokenPaise(paise)}, ${(share * 100).round()} percent',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(name, style: theme.textTheme.bodyMedium)),
                Text(
                  formatPaise(paise),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: share,
                minHeight: 8,
                color: theme.tokens.seriesA,
                backgroundColor: theme.colorScheme.surfaceContainer,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

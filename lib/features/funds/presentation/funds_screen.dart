import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tracks/app/icons.dart';
import 'package:tracks/app/providers.dart';
import 'package:tracks/app/theme.dart';
import 'package:tracks/core/money.dart';
import 'package:tracks/data/app_database.dart';
import 'package:tracks/features/budgets/domain/budget_math.dart';
import 'package:tracks/app/widgets/meter.dart';
import 'package:tracks/features/funds/domain/fund_math.dart';

/// Icons offered for a fund, by what people save for.
const fundIcons = [
  ('celebration', 'Wedding or festival'),
  ('flight', 'Trip'),
  ('home', 'Home'),
  ('school', 'Education'),
  ('medical_services', 'Medical'),
  ('savings', 'Other'),
];

/// Fills a new fund cycles through (dark ink on all of them).
final fundColors = [
  Palette.blush,
  Palette.jadeSoft,
  Palette.butter,
  Palette.clay,
  Palette.sage,
  Palette.coralSoft,
];

/// A fund's accounts and where it stands, for the list and its screen.
typedef FundView = ({Fund fund, List<Account> accounts, FundSummary summary});

FundView fundViewOf(
  Fund f,
  List<Account> allAccounts,
  List<Transaction> txns,
  Map<int, int> balances,
) {
  final accounts = [
    for (final a in allAccounts)
      if (a.fundId == f.id) a,
  ];
  final ids = {for (final a in accounts) a.id};
  return (
    fund: f,
    accounts: accounts,
    summary: summarizeFund(
      fundId: f.id,
      fundAccounts: ids,
      txns: txns.map(fundTxnOf),
      inFundPaise: ids.fold(0, (s, id) => s + (balances[id] ?? 0)),
      budgetPaise: f.budgetPaise,
    ),
  );
}

/// More → Funds: money kept for one purpose, each tracked on its own.
class FundsScreen extends ConsumerWidget {
  const FundsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final funds = ref.watch(fundsProvider).value;
    final accounts = ref.watch(allAccountsProvider).value ?? const <Account>[];
    final txns = ref.watch(allTransactionsProvider).value ?? const [];
    final balances = ref.watch(balancesProvider);
    final open = (funds ?? const <Fund>[]).where((f) => !f.archived).toList();
    final closed = (funds ?? const <Fund>[]).where((f) => f.archived).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Funds')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showNewFundSheet(context),
        icon: const Icon(Icons.add),
        label: const Text('Fund'),
      ),
      body: funds == null
          ? const SizedBox.shrink()
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              children: [
                if (open.isEmpty && closed.isEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 32, 16, 16),
                    child: Text(
                      'Keep money for one thing apart: a wedding, a trip, a '
                      'house. Its money and spending stay out of your monthly '
                      'numbers, with their own budget, unless you choose to '
                      'count them in.\n\nTry "+ Fund", then type "catering '
                      '50000 marriage" on Home.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                for (final f in open)
                  _FundCard(view: fundViewOf(f, accounts, txns, balances)),
                if (closed.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 16, 4, 4),
                    child: Text('Closed', style: theme.textTheme.titleSmall),
                  ),
                  for (final f in closed)
                    _FundCard(view: fundViewOf(f, accounts, txns, balances)),
                ],
              ],
            ),
    );
  }
}

class _FundCard extends StatelessWidget {
  const _FundCard({required this.view});

  final FundView view;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final f = view.fund;
    final s = view.summary;
    final mode = f.archived
        ? 'Closed'
        : f.mode == FundMode.separate
        ? 'Kept separate'
        : 'Counts in main';
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => context.push('/funds/${f.id}'),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    ExcludeSemantics(
                      child: CircleAvatar(
                        backgroundColor: Color(f.color),
                        foregroundColor: Colors.black87,
                        child: Icon(iconFor(f.icon), size: 20),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(f.name, style: theme.textTheme.titleMedium),
                          Text(
                            mode,
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Semantics(
                      label: '${spokenPaise(s.inFundPaise)} in the fund',
                      excludeSemantics: true,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            formatPaise(s.inFundPaise),
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                          Text(
                            'in the fund',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (f.budgetPaise != null) ...[
                  const SizedBox(height: 12),
                  BudgetMeter(
                    progress: budgetProgress(
                      limitPaise: f.budgetPaise!,
                      spentPaise: s.spentPaise,
                    ),
                  ),
                ] else if (s.spentPaise > 0) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Spent ${formatPaise(s.spentPaise)}',
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> showNewFundSheet(BuildContext context) => showModalBottomSheet(
  context: context,
  isScrollControlled: true,
  useRootNavigator: true,
  showDragHandle: true,
  useSafeArea: true,
  builder: (_) => const _NewFundSheet(),
);

class _NewFundSheet extends ConsumerStatefulWidget {
  const _NewFundSheet();

  @override
  ConsumerState<_NewFundSheet> createState() => _NewFundSheetState();
}

class _NewFundSheetState extends ConsumerState<_NewFundSheet> {
  final _name = TextEditingController();
  final _budget = TextEditingController();
  final _start = TextEditingController();
  String _icon = fundIcons.first.$1;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _budget.dispose();
    _start.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Give it a name, e.g. Marriage');
      return;
    }
    int? paise(TextEditingController c) =>
        c.text.trim().isEmpty ? null : parseRupeesToPaise(c.text);
    final budget = paise(_budget);
    final start = paise(_start);
    if ((_budget.text.trim().isNotEmpty && budget == null) ||
        (_start.text.trim().isNotEmpty && start == null)) {
      setState(() => _error = 'Amounts look like 8,00,000 or 50000');
      return;
    }
    final db = ref.read(appDatabaseProvider);
    final count = (ref.read(fundsProvider).value ?? const []).length;
    final id = await db.createFund(
      name: name,
      color: fundColors[count % fundColors.length].toARGB32(),
      icon: _icon,
      budgetPaise: budget,
      startPaise: start ?? 0,
    );
    if (!mounted) return;
    Navigator.pop(context);
    context.push('/funds/$id');
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
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('New fund', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 16),
            TextField(
              controller: _name,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                hintText: 'Name, e.g. Marriage',
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final (icon, label) in fundIcons)
                  ChoiceChip(
                    avatar: Icon(iconFor(icon), size: 18),
                    label: Text(label),
                    selected: _icon == icon,
                    onSelected: (_) => setState(() => _icon = icon),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _budget,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                prefixText: '₹ ',
                hintText: 'Budget in all (optional)',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _start,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                prefixText: '₹ ',
                hintText: 'Already set aside (optional)',
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
              child: Text(
                'Money already kept for this, e.g. in an FD. To move money '
                'from your accounts, use "Add money" on the fund.',
                style: theme.textTheme.bodySmall,
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _error!,
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.check),
              label: const Text('Create fund'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

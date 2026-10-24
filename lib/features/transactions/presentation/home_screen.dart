import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tracks/app/providers.dart';
import 'package:tracks/app/theme.dart';
import 'package:tracks/app/widgets/hero.dart';
import 'package:tracks/core/dates.dart';
import 'package:tracks/core/money.dart';
import 'package:tracks/data/app_database.dart';
import 'package:tracks/features/budgets/domain/budget_math.dart';
import 'package:tracks/features/insights/presentation/forecast_sheet.dart';
import 'package:tracks/features/capture/domain/capture_draft.dart';
import 'package:tracks/features/capture/presentation/confirm_sheet.dart';
import 'package:tracks/features/capture/presentation/share_intake.dart';
import 'package:tracks/features/recurring/domain/schedule.dart';
import 'package:tracks/features/recurring/presentation/recurring_screen.dart';
import 'package:tracks/features/transactions/domain/summary.dart';
import 'package:tracks/features/transactions/presentation/calendar_view.dart';
import 'package:tracks/features/transactions/presentation/search_screen.dart';
import 'package:tracks/features/transactions/presentation/txn_list.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _calendar = false;
  DateTime? _selectedDay;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mode = ref.watch(viewModeProvider);
    final month = ref.watch(selectedMonthProvider);
    final monthCtl = ref.read(selectedMonthProvider.notifier);
    final all = ref.watch(allDatedTxnsProvider).value ?? const <DatedTxn>[];

    void go(VoidCallback change) => setState(() {
      change();
      _selectedDay = null;
    });

    final (
      String title,
      VoidCallback? prev,
      VoidCallback? next,
    ) = switch (mode) {
      PeriodView.daily => (
        monthLabel(month),
        () => go(monthCtl.previous),
        () => go(monthCtl.next),
      ),
      PeriodView.monthly => (
        '${month.year}',
        () => go(monthCtl.previousYear),
        () => go(monthCtl.nextYear),
      ),
      PeriodView.yearly => ('All years', null, null),
    };

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 8,
        title: Row(
          children: [
            if (prev != null)
              IconButton(
                tooltip: 'Previous',
                icon: const Icon(Icons.chevron_left),
                onPressed: prev,
              ),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: EdgeInsets.only(left: prev == null ? 12 : 0),
                  child: Text(title),
                ),
              ),
            ),
            if (next != null)
              IconButton(
                tooltip: 'Next',
                icon: const Icon(Icons.chevron_right),
                onPressed: next,
              ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Search',
            icon: const Icon(Icons.search),
            onPressed: () => context.push('/search'),
          ),
          if (mode == PeriodView.daily)
            IconButton(
              tooltip: _calendar ? 'List view' : 'Calendar view',
              icon: Icon(
                _calendar ? Icons.view_agenda_outlined : Icons.calendar_month,
              ),
              onPressed: () => go(() => _calendar = !_calendar),
            ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                    child: SegmentedButton<PeriodView>(
                      showSelectedIcon: false,
                      segments: const [
                        ButtonSegment(
                          value: PeriodView.daily,
                          label: Text('Daily'),
                        ),
                        ButtonSegment(
                          value: PeriodView.monthly,
                          label: Text('Monthly'),
                        ),
                        ButtonSegment(
                          value: PeriodView.yearly,
                          label: Text('Yearly'),
                        ),
                      ],
                      selected: {mode},
                      onSelectionChanged: (s) => go(
                        () => ref.read(viewModeProvider.notifier).set(s.first),
                      ),
                    ),
                  ),
                ),
                ...switch (mode) {
                  PeriodView.daily => _dailySlivers(month),
                  PeriodView.monthly => _monthlySlivers(all, month.year),
                  PeriodView.yearly => _yearlySlivers(all),
                },
                const SliverPadding(padding: EdgeInsets.only(bottom: 16)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Divider(height: 1, color: theme.colorScheme.outlineVariant),
          ),
          const _QuickAddBar(),
        ],
      ),
    );
  }

  Widget _hero({
    required String label,
    required Totals totals,
    required SearchArgs Function(TxnType? type) argsFor,
  }) {
    final theme = Theme.of(context);
    final tokens = theme.tokens;
    void open(TxnType? type) => context.push('/search', extra: argsFor(type));
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: HeroCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: theme.textTheme.labelLarge?.copyWith(
                color: tokens.heroMuted,
              ),
            ),
            const SizedBox(height: 4),
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => open(null),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: AnimatedAmount(
                    totals.netPaise,
                    semanticsPrefix: '$label net ',
                    style: theme.textTheme.displaySmall?.copyWith(
                      color: tokens.heroInk,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: HeroFigure(
                    label: 'Income',
                    paise: totals.incomePaise,
                    income: true,
                    onTap: () => open(TxnType.income),
                  ),
                ),
                Expanded(
                  child: HeroFigure(
                    label: 'Spent',
                    paise: totals.expensePaise,
                    income: false,
                    onTap: () => open(TxnType.expense),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _dailySlivers(DateTime month) {
    final txns = ref.watch(monthTransactionsProvider);
    final lookup = watchTxnLookup(ref);
    final list = txns.value;
    if (list == null) {
      return [
        const SliverFillRemaining(
          child: Center(child: CircularProgressIndicator()),
        ),
      ];
    }
    final selected = _selectedDay;
    final shown = _calendar && selected != null
        ? list.where((t) => dateOnly(t.occurredAt) == selected).toList()
        : list;
    return [
      SliverToBoxAdapter(
        child: _hero(
          label: monthLabel(month),
          totals: totalsOfTxns(list),
          argsFor: (type) => SearchArgs.month(month, type: type),
        ),
      ),
      if (monthStart(DateTime.now()) == month)
        const SliverToBoxAdapter(child: _HeadsUp()),
      if (_calendar)
        SliverToBoxAdapter(
          child: CalendarGrid(
            month: month,
            txns: list,
            selected: selected,
            onSelect: (d) =>
                setState(() => _selectedDay = d == selected ? null : d),
          ),
        ),
      if (list.isEmpty)
        const SliverFillRemaining(hasScrollBody: false, child: _EmptyState())
      else if (_calendar && selected == null)
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Tap a day to see its transactions',
              textAlign: TextAlign.center,
            ),
          ),
        )
      else
        ...dayGroupSlivers(shown, lookup),
    ];
  }

  List<Widget> _monthlySlivers(List<DatedTxn> all, int year) {
    final now = DateTime.now();
    final months = totalsByMonth(all, year)
        .where((m) => year < now.year || m.$1.month <= now.month)
        .toList()
        .reversed
        .toList();
    final yearTotals = totalsOf(
      all
          .where((t) => t.occurredAt.year == year)
          .map((t) => (type: t.type, amountPaise: t.amountPaise)),
    );
    final maxSpend = months.fold(
      0,
      (a, m) => m.$2.expensePaise > a ? m.$2.expensePaise : a,
    );
    return [
      SliverToBoxAdapter(
        child: _hero(
          label: '$year',
          totals: yearTotals,
          argsFor: (type) => SearchArgs.year(year, type: type),
        ),
      ),
      if (months.isEmpty)
        const SliverFillRemaining(hasScrollBody: false, child: _EmptyState())
      else
        SliverList.list(
          children: [
            for (final (m, totals) in months)
              PeriodRow(
                title: monthLabel(m).split(' ').first,
                totals: totals,
                maxSpend: maxSpend,
                onTap: () {
                  ref.read(selectedMonthProvider.notifier).set(m);
                  ref.read(viewModeProvider.notifier).set(PeriodView.daily);
                },
              ),
          ],
        ),
    ];
  }

  List<Widget> _yearlySlivers(List<DatedTxn> all) {
    final years = totalsByYear(all);
    final allTotals = totalsOf(
      all.map((t) => (type: t.type, amountPaise: t.amountPaise)),
    );
    final maxSpend = years.fold(
      0,
      (a, y) => y.$2.expensePaise > a ? y.$2.expensePaise : a,
    );
    return [
      SliverToBoxAdapter(
        child: _hero(
          label: 'All time',
          totals: allTotals,
          argsFor: (type) => SearchArgs(type: type),
        ),
      ),
      if (years.isEmpty)
        const SliverFillRemaining(hasScrollBody: false, child: _EmptyState())
      else
        SliverList.list(
          children: [
            for (final (y, totals) in years)
              PeriodRow(
                title: '$y',
                totals: totals,
                maxSpend: maxSpend,
                onTap: () {
                  final now = DateTime.now();
                  ref
                      .read(selectedMonthProvider.notifier)
                      .set(DateTime(y, y == now.year ? now.month : 12));
                  ref.read(viewModeProvider.notifier).set(PeriodView.monthly);
                },
              ),
          ],
        ),
    ];
  }
}

/// A month or year with its totals and a spend bar scaled to the largest
/// period in view, so heavy months stand out at a glance.
class PeriodRow extends StatelessWidget {
  const PeriodRow({
    super.key,
    required this.title,
    required this.totals,
    required this.maxSpend,
    required this.onTap,
  });

  final String title;
  final Totals totals;
  final int maxSpend;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final fraction = maxSpend == 0 ? 0.0 : totals.expensePaise / maxSpend;
    final empty = totals.incomePaise == 0 && totals.expensePaise == 0;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, empty ? 6 : 12, 20, empty ? 6 : 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: empty
                        ? theme.textTheme.bodyLarge?.copyWith(
                            color: scheme.onSurfaceVariant,
                          )
                        : theme.textTheme.titleMedium,
                  ),
                ),
                if (empty)
                  Text('—', style: theme.textTheme.bodyMedium)
                else
                  Semantics(
                    label: '$title net ${spokenPaise(totals.netPaise)}',
                    excludeSemantics: true,
                    child: Text(
                      formatPaise(totals.netPaise),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
              ],
            ),
            if (!empty) ...[
              const SizedBox(height: 6),
              Wrap(
                spacing: 12,
                children: [
                  if (totals.incomePaise > 0)
                    SignedAmountText(TxnType.income, totals.incomePaise),
                  if (totals.expensePaise > 0)
                    SignedAmountText(TxnType.expense, totals.expensePaise),
                ],
              ),
              const SizedBox(height: 8),
              // Decorative: the figures above carry the meaning.
              ExcludeSemantics(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: fraction.clamp(0.0, 1.0),
                    minHeight: 6,
                    color: theme.expenseColor.withValues(alpha: 0.75),
                    backgroundColor: scheme.surfaceContainer,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The payday forecast, bills due soon and budgets running hot, for the
/// current month only.
class _HeadsUp extends ConsumerWidget {
  const _HeadsUp();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final now = DateTime.now();
    final due = ref
        .watch(dueItemsProvider)
        .where((i) => i.status != DueStatus.later)
        .take(6)
        .toList();
    final hot = ref
        .watch(budgetViewsProvider)
        .where((v) => v.progress.level != BudgetLevel.ok)
        .take(2)
        .toList();
    if (due.isEmpty && hot.isEmpty) return const ForecastTile();
    final names = {
      for (final c
          in ref.watch(categoriesProvider(CategoryKind.expense)).value ??
              const <Category>[])
        c.id: c.name,
    };
    String budgetText(BudgetView v) {
      final who = v.budget.categoryId == null
          ? 'Monthly budget'
          : names[v.budget.categoryId] ?? 'Budget';
      final what = v.progress.level == BudgetLevel.over
          ? 'over by ${formatPaise(-v.progress.remainingPaise, hideZeroPaise: true)}'
          : '${v.progress.percent}% used';
      return '$who: $what';
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ForecastTile(),
          for (final v in hot)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
              child: Material(
                color: scheme.tertiaryContainer,
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => context.push('/budgets'),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Icon(
                          v.progress.level == BudgetLevel.over
                              ? Icons.error_outline
                              : Icons.warning_amber_rounded,
                          color: scheme.onTertiaryContainer,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            budgetText(v),
                            style: TextStyle(color: scheme.onTertiaryContainer),
                          ),
                        ),
                        Icon(
                          Icons.chevron_right,
                          color: scheme.onTertiaryContainer,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          if (due.isNotEmpty)
            SizedBox(
              // Grows with text size so the three lines never clip.
              height: MediaQuery.textScalerOf(context).scale(96),
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                children: [
                  for (final i in due)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Material(
                        color: scheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(16),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => context.push('/bills'),
                          child: Container(
                            width: 160,
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  i.item.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.titleSmall,
                                ),
                                Text(
                                  formatPaise(
                                    i.item.amountPaise,
                                    hideZeroPaise: true,
                                  ),
                                  style: const TextStyle(
                                    fontFeatures: [
                                      FontFeature.tabularFigures(),
                                    ],
                                  ),
                                ),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.schedule,
                                      size: 14,
                                      color: i.status == DueStatus.soon
                                          ? scheme.onSurfaceVariant
                                          : theme.expenseColor,
                                    ),
                                    const SizedBox(width: 4),
                                    Flexible(
                                      child: Text(
                                        dueLabel(i.due, now),
                                        overflow: TextOverflow.ellipsis,
                                        style: theme.textTheme.labelMedium,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _EmptyState extends ConsumerWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
            'Type "chai 20" or "petrol 500 card" below,\n'
            'or share a bank SMS to Tracks',
            style: theme.textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          TextButton.icon(
            onPressed: () => context.push('/backup'),
            icon: const Icon(Icons.settings_backup_restore),
            label: const Text('New phone? Restore a backup'),
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
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    // A widget tap that opened the app before Home was built.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final r = ref.read(quickAddRequestsProvider);
      if (r != null && mounted) _answer(r);
    });
  }

  @override
  void dispose() {
    _ctl.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _answer(QuickAddRequest r) {
    if (r.form) {
      showConfirmSheet(context);
    } else {
      _focus.requestFocus();
    }
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
    ref.listen(quickAddRequestsProvider, (_, r) {
      if (r != null) _answer(r);
    });
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
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
              focusNode: _focus,
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

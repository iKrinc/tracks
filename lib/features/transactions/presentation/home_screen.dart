import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tracks/app/providers.dart';
import 'package:tracks/app/theme.dart';
import 'package:tracks/core/dates.dart';
import 'package:tracks/core/money.dart';
import 'package:tracks/data/app_database.dart';
import 'package:tracks/features/capture/domain/capture_draft.dart';
import 'package:tracks/features/capture/presentation/confirm_sheet.dart';
import 'package:tracks/features/capture/presentation/share_intake.dart';
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
    final month = ref.watch(selectedMonthProvider);
    final txns = ref.watch(monthTransactionsProvider);
    final lookup = watchTxnLookup(ref);
    final monthCtl = ref.read(selectedMonthProvider.notifier);
    void changeMonth(VoidCallback change) => setState(() {
      change();
      _selectedDay = null;
    });

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'Previous month',
              icon: const Icon(Icons.chevron_left),
              onPressed: () => changeMonth(monthCtl.previous),
            ),
            Text(monthLabel(month)),
            IconButton(
              tooltip: 'Next month',
              icon: const Icon(Icons.chevron_right),
              onPressed: () => changeMonth(monthCtl.next),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Search',
            icon: const Icon(Icons.search),
            onPressed: () => context.push('/search'),
          ),
          IconButton(
            tooltip: _calendar ? 'List view' : 'Calendar view',
            icon: Icon(
              _calendar ? Icons.view_agenda_outlined : Icons.calendar_month,
            ),
            onPressed: () => setState(() {
              _calendar = !_calendar;
              _selectedDay = null;
            }),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: txns.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Could not load: $e')),
              data: (list) {
                final selected = _selectedDay;
                final shown = _calendar && selected != null
                    ? list
                          .where((t) => dateOnly(t.occurredAt) == selected)
                          .toList()
                    : list;
                return CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(
                      child: SummaryCard(
                        totals: totalsOfTxns(list),
                        month: month,
                      ),
                    ),
                    if (_calendar)
                      SliverToBoxAdapter(
                        child: CalendarGrid(
                          month: month,
                          txns: list,
                          selected: selected,
                          onSelect: (d) => setState(
                            () => _selectedDay = d == selected ? null : d,
                          ),
                        ),
                      ),
                    if (list.isEmpty)
                      const SliverFillRemaining(
                        hasScrollBody: false,
                        child: _EmptyState(),
                      )
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
                    const SliverPadding(padding: EdgeInsets.only(bottom: 12)),
                  ],
                );
              },
            ),
          ),
          const _QuickAddBar(),
        ],
      ),
    );
  }
}

/// Month income / expense / total. Each figure opens the transactions
/// behind it.
class SummaryCard extends StatelessWidget {
  const SummaryCard({super.key, required this.totals, required this.month});

  final Totals totals;
  final DateTime month;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget cell(String label, int paise, Color color, TxnType? type) =>
        Expanded(
          child: Semantics(
            button: true,
            label: '$label ${spokenPaise(paise)}',
            excludeSemantics: true,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => context.push(
                '/search',
                extra: SearchArgs(type: type, month: month),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  children: [
                    Text(label, style: theme.textTheme.labelMedium),
                    const SizedBox(height: 4),
                    FittedBox(
                      child: Text(
                        formatPaise(paise),
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: color,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      elevation: 0,
      color: theme.colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        child: Row(
          children: [
            cell(
              'Income',
              totals.incomePaise,
              theme.incomeColor,
              TxnType.income,
            ),
            cell(
              'Expense',
              totals.expensePaise,
              theme.expenseColor,
              TxnType.expense,
            ),
            cell('Total', totals.netPaise, theme.colorScheme.onSurface, null),
          ],
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
            'Type "chai 20" or "petrol 500 card" below,\n'
            'or share a bank SMS to Tracks',
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

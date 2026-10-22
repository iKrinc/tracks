import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tracks/app/icons.dart';
import 'package:tracks/app/providers.dart';
import 'package:tracks/app/theme.dart';
import 'package:tracks/app/widgets/hero.dart';
import 'package:tracks/app/widgets/meter.dart';
import 'package:tracks/core/dates.dart';
import 'package:tracks/core/money.dart';
import 'package:tracks/data/app_database.dart';
import 'package:tracks/features/budgets/domain/budget_math.dart';

class BudgetsScreen extends ConsumerWidget {
  const BudgetsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final tokens = theme.tokens;
    final views = ref.watch(budgetViewsProvider);
    final categories = {
      for (final c
          in ref.watch(categoriesProvider(CategoryKind.expense)).value ??
              const <Category>[])
        c.id: c,
    };
    final overall = views.where((v) => v.budget.categoryId == null).firstOrNull;
    final perCategory = views.where((v) => v.budget.categoryId != null);
    final today = DateTime.now();

    return Scaffold(
      appBar: AppBar(title: Text('Budgets · ${monthLabel(today)}')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showBudgetSheet(context),
        icon: const Icon(Icons.add),
        label: const Text('Budget'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
        children: [
          if (overall != null)
            HeroCard(
              onTap: () => showBudgetSheet(context, budget: overall.budget),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Monthly budget',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: tokens.heroMuted,
                    ),
                  ),
                  const SizedBox(height: 4),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: AnimatedAmount(
                      overall.progress.remainingPaise,
                      semanticsPrefix: 'Left this month ',
                      style: theme.textTheme.displaySmall?.copyWith(
                        color: tokens.heroInk,
                      ),
                    ),
                  ),
                  Text(
                    overall.progress.remainingPaise > 0
                        ? 'left · about ${formatPaise(dailyAllowance(remainingPaise: overall.progress.remainingPaise, today: today), hideZeroPaise: true)} a day'
                        : 'over this month',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: tokens.heroInk,
                    ),
                  ),
                  const SizedBox(height: 16),
                  BudgetMeter(progress: overall.progress, onHero: true),
                ],
              ),
            )
          else
            Card(
              child: ListTile(
                contentPadding: const EdgeInsets.all(16),
                leading: const Icon(Icons.savings_outlined),
                title: const Text('Set a monthly budget'),
                subtitle: const Text(
                  'One limit for everything you spend, with a daily '
                  'allowance as the month goes on.',
                ),
                onTap: () => showBudgetSheet(context, overall: true),
              ),
            ),
          if (perCategory.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 24, 4, 8),
              child: Text('By category', style: theme.textTheme.titleMedium),
            ),
            for (final v in perCategory)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Card(
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => showBudgetSheet(context, budget: v.budget),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 16,
                                backgroundColor: Color(
                                  categories[v.budget.categoryId]?.color ??
                                      Palette.sky.toARGB32(),
                                ),
                                foregroundColor: Colors.black87,
                                child: Icon(
                                  iconFor(
                                    categories[v.budget.categoryId]?.icon ?? '',
                                  ),
                                  size: 16,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  categories[v.budget.categoryId]?.name ??
                                      'Category',
                                  style: theme.textTheme.titleMedium,
                                ),
                              ),
                              if (v.budget.rollover)
                                Tooltip(
                                  message: 'Unspent amount rolls over',
                                  child: Icon(
                                    Icons.redo,
                                    size: 18,
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          BudgetMeter(progress: v.progress),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ] else if (overall != null)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Add limits for categories like Food or Shopping to see '
                'where the month is going.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium,
              ),
            ),
        ],
      ),
    );
  }
}

Future<void> showBudgetSheet(
  BuildContext context, {
  Budget? budget,
  bool overall = false,
}) => showModalBottomSheet(
  context: context,
  isScrollControlled: true,
  useRootNavigator: true,
  showDragHandle: true,
  useSafeArea: true,
  builder: (_) => _BudgetSheet(budget: budget, startOverall: overall),
);

class _BudgetSheet extends ConsumerStatefulWidget {
  const _BudgetSheet({this.budget, this.startOverall = false});

  final Budget? budget;
  final bool startOverall;

  @override
  ConsumerState<_BudgetSheet> createState() => _BudgetSheetState();
}

class _BudgetSheetState extends ConsumerState<_BudgetSheet> {
  late final _amount = TextEditingController(
    text: widget.budget == null
        ? ''
        : formatPaise(
            widget.budget!.amountPaise,
            symbol: false,
            hideZeroPaise: true,
          ),
  );
  late int? _categoryId = widget.budget?.categoryId;
  late bool _overall = widget.budget == null
      ? widget.startOverall
      : widget.budget!.categoryId == null;
  late bool _rollover = widget.budget?.rollover ?? false;
  String? _error;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final paise = parseRupeesToPaise(_amount.text);
    if (paise == null || paise <= 0) {
      setState(() => _error = 'Enter a monthly amount');
      return;
    }
    if (!_overall && _categoryId == null) {
      setState(() => _error = 'Pick a category');
      return;
    }
    final existing = ref.read(budgetsProvider).value ?? const <Budget>[];
    final clash = existing.where(
      (b) =>
          b.id != widget.budget?.id &&
          b.categoryId == (_overall ? null : _categoryId),
    );
    if (clash.isNotEmpty) {
      setState(() => _error = 'There is already a budget for this');
      return;
    }
    final b = widget.budget;
    await ref
        .read(appDatabaseProvider)
        .saveBudget(
          BudgetsCompanion(
            id: b == null ? const Value.absent() : Value(b.id),
            categoryId: Value(_overall ? null : _categoryId),
            amountPaise: Value(paise),
            rollover: Value(_rollover),
          ),
        );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final categories =
        (ref.watch(categoriesProvider(CategoryKind.expense)).value ??
                const <Category>[])
            .where((c) => c.parentId == null)
            .toList();
    final editing = widget.budget != null;
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
            Text(
              editing ? 'Edit budget' : 'New monthly budget',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _amount,
              autofocus: !editing,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              style: theme.textTheme.headlineMedium,
              textAlign: TextAlign.center,
              decoration: const InputDecoration(
                prefixText: '₹ ',
                hintText: '0',
              ),
            ),
            const SizedBox(height: 16),
            Text('For', style: theme.textTheme.labelLarge),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  avatar: const Icon(Icons.all_inclusive, size: 18),
                  label: const Text('Everything'),
                  selected: _overall,
                  onSelected: (_) => setState(() => _overall = true),
                ),
                for (final c in categories)
                  ChoiceChip(
                    avatar: Icon(iconFor(c.icon), size: 18),
                    label: Text(c.name),
                    selected: !_overall && _categoryId == c.id,
                    onSelected: (_) => setState(() {
                      _overall = false;
                      _categoryId = c.id;
                    }),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Roll over unspent amount'),
              subtitle: const Text("Last month's leftover adds to this month"),
              value: _rollover,
              onChanged: (v) => setState(() => _rollover = v),
            ),
            if (_error != null)
              Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.check),
              label: const Text('Save'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
            ),
            if (editing)
              TextButton.icon(
                onPressed: () async {
                  final b = widget.budget!;
                  final db = ref.read(appDatabaseProvider);
                  final messenger = ScaffoldMessenger.of(context);
                  await db.deleteBudget(b.id);
                  if (!context.mounted) return;
                  Navigator.pop(context);
                  messenger.showSnackBar(
                    SnackBar(
                      content: const Text('Budget removed'),
                      action: SnackBarAction(
                        label: 'Undo',
                        onPressed: () => db.saveBudget(b.toCompanion(true)),
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.delete_outline),
                label: const Text('Remove budget'),
              ),
          ],
        ),
      ),
    );
  }
}

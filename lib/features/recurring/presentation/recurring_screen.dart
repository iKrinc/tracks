import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tracks/app/icons.dart';
import 'package:tracks/app/providers.dart';
import 'package:tracks/app/theme.dart';
import 'package:tracks/app/widgets/confirm.dart';
import 'package:tracks/app/widgets/hero.dart';
import 'package:tracks/core/dates.dart';
import 'package:tracks/core/money.dart';
import 'package:tracks/data/app_database.dart';
import 'package:tracks/features/capture/domain/capture_draft.dart';
import 'package:tracks/features/capture/presentation/confirm_sheet.dart';
import 'package:tracks/features/recurring/data/reminder_service.dart';
import 'package:tracks/features/recurring/domain/schedule.dart';

const autopayLabels = {
  AutopayKind.none: 'Manual',
  AutopayKind.upiMandate: 'UPI autopay',
  AutopayKind.cardStandingInstruction: 'Card autopay',
  AutopayKind.nach: 'NACH / ECS',
};

/// Common repeat choices → (unit, interval).
const _repeats = {
  'Weekly': (RepeatUnit.week, 1),
  'Monthly': (RepeatUnit.month, 1),
  'Quarterly': (RepeatUnit.month, 3),
  'Half-yearly': (RepeatUnit.month, 6),
  'Yearly': (RepeatUnit.year, 1),
};

String repeatLabel(RepeatUnit unit, int interval) =>
    _repeats.entries
        .where((e) => e.value == (unit, interval))
        .map((e) => e.key)
        .firstOrNull ??
    'Every $interval ${unit.name}s';

/// "Today", "Tomorrow", "In 3 days", "5 Nov", "2 days overdue".
String dueLabel(DateTime due, DateTime now) {
  final d = daysUntil(due, now);
  if (d < 0) return '${-d} day${d == -1 ? '' : 's'} overdue';
  if (d == 0) return 'Due today';
  if (d == 1) return 'Tomorrow';
  if (d <= 6) return 'In $d days';
  return shortDate(due).replaceFirst(' ${due.year}', '');
}

class RecurringScreen extends ConsumerWidget {
  const RecurringScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final tokens = theme.tokens;
    final items = ref.watch(dueItemsProvider);
    final paused = (ref.watch(recurringsProvider).value ?? const <Recurring>[])
        .where((r) => r.status == RecurringStatus.paused)
        .toList();
    final now = DateTime.now();
    final monthEnd = nextMonthStart(now);
    final dueThisMonth = items.where(
      (i) => i.due.isBefore(monthEnd) && i.item.type == TxnType.expense,
    );
    final dueSum = dueThisMonth.fold(0, (a, i) => a + i.item.amountPaise);

    List<Widget> section(String title, Iterable<DueItem> list) => [
      if (list.isNotEmpty) ...[
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
          child: Text(title, style: theme.textTheme.titleMedium),
        ),
        for (final i in list) _DueTile(item: i),
      ],
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Bills & autopay')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showRecurringSheet(context),
        icon: const Icon(Icons.add),
        label: const Text('Bill'),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 96),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: HeroCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Still to pay in ${monthLabel(now).split(' ').first}',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: tokens.heroMuted,
                    ),
                  ),
                  const SizedBox(height: 4),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: AnimatedAmount(
                      dueSum,
                      semanticsPrefix: 'Still to pay this month ',
                      style: theme.textTheme.displaySmall?.copyWith(
                        color: tokens.heroInk,
                      ),
                    ),
                  ),
                  Text(
                    dueThisMonth.isEmpty
                        ? 'Nothing else due this month'
                        : '${dueThisMonth.length} '
                              '${dueThisMonth.length == 1 ? 'bill' : 'bills'}'
                              ' · next: ${dueThisMonth.first.item.name}, '
                              '${dueLabel(dueThisMonth.first.due, now).toLowerCase()}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: tokens.heroInk,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (items.isEmpty && paused.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Text(
                'Add rent, EMIs, subscriptions and SIPs. Tracks shows '
                "what's due next and logs it in one tap when you pay.",
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium,
              ),
            ),
          ...section(
            'Overdue',
            items.where((i) => i.status == DueStatus.overdue),
          ),
          ...section(
            'Due soon',
            items.where(
              (i) => i.status == DueStatus.today || i.status == DueStatus.soon,
            ),
          ),
          ...section('Later', items.where((i) => i.status == DueStatus.later)),
          if (paused.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
              child: Text('Paused', style: theme.textTheme.titleMedium),
            ),
            for (final r in paused)
              ListTile(
                leading: const Icon(Icons.pause_circle_outline),
                title: Text(r.name),
                subtitle: Text(repeatLabel(r.unit, r.interval)),
                trailing: Text(formatPaise(r.amountPaise, hideZeroPaise: true)),
                onTap: () => showRecurringSheet(context, item: r),
              ),
          ],
        ],
      ),
    );
  }
}

class _DueTile extends ConsumerWidget {
  const _DueTile({required this.item});

  final DueItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final r = item.item;
    final now = DateTime.now();
    final category = r.categoryId == null
        ? null
        : [
            for (final k in CategoryKind.values)
              ...?ref.watch(categoriesProvider(k)).value,
          ].where((c) => c.id == r.categoryId).firstOrNull;
    final urgent =
        item.status == DueStatus.overdue || item.status == DueStatus.today;
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: category == null
            ? Palette.sand
            : Color(category.color),
        foregroundColor: Colors.black87,
        child: Icon(iconFor(category?.icon ?? 'receipt_long'), size: 20),
      ),
      title: Text(r.name),
      subtitle: Text(
        [
          repeatLabel(r.unit, r.interval),
          if (r.autopay != AutopayKind.none) autopayLabels[r.autopay]!,
        ].join(' · '),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            '${r.variableAmount ? '~' : ''}'
            '${formatPaise(r.amountPaise, hideZeroPaise: true)}',
            style: theme.textTheme.titleSmall?.copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (urgent)
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Icon(
                    Icons.schedule,
                    size: 14,
                    color: theme.expenseColor,
                  ),
                ),
              Text(
                dueLabel(item.due, now),
                style: theme.textTheme.labelMedium?.copyWith(
                  color: urgent
                      ? theme.expenseColor
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
      onTap: () => _showActions(context, ref, item),
    );
  }
}

Future<void> _showActions(BuildContext context, WidgetRef ref, DueItem i) {
  final r = i.item;
  final db = ref.read(appDatabaseProvider);
  return showModalBottomSheet(
    context: context,
    useRootNavigator: true,
    showDragHandle: true,
    builder: (sheet) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            title: Text(r.name, style: Theme.of(sheet).textTheme.titleLarge),
            subtitle: Text(
              'Due ${shortDate(i.due)} · '
              '${formatPaise(r.amountPaise, hideZeroPaise: true)}',
            ),
          ),
          ListTile(
            leading: const Icon(Icons.check_circle_outline),
            title: const Text('Mark paid'),
            subtitle: const Text('Log it as a transaction'),
            onTap: () async {
              Navigator.pop(sheet);
              await openMarkPaid(context, r);
            },
          ),
          ListTile(
            leading: const Icon(Icons.skip_next_outlined),
            title: const Text('Skip this one'),
            subtitle: Text('Move on to the next due date, nothing logged'),
            onTap: () async {
              Navigator.pop(sheet);
              await db.markRecurringPaid(r.id, i.due);
            },
          ),
          ListTile(
            leading: const Icon(Icons.edit_outlined),
            title: const Text('Edit'),
            onTap: () {
              Navigator.pop(sheet);
              showRecurringSheet(context, item: r);
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}

/// Logs a payment for [r] through a pre-filled Confirm Card; saving moves
/// the bill to its next due date. Used by the list and by reminders.
Future<bool?> openMarkPaid(BuildContext context, Recurring r) =>
    showConfirmSheet(
      context,
      draft: CaptureDraft(
        type: r.type,
        source: TxnSource.recurring,
        amountPaise: r.amountPaise,
        note: r.name,
        date: dateOnly(DateTime.now()),
        accountId: r.accountId,
        categoryId: r.categoryId,
        linkedRecurringId: r.id,
        tags: r.autopay == AutopayKind.none ? '' : 'autopay',
      ),
    );

Future<void> showRecurringSheet(BuildContext context, {Recurring? item}) =>
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (_) => _RecurringSheet(item: item),
    );

class _RecurringSheet extends ConsumerStatefulWidget {
  const _RecurringSheet({this.item});

  final Recurring? item;

  @override
  ConsumerState<_RecurringSheet> createState() => _RecurringSheetState();
}

class _RecurringSheetState extends ConsumerState<_RecurringSheet> {
  late final _name = TextEditingController(text: widget.item?.name);
  late final _amount = TextEditingController(
    text: widget.item == null
        ? ''
        : formatPaise(
            widget.item!.amountPaise,
            symbol: false,
            hideZeroPaise: true,
          ),
  );
  late TxnType _type = widget.item?.type ?? TxnType.expense;
  late bool _variable = widget.item?.variableAmount ?? false;
  late int? _accountId = widget.item?.accountId;
  late int? _categoryId = widget.item?.categoryId;
  late DateTime _start = widget.item?.startDate ?? dateOnly(DateTime.now());
  late (RepeatUnit, int) _repeat = widget.item == null
      ? (RepeatUnit.month, 1)
      : (widget.item!.unit, widget.item!.interval);
  late AutopayKind _autopay = widget.item?.autopay ?? AutopayKind.none;
  late int _remind = widget.item?.remindDaysBefore ?? 1;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    super.dispose();
  }

  Future<void> _save({RecurringStatus? status}) async {
    final name = _name.text.trim();
    final paise = parseRupeesToPaise(_amount.text);
    if (name.isEmpty) {
      setState(() => _error = 'Give it a name, e.g. Rent');
      return;
    }
    if (paise == null || paise <= 0) {
      setState(() => _error = 'Enter the amount');
      return;
    }
    if (_accountId == null) {
      setState(() => _error = 'Pick the account it is paid from');
      return;
    }
    final r = widget.item;
    await ref
        .read(appDatabaseProvider)
        .saveRecurring(
          RecurringsCompanion(
            id: r == null ? const Value.absent() : Value(r.id),
            name: Value(name),
            type: Value(_type),
            amountPaise: Value(paise),
            variableAmount: Value(_variable),
            accountId: Value(_accountId!),
            categoryId: Value(_categoryId),
            startDate: Value(_start),
            unit: Value(_repeat.$1),
            interval: Value(_repeat.$2),
            autopay: Value(_autopay),
            remindDaysBefore: Value(_remind),
            status: Value(status ?? r?.status ?? RecurringStatus.active),
            lastPaid: Value(r?.lastPaid),
            note: Value(r?.note ?? ''),
          ),
        );
    // Asks once (Android 13+), right when the reason is obvious.
    unawaited(ReminderService.instance.requestPermission());
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accounts = ref.watch(accountsProvider).value ?? const <Account>[];
    _accountId ??= accounts.firstOrNull?.id;
    final kind = _type == TxnType.income
        ? CategoryKind.income
        : CategoryKind.expense;
    final categories =
        (ref.watch(categoriesProvider(kind)).value ?? const <Category>[])
            .toList();
    final editing = widget.item != null;
    Widget label(String t) => Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 6),
      child: Text(t, style: theme.textTheme.labelLarge),
    );
    Widget chips<T>(
      Iterable<(T, String)> options,
      T selected,
      ValueChanged<T> onSelect,
    ) => Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final (v, text) in options)
          ChoiceChip(
            label: Text(text),
            selected: v == selected,
            onSelected: (_) => setState(() => onSelect(v)),
          ),
      ],
    );

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
              editing ? 'Edit ${widget.item!.name}' : 'New bill or income',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            SegmentedButton<TxnType>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: TxnType.expense, label: Text('Bill')),
                ButtonSegment(value: TxnType.income, label: Text('Income')),
              ],
              selected: {_type},
              onSelectionChanged: (s) => setState(() {
                _type = s.first;
                _categoryId = null;
              }),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _name,
              autofocus: !editing,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                hintText: 'Rent, Netflix, Car EMI, SIP…',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _amount,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                prefixText: '₹ ',
                hintText: 'Amount',
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Amount changes each time'),
              subtitle: const Text('Like electricity: you confirm when paying'),
              value: _variable,
              onChanged: (v) => setState(() => _variable = v),
            ),
            label('Repeats'),
            chips(
              [for (final e in _repeats.entries) (e.value, e.key)],
              _repeat,
              (v) => _repeat = v,
            ),
            label('First due date'),
            Align(
              alignment: Alignment.centerLeft,
              child: ActionChip(
                avatar: const Icon(Icons.event, size: 18),
                label: Text(shortDate(_start)),
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _start,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) setState(() => _start = picked);
                },
              ),
            ),
            label('Paid from'),
            chips(
              [for (final a in accounts) (a.id, a.name)],
              _accountId,
              (v) => _accountId = v,
            ),
            label('Category'),
            SizedBox(
              height: 48,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final c in categories)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        avatar: Icon(iconFor(c.icon), size: 18),
                        label: Text(c.name),
                        selected: c.id == _categoryId,
                        onSelected: (_) => setState(() => _categoryId = c.id),
                      ),
                    ),
                ],
              ),
            ),
            if (_type == TxnType.expense) ...[
              label('Autopay'),
              chips(
                [for (final e in autopayLabels.entries) (e.key, e.value)],
                _autopay,
                (v) => _autopay = v,
              ),
            ],
            label('Remind me'),
            chips(
              const [
                (0, 'On the day'),
                (1, '1 day before'),
                (3, '3 days before'),
              ],
              _remind,
              (v) => _remind = v,
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  _error!,
                  style: TextStyle(color: theme.colorScheme.error),
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
            if (editing) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextButton.icon(
                      onPressed: () => _save(
                        status: widget.item!.status == RecurringStatus.paused
                            ? RecurringStatus.active
                            : RecurringStatus.paused,
                      ),
                      icon: Icon(
                        widget.item!.status == RecurringStatus.paused
                            ? Icons.play_arrow
                            : Icons.pause,
                      ),
                      label: Text(
                        widget.item!.status == RecurringStatus.paused
                            ? 'Resume'
                            : 'Pause',
                      ),
                    ),
                  ),
                  Expanded(
                    child: TextButton.icon(
                      onPressed: () async {
                        final r = widget.item!;
                        final db = ref.read(appDatabaseProvider);
                        final messenger = ScaffoldMessenger.of(context);
                        if (!await confirmDestructive(
                          context,
                          title: 'Delete ${r.name}?',
                          message:
                              'Reminders stop. Payments already saved stay.',
                        )) {
                          return;
                        }
                        await db.deleteRecurring(r.id);
                        if (!context.mounted) return;
                        Navigator.pop(context);
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text('${r.name} removed'),
                            action: SnackBarAction(
                              label: 'Undo',
                              onPressed: () =>
                                  db.saveRecurring(r.toCompanion(true)),
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Delete'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

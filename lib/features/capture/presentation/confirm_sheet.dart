import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tracks/app/icons.dart';
import 'package:tracks/app/providers.dart';
import 'package:tracks/core/dates.dart';
import 'package:tracks/core/money.dart';
import 'package:tracks/data/app_database.dart';
import 'package:tracks/features/capture/domain/category_guess.dart';
import 'package:tracks/features/capture/domain/quick_add_parser.dart';

/// Opens the Confirm Card. Resolves to `true` when a transaction was saved.
Future<bool?> showConfirmSheet(
  BuildContext context, {
  QuickAddResult? parsed,
  String? rawText,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (_) => ConfirmSheet(parsed: parsed, rawText: rawText),
  );
}

class ConfirmSheet extends ConsumerStatefulWidget {
  const ConfirmSheet({super.key, this.parsed, this.rawText});

  final QuickAddResult? parsed;
  final String? rawText;

  @override
  ConsumerState<ConfirmSheet> createState() => _ConfirmSheetState();
}

class _ConfirmSheetState extends ConsumerState<ConfirmSheet> {
  late TxnType _type;
  late final TextEditingController _amount;
  late final TextEditingController _note;
  late DateTime _date;
  String _tags = '';
  int? _accountId;
  int? _toAccountId;
  int? _categoryId;
  bool _categoryTouched = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final p = widget.parsed;
    _type = switch (p?.kind) {
      QuickAddKind.income || QuickAddKind.borrowed => TxnType.income,
      QuickAddKind.transfer => TxnType.transfer,
      _ => TxnType.expense,
    };
    _amount = TextEditingController(
      text: p == null
          ? ''
          : formatPaise(p.amountPaise, symbol: false, hideZeroPaise: true),
    );
    _note = TextEditingController(text: _initialNote(p));
    _date = p?.date ?? dateOnly(DateTime.now());
    _tags = switch (p?.kind) {
      QuickAddKind.lent => 'lent',
      QuickAddKind.borrowed => 'borrowed',
      _ => '',
    };
  }

  static String _initialNote(QuickAddResult? p) {
    if (p == null) return '';
    final desc = p.description;
    final person = p.person;
    String join(String a) => desc.isEmpty ? a : '$desc · $a';
    return switch (p.kind) {
      QuickAddKind.lent when person != null => join('Lent to $person'),
      QuickAddKind.borrowed when person != null =>
        join('Borrowed from $person'),
      _ when person != null => join(person),
      _ => desc,
    };
  }

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  int? _resolveAccount(String? hint, List<Account> accounts) {
    if (hint == null) return null;
    for (final a in accounts) {
      final hints = a.matchHints
          .toLowerCase()
          .split(',')
          .map((h) => h.trim())
          .followedBy(a.name.toLowerCase().split(' '));
      if (hints.contains(hint)) return a.id;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accounts = ref.watch(accountsProvider).value ?? const <Account>[];
    final kind =
        _type == TxnType.income ? CategoryKind.income : CategoryKind.expense;
    final categories =
        ref.watch(categoriesProvider(kind)).value ?? const <Category>[];

    // Fill defaults once data has loaded.
    if (accounts.isNotEmpty) {
      _accountId ??=
          _resolveAccount(widget.parsed?.accountHint, accounts) ??
              accounts.first.id;
      if (_type == TxnType.transfer) {
        _toAccountId ??= _resolveAccount(widget.parsed?.toAccountHint, accounts);
      }
    }
    if (!_categoryTouched && _categoryId == null && categories.isNotEmpty) {
      final name = guessCategoryName(
        '${widget.parsed?.description ?? ''} ${_note.text}',
        categories.map((c) => c.name),
      );
      if (name != null) {
        _categoryId = categories.firstWhere((c) => c.name == name).id;
      }
    }

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
            SegmentedButton<TxnType>(
              segments: const [
                ButtonSegment(value: TxnType.expense, label: Text('Expense')),
                ButtonSegment(value: TxnType.income, label: Text('Income')),
                ButtonSegment(value: TxnType.transfer, label: Text('Transfer')),
              ],
              selected: {_type},
              onSelectionChanged: (s) => setState(() {
                _type = s.first;
                _categoryId = null;
                _categoryTouched = false;
                _error = null;
              }),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _amount,
              autofocus: widget.parsed == null,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              style: theme.textTheme.headlineMedium,
              textAlign: TextAlign.center,
              decoration: const InputDecoration(
                prefixText: '₹ ',
                hintText: '0',
              ),
            ),
            const SizedBox(height: 16),
            _Label(_type == TxnType.transfer ? 'From' : 'Account'),
            _AccountChips(
              accounts: accounts,
              selected: _accountId,
              onSelected: (id) => setState(() => _accountId = id),
            ),
            if (_type == TxnType.transfer) ...[
              const _Label('To'),
              _AccountChips(
                accounts: accounts.where((a) => a.id != _accountId).toList(),
                selected: _toAccountId,
                onSelected: (id) => setState(() => _toAccountId = id),
              ),
            ] else ...[
              const _Label('Category'),
              _CategoryChips(
                categories: categories,
                selected: _categoryId,
                onSelected: (id) => setState(() {
                  _categoryId = id;
                  _categoryTouched = true;
                }),
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: _note,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(hintText: 'Note'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                ActionChip(
                  avatar: const Icon(Icons.event, size: 18),
                  label: Text(_dateLabel(_date)),
                  onPressed: _pickDate,
                ),
                const Spacer(),
                if (_error != null)
                  Flexible(
                    child: Text(
                      _error!,
                      style: TextStyle(color: theme.colorScheme.error),
                      textAlign: TextAlign.end,
                    ),
                  ),
              ],
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
      ),
    );
  }

  String _dateLabel(DateTime d) {
    final today = dateOnly(DateTime.now());
    if (d == today) return 'Today';
    if (d == today.subtract(const Duration(days: 1))) return 'Yesterday';
    return '${weekdayShort(d)}, ${shortDate(d)}';
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _date = dateOnly(picked));
  }

  Future<void> _save() async {
    final paise = parseRupeesToPaise(_amount.text);
    if (paise == null || paise <= 0) {
      setState(() => _error = 'Enter an amount');
      return;
    }
    if (_accountId == null) {
      setState(() => _error = 'Pick an account');
      return;
    }
    final transfer = _type == TxnType.transfer;
    if (transfer && (_toAccountId == null || _toAccountId == _accountId)) {
      setState(() => _error = 'Pick a different "to" account');
      return;
    }

    final now = DateTime.now();
    await ref.read(appDatabaseProvider).addTransaction(
          TransactionsCompanion.insert(
            type: _type,
            amountPaise: paise,
            accountId: _accountId!,
            toAccountId: Value(transfer ? _toAccountId : null),
            categoryId: Value(transfer ? null : _categoryId),
            note: Value(_note.text.trim()),
            tags: Value(_tags),
            occurredAt: DateTime(
              _date.year,
              _date.month,
              _date.day,
              now.hour,
              now.minute,
              now.second,
            ),
            source: Value(
              widget.rawText == null ? TxnSource.manual : TxnSource.quickText,
            ),
            rawSourceText: Value(widget.rawText),
          ),
        );
    if (mounted) Navigator.of(context).pop(true);
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 4, bottom: 6),
        child: Text(text, style: Theme.of(context).textTheme.labelLarge),
      );
}

class _AccountChips extends ConsumerWidget {
  const _AccountChips({
    required this.accounts,
    required this.selected,
    required this.onSelected,
  });

  final List<Account> accounts;
  final int? selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          for (final a in accounts)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                avatar: Icon(iconFor(a.icon), size: 18),
                label: Text(a.name),
                selected: a.id == selected,
                onSelected: (_) => onSelected(a.id),
              ),
            ),
          ActionChip(
            avatar: const Icon(Icons.add, size: 18),
            label: const Text('Account'),
            onPressed: () async {
              final id = await showAddAccountDialog(context, ref);
              if (id != null) onSelected(id);
            },
          ),
        ],
      ),
    );
  }
}

class _CategoryChips extends StatelessWidget {
  const _CategoryChips({
    required this.categories,
    required this.selected,
    required this.onSelected,
  });

  final List<Category> categories;
  final int? selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    // Top-level categories each followed by their subcategories; the
    // current pick is pulled to the front so it's always visible.
    final ordered = <Category>[];
    for (final top in categories.where((c) => c.parentId == null)) {
      ordered.add(top);
      ordered.addAll(categories.where((c) => c.parentId == top.id));
    }
    final i = ordered.indexWhere((c) => c.id == selected);
    if (i > 0) ordered.insert(0, ordered.removeAt(i));

    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          for (final c in ordered)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                // Category colours are pastels, so selected chips always
                // use dark ink, in light and dark theme alike.
                avatar: Icon(
                  iconFor(c.icon),
                  size: 18,
                  color: c.id == selected ? Colors.black87 : null,
                ),
                label: Text(c.name),
                labelStyle: c.id == selected
                    ? const TextStyle(color: Colors.black87)
                    : null,
                selected: c.id == selected,
                selectedColor: Color(c.color),
                onSelected: (_) => onSelected(c.id),
              ),
            ),
        ],
      ),
    );
  }
}

/// Quick "new account" dialog. Returns the new account id.
Future<int?> showAddAccountDialog(BuildContext context, WidgetRef ref) {
  final name = TextEditingController();
  var type = AccountType.bank;
  return showDialog<int>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: const Text('New account'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(hintText: 'e.g. HDFC, GPay'),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final t in AccountType.values)
                  ChoiceChip(
                    label: Text(_accountTypeLabel(t)),
                    selected: t == type,
                    onSelected: (_) => setState(() => type = t),
                  ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final n = name.text.trim();
              if (n.isEmpty) return;
              final db = ref.read(appDatabaseProvider);
              final id = await db.into(db.accounts).insert(
                    AccountsCompanion.insert(
                      name: n,
                      type: type,
                      color: 0xFFAECBFA,
                      icon: _accountTypeIcon(type),
                      matchHints: Value(n.toLowerCase()),
                    ),
                  );
              if (context.mounted) Navigator.pop(context, id);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    ),
  );
}

String _accountTypeLabel(AccountType t) => switch (t) {
      AccountType.cash => 'Cash',
      AccountType.bank => 'Bank',
      AccountType.wallet => 'Wallet / UPI',
      AccountType.creditCard => 'Credit card',
      AccountType.loan => 'Loan',
    };

String _accountTypeIcon(AccountType t) => switch (t) {
      AccountType.cash => 'payments',
      AccountType.bank => 'account_balance',
      AccountType.wallet => 'account_balance_wallet',
      AccountType.creditCard => 'credit_card',
      AccountType.loan => 'request_quote',
    };

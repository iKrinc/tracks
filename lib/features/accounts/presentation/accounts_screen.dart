import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tracks/app/icons.dart';
import 'package:tracks/app/providers.dart';
import 'package:tracks/app/theme.dart';
import 'package:tracks/core/money.dart';
import 'package:tracks/data/app_database.dart';
import 'package:tracks/features/accounts/domain/balances.dart';
import 'package:tracks/features/accounts/domain/loan.dart';
import 'package:tracks/features/accounts/presentation/account_detail_sheet.dart';
import 'package:tracks/features/transactions/presentation/search_screen.dart';

const accountTypeLabels = {
  AccountType.cash: 'Cash',
  AccountType.bank: 'Bank',
  AccountType.wallet: 'Wallet / UPI',
  AccountType.creditCard: 'Credit card',
  AccountType.loan: 'Loans & money I owe',
  AccountType.lent: 'People who owe me',
};

const accountTypeIcons = {
  AccountType.cash: 'payments',
  AccountType.bank: 'account_balance',
  AccountType.wallet: 'account_balance_wallet',
  AccountType.creditCard: 'credit_card',
  AccountType.loan: 'request_quote',
  AccountType.lent: 'person',
};

class AccountsScreen extends ConsumerWidget {
  const AccountsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final all = ref.watch(allAccountsProvider).value ?? const <Account>[];
    final accounts = all.where((a) => !a.archived).toList();
    final archived = all.where((a) => a.archived).toList();
    final balances = ref.watch(balancesProvider);

    Color amountColor(int paise) =>
        paise < 0 ? theme.expenseColor : theme.colorScheme.onSurface;

    Widget section(String title) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
      child: Text(title, style: theme.textTheme.titleSmall),
    );

    Widget tile(Account a) => ListTile(
      leading: CircleAvatar(
        backgroundColor: Color(a.color),
        foregroundColor: Colors.black87,
        child: Icon(iconFor(a.icon), size: 20),
      ),
      title: Text(a.name),
      subtitle: a.matchHints.isEmpty
          ? null
          : Text(
              'Matches: ${a.matchHints.replaceAll(',', ', ')}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
      trailing: Semantics(
        label: spokenPaise(balances[a.id] ?? 0),
        excludeSemantics: true,
        child: Text(
          formatPaise(balances[a.id] ?? 0),
          style: theme.textTheme.titleSmall?.copyWith(
            color: amountColor(balances[a.id] ?? 0),
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ),
      // Honest numbers: a balance opens its transactions.
      onTap: () => hasDetail(a)
          ? showAccountDetail(context, a)
          : context.push('/search', extra: SearchArgs(accountId: a.id)),
      onLongPress: () => showAccountSheet(context, account: a),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Accounts')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showAccountSheet(context),
        icon: const Icon(Icons.add),
        label: const Text('Account'),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 96),
        children: [
          Card(
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            elevation: 0,
            color: theme.colorScheme.secondaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Text('Net worth', style: theme.textTheme.labelMedium),
                  const SizedBox(height: 4),
                  Semantics(
                    label: 'Net worth ${spokenPaise(netWorth(balances))}',
                    excludeSemantics: true,
                    child: Text(
                      formatPaise(netWorth(balances)),
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          for (final type in AccountType.values)
            if (accounts.any((a) => a.type == type)) ...[
              section(accountTypeLabels[type]!),
              for (final a in accounts.where((a) => a.type == type)) tile(a),
            ],
          if (archived.isNotEmpty) ...[
            section('Archived'),
            for (final a in archived) tile(a),
          ],
          if (accounts.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                'Tap an account to see its transactions, long-press to edit.',
                style: theme.textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }
}

Future<void> showAccountSheet(BuildContext context, {Account? account}) =>
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      // Above the bottom navigation, not inside the current tab.
      useRootNavigator: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (_) => _AccountSheet(account: account),
    );

class _AccountSheet extends ConsumerStatefulWidget {
  const _AccountSheet({this.account});

  final Account? account;

  @override
  ConsumerState<_AccountSheet> createState() => _AccountSheetState();
}

class _AccountSheetState extends ConsumerState<_AccountSheet> {
  late final _name = TextEditingController(text: widget.account?.name);
  late final _opening = TextEditingController(
    text: widget.account == null
        ? ''
        : formatPaise(
            // Cards and loans show what's owed as a positive number.
            switch (widget.account!.type) {
              AccountType.creditCard ||
              AccountType.loan => widget.account!.openingBalancePaise.abs(),
              _ => widget.account!.openingBalancePaise,
            },
            symbol: false,
            hideZeroPaise: true,
          ),
  );
  late final _hints = TextEditingController(
    text: widget.account?.matchHints.replaceAll(',', ', '),
  );
  late AccountType _type = widget.account?.type ?? AccountType.bank;
  String? _error;

  // Card and loan fields.
  static String _rupees(int? p) =>
      p == null ? '' : formatPaise(p, symbol: false, hideZeroPaise: true);
  late final _limit = TextEditingController(
    text: _rupees(widget.account?.creditLimitPaise),
  );
  late final _statementDay = TextEditingController(
    text: widget.account?.statementDay?.toString() ?? '',
  );
  late final _dueDay = TextEditingController(
    text: widget.account?.dueDay?.toString() ?? '',
  );
  late final _principal = TextEditingController(
    text: _rupees(widget.account?.principalPaise),
  );
  late final _rate = TextEditingController(
    text: widget.account?.interestRateBp == null
        ? ''
        : (widget.account!.interestRateBp! / 100).toString(),
  );
  late final _emi = TextEditingController(
    text: _rupees(widget.account?.emiPaise),
  );
  late final _tenure = TextEditingController(
    text: widget.account?.tenureMonths?.toString() ?? '',
  );

  bool get _isCard => _type == AccountType.creditCard;
  bool get _isDebt => _type == AccountType.loan || _type == AccountType.lent;

  @override
  void dispose() {
    for (final c in [
      _name,
      _opening,
      _hints,
      _limit,
      _statementDay,
      _dueDay,
      _principal,
      _rate,
      _emi,
      _tenure,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  /// Rate as typed ("9.5") → basis points (950), without touching double
  /// for money: only the percentage string is parsed.
  static int? _rateBp(String text) {
    final paise = parseRupeesToPaise(text.trim());
    return paise; // "9.5" → 950: same two-decimal shape as rupees.
  }

  static int? _day(String text) {
    final d = int.tryParse(text.trim());
    return d != null && d >= 1 && d <= 31 ? d : null;
  }

  void _fillEmi() {
    final p = parseRupeesToPaise(_principal.text);
    final months = int.tryParse(_tenure.text.trim());
    final rate = _rateBp(_rate.text) ?? 0;
    if (p == null || months == null || months <= 0) {
      setState(() => _error = 'Enter amount and tenure to work out the EMI');
      return;
    }
    setState(() {
      _error = null;
      _emi.text = _rupees(
        emiPaise(principalPaise: p, rateBp: rate, months: months),
      );
    });
  }

  /// [archive] true archives, false restores, null keeps the current state.
  Future<void> _save({bool? archive}) async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Give the account a name');
      return;
    }
    // Cards and loans: "outstanding / still owed" is typed as a positive
    // number and stored as a negative balance. Lent: positive (owed to you).
    // Other accounts allow a leading minus.
    final raw = _opening.text.trim();
    final typedNegative = raw.startsWith('-') || raw.startsWith('−');
    final amount = raw.isEmpty
        ? (_isDebt ? parseRupeesToPaise(_principal.text) ?? 0 : 0)
        : parseRupeesToPaise(typedNegative ? raw.substring(1) : raw);
    if (amount == null) {
      setState(() => _error = 'That amount needs to be a number');
      return;
    }
    final owes = _isCard || _type == AccountType.loan;
    final opening = owes || typedNegative ? -amount : amount;
    if (_isCard &&
        (_day(_statementDay.text) == null || _day(_dueDay.text) == null) &&
        (_statementDay.text.isNotEmpty || _dueDay.text.isNotEmpty)) {
      setState(() => _error = 'Statement and due days are 1 to 31');
      return;
    }
    final hints = _hints.text
        .toLowerCase()
        .split(',')
        .map((h) => h.trim())
        .where((h) => h.isNotEmpty)
        .join(',');
    final a = widget.account;
    await ref
        .read(appDatabaseProvider)
        .saveAccount(
          AccountsCompanion(
            id: a == null ? const Value.absent() : Value(a.id),
            name: Value(name),
            type: Value(_type),
            openingBalancePaise: Value(opening),
            color: Value(a?.color ?? Palette.marigoldSoft.toARGB32()),
            icon: Value(accountTypeIcons[_type]!),
            matchHints: Value(hints),
            sortOrder: Value(a?.sortOrder ?? 0),
            archived: Value(archive ?? a?.archived ?? false),
            creditLimitPaise: Value(
              _isCard ? parseRupeesToPaise(_limit.text) : null,
            ),
            statementDay: Value(_isCard ? _day(_statementDay.text) : null),
            dueDay: Value(_isCard ? _day(_dueDay.text) : null),
            principalPaise: Value(
              _isDebt ? parseRupeesToPaise(_principal.text) : null,
            ),
            interestRateBp: Value(_isDebt ? _rateBp(_rate.text) : null),
            emiPaise: Value(_isDebt ? parseRupeesToPaise(_emi.text) : null),
            tenureMonths: Value(
              _isDebt ? int.tryParse(_tenure.text.trim()) : null,
            ),
          ),
        );
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final db = ref.read(appDatabaseProvider);
    Navigator.pop(context);
    if (archive == true && a != null) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Archived ${a.name}'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () => db.saveAccount(
              a.toCompanion(true).copyWith(archived: const Value(false)),
            ),
          ),
        ),
      );
    }
  }

  Widget _money(TextEditingController c, String hint, {bool signed = false}) =>
      TextField(
        controller: c,
        keyboardType: TextInputType.numberWithOptions(
          decimal: true,
          signed: signed,
        ),
        decoration: InputDecoration(prefixText: '₹ ', labelText: hint),
      );

  Widget _number(TextEditingController c, String hint) => TextField(
    controller: c,
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    decoration: InputDecoration(labelText: hint),
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final editing = widget.account != null;
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
              editing ? 'Edit account' : 'New account',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _name,
              autofocus: !editing,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(hintText: 'Name, e.g. HDFC'),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final t in AccountType.values)
                  ChoiceChip(
                    avatar: Icon(iconFor(accountTypeIcons[t]!), size: 18),
                    label: Text(accountTypeLabels[t]!),
                    selected: t == _type,
                    onSelected: (_) => setState(() => _type = t),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (_isDebt) ...[
              _money(_principal, 'Original amount'),
              const SizedBox(height: 12),
            ],
            _money(_opening, switch (_type) {
              AccountType.creditCard => 'Outstanding today',
              AccountType.loan => 'Still owed now (blank = full amount)',
              AccountType.lent => 'They still owe (blank = full amount)',
              _ => 'Balance today (use − if overdrawn)',
            }, signed: !_isCard && !_isDebt),
            if (_isCard) ...[
              const SizedBox(height: 12),
              _money(_limit, 'Credit limit'),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _number(_statementDay, 'Statement day')),
                  const SizedBox(width: 12),
                  Expanded(child: _number(_dueDay, 'Due day')),
                ],
              ),
            ],
            if (_isDebt) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _number(_rate, 'Interest % / yr')),
                  const SizedBox(width: 12),
                  Expanded(child: _number(_tenure, 'Months')),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _money(_emi, 'EMI per month')),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: _fillEmi,
                    child: const Text('Work it out'),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: _hints,
              decoration: const InputDecoration(
                hintText: 'SMS matches, e.g. hdfc, 1234',
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
              child: Text(
                'Words or last 4 digits that identify this account in '
                'shared SMS and quick-add.',
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
              onPressed: () => _save(),
              icon: const Icon(Icons.check),
              label: const Text('Save'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
            ),
            if (editing) ...[
              const SizedBox(height: 8),
              if (widget.account!.archived)
                TextButton.icon(
                  onPressed: () => _save(archive: false),
                  icon: const Icon(Icons.unarchive_outlined),
                  label: const Text('Restore account'),
                )
              else
                TextButton.icon(
                  onPressed: () => _save(archive: true),
                  icon: const Icon(Icons.archive_outlined),
                  label: const Text('Archive (keeps its transactions)'),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

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
import 'package:tracks/features/transactions/presentation/search_screen.dart';

const accountTypeLabels = {
  AccountType.cash: 'Cash',
  AccountType.bank: 'Bank',
  AccountType.wallet: 'Wallet / UPI',
  AccountType.creditCard: 'Credit card',
  AccountType.loan: 'Loan',
};

const accountTypeIcons = {
  AccountType.cash: 'payments',
  AccountType.bank: 'account_balance',
  AccountType.wallet: 'account_balance_wallet',
  AccountType.creditCard: 'credit_card',
  AccountType.loan: 'request_quote',
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
      onTap: () => context.push('/search', extra: SearchArgs(accountId: a.id)),
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
            widget.account!.openingBalancePaise,
            symbol: false,
            hideZeroPaise: true,
          ),
  );
  late final _hints = TextEditingController(
    text: widget.account?.matchHints.replaceAll(',', ', '),
  );
  late AccountType _type = widget.account?.type ?? AccountType.bank;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _opening.dispose();
    _hints.dispose();
    super.dispose();
  }

  /// [archive] true archives, false restores, null keeps the current state.
  Future<void> _save({bool? archive}) async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Give the account a name');
      return;
    }
    // Allow a leading minus for card/loan dues.
    final raw = _opening.text.trim();
    final negative = raw.startsWith('-') || raw.startsWith('−');
    final opening = raw.isEmpty
        ? 0
        : parseRupeesToPaise(negative ? raw.substring(1) : raw);
    if (opening == null) {
      setState(() => _error = 'Opening balance should be an amount');
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
            openingBalancePaise: Value(negative ? -opening : opening),
            color: Value(a?.color ?? Palette.blue.toARGB32()),
            icon: Value(accountTypeIcons[_type]!),
            matchHints: Value(hints),
            sortOrder: Value(a?.sortOrder ?? 0),
            archived: Value(archive ?? a?.archived ?? false),
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
            TextField(
              controller: _opening,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
                signed: true,
              ),
              decoration: const InputDecoration(
                prefixText: '₹ ',
                hintText: 'Opening balance (use − for dues)',
              ),
            ),
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

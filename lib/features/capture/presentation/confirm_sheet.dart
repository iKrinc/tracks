import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tracks/app/icons.dart';
import 'package:tracks/app/providers.dart';
import 'package:tracks/core/dates.dart';
import 'package:tracks/core/money.dart';
import 'package:tracks/data/app_database.dart';
import 'package:tracks/data/default_data.dart';
import 'package:tracks/features/accounts/domain/loan.dart';
import 'package:tracks/features/capture/domain/account_match.dart';
import 'package:tracks/features/capture/domain/capture_draft.dart';
import 'package:tracks/features/capture/domain/category_guess.dart';
import 'package:tracks/features/capture/domain/rules.dart';

/// Opens the Confirm Card, pre-filled from [draft] (or blank for the form
/// fallback). Resolves to `true` when a transaction was saved.
Future<bool?> showConfirmSheet(BuildContext context, {CaptureDraft? draft}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    // Above the bottom navigation, not inside the current tab.
    useRootNavigator: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (_) => ConfirmSheet(draft: draft),
  );
}

class ConfirmSheet extends ConsumerStatefulWidget {
  const ConfirmSheet({super.key, this.draft});

  final CaptureDraft? draft;

  @override
  ConsumerState<ConfirmSheet> createState() => _ConfirmSheetState();
}

class _ConfirmSheetState extends ConsumerState<ConfirmSheet> {
  late TxnType _type;
  late final TextEditingController _amount;
  late final TextEditingController _note;
  late DateTime _date;
  int? _accountId;
  int? _toAccountId;
  bool _accountMatched = false;
  bool _toAccountMatched = false;
  int? _categoryId;
  bool _categoryTouched = false;
  List<Transaction> _duplicates = const [];
  late bool _asIou = widget.draft?.person != null;

  /// The learned rule that pre-filled this card, if any.
  RuleLike? _rule;
  bool _ruleLooked = false;

  /// What the card first suggested; changing it is a correction worth
  /// remembering.
  int? _suggestedAccountId;
  int? _suggestedCategoryId;
  bool _suggestionsTaken = false;
  bool _remember = true;

  /// Paying into a loan with a rate: book this month's interest as an
  /// expense and only the rest against the loan.
  bool _splitInterest = true;

  /// The fund a main-account spend is for; a fund's own account sets it.
  late int? _fundId = widget.draft?.fundId;
  String? _error;

  CaptureDraft? get _d => widget.draft;

  @override
  void initState() {
    super.initState();
    final d = _d;
    _type = d?.type ?? TxnType.expense;
    final paise = d?.amountPaise;
    _amount = TextEditingController(
      text: paise == null
          ? ''
          : formatPaise(paise, symbol: false, hideZeroPaise: true),
    );
    _note = TextEditingController(text: d?.note ?? '');
    _date = d?.date ?? dateOnly(DateTime.now());
    if (paise != null) _checkDuplicates(paise);
  }

  Future<void> _checkDuplicates(int paise) async {
    final found = await ref
        .read(appDatabaseProvider)
        .findPossibleDuplicates(
          amountPaise: paise,
          day: _date,
          refNo: _d?.refNo,
        );
    if (mounted && found.isNotEmpty) setState(() => _duplicates = found);
  }

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  static Iterable<MatchableAccount> _matchable(List<Account> accounts) =>
      accounts.map((a) => (id: a.id, name: a.name, matchHints: a.matchHints));

  /// Resolves draft hints against accounts once they've loaded.
  void _resolveAccounts(List<Account> accounts) {
    if (accounts.isEmpty) return;
    final d = _d;
    if (_accountId == null) {
      // The capture's own account hint beats a learned rule.
      final ruleAccount = _rule?.accountId;
      final id = d == null
          ? null
          : d.accountId ??
                matchAccount(
                  _matchable(accounts),
                  hint: d.accountHint,
                  last4: d.accountLast4,
                  bank: d.bankHint,
                ) ??
                (accounts.any((a) => a.id == ruleAccount) ? ruleAccount : null);
      _accountMatched = id != null;
      // Unmatched (e.g. a card bill payment, whose source bank is rarely in
      // the SMS): fall back to the first account; the user can change it.
      _accountId = id ?? accounts.first.id;
    }
    if (_type == TxnType.transfer && _toAccountId == null && d != null) {
      final id =
          d.toAccountId ??
          matchAccount(
            _matchable(accounts),
            hint: d.toAccountHint,
            last4: d.toAccountLast4,
          );
      _toAccountMatched = id != null;
      _toAccountId = id == _accountId ? null : id;
    }
  }

  /// "HDFC ••1234" when the capture names an account we couldn't match.
  String? _unmatchedLabel({required bool to}) {
    final d = _d;
    if (d == null) return null;
    final last4 = to ? d.toAccountLast4 : d.accountLast4;
    final bank = to ? null : d.bankHint;
    if ((to ? _toAccountMatched : _accountMatched) ||
        (last4 == null && bank == null)) {
      return null;
    }
    return [
      if (bank != null) bank.toUpperCase(),
      if (last4 != null) '••$last4',
    ].join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accounts = ref.watch(accountsProvider).value ?? const <Account>[];
    final kind = _type == TxnType.income
        ? CategoryKind.income
        : CategoryKind.expense;
    final categories =
        ref.watch(categoriesProvider(kind)).value ?? const <Category>[];

    // Kept live for the EMI interest split, which needs what's still owed.
    ref.watch(balancesProvider);
    final rules = ref.watch(rulesProvider);
    if (!_ruleLooked && rules.hasValue) {
      _ruleLooked = true;
      final d = _d;
      if (d != null) {
        _rule = findRule(
          ruleLikes(rules.value!),
          merchant: d.merchant,
          note: d.note,
        );
      }
    }
    // Wait for rules (a few ms) so a learned account isn't overridden by
    // the first-account fallback.
    if (_ruleLooked) _resolveAccounts(accounts);
    final presetCategory = _d?.categoryId;
    if (!_categoryTouched &&
        _categoryId == null &&
        presetCategory != null &&
        categories.any((c) => c.id == presetCategory)) {
      _categoryId = presetCategory;
    }
    final ruleCategory = _rule?.categoryId;
    if (!_categoryTouched &&
        _categoryId == null &&
        ruleCategory != null &&
        categories.any((c) => c.id == ruleCategory)) {
      _categoryId = ruleCategory;
    }
    // The keyword guess waits for rules too, or it would beat a learned one.
    if (_ruleLooked &&
        !_categoryTouched &&
        _categoryId == null &&
        categories.isNotEmpty) {
      final name = guessCategoryName(
        '${_d?.categoryText ?? ''} ${_note.text}',
        categories.map((c) => c.name),
      );
      if (name != null) {
        _categoryId = categories.firstWhere((c) => c.name == name).id;
      }
    }
    if (!_suggestionsTaken &&
        _ruleLooked &&
        accounts.isNotEmpty &&
        categories.isNotEmpty) {
      _suggestionsTaken = true;
      _suggestedAccountId = _accountId;
      _suggestedCategoryId = _categoryId;
    }
    final transfer = _type == TxnType.transfer;
    final openFunds = [
      for (final f in ref.watch(fundsProvider).value ?? const <Fund>[])
        if (!f.archived) f,
    ];
    final accountFund = accounts
        .where((a) => a.id == _accountId)
        .firstOrNull
        ?.fundId;
    final learnKey = _learnKey();
    final unmatchedFrom = _unmatchedLabel(to: false);
    final unmatchedTo = transfer ? _unmatchedLabel(to: true) : null;

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
            if (_duplicates.isNotEmpty) ...[
              _DuplicateBanner(existing: _duplicates.first),
              const SizedBox(height: 12),
            ],
            SegmentedButton<TxnType>(
              // The fill marks the choice; a checkmark squeezes "Transfer"
              // onto two lines at large text sizes.
              showSelectedIcon: false,
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
              autofocus: _d?.amountPaise == null,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              style: theme.textTheme.headlineMedium?.copyWith(
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
              textAlign: TextAlign.center,
              decoration: const InputDecoration(
                prefixText: '₹ ',
                hintText: '0',
              ),
            ),
            const SizedBox(height: 16),
            _Label(transfer ? 'From' : 'Account'),
            _AccountChips(
              accounts: accounts,
              selected: _accountId,
              onSelected: (id) => setState(() {
                _accountId = id;
                _accountMatched = true;
              }),
              suggestion: unmatchedFrom == null
                  ? null
                  : _NewAccountSuggestion(
                      label: unmatchedFrom,
                      name: _d?.bankHint?.toUpperCase() ?? 'Account',
                      hints: suggestedHints(
                        last4: _d?.accountLast4,
                        bank: _d?.bankHint,
                      ),
                    ),
            ),
            if (transfer) ...[
              const _Label('To'),
              _AccountChips(
                accounts: accounts.where((a) => a.id != _accountId).toList(),
                selected: _toAccountId,
                onSelected: (id) => setState(() {
                  _toAccountId = id;
                  _toAccountMatched = true;
                }),
                suggestion: unmatchedTo == null
                    ? null
                    : _NewAccountSuggestion(
                        label: unmatchedTo,
                        name: 'Credit card',
                        hints: suggestedHints(last4: _d?.toAccountLast4),
                        type: AccountType.creditCard,
                      ),
              ),
              if (_loanPaid(accounts) case final loan?)
                _InterestSplit(
                  loan: loan,
                  paymentPaise: parseRupeesToPaise(_amount.text) ?? 0,
                  split: _split(loan, parseRupeesToPaise(_amount.text) ?? 0),
                  on: _splitInterest,
                  onChanged: (v) => setState(() => _splitInterest = v),
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
              if (openFunds.isNotEmpty) ...[
                const _Label('For a fund'),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final f in [null, ...openFunds])
                      ChoiceChip(
                        label: Text(f?.name ?? 'None'),
                        selected: (accountFund ?? _fundId) == f?.id,
                        // Spending from a fund's own account is always its.
                        onSelected: accountFund != null
                            ? null
                            : (_) => setState(() => _fundId = f?.id),
                      ),
                  ],
                ),
              ],
            ],
            const SizedBox(height: 12),
            TextField(
              controller: _note,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(hintText: 'Note'),
            ),
            const SizedBox(height: 12),
            // Wrap, not Row: two chips overflow 360 dp at large text scale.
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                ActionChip(
                  avatar: const Icon(Icons.event, size: 18),
                  label: Text(_dateLabel(_date)),
                  onPressed: _pickDate,
                ),
                if (_d?.person != null && _type != TxnType.transfer)
                  FilterChip(
                    avatar: const Icon(Icons.handshake_outlined, size: 18),
                    label: Text('Track as IOU with ${_d!.person}'),
                    tooltip: 'Keeps it out of spending; shows what is owed',
                    // The global theme hides checkmarks; this toggle needs one
                    // because its fill alone barely differs from the sheet.
                    showCheckmark: true,
                    selected: _asIou,
                    onSelected: (v) => setState(() => _asIou = v),
                  ),
                if (learnKey != null)
                  FilterChip(
                    label: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 240),
                      child: Text(
                        'Always for "$learnKey"',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    tooltip: 'Next time, fill this in the same way',
                    showCheckmark: true,
                    selected: _remember,
                    onSelected: (v) => setState(() => _remember = v),
                  ),
                if (_d?.source == TxnSource.sms)
                  const Chip(
                    avatar: Icon(Icons.sms_outlined, size: 18),
                    label: Text('From SMS'),
                  ),
              ],
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
              label: Text(_duplicates.isEmpty ? 'Save' : 'Save anyway'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The fund a spend from [accountId] is for: the account's own fund, else
  /// the one picked.
  int? _fundFor(int accountId) {
    final accounts = ref.read(allAccountsProvider).value ?? const <Account>[];
    final own = accounts.where((a) => a.id == accountId).firstOrNull?.fundId;
    return own ?? _fundId;
  }

  /// The loan being paid, when it has a rate to split interest by.
  Account? _loanPaid(List<Account> accounts) {
    if (_type != TxnType.transfer || _asIou) return null;
    final to = accounts.where((a) => a.id == _toAccountId).firstOrNull;
    if (to == null || to.type != AccountType.loan) return null;
    return (to.interestRateBp ?? 0) > 0 ? to : null;
  }

  /// Principal and interest of [paise] paid into [loan].
  EmiSplit _split(Account loan, int paise) {
    final balance = ref.read(balancesProvider)[loan.id] ?? 0;
    return splitEmi(
      paymentPaise: paise,
      // A loan's balance is negative: what's still owed.
      outstandingPaise: -balance,
      rateBp: loan.interestRateBp,
    );
  }

  /// The keyword to offer "Always for …" under, when the user corrected
  /// the suggested category or account of a capture.
  String? _learnKey() {
    final d = _d;
    if (d == null || !_suggestionsTaken || _asIou) return null;
    if (_type == TxnType.transfer) return null;
    final categoryChanged =
        _categoryId != null && _categoryId != _suggestedCategoryId;
    final accountChanged =
        _accountId != null && _accountId != _suggestedAccountId;
    if (!categoryChanged && !accountChanged) return null;
    return ruleKey(merchant: d.merchant, note: _note.text);
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

    final d = _d;
    final now = DateTime.now();
    final db = ref.read(appDatabaseProvider);
    // IOU: move money to/from the person's account instead of spending it.
    var type = _type;
    var from = _accountId!;
    int? to = transfer ? _toAccountId : null;
    final person = d?.person;
    if (_asIou && person != null && !transfer) {
      final lent = d!.tags.contains('lent');
      final personId = await db.findOrCreatePerson(person, lent: lent);
      type = TxnType.transfer;
      if (lent) {
        to = personId;
      } else {
        to = from;
        from = personId;
      }
    }
    final occurredAt = DateTime(
      _date.year,
      _date.month,
      _date.day,
      d?.time?.hour ?? now.hour,
      d?.time?.minute ?? now.minute,
      d?.time == null ? now.second : 0,
    );
    // An EMI: the interest part is spending, only the principal lowers
    // the loan.
    final accounts = ref.read(accountsProvider).value ?? const <Account>[];
    final loan = _splitInterest ? _loanPaid(accounts) : null;
    final split = loan == null ? null : _split(loan, paise);
    final expense = split == null || split.interestPaise == 0
        ? const <Category>[]
        : await ref.read(categoriesProvider(CategoryKind.expense).future);
    // Interest and principal are saved together or not at all. A payment
    // smaller than the month's interest is all interest: no transfer.
    final transferPaise = split?.principalPaise ?? paise;
    await db.transaction(() async {
      if (loan != null && split != null && split.interestPaise > 0) {
        await db.addTransaction(
          TransactionsCompanion.insert(
            type: TxnType.expense,
            amountPaise: split.interestPaise,
            accountId: from,
            categoryId: Value(
              expense.where((c) => c.name == 'EMI & Loans').firstOrNull?.id,
            ),
            note: Value('Interest · ${loan.name}'),
            tags: Value(
              [d?.tags ?? '', 'interest'].where((t) => t.isNotEmpty).join(','),
            ),
            occurredAt: occurredAt,
            source: Value(d?.source ?? TxnSource.manual),
            rawSourceText: Value(d?.rawText),
          ),
        );
      }
      if (transferPaise <= 0) return;
      await db.addTransaction(
        TransactionsCompanion.insert(
          type: type,
          amountPaise: transferPaise,
          accountId: from,
          toAccountId: Value(to),
          categoryId: Value(type == TxnType.transfer ? null : _categoryId),
          fundId: Value(type == TxnType.transfer ? null : _fundFor(from)),
          note: Value(_note.text.trim()),
          merchant: Value(d?.merchant),
          tags: Value(d?.tags ?? ''),
          // The SMS/receipt's own time when it has one, else now.
          occurredAt: occurredAt,
          source: Value(d?.source ?? TxnSource.manual),
          rawSourceText: Value(d?.rawText),
          refNo: Value(d?.refNo),
          linkedRecurringId: Value(d?.linkedRecurringId),
        ),
      );
    });
    final learnKey = _learnKey();
    if (learnKey != null && _remember) {
      await db.learnRule(
        learnKey,
        categoryId: _categoryId != _suggestedCategoryId ? _categoryId : null,
        accountId: _accountId != _suggestedAccountId ? _accountId : null,
      );
    } else if (_rule != null && learnKey == null) {
      await db.bumpRule(_rule!.id);
    }
    final recurringId = d?.linkedRecurringId;
    if (recurringId != null) {
      await ref.read(appDatabaseProvider).markRecurringPaid(recurringId, _date);
    }
    if (mounted) Navigator.of(context).pop(true);
  }
}

/// "₹6,542 lowers the loan · ₹3,958 interest at 9.5%", with a toggle for
/// prepayments the user wants booked entirely against the loan.
class _InterestSplit extends StatelessWidget {
  const _InterestSplit({
    required this.loan,
    required this.paymentPaise,
    required this.split,
    required this.on,
    required this.onChanged,
  });

  final Account loan;
  final int paymentPaise;
  final EmiSplit split;
  final bool on;
  final ValueChanged<bool> onChanged;

  /// 950 bp → "9.5", 900 → "9", 1075 → "10.75"; no doubles.
  static String _percent(int bp) {
    final whole = bp ~/ 100;
    final frac = (bp % 100)
        .toString()
        .padLeft(2, '0')
        .replaceFirst(RegExp(r'0+$'), '');
    return frac.isEmpty ? '$whole' : '$whole.$frac';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rate = _percent(loan.interestRateBp!);
    final String text;
    final String spoken;
    if (paymentPaise <= 0) {
      text = 'Enter the amount to see the interest at $rate%';
      spoken = text.replaceFirst('%', ' percent');
    } else if (on) {
      text =
          '${formatPaise(split.principalPaise)} lowers the loan\n'
          '${formatPaise(split.interestPaise)} interest at $rate%';
      spoken =
          '${spokenPaise(split.principalPaise)} lowers the loan, '
          '${spokenPaise(split.interestPaise)} interest at $rate percent';
    } else {
      text = 'All ${formatPaise(paymentPaise)} lowers the loan (a prepayment)';
      spoken = 'All ${spokenPaise(paymentPaise)} lowers the loan';
    }
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: SwitchListTile(
        contentPadding: EdgeInsets.zero,
        isThreeLine: true,
        value: on,
        onChanged: onChanged,
        title: const Text('Split out interest'),
        subtitle: Semantics(
          label: spoken,
          excludeSemantics: true,
          child: Text(
            text,
            style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
          ),
        ),
      ),
    );
  }
}

class _DuplicateBanner extends StatelessWidget {
  const _DuplicateBanner({required this.existing});

  final Transaction existing;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final what = [
      formatPaise(existing.amountPaise),
      shortDate(existing.occurredAt),
      if (existing.note.isNotEmpty) existing.note,
    ].join(' · ');
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          ExcludeSemantics(
            child: Icon(
              Icons.copy_all_outlined,
              color: scheme.onTertiaryContainer,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Semantics(
              label: [
                'Possible duplicate of ${spokenPaise(existing.amountPaise)}',
                'on ${shortDate(existing.occurredAt)}',
                if (existing.note.isNotEmpty) existing.note,
              ].join(', '),
              excludeSemantics: true,
              child: Text(
                'Possible duplicate of $what',
                style: TextStyle(color: scheme.onTertiaryContainer),
              ),
            ),
          ),
        ],
      ),
    );
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

/// An account the capture mentions but the user hasn't set up yet.
class _NewAccountSuggestion {
  const _NewAccountSuggestion({
    required this.label,
    required this.name,
    required this.hints,
    this.type = AccountType.bank,
  });

  final String label;
  final String name;
  final String hints;
  final AccountType type;
}

class _AccountChips extends ConsumerWidget {
  const _AccountChips({
    required this.accounts,
    required this.selected,
    required this.onSelected,
    this.suggestion,
  });

  final List<Account> accounts;
  final int? selected;
  final ValueChanged<int> onSelected;
  final _NewAccountSuggestion? suggestion;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = suggestion;
    return SizedBox(
      height: 48, // room for the chips' 48 dp touch targets
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          if (s != null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ActionChip(
                avatar: const Icon(Icons.add_card, size: 18),
                label: Text('Add ${s.label}'),
                tooltip: 'Set up this account so future SMS match it',
                onPressed: () async {
                  final id = await showAddAccountDialog(
                    context,
                    ref,
                    initialName: s.name,
                    hints: s.hints,
                    initialType: s.type,
                  );
                  if (id != null) onSelected(id);
                },
              ),
            ),
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
          if (s == null)
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
      height: 48, // room for the chips' 48 dp touch targets
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

/// Quick "new account" dialog. Returns the new account id. [hints] are
/// stored alongside the name so later captures match this account.
Future<int?> showAddAccountDialog(
  BuildContext context,
  WidgetRef ref, {
  String initialName = '',
  String hints = '',
  AccountType initialType = AccountType.bank,
}) {
  final name = TextEditingController(text: initialName);
  var type = initialType;
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
              final allHints = {
                n.toLowerCase(),
                ...hints.split(',').where((h) => h.isNotEmpty),
              }.join(',');
              final id = await db
                  .into(db.accounts)
                  .insert(
                    AccountsCompanion.insert(
                      name: n,
                      type: type,
                      color: defaultAccountColor,
                      icon: _accountTypeIcon(type),
                      matchHints: Value(allHints),
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
  AccountType.lent => 'Owes me',
};

String _accountTypeIcon(AccountType t) => switch (t) {
  AccountType.cash => 'payments',
  AccountType.bank => 'account_balance',
  AccountType.wallet => 'account_balance_wallet',
  AccountType.creditCard => 'credit_card',
  AccountType.loan => 'request_quote',
  AccountType.lent => 'person',
};

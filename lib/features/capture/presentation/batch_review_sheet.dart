import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tracks/app/icons.dart';
import 'package:tracks/app/providers.dart';
import 'package:tracks/app/theme.dart';
import 'package:tracks/core/dates.dart';
import 'package:tracks/core/money.dart';
import 'package:tracks/data/app_database.dart';
import 'package:tracks/features/capture/domain/account_match.dart';
import 'package:tracks/features/capture/domain/capture_draft.dart';
import 'package:tracks/features/capture/domain/category_guess.dart';
import 'package:tracks/features/capture/presentation/confirm_sheet.dart';

/// Review several captured transactions (e.g. a screenshot of an SMS
/// thread) and save the ticked ones in one go. Resolves to true if any
/// were saved, including ones saved one by one through the Confirm Card.
Future<bool> showBatchReview(
  BuildContext context,
  List<CaptureDraft> drafts,
) async {
  final anySaved = ValueNotifier(false);
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useRootNavigator: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (_) => _BatchReview(drafts: drafts, anySaved: anySaved),
  );
  final saved = anySaved.value;
  anySaved.dispose();
  return saved;
}

class _Row {
  _Row(this.draft);
  final CaptureDraft draft;
  bool selected = true;
  bool duplicate = false;
  bool saved = false;
}

/// What saving a draft would store: shown in its row and used by save, so
/// the preview never disagrees with the result.
typedef _Resolved = ({
  int? account,
  int? toAccount,
  TxnType type,
  int? category,
});

class _BatchReview extends ConsumerStatefulWidget {
  const _BatchReview({required this.drafts, required this.anySaved});

  final List<CaptureDraft> drafts;
  final ValueNotifier<bool> anySaved;

  @override
  ConsumerState<_BatchReview> createState() => _BatchReviewState();
}

class _BatchReviewState extends ConsumerState<_BatchReview> {
  late final _rows = [for (final d in widget.drafts) _Row(d)];
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _markDuplicates();
  }

  Future<void> _markDuplicates() async {
    final db = ref.read(appDatabaseProvider);
    for (final r in _rows) {
      final d = r.draft;
      if (d.amountPaise == null) continue;
      final found = await db.findPossibleDuplicates(
        amountPaise: d.amountPaise!,
        day: d.date ?? dateOnly(DateTime.now()),
        refNo: d.refNo,
      );
      if (found.isNotEmpty && mounted) {
        setState(() {
          r.duplicate = true;
          r.selected = false;
        });
      }
    }
  }

  Iterable<MatchableAccount> _matchable(List<Account> accounts) =>
      accounts.map((a) => (id: a.id, name: a.name, matchHints: a.matchHints));

  int? _accountFor(CaptureDraft d, List<Account> accounts) =>
      matchAccount(
        _matchable(accounts),
        hint: d.accountHint,
        last4: d.accountLast4,
        bank: d.bankHint,
      ) ??
      accounts.firstOrNull?.id;

  int? _categoryFor(CaptureDraft d, List<Category> categories) {
    final name = guessCategoryName(
      '${d.categoryText} ${d.note}',
      categories.map((c) => c.name),
    );
    return categories.where((c) => c.name == name).firstOrNull?.id;
  }

  /// A transfer (ATM, card bill) needs both ends; without a match for the
  /// other one it is saved as an expense.
  _Resolved _resolve(
    CaptureDraft d,
    List<Account> accounts,
    Map<CategoryKind, List<Category>> categories,
  ) {
    final account = _accountFor(d, accounts);
    final to = d.type == TxnType.transfer
        ? matchAccount(
            _matchable(accounts),
            hint: d.toAccountHint,
            last4: d.toAccountLast4,
          )
        : null;
    final transfer = to != null && to != account;
    final type = transfer
        ? TxnType.transfer
        : (d.type == TxnType.transfer ? TxnType.expense : d.type);
    final kind = type == TxnType.income
        ? CategoryKind.income
        : CategoryKind.expense;
    return (
      account: account,
      toAccount: transfer ? to : null,
      type: type,
      category: transfer ? null : _categoryFor(d, categories[kind] ?? const []),
    );
  }

  /// Rows that can be saved straight from this list; the rest need the
  /// Confirm Card (no amount, or no account to put them in).
  bool _savable(_Row r, List<Account> accounts) =>
      !r.saved &&
      (r.draft.amountPaise ?? 0) > 0 &&
      _accountFor(r.draft, accounts) != null;

  Future<void> _saveSelected(
    List<Account> accounts,
    Map<CategoryKind, List<Category>> categories,
  ) async {
    setState(() => _busy = true);
    final db = ref.read(appDatabaseProvider);
    final now = DateTime.now();
    var saved = 0;
    for (final r in _rows.where((r) => r.selected && _savable(r, accounts))) {
      final d = r.draft;
      final x = _resolve(d, accounts, categories);
      final date = d.date ?? dateOnly(now);
      await db.addTransaction(
        TransactionsCompanion.insert(
          type: x.type,
          amountPaise: d.amountPaise!,
          accountId: x.account!,
          toAccountId: Value(x.toAccount),
          categoryId: Value(x.category),
          note: Value(d.note),
          merchant: Value(d.merchant),
          tags: Value(d.tags),
          occurredAt: DateTime(
            date.year,
            date.month,
            date.day,
            d.time?.hour ?? 12,
            d.time?.minute ?? 0,
          ),
          source: Value(d.source),
          rawSourceText: Value(d.rawText),
          refNo: Value(d.refNo),
        ),
      );
      r.saved = true;
      saved++;
    }
    if (!mounted) return;
    setState(() => _busy = false);
    if (saved == 0) return;
    widget.anySaved.value = true;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Saved $saved transaction${saved == 1 ? '' : 's'}'),
      ),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accounts = ref.watch(accountsProvider).value ?? const <Account>[];
    final categories = {
      for (final k in CategoryKind.values)
        k: ref.watch(categoriesProvider(k)).value ?? const <Category>[],
    };
    final byId = {for (final a in accounts) a.id: a};
    final catById = {
      for (final list in categories.values)
        for (final c in list) c.id: c,
    };
    final count = _rows
        .where((r) => r.selected && _savable(r, accounts))
        .length;
    final n = _rows.length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              'Found $n transaction${n == 1 ? '' : 's'}',
              style: theme.textTheme.headlineSmall,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 4, 12),
            child: Text(
              'Untick anything you don\'t want. Tap one to adjust it.',
              style: theme.textTheme.bodyMedium,
            ),
          ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final r in _rows)
                  Builder(
                    builder: (context) {
                      final x = _resolve(r.draft, accounts, categories);
                      final savable = _savable(r, accounts);
                      return _ReviewTile(
                        row: r,
                        type: x.type,
                        account: byId[x.account],
                        toAccount: byId[x.toAccount],
                        category: catById[x.category],
                        needsFixing: !r.saved && !savable,
                        onToggle: savable
                            ? (v) => setState(() => r.selected = v)
                            : null,
                        onOpen: r.saved
                            ? null
                            : () async {
                                final ok = await showConfirmSheet(
                                  context,
                                  draft: r.draft,
                                );
                                if (ok == true && mounted) {
                                  widget.anySaved.value = true;
                                  setState(() {
                                    r.saved = true;
                                    r.selected = false;
                                  });
                                }
                              },
                      );
                    },
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: count == 0 || _busy
                ? null
                : () => _saveSelected(accounts, categories),
            icon: const Icon(Icons.done_all),
            label: Text(count == 0 ? 'Nothing selected' : 'Save $count'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewTile extends StatelessWidget {
  const _ReviewTile({
    required this.row,
    required this.type,
    required this.account,
    required this.toAccount,
    required this.category,
    required this.needsFixing,
    required this.onToggle,
    required this.onOpen,
  });

  final _Row row;
  final TxnType type;
  final Account? account;
  final Account? toAccount;
  final Category? category;
  final bool needsFixing;
  final ValueChanged<bool>? onToggle;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final d = row.draft;
    final income = type == TxnType.income;
    final transfer = type == TxnType.transfer;
    final paise = d.amountPaise ?? 0;
    final title = d.note.isNotEmpty
        ? d.note
        : (d.merchant ?? (income ? 'Received' : 'Unnamed'));
    final when = [
      if (d.date != null)
        shortDate(d.date!).replaceFirst(' ${d.date!.year}', ''),
      if (d.time != null)
        '${d.time!.hour.toString().padLeft(2, '0')}:'
            '${d.time!.minute.toString().padLeft(2, '0')}',
    ].join(' · ');
    final status = row.saved
        ? 'Saved'
        : needsFixing
        ? ((d.amountPaise ?? 0) <= 0
              ? 'Amount missing, tap to fix'
              : 'No account yet, tap to fix')
        : row.duplicate
        ? 'Already in Tracks'
        : transfer
        ? '${account?.name} → ${toAccount?.name}'
        : [category?.name, account?.name].nonNulls.join(' · ');
    final warn = !row.saved && (row.duplicate || needsFixing);
    final sign = transfer ? '' : (income ? '+' : '−');
    final kindWord = transfer ? 'transfer' : (income ? 'income' : 'expense');
    final spokenAmount = paise > 0 ? spokenPaise(paise) : 'no amount';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Checkbox(
                value: row.saved || (row.selected && !needsFixing),
                onChanged: onToggle == null
                    ? null
                    : (v) => onToggle!(v ?? false),
                semanticLabel: 'Include $title',
              ),
              ExcludeSemantics(
                child: CircleAvatar(
                  radius: 18,
                  backgroundColor: transfer
                      ? Palette.sand
                      : Color(category?.color ?? Palette.sand.toARGB32()),
                  foregroundColor: Colors.black87,
                  child: Icon(
                    transfer ? Icons.swap_horiz : iconFor(category?.icon ?? ''),
                    size: 18,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Semantics(
                  button: onOpen != null,
                  excludeSemantics: true,
                  label: '$title, $spokenAmount $kindWord, $when. $status',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall,
                      ),
                      if (when.isNotEmpty)
                        Text(
                          when,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: muted,
                          ),
                        ),
                      // Wraps instead of truncating: at large text sizes
                      // "Already in Tracks" must stay readable.
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (warn)
                            Padding(
                              padding: const EdgeInsets.only(top: 1, right: 4),
                              child: Icon(
                                Icons.warning_amber_rounded,
                                size: 14,
                                color: muted,
                              ),
                            ),
                          Expanded(
                            child: Text(
                              status,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: muted,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ExcludeSemantics(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 132),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text(
                      paise > 0 ? '$sign${formatPaise(paise)}' : '—',
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: transfer
                            ? muted
                            : (income ? theme.incomeColor : theme.expenseColor),
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

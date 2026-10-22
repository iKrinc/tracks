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
/// were saved.
Future<bool?> showBatchReview(
  BuildContext context,
  List<CaptureDraft> drafts,
) => showModalBottomSheet<bool>(
  context: context,
  isScrollControlled: true,
  useRootNavigator: true,
  showDragHandle: true,
  useSafeArea: true,
  builder: (_) => _BatchReview(drafts: drafts),
);

class _Row {
  _Row(this.draft);
  final CaptureDraft draft;
  bool selected = true;
  bool duplicate = false;
  bool saved = false;
}

class _BatchReview extends ConsumerStatefulWidget {
  const _BatchReview({required this.drafts});

  final List<CaptureDraft> drafts;

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

  int? _accountFor(CaptureDraft d, List<Account> accounts) =>
      matchAccount(
        accounts.map((a) => (id: a.id, name: a.name, matchHints: a.matchHints)),
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

  Future<void> _saveSelected(
    List<Account> accounts,
    Map<CategoryKind, List<Category>> categories,
  ) async {
    setState(() => _busy = true);
    final db = ref.read(appDatabaseProvider);
    final now = DateTime.now();
    var saved = 0;
    for (final r in _rows.where((r) => r.selected && !r.saved)) {
      final d = r.draft;
      final account = _accountFor(d, accounts);
      if (account == null || d.amountPaise == null) continue;
      final kind = d.type == TxnType.income
          ? CategoryKind.income
          : CategoryKind.expense;
      final date = d.date ?? dateOnly(now);
      // A transfer (ATM, card bill) needs both ends; without a match for
      // the other one it is saved as a plain expense.
      final to = d.type == TxnType.transfer
          ? matchAccount(
              accounts.map(
                (a) => (id: a.id, name: a.name, matchHints: a.matchHints),
              ),
              hint: d.toAccountHint,
              last4: d.toAccountLast4,
            )
          : null;
      final transfer = to != null && to != account;
      await db.addTransaction(
        TransactionsCompanion.insert(
          type: transfer
              ? TxnType.transfer
              : (d.type == TxnType.transfer ? TxnType.expense : d.type),
          amountPaise: d.amountPaise!,
          accountId: account,
          toAccountId: Value(transfer ? to : null),
          categoryId: Value(
            transfer ? null : _categoryFor(d, categories[kind] ?? const []),
          ),
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Saved $saved transaction${saved == 1 ? '' : 's'}'),
      ),
    );
    Navigator.pop(context, saved > 0);
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
    final count = _rows.where((r) => r.selected && !r.saved).length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              'Found ${_rows.length} transactions',
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
                  _ReviewTile(
                    row: r,
                    account: byId[_accountFor(r.draft, accounts)],
                    category:
                        catById[_categoryFor(
                          r.draft,
                          categories[r.draft.type == TxnType.income
                                  ? CategoryKind.income
                                  : CategoryKind.expense] ??
                              const [],
                        )],
                    onToggle: r.saved
                        ? null
                        : (v) => setState(() => r.selected = v),
                    onOpen: r.saved
                        ? null
                        : () async {
                            final ok = await showConfirmSheet(
                              context,
                              draft: r.draft,
                            );
                            if (ok == true && mounted) {
                              setState(() {
                                r.saved = true;
                                r.selected = false;
                              });
                            }
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
    required this.account,
    required this.category,
    required this.onToggle,
    required this.onOpen,
  });

  final _Row row;
  final Account? account;
  final Category? category;
  final ValueChanged<bool>? onToggle;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final d = row.draft;
    final income = d.type == TxnType.income;
    final paise = d.amountPaise ?? 0;
    final when = [
      if (d.date != null)
        shortDate(d.date!).replaceFirst(' ${d.date!.year}', ''),
      if (d.time != null)
        '${d.time!.hour.toString().padLeft(2, '0')}:'
            '${d.time!.minute.toString().padLeft(2, '0')}',
    ].join(' · ');
    final status = row.saved
        ? 'Saved'
        : row.duplicate
        ? 'Already in Tracks'
        : [category?.name, account?.name].nonNulls.join(' · ');

    return Semantics(
      label:
          '${spokenPaise(paise)} ${income ? 'income' : 'expense'}, '
          '${d.note.isEmpty ? 'unnamed' : d.note}, $when. $status',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onOpen,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Checkbox(
                  value: row.saved || row.selected,
                  onChanged: onToggle == null
                      ? null
                      : (v) => onToggle!(v ?? false),
                ),
                CircleAvatar(
                  radius: 18,
                  backgroundColor: Color(
                    category?.color ?? Palette.sand.toARGB32(),
                  ),
                  foregroundColor: Colors.black87,
                  child: Icon(iconFor(category?.icon ?? ''), size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        d.note.isEmpty ? 'Unnamed' : d.note,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall,
                      ),
                      Text(
                        [when, status].where((s) => s.isNotEmpty).join(' · '),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: row.duplicate && !row.saved
                              ? theme.expenseColor
                              : null,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${income ? '+' : '−'}${formatPaise(paise, hideZeroPaise: true)}',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: income ? theme.incomeColor : theme.expenseColor,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

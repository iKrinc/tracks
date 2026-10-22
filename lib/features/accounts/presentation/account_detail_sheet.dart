import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tracks/app/providers.dart';
import 'package:tracks/app/theme.dart';
import 'package:tracks/app/widgets/hero.dart';
import 'package:tracks/core/dates.dart';
import 'package:tracks/core/money.dart';
import 'package:tracks/data/app_database.dart';
import 'package:tracks/features/accounts/domain/credit_card.dart';
import 'package:tracks/features/accounts/domain/loan.dart';
import 'package:tracks/features/capture/domain/capture_draft.dart';
import 'package:tracks/features/capture/presentation/confirm_sheet.dart';
import 'package:tracks/features/transactions/presentation/search_screen.dart';

/// Cards with a statement day, and loans/IOUs, get a detail sheet.
bool hasDetail(Account a) =>
    (a.type == AccountType.creditCard && a.statementDay != null) ||
    a.type == AccountType.loan ||
    a.type == AccountType.lent;

Future<void> showAccountDetail(BuildContext context, Account a) =>
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (_) => _AccountDetail(account: a),
    );

/// How a transaction moves this account's balance (+ in, − out).
int _signedFor(Transaction t, int accountId) => switch (t.type) {
  TxnType.income => t.amountPaise,
  TxnType.expense => -t.amountPaise,
  TxnType.transfer =>
    t.toAccountId == accountId ? t.amountPaise : -t.amountPaise,
};

class _AccountDetail extends ConsumerWidget {
  const _AccountDetail({required this.account});

  final Account account;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final tokens = theme.tokens;
    final a = account;
    final txns = ref.watch(accountTxnsProvider(a.id)).value ?? const [];
    final balance = ref.watch(balancesProvider)[a.id] ?? a.openingBalancePaise;
    final banks = (ref.watch(accountsProvider).value ?? const <Account>[])
        .where(
          (x) =>
              x.id != a.id &&
              (x.type == AccountType.bank ||
                  x.type == AccountType.wallet ||
                  x.type == AccountType.cash),
        )
        .toList();

    Widget stat(String label, String value) => Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: tokens.heroMuted,
            ),
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: theme.textTheme.titleMedium?.copyWith(
                color: tokens.heroInk,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );

    Future<void> pay(int paise, {required bool intoThis}) async {
      Navigator.pop(context);
      final from = banks.firstOrNull?.id;
      await showConfirmSheet(
        context,
        draft: CaptureDraft(
          type: TxnType.transfer,
          source: TxnSource.manual,
          amountPaise: paise > 0 ? paise : null,
          note: intoThis ? '${a.name} payment' : '${a.name} repaid',
          accountId: intoThis ? from : a.id,
          toAccountId: intoThis ? a.id : from,
        ),
      );
    }

    final Widget hero;
    final List<Widget> actions;
    if (a.type == AccountType.creditCard && a.statementDay != null) {
      final cycle = cardCycle(
        statementDay: a.statementDay!,
        dueDay: a.dueDay ?? a.statementDay!,
        today: DateTime.now(),
      );
      final s = cardStatus(
        moves: [
          for (final t in txns) (at: t.occurredAt, paise: _signedFor(t, a.id)),
        ],
        openingPaise: a.openingBalancePaise,
        cycle: cycle,
        limitPaise: a.creditLimitPaise ?? 0,
      );
      final daysLeft = daysBetween(DateTime.now(), cycle.due);
      hero = HeroCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              s.dueNowPaise == 0
                  ? 'Statement paid'
                  : 'Due ${shortDate(cycle.due)}'
                        '${daysLeft >= 0 ? ' · in $daysLeft days' : ' · overdue'}',
              style: theme.textTheme.labelLarge?.copyWith(
                color: tokens.heroMuted,
              ),
            ),
            AnimatedAmount(
              s.dueNowPaise,
              semanticsPrefix: 'Due now ',
              style: theme.textTheme.displaySmall?.copyWith(
                color: tokens.heroInk,
              ),
            ),
            if (s.minimumDuePaise > 0)
              Text(
                'Minimum about ${formatPaise(s.minimumDuePaise, hideZeroPaise: true)}'
                ' · check your statement',
                style: TextStyle(color: tokens.heroInk),
              ),
            const SizedBox(height: 16),
            Row(
              children: [
                stat(
                  'Unbilled',
                  formatPaise(s.unbilledPaise, hideZeroPaise: true),
                ),
                stat(
                  'Outstanding',
                  formatPaise(s.outstandingPaise, hideZeroPaise: true),
                ),
                if ((a.creditLimitPaise ?? 0) > 0)
                  stat('Limit used', '${s.utilisationBp ~/ 100}%'),
              ],
            ),
            if ((a.creditLimitPaise ?? 0) > 0) ...[
              const SizedBox(height: 12),
              Semantics(
                label: '${s.utilisationBp ~/ 100} percent of limit used',
                excludeSemantics: true,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: (s.utilisationBp / 10000).clamp(0.0, 1.0),
                    minHeight: 10,
                    // Above 30% utilisation starts to hurt credit scores.
                    color: s.utilisationBp > 3000
                        ? theme.expenseColor
                        : theme.incomeColor,
                    backgroundColor: tokens.heroTrack,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                s.utilisationBp > 3000
                    ? 'Above 30% of the limit can lower your credit score'
                    : 'Under 30% of the limit: healthy for your score',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: tokens.heroInk,
                ),
              ),
            ],
          ],
        ),
      );
      actions = [
        FilledButton.icon(
          onPressed: () => pay(s.dueNowPaise, intoThis: true),
          icon: const Icon(Icons.payments_outlined),
          label: Text(
            s.dueNowPaise > 0
                ? 'Pay ${formatPaise(s.dueNowPaise, hideZeroPaise: true)}'
                : 'Pay card',
          ),
        ),
      ];
    } else {
      final lent = a.type == AccountType.lent;
      final owed = lent ? balance : -balance;
      // Without a recorded original amount (IOUs made from quick-add), the
      // total ever lent/borrowed is the opening plus every movement that
      // increased what's owed, so repayments show as progress.
      final sign = lent ? 1 : -1;
      final grew = txns
          .map((t) => _signedFor(t, a.id) * sign)
          .where((v) => v > 0)
          .fold(0, (x, v) => x + v);
      final principal =
          a.principalPaise ??
          (a.openingBalancePaise * sign).clamp(0, 1 << 52) + grew;
      final p = loanProgress(
        principalPaise: principal,
        outstandingPaise: owed,
        emiPaise: a.emiPaise,
        rateBp: a.interestRateBp,
      );
      hero = HeroCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              lent ? '${a.name} still owes you' : 'Still to repay',
              style: theme.textTheme.labelLarge?.copyWith(
                color: tokens.heroMuted,
              ),
            ),
            AnimatedAmount(
              owed > 0 ? owed : 0,
              semanticsPrefix: lent ? 'Owed to you ' : 'Still to repay ',
              style: theme.textTheme.displaySmall?.copyWith(
                color: tokens.heroInk,
              ),
            ),
            const SizedBox(height: 12),
            Semantics(
              label: '${p.percentPaid} percent repaid',
              excludeSemantics: true,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: p.percentPaid / 100,
                  minHeight: 10,
                  color: theme.incomeColor,
                  backgroundColor: tokens.heroTrack,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                stat('Repaid', '${p.percentPaid}%'),
                stat('Of', formatPaise(principal, hideZeroPaise: true)),
                if (p.monthsLeft != null)
                  stat('Months left', '${p.monthsLeft}'),
              ],
            ),
            if (a.emiPaise != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'EMI ${formatPaise(a.emiPaise!, hideZeroPaise: true)}'
                  '${a.interestRateBp == null ? '' : ' at ${a.interestRateBp! / 100}%'}',
                  style: TextStyle(color: tokens.heroInk),
                ),
              ),
          ],
        ),
      );
      actions = [
        FilledButton.icon(
          onPressed: () => pay(a.emiPaise ?? 0, intoThis: !lent),
          icon: Icon(lent ? Icons.call_received : Icons.call_made),
          label: Text(lent ? 'They paid me back' : 'Record a repayment'),
        ),
      ];
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
            child: Text(a.name, style: theme.textTheme.headlineSmall),
          ),
          hero,
          const SizedBox(height: 16),
          ...actions,
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              context.push('/search', extra: SearchArgs(accountId: a.id));
            },
            icon: const Icon(Icons.receipt_long_outlined),
            label: const Text('See transactions'),
          ),
        ],
      ),
    );
  }
}

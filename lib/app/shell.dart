import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tracks/app/providers.dart';
import 'package:tracks/features/accounts/presentation/account_detail_sheet.dart';
import 'package:tracks/features/capture/presentation/share_intake.dart';
import 'package:tracks/features/recurring/domain/reminder_plan.dart';
import 'package:tracks/features/recurring/data/reminder_service.dart';
import 'package:tracks/features/recurring/presentation/recurring_screen.dart';
import 'package:tracks/features/capture/data/share_channel.dart';
import 'package:tracks/features/settings/presentation/welcome_screen.dart';

/// Bottom navigation around the tabs. Share intake lives here so an SMS or
/// backup shared into the app is handled from any tab.
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  StreamSubscription<int>? _reminderTaps;

  @override
  void initState() {
    super.initState();
    _maybeWelcome();
    final reminders = ReminderService.instance;
    reminders.init();
    _reminderTaps = reminders.taps.listen(_openBill);
    // Keep scheduled reminders in step with bills; sync() is a no-op when
    // the plan hasn't changed.
    ref.listenManual(
      reminderPlanProvider,
      (_, plan) => reminders.sync(plan),
      fireImmediately: true,
    );
  }

  @override
  void dispose() {
    _reminderTaps?.cancel();
    super.dispose();
  }

  /// A reminder (or its "Mark paid" button) was tapped.
  Future<void> _openBill(int id) async {
    if (id >= cardReminderIdBase) {
      final accounts = await ref.read(accountsProvider.future);
      final card = accounts
          .where((a) => a.id == id - cardReminderIdBase)
          .firstOrNull;
      if (card != null && mounted) await showAccountDetail(context, card);
      return;
    }
    final bills = await ref.read(recurringsProvider.future);
    final bill = bills.where((b) => b.id == id).firstOrNull;
    if (bill != null && mounted) await openMarkPaid(context, bill);
  }

  /// First launch with an empty database: offer restore before anything.
  Future<void> _maybeWelcome() async {
    final db = ref.read(appDatabaseProvider);
    if (await db.getSetting(welcomeSeenKey) != null) return;
    // Opened by sharing something in (say a backup from Drive): showing the
    // welcome would throw that share away. Handle it; welcome next time.
    if (ShareChannel.supported) {
      final shared = await ShareChannel.instance.peekInitial();
      if (shared != null && (shared.files.isNotEmpty || shared.text != null)) {
        return;
      }
    }
    final hasData = (await (db.select(
      db.transactions,
    )..limit(1)).get()).isNotEmpty;
    if (hasData) {
      await db.setSetting(welcomeSeenKey, '1');
      return;
    }
    if (mounted) context.go('/welcome');
  }

  @override
  Widget build(BuildContext context) {
    final shell = widget.shell;
    return ShareIntake(
      child: Scaffold(
        body: shell,
        bottomNavigationBar: NavigationBar(
          selectedIndex: shell.currentIndex,
          onDestinationSelected: (i) =>
              shell.goBranch(i, initialLocation: i == shell.currentIndex),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.receipt_long_outlined),
              selectedIcon: Icon(Icons.receipt_long),
              label: 'Transactions',
            ),
            NavigationDestination(
              icon: Icon(Icons.donut_large_outlined),
              selectedIcon: Icon(Icons.donut_large),
              label: 'Reports',
            ),
            NavigationDestination(
              icon: Icon(Icons.celebration_outlined),
              selectedIcon: Icon(Icons.celebration),
              label: 'Funds',
            ),
            NavigationDestination(
              icon: Icon(Icons.account_balance_wallet_outlined),
              selectedIcon: Icon(Icons.account_balance_wallet),
              label: 'Accounts',
            ),
            NavigationDestination(icon: Icon(Icons.more_horiz), label: 'More'),
          ],
        ),
      ),
    );
  }
}

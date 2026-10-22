import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tracks/app/providers.dart';
import 'package:tracks/features/capture/presentation/share_intake.dart';
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
  @override
  void initState() {
    super.initState();
    _maybeWelcome();
  }

  /// First launch with an empty database: offer restore before anything.
  Future<void> _maybeWelcome() async {
    final db = ref.read(appDatabaseProvider);
    if (await db.getSetting(welcomeSeenKey) != null) return;
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

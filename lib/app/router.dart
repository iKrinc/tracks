import 'package:go_router/go_router.dart';
import 'package:tracks/app/shell.dart';
import 'package:tracks/features/accounts/presentation/accounts_screen.dart';
import 'package:tracks/features/backup/presentation/backup_screen.dart';
import 'package:tracks/features/settings/presentation/more_screen.dart';
import 'package:tracks/features/transactions/presentation/home_screen.dart';
import 'package:tracks/features/transactions/presentation/search_screen.dart';

final appRouter = GoRouter(
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, shell) => AppShell(shell: shell),
      branches: [
        StatefulShellBranch(
          routes: [GoRoute(path: '/', builder: (_, _) => const HomeScreen())],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/accounts',
              builder: (_, _) => const AccountsScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(path: '/more', builder: (_, _) => const MoreScreen()),
          ],
        ),
      ],
    ),
    GoRoute(
      path: '/search',
      builder: (_, state) => SearchScreen(
        args: state.extra is SearchArgs
            ? state.extra! as SearchArgs
            : const SearchArgs(),
      ),
    ),
    GoRoute(path: '/backup', builder: (_, _) => const BackupScreen()),
  ],
);

import 'package:go_router/go_router.dart';
import 'package:tracks/app/shell.dart';
import 'package:tracks/features/accounts/presentation/accounts_screen.dart';
import 'package:tracks/features/backup/presentation/backup_screen.dart';
import 'package:tracks/features/budgets/presentation/budgets_screen.dart';
import 'package:tracks/features/capture/presentation/rules_screen.dart';
import 'package:tracks/features/funds/presentation/fund_screen.dart';
import 'package:tracks/features/funds/presentation/funds_screen.dart';
import 'package:tracks/features/insights/presentation/reports_screen.dart';
import 'package:tracks/features/recurring/presentation/recurring_screen.dart';
import 'package:tracks/features/settings/presentation/appearance_screen.dart';
import 'package:tracks/features/settings/presentation/categories_screen.dart';
import 'package:tracks/features/settings/presentation/more_screen.dart';
import 'package:tracks/features/settings/presentation/welcome_screen.dart';
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
            GoRoute(path: '/reports', builder: (_, _) => const ReportsScreen()),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(path: '/funds', builder: (_, _) => const FundsScreen()),
          ],
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
    GoRoute(path: '/welcome', builder: (_, _) => const WelcomeScreen()),
    GoRoute(path: '/budgets', builder: (_, _) => const BudgetsScreen()),
    GoRoute(path: '/bills', builder: (_, _) => const RecurringScreen()),
    GoRoute(path: '/categories', builder: (_, _) => const CategoriesScreen()),
    GoRoute(path: '/rules', builder: (_, _) => const RulesScreen()),
    GoRoute(path: '/appearance', builder: (_, _) => const AppearanceScreen()),
    GoRoute(
      path: '/funds/:id',
      builder: (_, state) =>
          FundScreen(fundId: int.parse(state.pathParameters['id']!)),
    ),
  ],
);

import 'package:go_router/go_router.dart';
import 'package:tracks/features/transactions/presentation/home_screen.dart';

final appRouter = GoRouter(
  routes: [
    GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
  ],
);

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tracks/app/providers.dart';
import 'package:tracks/app/router.dart';
import 'package:tracks/app/theme.dart';
import 'package:tracks/features/settings/presentation/app_lock_gate.dart';

class TracksApp extends ConsumerWidget {
  const TracksApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final a = ref.watch(appearanceProvider);
    return MaterialApp.router(
      title: 'Tracks',
      debugShowCheckedModeBanner: false,
      themeMode: a.mode,
      theme: buildTheme(Brightness.light, accent: a.accent, compact: a.compact),
      darkTheme: buildTheme(
        Brightness.dark,
        accent: a.accent,
        compact: a.compact,
      ),
      routerConfig: appRouter,
      builder: (context, child) {
        // The chosen size scales on top of the phone's own text setting.
        final mq = MediaQuery.of(context);
        return MediaQuery(
          data: mq.copyWith(
            textScaler: TextScaler.linear(
              mq.textScaler.scale(1) * a.textSize.factor,
            ),
          ),
          child: AppLockGate(child: child!),
        );
      },
    );
  }
}

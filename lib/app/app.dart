import 'package:flutter/material.dart';
import 'package:tracks/app/router.dart';
import 'package:tracks/app/theme.dart';
import 'package:tracks/features/settings/presentation/app_lock_gate.dart';

class TracksApp extends StatelessWidget {
  const TracksApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Tracks',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      routerConfig: appRouter,
      builder: (context, child) => AppLockGate(child: child!),
    );
  }
}

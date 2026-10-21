import 'package:flutter/material.dart';
import 'package:tracks/app/router.dart';
import 'package:tracks/app/theme.dart';

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
    );
  }
}

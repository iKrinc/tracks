import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tracks/app/app.dart';

void main() {
  // Last line of defence: an error nobody caught is logged, never fatal.
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('Uncaught: $error\n$stack');
    return true;
  };
  // In release a widget that fails to build shows a quiet note instead of
  // a grey box; the rest of the screen keeps working.
  if (kReleaseMode) {
    ErrorWidget.builder = (details) => const Padding(
      padding: EdgeInsets.all(16),
      child: Text(
        "Something here couldn't be shown. Your data is safe.",
        textAlign: TextAlign.center,
      ),
    );
  }
  runApp(const ProviderScope(child: TracksApp()));
}

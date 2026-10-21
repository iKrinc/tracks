import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:tracks/app/providers.dart';
import 'package:tracks/data/app_database.dart';
import 'package:tracks/features/capture/domain/capture_draft.dart';
import 'package:tracks/features/capture/presentation/confirm_sheet.dart';

/// Words that identify the user's accounts in typed or shared text.
Set<String> accountKeywordsOf(List<Account> accounts) => {
  for (final a in accounts) ...[
    ...a.name.toLowerCase().split(' '),
    ...a.matchHints.toLowerCase().split(',').map((h) => h.trim()),
  ],
}..remove('');

/// Shows a capture: a Confirm Card for a draft, a SnackBar otherwise.
/// Resolves to `true` when something was saved.
Future<bool> presentCapture(
  BuildContext context,
  CaptureOutcome outcome,
) async {
  switch (outcome) {
    case CaptureIgnored(:final message):
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
      return false;
    case CaptureReady(:final draft):
      return await showConfirmSheet(context, draft: draft) ?? false;
  }
}

/// Listens for text shared into the app (Android share sheet) and opens the
/// Confirm Card. Wrap a screen that has a Scaffold above it in the tree.
class ShareIntake extends ConsumerStatefulWidget {
  const ShareIntake({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<ShareIntake> createState() => _ShareIntakeState();
}

class _ShareIntakeState extends ConsumerState<ShareIntake> {
  StreamSubscription<List<SharedMediaFile>>? _sub;

  static bool get _supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  @override
  void initState() {
    super.initState();
    if (!_supported) return;
    final intent = ReceiveSharingIntent.instance;
    // Shared while the app was closed…
    intent.getInitialMedia().then((files) {
      _handle(files);
      intent.reset();
    });
    // …or while it's running.
    _sub = intent.getMediaStream().listen(_handle);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _handle(List<SharedMediaFile> files) async {
    final text = files
        .where(
          (f) =>
              f.type == SharedMediaType.text || f.type == SharedMediaType.url,
        )
        .map((f) => f.path)
        .join('\n')
        .trim();
    if (text.isEmpty) {
      if (files.isNotEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Only shared text is supported so far')),
        );
      }
      return;
    }
    // Accounts may still be loading on a cold start.
    final accounts = await ref.read(accountsProvider.future);
    if (!mounted) return;
    await presentCapture(
      context,
      captureFromSharedText(
        text,
        now: DateTime.now(),
        accountKeywords: accountKeywordsOf(accounts),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

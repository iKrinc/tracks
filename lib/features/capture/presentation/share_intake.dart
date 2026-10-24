import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tracks/app/providers.dart';
import 'package:tracks/data/app_database.dart';
import 'package:tracks/features/backup/presentation/backup_actions.dart';
import 'package:tracks/features/capture/data/ocr.dart';
import 'package:tracks/features/capture/data/share_channel.dart';
import 'package:tracks/features/capture/domain/capture_draft.dart';
import 'package:tracks/features/capture/presentation/batch_review_sheet.dart';
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
    case CaptureMany(:final drafts):
      return showBatchReview(context, drafts);
  }
}

/// Listens for things shared into the app (Android share sheet): bank SMS
/// text, payment screenshots, backups and CSVs. Wrap a screen that has a
/// Scaffold above it in the tree.
///
/// Nothing a sharing app sends may crash Tracks: native code copies streams
/// inside try/catch (MainActivity.kt), and every step here falls back to a
/// SnackBar.
class ShareIntake extends ConsumerStatefulWidget {
  const ShareIntake({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<ShareIntake> createState() => _ShareIntakeState();
}

class _ShareIntakeState extends ConsumerState<ShareIntake> {
  StreamSubscription<SharedPayload>? _sub;

  @override
  void initState() {
    super.initState();
    if (!ShareChannel.supported) return;
    final channel = ShareChannel.instance;
    // Shared while the app was closed…
    channel.initial().then((p) {
      if (p != null) _safely(p);
    });
    // …or while it's running.
    _sub = channel.stream.listen(_safely);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _say(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _safely(SharedPayload p) async {
    try {
      await _handle(p);
    } catch (e, st) {
      debugPrint('Share intake failed: $e\n$st');
      _say("Couldn't read what was shared. Nothing was saved.");
    }
  }

  Future<void> _handle(SharedPayload p) async {
    if (p.error != null && p.files.isEmpty && (p.text ?? '').trim().isEmpty) {
      _say("Couldn't open what was shared");
      return;
    }

    // A backup or CSV opened from Drive / Gmail / Files.
    bool isImage(SharedFile f) =>
        (f.mime ?? '').startsWith('image/') ||
        RegExp(r'\.(png|jpe?g|webp|heic)$').hasMatch(f.name.toLowerCase());
    final file = p.files.where((f) => !isImage(f)).firstOrNull;
    if (file != null) {
      final name = file.name.toLowerCase();
      final mime = file.mime ?? '';
      final isJson = name.endsWith('.json') || mime == 'application/json';
      final isCsv = name.endsWith('.csv') || mime.contains('csv');
      if (!isJson && !isCsv) {
        _say('Tracks can open backup (.json) and .csv files');
        return;
      }
      String contents;
      try {
        contents = await File(file.path).readAsString();
      } catch (_) {
        _say("That file isn't readable text");
        return;
      }
      if (!mounted) return;
      await guardFileJob(context, () async {
        if (isJson) {
          await restoreFromJsonText(context, ref, contents);
        } else {
          await importCsvText(context, ref, contents);
        }
      });
      return;
    }

    final text = (p.text ?? '').trim();
    if (text.isEmpty) {
      // Payment screenshots: read each on-device, then parse.
      final images = p.files.where(isImage).toList();
      if (images.isEmpty || !mounted) {
        _say('Nothing to add from that share');
        return;
      }
      final messenger = ScaffoldMessenger.of(context)
        ..showSnackBar(
          SnackBar(
            content: Text(
              images.length == 1
                  ? 'Reading the screenshot…'
                  : 'Reading ${images.length} screenshots…',
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      final outcomes = <CaptureOutcome>[];
      var unreadable = 0;
      for (final image in images) {
        try {
          final blocks = await readTextBlocksFromImage(image.path);
          outcomes.add(captureFromScreenshotBlocks(blocks));
        } catch (_) {
          unreadable++;
        }
      }
      if (!mounted) return;
      messenger.hideCurrentSnackBar();
      if (outcomes.isEmpty) {
        _say("Couldn't read that image");
        return;
      }
      if (unreadable > 0) {
        _say("Skipped $unreadable image(s) that couldn't be read");
      }
      await presentCapture(context, mergeCaptures(outcomes));
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

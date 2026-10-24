import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:tracks/app/providers.dart';
import 'package:tracks/features/backup/data/backup_service.dart';
import 'package:tracks/features/capture/data/share_channel.dart';
import 'package:tracks/features/backup/domain/csv_transactions.dart';
import 'package:tracks/features/backup/presentation/csv_mapping_sheet.dart';

/// Backup, restore, export and import flows, shared by the Backup screen,
/// the first-run welcome and files opened into the app from Drive/Files.
/// Files leave the phone only through the share sheet: no network calls.

String _stamp() {
  final n = DateTime.now();
  String two(int v) => v.toString().padLeft(2, '0');
  return '${n.year}-${two(n.month)}-${two(n.day)}';
}

void _toast(BuildContext context, String message) =>
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));

/// Runs [job], turning bad files into a readable SnackBar.
Future<void> guardFileJob(
  BuildContext context,
  Future<void> Function() job,
) async {
  try {
    await job();
  } on BackupFormatException catch (e) {
    if (context.mounted) _toast(context, e.message);
  } on FormatException {
    if (context.mounted) _toast(context, "That file couldn't be read.");
  } catch (e) {
    // Never fail silently: anything else still tells the user.
    debugPrint('File job failed: $e');
    if (context.mounted) {
      _toast(context, "That didn't work: the file couldn't be opened.");
    }
  }
}

Future<void> _shareFile(String name, String contents, String mime) async {
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/$name');
  await file.writeAsString(contents, flush: true);
  await SharePlus.instance.share(
    ShareParams(
      files: [XFile(file.path, mimeType: mime)],
      subject: name,
    ),
  );
}

Future<void> exportJsonBackup(WidgetRef ref) async {
  final backup = await buildBackup(ref.read(appDatabaseProvider));
  await _shareFile(
    'tracks-backup-${_stamp()}.json',
    const JsonEncoder.withIndent(' ').convert(backup),
    'application/json',
  );
}

/// Saves a full backup where the user picks in Android's "Save to" screen:
/// Google Drive appears there (with the Drive app), as do Downloads and SD
/// cards. Android does the upload; Tracks itself makes no network call.
/// Resolves to false when the user backs out.
Future<bool> saveJsonBackupToFolder(WidgetRef ref) async {
  final backup = await buildBackup(ref.read(appDatabaseProvider));
  final uri = await FilePicker.saveFile(
    dialogTitle: 'Save Tracks backup',
    fileName: 'tracks-backup-${_stamp()}.json',
    bytes: Uint8List.fromList(
      utf8.encode(const JsonEncoder.withIndent(' ').convert(backup)),
    ),
    mimeType: 'application/json',
  );
  return uri != null;
}

Future<void> exportCsv(WidgetRef ref) async {
  final rows = await csvExportRows(ref.read(appDatabaseProvider));
  await _shareFile(
    'tracks-transactions-${_stamp()}.csv',
    transactionsToCsv(rows),
    'text/csv',
  );
}

/// Lets the user pick a file and returns its text; null if they backed out.
/// Files from Drive or other cloud apps come as content:// links with no
/// path on the phone, so Android reads those for us.
Future<String?> pickTextFile(List<String> extensions) async {
  final files = await FilePicker.pickFiles(
    type: FileType.custom,
    allowedExtensions: extensions,
  );
  if (files.isEmpty) return null;
  final f = files.first;
  if (f.path != null) {
    return utf8.decode(await File(f.path!).readAsBytes(), allowMalformed: true);
  }
  final copied = ShareChannel.supported
      ? await ShareChannel.instance.copyUri(f.uri.toString())
      : null;
  if (copied == null) {
    throw const BackupFormatException(
      "Couldn't open that file. If it's in Drive, check you're online, or "
      'download it first and pick it from Downloads.',
    );
  }
  return utf8.decode(await File(copied).readAsBytes(), allowMalformed: true);
}

/// Confirms, then replaces all data with the backup in [text].
/// Returns true if restored.
Future<bool> restoreFromJsonText(
  BuildContext context,
  WidgetRef ref,
  String text,
) async {
  final json = jsonDecode(text);
  if (json is! Map<String, dynamic> || json['app'] != 'tracks') {
    throw const BackupFormatException('This is not a Tracks backup file.');
  }
  final db = ref.read(appDatabaseProvider);
  final count = (json['transactions'] as List?)?.length ?? 0;
  final when = (json['exportedAt'] as String? ?? '').split('T').first;
  final hasData = (await db.select(db.transactions).get()).isNotEmpty;
  if (!context.mounted) return false;
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(hasData ? 'Replace all data?' : 'Restore this backup?'),
      content: Text(
        'Backup from ${when.isEmpty ? 'an unknown date' : when}, '
        '$count transactions.'
        '${hasData ? ' Everything currently in Tracks will be replaced. '
                  'Export a backup first if you might need it.' : ''}',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(hasData ? 'Replace' : 'Restore'),
        ),
      ],
    ),
  );
  if (ok != true) return false;
  final s = await restoreBackup(db, json);
  if (context.mounted) {
    _toast(
      context,
      'Restored ${s.transactions} transactions, '
      '${s.accounts} accounts',
    );
  }
  return true;
}

/// Lets the user map columns, then imports the CSV in [text].
Future<bool> importCsvText(
  BuildContext context,
  WidgetRef ref,
  String text,
) async {
  final table = decodeCsv(text);
  if (table.length < 2) {
    _toast(context, 'That CSV has no rows to import.');
    return false;
  }
  final mapping = await showModalBottomSheet<CsvMapping>(
    context: context,
    isScrollControlled: true,
    useRootNavigator: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (_) => CsvMappingSheet(table: table),
  );
  if (mapping == null) return false;
  final parsed = parseCsvRows(table, mapping);
  final result = await importCsvRows(
    ref.read(appDatabaseProvider),
    parsed.rows,
  );
  final skipped = parsed.errors.length;
  if (context.mounted) {
    _toast(
      context,
      'Imported ${result.imported}'
      '${skipped > 0 ? ', skipped $skipped (${parsed.errors.first})' : ''}'
      '${result.newAccounts.isNotEmpty ? '. New accounts: ${result.newAccounts.join(', ')}' : ''}',
    );
  }
  return true;
}

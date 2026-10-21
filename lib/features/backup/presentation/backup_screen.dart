import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:tracks/app/providers.dart';
import 'package:tracks/features/backup/data/backup_service.dart';
import 'package:tracks/features/backup/domain/csv_transactions.dart';

/// Export and import. Files leave the device only through the share sheet,
/// where the user picks the destination: the app makes no network calls.
class BackupScreen extends ConsumerStatefulWidget {
  const BackupScreen({super.key});

  @override
  ConsumerState<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends ConsumerState<BackupScreen> {
  bool _busy = false;

  String get _stamp {
    final n = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${n.year}-${two(n.month)}-${two(n.day)}';
  }

  void _toast(String message) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));

  Future<void> _run(Future<void> Function() job) async {
    setState(() => _busy = true);
    try {
      await job();
    } on BackupFormatException catch (e) {
      _toast(e.message);
    } on FormatException {
      _toast("That file couldn't be read.");
    } finally {
      if (mounted) setState(() => _busy = false);
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

  Future<void> _exportJson() => _run(() async {
    final backup = await buildBackup(ref.read(appDatabaseProvider));
    await _shareFile(
      'tracks-backup-$_stamp.json',
      const JsonEncoder.withIndent(' ').convert(backup),
      'application/json',
    );
  });

  Future<void> _exportCsv() => _run(() async {
    final rows = await csvExportRows(ref.read(appDatabaseProvider));
    await _shareFile(
      'tracks-transactions-$_stamp.csv',
      transactionsToCsv(rows),
      'text/csv',
    );
  });

  Future<String?> _pickText(List<String> extensions) async {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: extensions,
    );
    if (files.isEmpty) return null;
    return utf8.decode(await files.first.readAsBytes(), allowMalformed: true);
  }

  Future<void> _restoreJson() => _run(() async {
    final text = await _pickText(['json']);
    if (text == null || !mounted) return;
    final json = jsonDecode(text);
    if (json is! Map<String, dynamic>) {
      throw const BackupFormatException('This is not a Tracks backup file.');
    }
    final count = (json['transactions'] as List?)?.length ?? 0;
    final when = json['exportedAt'] as String? ?? 'an unknown date';
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Replace all data?'),
        content: Text(
          'This replaces everything in Tracks with the backup from '
          '${when.split('T').first} ($count transactions). Export a backup '
          'of your current data first if you might need it.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Replace'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final s = await restoreBackup(ref.read(appDatabaseProvider), json);
    _toast('Restored ${s.transactions} transactions, ${s.accounts} accounts');
  });

  Future<void> _importCsv() => _run(() async {
    final text = await _pickText(['csv', 'txt']);
    if (text == null || !mounted) return;
    final table = decodeCsv(text);
    if (table.length < 2) {
      _toast('That CSV has no rows to import.');
      return;
    }
    final mapping = await showModalBottomSheet<CsvMapping>(
      context: context,
      isScrollControlled: true,
      // Above the bottom navigation, not inside the current tab.
      useRootNavigator: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (_) => _CsvMappingSheet(table: table),
    );
    if (mapping == null) return;
    final parsed = parseCsvRows(table, mapping);
    final result = await importCsvRows(
      ref.read(appDatabaseProvider),
      parsed.rows,
    );
    final skipped = parsed.errors.length;
    _toast(
      'Imported ${result.imported}'
      '${skipped > 0 ? ', skipped $skipped (${parsed.errors.first})' : ''}'
      '${result.newAccounts.isNotEmpty ? '. New accounts: ${result.newAccounts.join(', ')}' : ''}',
    );
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget tile(IconData icon, String title, String sub, VoidCallback onTap) =>
        ListTile(
          leading: Icon(icon),
          title: Text(title),
          subtitle: Text(sub),
          onTap: _busy ? null : onTap,
        );

    return Scaffold(
      appBar: AppBar(title: const Text('Backup & export')),
      body: ListView(
        children: [
          if (_busy) const LinearProgressIndicator(),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
            child: Text('Back up', style: theme.textTheme.titleSmall),
          ),
          tile(
            Icons.save_alt,
            'Full backup (JSON)',
            'Everything, restorable on any phone. Save it to Drive, email or '
                'a folder from the share sheet.',
            _exportJson,
          ),
          tile(
            Icons.table_view,
            'Export transactions (CSV)',
            'Opens in Excel or Google Sheets.',
            _exportCsv,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
            child: Text('Bring data in', style: theme.textTheme.titleSmall),
          ),
          tile(
            Icons.settings_backup_restore,
            'Restore full backup',
            'Replaces all current data. You confirm first.',
            _restoreJson,
          ),
          tile(
            Icons.upload_file,
            'Import CSV',
            'From a bank statement, Money Manager or a spreadsheet. You '
                'match the columns.',
            _importCsv,
          ),
        ],
      ),
    );
  }
}

const _fieldLabels = {
  CsvField.date: 'Date',
  CsvField.amount: 'Amount',
  CsvField.type: 'Type (income/expense)',
  CsvField.account: 'Account',
  CsvField.toAccount: 'To account',
  CsvField.category: 'Category',
  CsvField.note: 'Note',
  CsvField.merchant: 'Merchant',
  CsvField.tags: 'Tags',
  CsvField.ref: 'Ref no.',
};

class _CsvMappingSheet extends StatefulWidget {
  const _CsvMappingSheet({required this.table});

  final List<List<String>> table;

  @override
  State<_CsvMappingSheet> createState() => _CsvMappingSheetState();
}

class _CsvMappingSheetState extends State<_CsvMappingSheet> {
  late final CsvMapping _mapping = guessMapping(widget.table.first);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final headers = widget.table.first;
    final parsed = parseCsvRows(widget.table, _mapping);
    final ready =
        _mapping.containsKey(CsvField.date) &&
        _mapping.containsKey(CsvField.amount);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Match columns', style: theme.textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(
            '${widget.table.length - 1} rows. Date and Amount are required; '
            'without a Type column, negative amounts are expenses.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final field in CsvField.values)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Expanded(child: Text(_fieldLabels[field]!)),
                        Expanded(
                          child: DropdownButton<int?>(
                            isExpanded: true,
                            value: _mapping[field],
                            hint: const Text('—'),
                            items: [
                              const DropdownMenuItem(
                                value: null,
                                child: Text('—'),
                              ),
                              for (var i = 0; i < headers.length; i++)
                                DropdownMenuItem(
                                  value: i,
                                  child: Text(
                                    headers[i].isEmpty
                                        ? 'Column ${i + 1}'
                                        : headers[i],
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                            ],
                            onChanged: (v) => setState(() {
                              if (v == null) {
                                _mapping.remove(field);
                              } else {
                                _mapping[field] = v;
                              }
                            }),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            ready
                ? '${parsed.rows.length} ready'
                      '${parsed.errors.isEmpty ? '' : ', ${parsed.errors.length} will be skipped'}'
                : 'Pick the Date and Amount columns',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: ready && parsed.rows.isNotEmpty
                ? () => Navigator.pop(context, _mapping)
                : null,
            icon: const Icon(Icons.check),
            label: Text('Import ${parsed.rows.length}'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
          ),
        ],
      ),
    );
  }
}

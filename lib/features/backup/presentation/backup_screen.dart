import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tracks/features/backup/presentation/backup_actions.dart';

class BackupScreen extends ConsumerStatefulWidget {
  const BackupScreen({super.key});

  @override
  ConsumerState<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends ConsumerState<BackupScreen> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() job) async {
    setState(() => _busy = true);
    await guardFileJob(context, job);
    if (mounted) setState(() => _busy = false);
  }

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
    Widget section(String text) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
      child: Text(text, style: theme.textTheme.titleSmall),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Backup & restore')),
      body: ListView(
        children: [
          if (_busy) const LinearProgressIndicator(),
          section('Back up'),
          tile(
            Icons.save_alt,
            'Full backup (JSON)',
            'Everything, restorable on any phone. Save it to Drive, email or '
                'a folder from the share sheet.',
            () => _run(() => exportJsonBackup(ref)),
          ),
          tile(
            Icons.table_view,
            'Export transactions (CSV)',
            'Opens in Excel or Google Sheets.',
            () => _run(() => exportCsv(ref)),
          ),
          section('Restore & import'),
          tile(
            Icons.settings_backup_restore,
            'Restore full backup',
            'New phone or reinstall? Pick your tracks-backup file. You '
                'confirm before anything changes.',
            () => _run(() async {
              final text = await pickTextFile(['json']);
              if (text != null && context.mounted) {
                await restoreFromJsonText(context, ref, text);
              }
            }),
          ),
          tile(
            Icons.upload_file,
            'Import CSV',
            'From a bank statement, Money Manager or a spreadsheet. You '
                'match the columns.',
            () => _run(() async {
              final text = await pickTextFile(['csv', 'txt']);
              if (text != null && context.mounted) {
                await importCsvText(context, ref, text);
              }
            }),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Text(
              'Tip: you can also open a backup or CSV file from Drive, Gmail '
              'or Files and share it to Tracks.',
              style: theme.textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

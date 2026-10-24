import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tracks/app/providers.dart';
import 'package:tracks/features/settings/domain/app_lock_policy.dart';
import 'package:tracks/features/settings/presentation/app_lock_gate.dart';

class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final lockOn = ref.watch(settingProvider(appLockKey)).value == 'on';

    Future<void> toggleLock(bool on) async {
      // Prove the device can unlock before relying on it.
      final ok = await authenticateUser(
        on ? 'Confirm to turn on App lock' : 'Confirm to turn off App lock',
      );
      if (!ok) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Not changed. App lock needs a screen lock set on this phone.',
              ),
            ),
          );
        }
        return;
      }
      await ref
          .read(appDatabaseProvider)
          .setSetting(appLockKey, on ? 'on' : 'off');
    }

    return Scaffold(
      appBar: AppBar(title: const Text('More')),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
            child: Text('Plan', style: theme.textTheme.titleSmall),
          ),
          ListTile(
            leading: const Icon(Icons.event_repeat),
            title: const Text('Bills & autopay'),
            subtitle: const Text('Rent, EMIs, subscriptions, SIPs'),
            onTap: () => context.push('/bills'),
          ),
          ListTile(
            leading: const Icon(Icons.savings_outlined),
            title: const Text('Budgets'),
            subtitle: const Text('Monthly limits with a daily allowance'),
            onTap: () => context.push('/budgets'),
          ),
          ListTile(
            leading: const Icon(Icons.category_outlined),
            title: const Text('Categories'),
            subtitle: const Text('Add, rename, recolour, reorder'),
            onTap: () => context.push('/categories'),
          ),
          ListTile(
            leading: const Icon(Icons.auto_awesome_outlined),
            title: const Text('Rules'),
            subtitle: const Text('What Tracks learned from your corrections'),
            onTap: () => context.push('/rules'),
          ),
          ListTile(
            leading: const Icon(Icons.palette_outlined),
            title: const Text('Appearance'),
            subtitle: const Text('Light or dark, colour, text size'),
            onTap: () => context.push('/appearance'),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
            child: Text('Your data', style: theme.textTheme.titleSmall),
          ),
          ListTile(
            leading: const Icon(Icons.save_alt),
            title: const Text('Backup & restore'),
            subtitle: const Text(
              'Google Drive, new phone, CSV export & import',
            ),
            onTap: () => context.push('/backup'),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
            child: Text('Security', style: theme.textTheme.titleSmall),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.lock_outline),
            title: const Text('App lock'),
            subtitle: const Text(
              'Fingerprint, face or phone PIN when opening Tracks',
            ),
            value: lockOn,
            onChanged: toggleLock,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
            child: Text(
              'Tracks keeps everything on this phone. No accounts, no ads, '
              'no analytics, and the app never goes online. If Android '
              'backup is on for your Google account, your phone backs up '
              'Tracks with your other apps, so a new phone gets it back.',
              style: theme.textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

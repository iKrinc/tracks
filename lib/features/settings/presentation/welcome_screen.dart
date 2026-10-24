import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tracks/app/providers.dart';
import 'package:tracks/app/theme.dart';
import 'package:tracks/app/widgets/hero.dart';
import 'package:tracks/features/backup/presentation/backup_actions.dart';
import 'package:tracks/features/capture/presentation/share_intake.dart';

const welcomeSeenKey = 'welcomeSeen';

/// First launch on a phone: start fresh, or bring data over from the old
/// phone (backup JSON) or another app (CSV).
class WelcomeScreen extends ConsumerWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final tokens = theme.tokens;

    Future<void> done() async {
      await ref.read(appDatabaseProvider).setSetting(welcomeSeenKey, '1');
      if (context.mounted) context.go('/');
    }

    Future<void> fromFile(List<String> ext, bool json) =>
        guardFileJob(context, () async {
          final text = await pickTextFile(ext);
          if (text == null || !context.mounted) return;
          final ok = json
              ? await restoreFromJsonText(context, ref, text)
              : await importCsvText(context, ref, text);
          if (ok) await done();
        });

    // Shares (a backup from Drive, say) can arrive while this is showing.
    return ShareIntake(
      child: Scaffold(
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              HeroCard(
                padding: const EdgeInsets.fromLTRB(28, 40, 28, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.bolt, size: 40, color: tokens.heroInk),
                    const SizedBox(height: 24),
                    Text(
                      'Every rupee,\nin three seconds.',
                      style: theme.textTheme.displaySmall?.copyWith(
                        color: tokens.heroInk,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Type "chai 20" or share a bank SMS. Tracks keeps it all '
                      'on this phone: no account, no ads, no internet.',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: tokens.heroMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              _Choice(
                icon: Icons.auto_awesome,
                title: 'Start fresh',
                subtitle: 'Begin with Cash and Indian default categories',
                primary: true,
                onTap: done,
              ),
              const SizedBox(height: 12),
              _Choice(
                icon: Icons.phonelink_setup,
                title: 'Restore from my old phone',
                subtitle:
                    'Pick the tracks-backup .json you saved to Drive or '
                    'email',
                onTap: () => fromFile(['json'], true),
              ),
              const SizedBox(height: 12),
              _Choice(
                icon: Icons.upload_file,
                title: 'Import from another app',
                subtitle: 'A CSV from Money Manager, your bank or a sheet',
                onTap: () => fromFile(['csv', 'txt'], false),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Choice extends StatelessWidget {
  const _Choice({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.primary = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final fill = primary ? scheme.primaryContainer : scheme.surfaceContainerLow;
    final ink = primary ? scheme.onPrimaryContainer : scheme.onSurface;
    return Material(
      color: fill,
      borderRadius: BorderRadius.circular(TracksTokens.radiusCard),
      child: InkWell(
        borderRadius: BorderRadius.circular(TracksTokens.radiusCard),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Icon(icon, color: ink),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(color: ink),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: primary ? ink : scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward, color: ink),
            ],
          ),
        ),
      ),
    );
  }
}

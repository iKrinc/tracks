import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tracks/app/icons.dart';
import 'package:tracks/app/providers.dart';
import 'package:tracks/app/theme.dart';
import 'package:tracks/app/widgets/confirm.dart';
import 'package:tracks/data/app_database.dart';

/// What Tracks learned from corrections ("Always for …" on the Confirm
/// Card). Swipe or tap delete to forget one.
class RulesScreen extends ConsumerWidget {
  const RulesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final rules = ref.watch(rulesProvider).value;
    final accounts = {
      for (final a in ref.watch(allAccountsProvider).value ?? const <Account>[])
        a.id: a,
    };
    final categories = {
      for (final k in CategoryKind.values)
        for (final c
            in ref.watch(categoriesProvider(k)).value ?? const <Category>[])
          c.id: c,
    };

    return Scaffold(
      appBar: AppBar(title: const Text('Rules')),
      body: rules == null
          ? const SizedBox.shrink()
          : rules.isEmpty
          ? Padding(
              padding: const EdgeInsets.all(32),
              child: Center(
                child: Text(
                  'Nothing learned yet.\n\nTry it: type "swiggy 250" on '
                  'Home, pick Food delivery, and keep "Always for swiggy" '
                  'on. Next time Tracks fills it in by itself.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            )
          : ListView(
              children: [
                for (final r in rules)
                  _RuleTile(
                    rule: r,
                    category: categories[r.categoryId],
                    account: accounts[r.accountId],
                    onDelete: () => _delete(context, ref, r),
                  ),
              ],
            ),
    );
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, Rule r) async {
    final db = ref.read(appDatabaseProvider);
    final messenger = ScaffoldMessenger.of(context);
    await db.deleteRule(r.id);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('Forgot "${r.keyword}"'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () => db.restoreRule(r),
          ),
        ),
      );
  }
}

class _RuleTile extends StatelessWidget {
  const _RuleTile({
    required this.rule,
    required this.category,
    required this.account,
    required this.onDelete,
  });

  final Rule rule;
  final Category? category;
  final Account? account;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final does = [?category?.name, ?account?.name].join(' · ');
    final used = rule.hits == 0
        ? 'Not used yet'
        : 'Used ${rule.hits} time${rule.hits == 1 ? '' : 's'}';
    return Dismissible(
      key: ValueKey(rule.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => confirmDestructive(
        context,
        title: 'Forget "${rule.keyword}"?',
        message: 'Tracks will guess again next time.',
        action: 'Forget',
      ),
      onDismissed: (_) => onDelete(),
      background: Container(
        color: theme.colorScheme.errorContainer,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        child: Icon(
          Icons.delete_outline,
          color: theme.colorScheme.onErrorContainer,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.fromLTRB(20, 4, 8, 4),
        leading: ExcludeSemantics(
          child: CircleAvatar(
            backgroundColor: Color(category?.color ?? Palette.sand.toARGB32()),
            foregroundColor: Colors.black87,
            child: Icon(iconFor(category?.icon ?? ''), size: 20),
          ),
        ),
        title: Text('"${rule.keyword}"'),
        subtitle: Text(
          [if (does.isNotEmpty) '→ $does' else '→ nothing', used].join('\n'),
        ),
        isThreeLine: true,
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline),
          tooltip: 'Forget this rule',
          onPressed: () async {
            if (await confirmDestructive(
              context,
              title: 'Forget "${rule.keyword}"?',
              message: 'Tracks will guess again next time.',
              action: 'Forget',
            )) {
              onDelete();
            }
          },
        ),
      ),
    );
  }
}

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';
import 'package:tracks/app/providers.dart';
import 'package:tracks/features/settings/domain/app_lock_policy.dart';

/// Device unlock (fingerprint, face, or the phone's PIN/pattern as fallback).
/// Returns false if the user cancels or the device has no screen lock.
Future<bool> authenticateUser(String reason) async {
  if (kIsWeb) return true;
  final auth = LocalAuthentication();
  try {
    if (!await auth.isDeviceSupported()) return false;
    return await auth.authenticate(localizedReason: reason);
  } on Exception {
    return false;
  }
}

/// Covers the app with a lock screen when App lock is on: at launch, and
/// after it has been in the background longer than [relockGrace].
class AppLockGate extends ConsumerStatefulWidget {
  const AppLockGate({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends ConsumerState<AppLockGate> {
  late final AppLifecycleListener _lifecycle;
  bool? _locked; // null until the setting has loaded
  DateTime? _leftAt;
  bool _prompting = false;

  bool get _enabled => ref.read(settingProvider(appLockKey)).value == 'on';

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onHide: () => _leftAt ??= DateTime.now(),
      onShow: () {
        final relock = shouldRelock(
          enabled: _enabled,
          leftAt: _leftAt,
          now: DateTime.now(),
        );
        _leftAt = null;
        if (relock) setState(() => _locked = true);
        if (_locked ?? false) _unlock();
      },
    );
    ref.read(appDatabaseProvider).getSetting(appLockKey).then((v) {
      if (!mounted) return;
      setState(() => _locked = v == 'on');
      if (v == 'on') _unlock();
    });
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  Future<void> _unlock() async {
    if (_prompting) return;
    _prompting = true;
    final ok = await authenticateUser('Unlock Tracks');
    _prompting = false;
    // The prompt backgrounds the app briefly; don't count that as leaving.
    _leftAt = null;
    if (ok && mounted) setState(() => _locked = false);
  }

  @override
  Widget build(BuildContext context) {
    // Keep the setting live so [_enabled] sees changes made in More.
    ref.watch(settingProvider(appLockKey));
    final locked = _locked;
    if (locked == null) {
      // Don't flash content before we know whether it's locked.
      return const ColoredBox(color: Colors.transparent);
    }
    return Stack(
      children: [
        ExcludeSemantics(excluding: locked, child: widget.child),
        if (locked) _LockScreen(onUnlock: _unlock),
      ],
    );
  }
}

class _LockScreen extends StatelessWidget {
  const _LockScreen({required this.onUnlock});

  final VoidCallback onUnlock;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Positioned.fill(
      child: Material(
        color: theme.colorScheme.surface,
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.lock_outline,
                  size: 56,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(height: 16),
                Text('Tracks is locked', style: theme.textTheme.titleLarge),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: onUnlock,
                  icon: const Icon(Icons.fingerprint),
                  label: const Text('Unlock'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(200, 52),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

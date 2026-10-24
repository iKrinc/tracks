import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// A file another app shared, already copied into Tracks' cache.
typedef SharedFile = ({String path, String? mime, String name});

/// Something shared into Tracks from the Android share sheet.
class SharedPayload {
  const SharedPayload({
    this.text,
    this.files = const [],
    this.error,
    this.open,
  });

  final String? text;
  final List<SharedFile> files;

  /// Set when the sharing app handed over something unreadable.
  final String? error;

  /// From the home-screen widget: "quickAdd" or "form".
  final String? open;

  /// Reads the map MainActivity sends; anything malformed becomes an
  /// error payload rather than a crash.
  factory SharedPayload.fromMap(Object? raw) {
    try {
      final m = (raw as Map).cast<String, Object?>();
      return SharedPayload(
        text: m['text'] as String?,
        files: [
          for (final f in (m['files'] as List? ?? const []))
            if (f is Map && f['path'] is String)
              (
                path: f['path'] as String,
                mime: f['mime'] as String?,
                name: (f['name'] as String?) ?? '',
              ),
        ],
        error: m['error'] as String?,
        open: m['open'] as String?,
      );
    } catch (e) {
      return SharedPayload(error: '$e');
    }
  }
}

/// The `tracks/share` channel implemented in MainActivity.kt (Android only).
class ShareChannel {
  ShareChannel._() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'shared') {
        _shared.add(SharedPayload.fromMap(call.arguments));
      }
    });
  }

  static final instance = ShareChannel._();

  static const _channel = MethodChannel('tracks/share');
  final _shared = StreamController<SharedPayload>.broadcast();

  static bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// What the app was opened with, once (null if it wasn't a share).
  /// What the app was opened with, without using it up: the first-run
  /// welcome checks this so it doesn't hide a share.
  Future<SharedPayload?> peekInitial() => _initial ??= _readInitial();
  Future<SharedPayload?>? _initial;
  bool _initialTaken = false;

  /// The launch share, handed to exactly one caller; later callers (a
  /// screen rebuilt after restoring, say) get null so it isn't handled
  /// twice.
  Future<SharedPayload?> takeInitial() async {
    final p = await peekInitial();
    if (_initialTaken) return null;
    _initialTaken = true;
    return p;
  }

  Future<SharedPayload?> _readInitial() async {
    try {
      final raw = await _channel.invokeMethod<Object?>('initial');
      return raw == null ? null : SharedPayload.fromMap(raw);
    } catch (e) {
      return SharedPayload(error: '$e');
    }
  }

  /// Copies a content:// file (Drive, Gmail, other cloud apps) into the
  /// app cache and returns its path; null if Android couldn't read it.
  Future<String?> copyUri(String uri) async {
    try {
      return await _channel.invokeMethod<String>('readUri', {'uri': uri});
    } catch (_) {
      return null;
    }
  }

  /// Shares that arrive while Tracks is running.
  Stream<SharedPayload> get stream => _shared.stream;
}

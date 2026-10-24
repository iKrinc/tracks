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
  Future<SharedPayload?> initial() async {
    try {
      final raw = await _channel.invokeMethod<Object?>('initial');
      return raw == null ? null : SharedPayload.fromMap(raw);
    } catch (e) {
      return SharedPayload(error: '$e');
    }
  }

  /// Shares that arrive while Tracks is running.
  Stream<SharedPayload> get stream => _shared.stream;
}

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'package:tracks/features/recurring/domain/reminder_plan.dart';

/// Local (on-device) bill reminders. Nothing leaves the phone: Android's
/// alarm manager fires them, even if Tracks isn't running.
class ReminderService {
  ReminderService._();
  static final instance = ReminderService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  final _taps = StreamController<int>.broadcast();
  bool _ready = false;
  String _lastSignature = '';

  /// Recurring ids whose reminder was tapped ("Mark paid" or the body).
  Stream<int> get taps => _taps.stream;

  static bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<void> init() async {
    if (!supported || _ready) return;
    tzdata.initializeTimeZones();
    tz.setLocalLocation(_deviceLocation());
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
      onDidReceiveNotificationResponse: _onResponse,
    );
    _ready = true;
    // Opened from a reminder while the app was closed.
    final launch = await _plugin.getNotificationAppLaunchDetails();
    final r = launch?.notificationResponse;
    if ((launch?.didNotificationLaunchApp ?? false) && r != null) {
      // Let the UI subscribe first.
      Future<void>.delayed(
        const Duration(milliseconds: 600),
        () => _onResponse(r),
      );
    }
  }

  void _onResponse(NotificationResponse r) {
    final id = int.tryParse(r.payload?.replaceFirst('recurring:', '') ?? '');
    if (id != null) _taps.add(id);
  }

  /// Ids at or above [cardReminderIdBase] are card bills (account id =
  /// id - base); below are recurring items.

  /// Android 13+ asks the user once; earlier versions always allow.
  Future<bool> requestPermission() async {
    if (!supported) return false;
    await init();
    return await _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >()
            ?.requestNotificationsPermission() ??
        false;
  }

  /// Replaces all pending reminders with [plan]. Skips the work when the
  /// plan hasn't changed since the last sync.
  Future<void> sync(List<PlannedReminder> plan) async {
    if (!supported) return;
    await init();
    final signature = plan.map((p) => '${p.id}@${p.at}:${p.title}').join('|');
    if (signature == _lastSignature) return;
    _lastSignature = signature;
    await _plugin.cancelAll();
    for (final p in plan) {
      await _plugin.zonedSchedule(
        id: p.id,
        title: p.title,
        body: p.body,
        scheduledDate: tz.TZDateTime.from(p.at, tz.local),
        payload: 'recurring:${p.id}',
        // Inexact: no special alarm permission; a few minutes' drift is fine
        // for a 9 am bill nudge.
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'bills',
            'Bills & autopay',
            channelDescription: 'Reminders before rent, EMIs and subscriptions',
            importance: Importance.high,
            priority: Priority.high,
            actions: [
              AndroidNotificationAction(
                'mark_paid',
                'Mark paid',
                showsUserInterface: true,
              ),
            ],
          ),
        ),
      );
    }
  }

  /// The timezone database location matching the device's current offset,
  /// preferring Asia/Kolkata (IST) since that's who Tracks is for.
  static tz.Location _deviceLocation() {
    final offset = DateTime.now().timeZoneOffset;
    final ist = tz.getLocation('Asia/Kolkata');
    if (offset == const Duration(hours: 5, minutes: 30)) return ist;
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final loc in tz.timeZoneDatabase.locations.values) {
      if (loc.timeZone(now).offset == offset) return loc;
    }
    return tz.UTC;
  }
}

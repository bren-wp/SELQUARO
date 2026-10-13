import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'models.dart';

/// Opt-in device-only warranty reminders. No network or user identity.
class WarrantyReminders {
  WarrantyReminders({FlutterSecureStorage? preferences})
      : _preferences = preferences ?? const FlutterSecureStorage();

  static const preferenceKey = 'selquaro.reminders.enabled';
  final FlutterSecureStorage _preferences;
  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  bool enabled = false;
  bool available = false;

  Future<void> initialize() async {
    tzdata.initializeTimeZones();
    try {
      final zone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(zone.identifier));
    } catch (_) {
      // Fail closed: never schedule at an incorrect UTC time.
      available = false;
      return;
    }
    try {
      await _notifications.initialize(const InitializationSettings(
        android: AndroidInitializationSettings('ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ));
      available = true;
      enabled = await _preferences.read(key: preferenceKey) == 'true';
    } catch (_) {
      available = false;
      enabled = false;
    }
  }

  Future<bool> setEnabled(bool desired, List<Purchase> items) async {
    if (!available) return false;
    if (desired) {
      bool granted = false;
      if (Platform.isAndroid) {
        granted = await _notifications
              .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
              ?.requestNotificationsPermission() ?? false;
      } else if (Platform.isIOS) {
        granted = await _notifications
              .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
              ?.requestPermissions(alert: true, badge: true, sound: true) ?? false;
      }
      if (!granted) return false;
    }
    await _preferences.write(key: preferenceKey, value: desired.toString());
    enabled = desired;
    await sync(items);
    return true;
  }

  Future<void> sync(List<Purchase> items) async {
    if (!available) return;
    await _notifications.cancelAll();
    if (!enabled) return;
    final now = tz.TZDateTime.now(tz.local);
    final plans = <_PlannedReminder>[];
    for (final item in items) {
      final expiry = item.warrantyEndsAt;
      if (expiry == null) continue;
      for (final daysBefore in [30, 7, 1]) {
        // Subtract civil calendar days in UTC, then schedule 09:00 local.\n        // Subtracting Duration from local midnight crosses DST incorrectly.
        final calendar = DateTime.utc(expiry.year, expiry.month, expiry.day).subtract(Duration(days: daysBefore));
        final scheduled = tz.TZDateTime(
          tz.local, calendar.year, calendar.month, calendar.day, 9,
        );
        if (scheduled.isAfter(now)) {
          plans.add(_PlannedReminder(item.id, daysBefore, scheduled));
        }
      }
    }
    plans.sort((a, b) => a.when.compareTo(b.when));
    // iOS has a pending notification limit of 64. Keep a small reserve.
    for (var i = 0; i < plans.length && i < 60; i++) {
      final plan = plans[i];
      await _notifications.zonedSchedule(
        i + 1000,
        'SELQUARO warranty reminder',
        'A saved warranty expires in ${plan.daysBefore} day${plan.daysBefore == 1 ? '' : 's'}.',
        plan.when,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'selquaro_warranties_v1',
            'Warranty reminders',
            channelDescription: 'Private alerts ahead of saved warranty expirations',
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
            visibility: NotificationVisibility.private,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: false,
            presentSound: true,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: plan.itemId,
      );
    }
  }

  Future<void> clear() async {
    if (available) await _notifications.cancelAll();
    await _preferences.delete(key: preferenceKey);
    enabled = false;
  }
}

class _PlannedReminder {
  const _PlannedReminder(this.itemId, this.daysBefore, this.when);
  final String itemId;
  final int daysBefore;
  final tz.TZDateTime when;
}

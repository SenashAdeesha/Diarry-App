import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;

class NotificationService {
  static final NotificationService instance = NotificationService._();
  NotificationService._();

  final _notifications = FlutterLocalNotificationsPlugin();
  final _storage = const FlutterSecureStorage();
  bool _initialized = false;

  static const _reminderEnabledKey = 'reminder_enabled';
  static const _reminderHourKey = 'reminder_hour';
  static const _reminderMinuteKey = 'reminder_minute';
  static const _lastStreakNotifiedKey = 'last_streak_notified';
  static const _notificationChannelId = 'diary_reminder';
  static const _streakChannelId = 'diary_streak';
  static const _notificationId = 1001;
  static const _streakNotificationId = 1002;

  Future<void> init({required GlobalKey<NavigatorState> navigatorKey}) async {
    if (_initialized) return;

    tz_data.initializeTimeZones();

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      settings,
      onDidReceiveNotificationResponse: (response) {
        if (response.payload == 'open_app') {
          navigatorKey.currentState?.pushNamedAndRemoveUntil(
            '/',
            (_) => false,
          );
        }
      },
    );

    _initialized = true;
  }

  Future<bool> isReminderEnabled() async {
    final val = await _storage.read(key: _reminderEnabledKey);
    return val == 'true';
  }

  Future<TimeOfDay> getReminderTime() async {
    final hour = await _storage.read(key: _reminderHourKey);
    final minute = await _storage.read(key: _reminderMinuteKey);
    if (hour != null && minute != null) {
      return TimeOfDay(
        hour: int.tryParse(hour) ?? 21,
        minute: int.tryParse(minute) ?? 0,
      );
    }
    return const TimeOfDay(hour: 21, minute: 0);
  }

  Future<void> setReminderEnabled(bool enabled, {TimeOfDay? time}) async {
    final currentTime = time ?? await getReminderTime();
    await _storage.write(key: _reminderEnabledKey, value: enabled.toString());
    await _storage.write(key: _reminderHourKey, value: currentTime.hour.toString());
    await _storage.write(key: _reminderMinuteKey, value: currentTime.minute.toString());

    if (enabled) {
      await scheduleDailyReminder(currentTime);
    } else {
      await cancelReminder();
    }
  }

  Future<void> scheduleDailyReminder(TimeOfDay time) async {
    await _createChannel(
      _notificationChannelId,
      'Daily Reminder',
      'Reminds you to write in your diary',
    );

    final now = DateTime.now();
    var scheduledDate = DateTime(now.year, now.month, now.day, time.hour, time.minute);

    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    final tzScheduledDate = tz.TZDateTime.from(scheduledDate, tz.local);

    await _notifications.zonedSchedule(
      _notificationId,
      'Time to write in your diary',
      'Take a moment to reflect on your day.',
      tzScheduledDate,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _notificationChannelId,
          'Daily Reminder',
          channelDescription: 'Reminds you to write in your diary',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: 'open_app',
    );
  }

  Future<void> cancelReminder() async {
    await _notifications.cancel(_notificationId);
  }

  Future<void> checkStreakAndNotify(int streak) async {
    final milestones = [3, 7, 14, 30, 60, 100, 365];
    final milestone = milestones.where((m) => streak >= m).toList();

    if (milestone.isEmpty) return;

    final lastNotified = await _storage.read(key: _lastStreakNotifiedKey);
    final lastNotifiedInt = int.tryParse(lastNotified ?? '0') ?? 0;

    final newMilestones = milestone.where((m) => m > lastNotifiedInt).toList();
    if (newMilestones.isEmpty) return;

    await _createChannel(
      _streakChannelId,
      'Streak Achievement',
      'Celebrate your writing streak',
    );

    for (final m in newMilestones) {
      await _notifications.show(
        _streakNotificationId + m,
        '🔥 $m-Day Streak!',
        _streakMessage(m),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _streakChannelId,
            'Streak Achievement',
            channelDescription: 'Celebrate your writing streak',
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: false,
            presentSound: true,
          ),
        ),
        payload: 'open_app',
      );
    }

    await _storage.write(
      key: _lastStreakNotifiedKey,
      value: milestone.last.toString(),
    );
  }

  String _streakMessage(int days) {
    switch (days) {
      case 3:
        return 'Three days in a row — you\'re building a habit!';
      case 7:
        return 'One week of journaling! Consistency is key.';
      case 14:
        return 'Two weeks! Your diary is becoming a rich record.';
      case 30:
        return 'One month of daily writing! That\'s incredible dedication.';
      case 60:
        return 'Two months! You\'ve written more than most people do in a year.';
      case 100:
        return '💯 100-day streak! You\'re a true diarist.';
      case 365:
        return '🎉 ONE YEAR of daily journaling! What an achievement!';
      default:
        return '$days-day streak! Keep it going!';
    }
  }

  Future<void> rescheduleIfNeeded() async {
    if (await isReminderEnabled()) {
      final time = await getReminderTime();
      await scheduleDailyReminder(time);
    }
  }

  Future<void> _createChannel(String id, String name, String description) async {
    final android = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      await android.createNotificationChannel(
        AndroidNotificationChannel(
          id,
          name,
          description: description,
          importance: id == _notificationChannelId
              ? Importance.high
              : Importance.defaultImportance,
        ),
      );
    }
  }

  Future<void> showTestNotification() async {
    await _notifications.show(
      0,
      'Diary App',
      'Notifications are working!',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _notificationChannelId,
          'Daily Reminder',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: 'open_app',
    );
  }
}

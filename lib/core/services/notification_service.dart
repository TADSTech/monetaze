import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications_plus/flutter_local_notifications_plus.dart';
import 'package:monetaze/core/models/goal_model.dart';
import 'package:monetaze/core/models/task_model.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:permission_handler/permission_handler.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  late final FlutterLocalNotificationsPlugin _notificationsPlugin;

  Future<void> init() async {
    _notificationsPlugin = FlutterLocalNotificationsPlugin();
    tz.initializeTimeZones();

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );

    final iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    final initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
      macOS: iosSettings,
    );

    await _notificationsPlugin.initialize(initSettings);
  }

  Future<bool> requestPermissions() async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      final status = await Permission.notification.request();
      return status.isGranted;
    }

    if (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      return true; // Already requested in iOS/macOS init
    }

    return false;
  }

  Future<void> scheduleTaskNotification(Task task, Goal goal) async {
    try {
      if (!await requestPermissions()) {
        debugPrint('Notification permission denied.');
        return;
      }

      final scheduledDate = tz.TZDateTime.from(task.dueDate, tz.local);
      if (!scheduledDate.isAfter(DateTime.now())) {
        debugPrint('Attempted to schedule notification for a past time.');
        return;
      }

      final androidDetails = AndroidNotificationDetails(
        'payment_channel_id',
        'Payment Notifications',
        channelDescription: 'Notifies about upcoming payment-related tasks',
        importance: Importance.high,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
        visibility: NotificationVisibility.public,
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      final notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
        macOS: iosDetails,
      );

      await _notificationsPlugin.zonedSchedule(
        task.hashCode,
        'Payment Due: ${goal.name}',
        'Amount: ${task.currency}${task.amount.toStringAsFixed(0)}',
        scheduledDate,
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exact,

        matchDateTimeComponents: DateTimeComponents.dateAndTime,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (e) {
      debugPrint('Failed to schedule notification: $e');
    }
  }

  Future<void> cancelNotification(Task task) async {
    try {
      await _notificationsPlugin.cancel(task.hashCode);
    } catch (e) {
      debugPrint('Error cancelling notification: $e');
    }
  }

  Future<void> cancelAllNotifications() async {
    try {
      await _notificationsPlugin.cancelAll();
    } catch (e) {
      debugPrint('Error cancelling all notifications: $e');
    }
  }
}

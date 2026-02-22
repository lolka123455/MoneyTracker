import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz_data;
import '../core/constants.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    tz_data.initializeTimeZones();

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      macOS: darwinSettings,
      iOS: darwinSettings,
    );

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );
  }

  static void _onNotificationTap(NotificationResponse response) {
    // Handle notification tap — navigation logic would go here
  }

  static Future<void> requestPermissions() async {
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    await _plugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);
  }

  /// Schedule a notification for a subscription payment
  static Future<void> scheduleSubscriptionReminder({
    required int id,
    required String subscriptionName,
    required double amount,
    required String currency,
    required DateTime nextPaymentDate,
    required String time, // "HH:mm" format
  }) async {
    final timeParts = time.split(':');
    final hour = int.parse(timeParts[0]);
    final minute = int.parse(timeParts[1]);

    final scheduledDate = tz.TZDateTime(
      tz.local,
      nextPaymentDate.year,
      nextPaymentDate.month,
      nextPaymentDate.day,
      hour,
      minute,
    );

    // Only schedule if in the future
    if (scheduledDate.isBefore(tz.TZDateTime.now(tz.local))) return;

    final symbol = currency == 'USD' ? '\$' : '\u20BD';

    await _plugin.zonedSchedule(
      id,
      'Payment Reminder',
      '$subscriptionName — $symbol${amount.toStringAsFixed(2)} due today',
      scheduledDate,
      NotificationDetails(
        android: AndroidNotificationDetails(
          AppConstants.notificationChannelId,
          AppConstants.notificationChannelName,
          importance: Importance.high,
          priority: Priority.high,
        ),
        macOS: const DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.dateAndTime,
    );
  }

  /// Cancel a specific notification
  static Future<void> cancelNotification(int id) async {
    await _plugin.cancel(id);
  }

  /// Cancel all notifications
  static Future<void> cancelAllNotifications() async {
    await _plugin.cancelAll();
  }
}

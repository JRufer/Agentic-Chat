import 'dart:async';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ReminderService {
  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  
  static final StreamController<String> _payloadStream = StreamController<String>.broadcast();
  Stream<String> get onReminderTapped => _payloadStream.stream;

  Future<void> initialize() async {
    tz.initializeTimeZones();
    
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
        
    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );

    await _notificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        if (response.payload != null) {
          _payloadStream.add(response.payload!);
        }
      },
    );
    
    final details = await _notificationsPlugin.getNotificationAppLaunchDetails();
    if (details?.didNotificationLaunchApp ?? false) {
       final payload = details?.notificationResponse?.payload;
       if (payload != null) {
         Future.delayed(const Duration(seconds: 2), () {
           _payloadStream.add(payload);
         });
       }
    }
  }

  Future<void> scheduleReminder(String title, DateTime scheduledTime) async {
    final tz.TZDateTime tzTime = tz.TZDateTime.from(scheduledTime, tz.local);
    
    final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
        _notificationsPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
            
    if (androidImplementation != null) {
      await androidImplementation.createNotificationChannel(const AndroidNotificationChannel(
        'reminder_channel_id',
        'Reminders',
        description: 'Agentic Chat Reminders',
        importance: Importance.high,
      ));
    }
    
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'reminder_channel_id',
      'Reminders',
      channelDescription: 'Agentic Chat Reminders',
      importance: Importance.high,
      priority: Priority.high,
    );
    
    const NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
    );

    await _notificationsPlugin.show(
      DateTime.now().millisecond + 1,
      'Reminder Configured!',
      'Scheduled for $tzTime',
      platformDetails,
    );

    await _notificationsPlugin.zonedSchedule(
      DateTime.now().millisecond,
      title,
      'Click to talk to your AI agent',
      tzTime,
      platformDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      payload: 'REMINDER_TRIGGERED|$title',
    );
  }
}

final reminderServiceProvider = Provider((ref) => ReminderService());

import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final _notifications = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  /// Initializes local notifications and registers the Android channel.
  static Future<void> init() async {
    if (_initialized) return;

    // Bypass native platform channels in unit tests
    if (Platform.environment.containsKey('FLUTTER_TEST')) {
      _initialized = true;
      return;
    }

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);

    await _notifications.initialize(initSettings);

    const channel = AndroidNotificationChannel(
      'bitchat_mesh_channel',
      'BitChat Mesh Notifications',
      description: 'Notifications for incoming offline messages',
      importance: Importance.max,
      playSound: true,
    );

    await _notifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    _initialized = true;
  }

  /// Displays a local notification instantly with sound and high priority.
  static Future<void> showNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    await init(); // Verify initialization

    if (Platform.environment.containsKey('FLUTTER_TEST')) {
      return;
    }

    const androidDetails = AndroidNotificationDetails(
      'bitchat_mesh_channel',
      'BitChat Mesh Notifications',
      channelDescription: 'Notifications for incoming offline messages',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
      playSound: true,
    );

    const details = NotificationDetails(android: androidDetails);
    await _notifications.show(id, title, body, details);
  }
}

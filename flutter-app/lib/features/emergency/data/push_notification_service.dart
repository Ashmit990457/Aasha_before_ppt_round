import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;

import '../../../core/config/api_config.dart';
import '../../auth/data/auth_service.dart';

final FlutterLocalNotificationsPlugin _localNotifications =
    FlutterLocalNotificationsPlugin();

const _channelId = 'aasha_emergency_alerts';
const _channelName = 'Emergency alerts';
final _vibrationPattern = Int64List.fromList([
  0,
  500,
  500,
  500,
  500,
  500,
  500,
  500,
  500,
  500,
  500,
  500,
  500,
  500,
  500,
  500,
  500,
  500,
  500,
  500,
  500,
]);

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
    await _initializeLocalNotifications();
    await _showEmergencyNotification(message);
  } catch (error) {
    debugPrint(
      '[FCM-DEBUG] background_notification_failed=${error.runtimeType}',
    );
  }
}

Future<void> _initializeLocalNotifications() async {
  const android = AndroidInitializationSettings('@mipmap/ic_launcher');
  await _localNotifications.initialize(
    const InitializationSettings(android: android),
    onDidReceiveNotificationResponse: (response) {
      PushNotificationService.instance._handleLocalNotificationTap(
        response.payload,
      );
    },
  );
  final androidPlugin = _localNotifications
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();
  await androidPlugin?.createNotificationChannel(
    AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: 'High-priority Asha government emergency alerts',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
      vibrationPattern: _vibrationPattern,
    ),
  );
}

Future<void> _showEmergencyNotification(RemoteMessage message) async {
  final data = message.data;
  final title =
      message.notification?.title ?? data['title'] ?? 'Emergency alert';
  final body =
      message.notification?.body ??
      data['message'] ??
      'A government emergency alert is active.';
  await _localNotifications.show(
    message.hashCode,
    title,
    body,
    NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: 'High-priority Asha government emergency alerts',
        importance: Importance.max,
        priority: Priority.max,
        playSound: true,
        enableVibration: true,
        vibrationPattern: _vibrationPattern,
        category: AndroidNotificationCategory.alarm,
      ),
    ),
    payload: data['alert_id'],
  );
}

class PushNotificationService {
  PushNotificationService._();
  static final instance = PushNotificationService._();

  final alertOpened = ValueNotifier<String?>(null);
  final AuthService _auth = AuthService();
  bool _initialized = false;
  String? _registeredUser;

  Future<void> initializeForUser(String userId) async {
    if (_registeredUser == userId && _initialized) return;
    try {
      await Firebase.initializeApp();
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
      await _initializeLocalNotifications();

      final messaging = FirebaseMessaging.instance;
      final permission = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        criticalAlert: true,
      );
      debugPrint(
        '[FCM-DEBUG] permission_status=${permission.authorizationStatus}',
      );

      final token = await messaging.getToken();
      debugPrint('[FCM-DEBUG] token_available=${token?.isNotEmpty == true}');
      if (token != null && token.isNotEmpty) {
        await _registerToken(userId, token);
      }
      messaging.onTokenRefresh.listen((newToken) async {
        if (newToken.isNotEmpty) await _registerToken(userId, newToken);
      });
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
      FirebaseMessaging.onMessageOpenedApp.listen(_handleOpenedMessage);
      final initial = await messaging.getInitialMessage();
      if (initial != null) _handleOpenedMessage(initial);
      _registeredUser = userId;
      _initialized = true;
    } catch (error) {
      debugPrint('[FCM-DEBUG] initialization_failed=${error.runtimeType}');
      debugPrint('[FCM-DEBUG] token_registered=false');
    }
  }

  Future<void> _registerToken(String userId, String token) async {
    await _auth.tryAutoLogin();
    try {
      final response = await http
          .post(
            Uri.parse(
              '${ApiConfig.matchingBaseUrl}/api/notifications/device-token',
            ),
            headers: {'Content-Type': 'application/json', ..._auth.authHeaders},
            body: jsonEncode({'token': token, 'platform': 'android'}),
          )
          .timeout(const Duration(seconds: 15));
      debugPrint('[FCM-DEBUG] token_registered=${response.statusCode == 200}');
    } catch (error) {
      debugPrint(
        '[FCM-DEBUG] token_registered=false error=${error.runtimeType}',
      );
    }
  }

  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    if (message.data['type'] == 'GOVERNMENT_EMERGENCY_ALERT') {
      await _showEmergencyNotification(message);
    }
  }

  void _handleOpenedMessage(RemoteMessage message) {
    final alertId = message.data['alert_id'];
    if (alertId is String && alertId.isNotEmpty) alertOpened.value = alertId;
  }

  void _handleLocalNotificationTap(String? alertId) {
    if (alertId != null && alertId.isNotEmpty) alertOpened.value = alertId;
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../screens/events_screen.dart';
import 'auth_service.dart';

/// Push-notification setup.
///
/// All users automatically subscribe to the `public_events` topic. When the
/// admin approves a public event, a Cloud Function publishes to that topic
/// and every subscribed device receives it (even when the app is closed).
class NotificationService {
  NotificationService._();
  static final instance = NotificationService._();

  /// Global navigator key — used to navigate from notification taps.
  static final navigatorKey = GlobalKey<NavigatorState>();

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    // Web push needs a service worker and a VAPID key that are not configured,
    // and requesting permission without them throws. The web build simply has
    // no notifications rather than no app — see the guard in main().
    if (kIsWeb) {
      debugPrint('[Notifications] Skipped on web (no service worker/VAPID key)');
      return;
    }

    final messaging = FirebaseMessaging.instance;

    // 1. Permission (Android 13+ shows the prompt; iOS always prompts)
    final settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      debugPrint('[Notifications] Permission denied');
      return;
    }

    // 2. Subscribe to the public-events topic
    try {
      await messaging.subscribeToTopic('public_events');
    } catch (e) {
      debugPrint('[Notifications] Topic subscribe failed: $e');
    }

    // 3. Save FCM token to user's Firestore doc — lets us send individual
    //    notifications in the future (event updates, admin messages, etc.)
    try {
      final token = await messaging.getToken();
      if (token != null) await _saveTokenToFirestore(token);
      messaging.onTokenRefresh.listen(_saveTokenToFirestore);
    } catch (_) {}

    // 4. Foreground messages — show as an in-app SnackBar
    FirebaseMessaging.onMessage.listen(_onForeground);

    // 5. Tap-on-notification while app is in background
    FirebaseMessaging.onMessageOpenedApp.listen(_onMessageOpened);

    // 6. Tap-on-notification while app was terminated
    final initial = await messaging.getInitialMessage();
    if (initial != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _onMessageOpened(initial);
      });
    }
  }

  Future<void> _saveTokenToFirestore(String token) async {
    final uid = AuthService.instance.currentUser?.id;
    if (uid == null) return;
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'fcmToken': token,
        'fcmTokenUpdatedAt': DateTime.now().toIso8601String(),
      });
    } catch (_) {}
  }

  void _onForeground(RemoteMessage msg) {
    final ctx = navigatorKey.currentContext;
    if (ctx == null) return;
    final title = msg.notification?.title ?? '🌿 Botanica';
    final body = msg.notification?.body ?? '';
    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
      backgroundColor: const Color(0xFF1B4020),
      duration: const Duration(seconds: 4),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title,
              style: const TextStyle(
                  color: Color(0xFFE8F5E9),
                  fontSize: 14,
                  fontWeight: FontWeight.w700)),
          if (body.isNotEmpty)
            Text(body,
                style: const TextStyle(color: Color(0xFFC5E1A5), fontSize: 13)),
        ],
      ),
    ));
  }

  void _onMessageOpened(RemoteMessage msg) {
    if (kDebugMode) {
      debugPrint('[Notifications] Tap-opened: ${msg.data}');
    }
    final type = msg.data['type'];
    if (type == 'public_event') {
      final eventId = msg.data['eventId'] as String?;
      final nav = navigatorKey.currentState;
      if (nav != null) {
        nav.push(MaterialPageRoute(
          builder: (_) => EventsScreen(highlightEventId: eventId),
        ));
      }
    }
  }
}

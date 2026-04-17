import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../utils/constants.dart';

class NotifSvc {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _ready = false;

  static Future<void> init() async {
    if (_ready) return;
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios     = DarwinInitializationSettings();
    await _plugin.initialize(
        const InitializationSettings(android: android, iOS: ios));
    await _ensureChannels();
    _ready = true;
  }

  static Future<void> _ensureChannels() async {
    final impl = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (impl == null) return;

    await impl.createNotificationChannel(const AndroidNotificationChannel(
      K.chGuardian, 'Guardian Mode',
      description: 'Guardian check-in reminders',
      importance:  Importance.high,
    ));
    await impl.createNotificationChannel(const AndroidNotificationChannel(
      K.chSos, 'SOS Alerts',
      description: 'SOS sent confirmations',
      importance:  Importance.max,
    ));
    await impl.createNotificationChannel(const AndroidNotificationChannel(
      K.chCrash, 'Crash Detection',
      description: 'Crash detected alerts',
      importance:  Importance.max,
    ));
  }

  // ── Guardian active reminder ───────────────────────────────────────────────

  static Future<void> guardianActive(int minsLeft) => _plugin.show(
        K.notifGuardian,
        '🛡️ Guardian Active',
        'Next check-in in $minsLeft min',
        _details(K.chGuardian, Importance.low, color: const Color(0xFF2979FF)),
      );

  static Future<void> guardianCheckIn(int secsLeft) => _plugin.show(
        K.notifGuardian,
        '⚠️ Check-In Required',
        'SOS fires in ${secsLeft}s — open app to confirm',
        _details(K.chGuardian, Importance.max,
            color: const Color(0xFFFF9100), fullScreen: true),
      );

  // ── SOS sent ──────────────────────────────────────────────────────────────

  static Future<void> sosSent(String sessionId) => _plugin.show(
        K.notifSos,
        '🚨 SOS Sent',
        'Session $sessionId transmitted',
        _details(K.chSos, Importance.max, color: const Color(0xFFFF1744)),
      );

  // ── Crash warning ─────────────────────────────────────────────────────────

  static Future<void> crashWarning(int secsLeft) => _plugin.show(
        K.notifCrash,
        '🚗 CRASH DETECTED',
        'SOS fires in ${secsLeft}s — open app to cancel',
        _details(K.chCrash, Importance.max,
            color: const Color(0xFFFF1744), fullScreen: true),
      );

  // ── Cancel ────────────────────────────────────────────────────────────────

  static Future<void> cancel(int id) => _plugin.cancel(id);
  static Future<void> cancelAll()    => _plugin.cancelAll();

  // ── Helper ────────────────────────────────────────────────────────────────

  static NotificationDetails _details(
    String channelId,
    Importance importance, {
    Color? color,
    bool fullScreen = false,
  }) =>
      NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          channelId,
          importance:       importance,
          priority:         Priority.max,
          color:            color,
          fullScreenIntent: fullScreen,
          playSound:        true,
          enableVibration:  true,
        ),
      );
}

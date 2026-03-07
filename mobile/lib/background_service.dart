// mobile/lib/background_service.dart
import 'dart:async';
import 'dart:math';
import 'dart:convert';
import 'dart:ui';
import 'package:http/http.dart' as http;
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> initializeService() async {
  final service = FlutterBackgroundService();

  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'sos_foreground',
    'SOS Monitoring',
    description: 'Keeps SOS Guardian active in background.',
    importance: Importance.low,
  );

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
  FlutterLocalNotificationsPlugin();

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
      AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStart: false,
      isForegroundMode: true,
      notificationChannelId: 'sos_foreground',
      initialNotificationTitle: 'SOS Guardian Active',
      initialNotificationContent: 'Monitoring system running silently...',
      foregroundServiceNotificationId: 888,
    ),
    iosConfiguration: IosConfiguration(
      autoStart: false,
      onForeground: onStart,
      onBackground: onIosBackground,
    ),
  );
}

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  return true;
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  if (service is AndroidServiceInstance) {
    service.on('setAsForeground').listen((event) {
      service.setAsForegroundService();
    });

    service.on('setAsBackground').listen((event) {
      service.setAsBackgroundService();
    });
  }

  service.on('stopService').listen((event) {
    service.stopSelf();
  });

  Timer.periodic(const Duration(minutes: 15), (timer) async {
    service.invoke(
      'update',
      {"current_date": DateTime.now().toIso8601String()},
    );
  });

  const double crashThreshold = 10.5;
  const double spinThreshold = 3.0;
  DateTime? lastAlertTime;
  bool highGDetected = false;

  gyroscopeEventStream().listen((GyroscopeEvent event) {
    if (!highGDetected) return;

    final double rotation = sqrt(pow(event.x, 2) + pow(event.y, 2) + pow(event.z, 2));
    if (rotation > spinThreshold) {
      print("🚨 SPIN DETECTED: $rotation rad/s. Triggering Backend SOS!");
      final now = DateTime.now();
      if (lastAlertTime == null || now.difference(lastAlertTime!).inSeconds > 30) {
        lastAlertTime = now;
        highGDetected = false;
        _triggerAutomatedSos();
      }
    }
  });

  userAccelerometerEventStream().listen((UserAccelerometerEvent event) {
    final double magnitude = sqrt(pow(event.x, 2) + pow(event.y, 2) + pow(event.z, 2));
    if (magnitude > crashThreshold) {
      print("💥 HIGH-G IMPACT DETECTED: $magnitude m/s²");
      highGDetected = true;
      Future.delayed(const Duration(seconds: 4), () {
        if (highGDetected) print("Impact window closed. Waiting for new event.");
        highGDetected = false;
      });
    }
  });
}

Future<void> _triggerAutomatedSos() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final deviceId = prefs.getString('device_id');
    if (deviceId == null) return;

    final pos = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 5)),
    );

    final payload = jsonEncode({
      "lat": pos.latitude,
      "lon": pos.longitude,
      "message": "AUTOMATED ALERT: High-G impact + Spin detected.",
      "timestamp": DateTime.now().toIso8601String()
    });

    const String backendUrl = 'http://10.0.2.2:8000';

    await http.post(
      Uri.parse('$backendUrl/v1/sos/init'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'creator_device_id': deviceId,
        'encrypted_session_blob': base64Encode(utf8.encode(payload)),
      }),
    ).timeout(const Duration(seconds: 5));
  } catch (_) {}
}
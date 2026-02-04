import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

import 'package:porcupine_flutter/porcupine.dart';
import 'package:porcupine_flutter/porcupine_manager.dart';
import 'package:porcupine_flutter/porcupine_error.dart';

import 'package:shared_preferences/shared_preferences.dart';

const String backendUrl = 'http://10.0.2.2:8000';
const String accessKey = 'z6xIVP6LmdvZPj1Ze17bn7Tn3hLHgQWupTUuMc5bbsJnziF0z7UerA==';

Future<void> initializeService() async {
  final service = FlutterBackgroundService();

  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'sos_foreground',
    'SOS Monitoring',
    description: 'Keeps SOS Guardian active and listening.',
    importance: Importance.high,
  );

  final flutterLocalNotificationsPlugin =
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
      initialNotificationContent: 'Listening for safe words...',
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
  DartPluginRegistrant.ensureInitialized();
  final notifications = FlutterLocalNotificationsPlugin();

  PorcupineManager? porcupineManager;

  try {
    porcupineManager = await PorcupineManager.fromBuiltInKeywords(
      accessKey,
      [BuiltInKeyword.PORCUPINE, BuiltInKeyword.BUMBLEBEE],
          (int keywordIndex) {
        _triggerSosLogic(service, notifications);
      },
    );
    await porcupineManager.start();
  } on PorcupineException catch (e) {
    service.invoke('update', {"error": e.toString()});
  }

  if (service is AndroidServiceInstance) {
    service.on('setAsForeground')
        .listen((_) => service.setAsForegroundService());
    service.on('setAsBackground')
        .listen((_) => service.setAsBackgroundService());
  }

  service.on('stopService').listen((_) async {
    await porcupineManager?.stop();
    await porcupineManager?.delete();
    service.stopSelf();
  });

  Timer.periodic(const Duration(seconds: 10), (timer) async {
    if (service is AndroidServiceInstance) {
      if (await service.isForegroundService()) {
        service.setForegroundNotificationInfo(
          title: "Guardian Ears Active",
          content:
          "Safe Words Active (${DateTime.now().minute}:${DateTime.now().second})",
        );
      }
    }
  });
}

Future<void> _triggerSosLogic(
    ServiceInstance service,
    FlutterLocalNotificationsPlugin notifications) async {

  const details = NotificationDetails(
    android: AndroidNotificationDetails(
      'sos_foreground',
      'SOS Monitoring',
      importance: Importance.high,
      priority: Priority.high,
    ),
  );

  // ✅ FIXED
  await notifications.show(
    id: 999,
    title: "EMERGENCY TRIGGERED",
    body: "Voice command detected! Sending Help...",
    notificationDetails: details,
  );

  try {
    Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);

    final payloadPlain =
        'VOICE_ALERT_LAT:${position.latitude},LON:${position.longitude}';
    final encryptedBlob = base64Encode(utf8.encode(payloadPlain));

    final response = await http
        .post(
      Uri.parse('$backendUrl/v1/sos/init'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'creator_device_id': 'android_voice_bg',
        'encrypted_session_blob': encryptedBlob,
      }),
    )
        .timeout(const Duration(seconds: 10));

    if (response.statusCode == 201) {
      await notifications.show(
        id: 1000,
        title: "SOS SENT",
        body: "Authorities have been notified.",
        notificationDetails: details,
      );
    }
  } catch (e) {
    await notifications.show(
      id: 1001,
      title: "SOS FAILED",
      body: "Check internet connection.",
      notificationDetails: details,
    );
  }
}

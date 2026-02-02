import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

// --- FIX: Added these imports ---
import 'package:porcupine_flutter/porcupine.dart';
import 'package:porcupine_flutter/porcupine_manager.dart';
import 'package:porcupine_flutter/porcupine_error.dart';

import 'package:shared_preferences/shared_preferences.dart';

// --- CONFIGURATION ---
// CHANGE THIS to your PC's IP if using a real device (e.g., 'http://192.168.1.5:8000')
const String backendUrl = 'http://10.0.2.2:8000';

// PASTE YOUR KEY HERE
const String accessKey = 'z6xIVP6LmdvZPj1Ze17bn7Tn3hLHgQWupTUuMc5bbsJnziF0z7UerA==';

Future<void> initializeService() async {
  final service = FlutterBackgroundService();

  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'sos_foreground',
    'SOS Monitoring',
    description: 'Keeps SOS Guardian active and listening.',
    importance: Importance.high,
  );

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
  FlutterLocalNotificationsPlugin();

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
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

  // Initialize Porcupine
  PorcupineManager? porcupineManager;

  try {
    porcupineManager = await PorcupineManager.fromBuiltInKeywords(
      accessKey,
      [BuiltInKeyword.PORCUPINE, BuiltInKeyword.BUMBLEBEE],
          (int keywordIndex) {
        debugPrint("WAKE WORD DETECTED: Index $keywordIndex");
        _triggerSosLogic(service, notifications);
      },
    );
    await porcupineManager.start();
    debugPrint("Voice Engine Started Successfully");
  } on PorcupineException catch (e) {
    debugPrint("Porcupine Error: $e");
    service.invoke('update', {"error": e.toString()});
  }

  if (service is AndroidServiceInstance) {
    service.on('setAsForeground').listen((event) => service.setAsForegroundService());
    service.on('setAsBackground').listen((event) => service.setAsBackgroundService());
  }

  service.on('stopService').listen((event) async {
    await porcupineManager?.stop();
    await porcupineManager?.delete();
    service.stopSelf();
  });

  Timer.periodic(const Duration(seconds: 10), (timer) async {
    if (service is AndroidServiceInstance) {
      if (await service.isForegroundService()) {
        service.setForegroundNotificationInfo(
          title: "Guardian Ears Active",
          content: "Safe Words Active. (${DateTime.now().minute}:${DateTime.now().second})",
        );
      }
    }
  });
}

Future<void> _triggerSosLogic(ServiceInstance service, FlutterLocalNotificationsPlugin notifications) async {
  // 1. Show Local Alert
  await notifications.show(
      999,
      "EMERGENCY TRIGGERED",
      "Voice command detected! Sending Help...",
      const NotificationDetails(android: AndroidNotificationDetails('sos_foreground', 'SOS Monitoring'))
  );

  try {
    Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);

    final String payloadPlain = 'VOICE_ALERT_LAT:${position.latitude},LON:${position.longitude}';
    final String encryptedBlob = base64Encode(utf8.encode(payloadPlain));

    final response = await http.post(
      Uri.parse('$backendUrl/v1/sos/init'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'creator_device_id': 'android_voice_bg',
        'encrypted_session_blob': encryptedBlob,
      }),
    ).timeout(const Duration(seconds: 10));

    if (response.statusCode == 201) {
      await notifications.show(
          999,
          "SOS SENT",
          "Authorities have been notified.",
          const NotificationDetails(android: AndroidNotificationDetails('sos_foreground', 'SOS Monitoring'))
      );
    }

  } catch (e) {
    debugPrint("Background SOS Failed: $e");
    await notifications.show(
        999,
        "SOS FAILED",
        "Check internet connection.",
        const NotificationDetails(android: AndroidNotificationDetails('sos_foreground', 'SOS Monitoring'))
    );
  }
}
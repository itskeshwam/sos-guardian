import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

Future<void> initializeService() async {
  final service = FlutterBackgroundService();

  // Create the Notification Channel (Required for Android)
  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'sos_foreground', // id
    'SOS Monitoring', // title
    description: 'Keeps SOS Guardian active in background.',
    importance: Importance.high,
  );

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
  FlutterLocalNotificationsPlugin();

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      // This function runs in a separate Isolate
      onStart: onStart,
      autoStart: false, // We will start it manually from the UI
      isForegroundMode: true,
      notificationChannelId: 'sos_foreground',
      initialNotificationTitle: 'SOS Guardian Active',
      initialNotificationContent: 'Monitoring for safe words...',
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
  // Ensure Dart bindings are ready
  DartPluginRegistrant.ensureInitialized();

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

  // Heartbeat Loop: This proves the app is alive even when closed
  Timer.periodic(const Duration(seconds: 5), (timer) async {
    if (service is AndroidServiceInstance) {
      if (await service.isForegroundService()) {
        service.setForegroundNotificationInfo(
          title: "Guardian Active",
          content: "Security Check: ${DateTime.now().hour}:${DateTime.now().minute}:${DateTime.now().second}",
        );
      }
    }

    // Send data back to the main UI if it's open
    service.invoke(
      'update',
      {"current_date": DateTime.now().toIso8601String()},
    );

    debugPrint("Background Service Pulse: ${DateTime.now()}");
  });
}
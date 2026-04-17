import 'package:flutter/services.dart';
import '../utils/constants.dart';

class DeviceSvc {
  static const _ch = MethodChannel(K.bleChannel);

  static int _battery    = 100;
  static bool _charging  = false;
  static String _network = 'unknown';

  static int    get battery   => _battery;
  static bool   get charging  => _charging;
  static String get network   => _network;
  static bool   get lowBatt   => _battery <= 20 && !_charging;

  static Future<void> refresh() async {
    try {
      _battery  = await _ch.invokeMethod<int>('getBatteryLevel') ?? 100;
    } catch (_) {}
    try {
      _charging = await _ch.invokeMethod<bool>('isCharging') ?? false;
    } catch (_) {}
    try {
      _network  = await _ch.invokeMethod<String>('getNetworkType') ?? 'unknown';
    } catch (_) {}
  }

  // ── BLE advertising (SOS beacon) ─────────────────────────────────────────

  static Future<void> startBleBeacon(String userName) async {
    try {
      await _ch.invokeMethod('startBleAdvert', {'name': userName});
    } catch (_) {}
  }

  static Future<void> stopBleBeacon() async {
    try {
      await _ch.invokeMethod('stopBleAdvert');
    } catch (_) {}
  }
}

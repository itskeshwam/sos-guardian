import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:sensors_plus/sensors_plus.dart';
import '../utils/constants.dart';

class CrashNotifier extends ChangeNotifier {
  StreamSubscription<AccelerometerEvent>? _sub;
  bool _active = false;
  bool get active => _active;

  VoidCallback? onCrash;

  // Track last sample to calculate delta
  double _prevMag = 9.8; // approx 1g at rest

  void start(VoidCallback callback) {
    if (_active) return;
    _active  = true;
    onCrash  = callback;

    _sub = accelerometerEventStream(
      samplingPeriod: SensorInterval.normalInterval,
    ).listen((e) {
      final mag   = sqrt(e.x * e.x + e.y * e.y + e.z * e.z);
      final delta = (mag - _prevMag).abs();
      _prevMag    = mag;

      // Spike above threshold AND large delta → likely crash/impact
      if (mag > K.crashThreshold && delta > K.crashDeltaMin) {
        onCrash?.call();
      }
    });

    notifyListeners();
  }

  void stop() {
    _sub?.cancel();
    _active = false;
    _prevMag = 9.8;
    notifyListeners();
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }
}

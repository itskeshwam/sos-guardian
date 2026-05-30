import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../models/contact.dart';
import '../models/sos_record.dart';
import '../services/api.dart';
import '../services/device_svc.dart';
import '../services/location_svc.dart';
import '../services/notif_svc.dart';
import '../services/sms_svc.dart';
import '../services/audio_record_svc.dart'; // Ensure this file exists
import '../utils/constants.dart';

enum AppPhase { boot, unregistered, home }
enum SendState { idle, sending, done, failed }
enum GuardianPhase { off, ticking, awaitingCheckin }

class AppState extends ChangeNotifier {
  AppPhase phase = AppPhase.boot;
  String deviceId = '';
  String username = '';
  String phone = '';
  bool online = false;
  SendState sendState = SendState.idle;
  String sendMsg = '';
  Position? lastPos;
  SosRecord? lastSos;
  bool showFakeShutdown = false;

  GuardianPhase guardianPhase = GuardianPhase.off;
  DateTime? nextCheckIn;
  int checkInCountdown = 0;
  Timer? _guardianTick, _checkInTick, _uiTick;

  bool crashEnabled = false;
  bool crashPending = false;
  int crashCountdown = K.crashCancelSec;
  Timer? _crashTick;

  List<Contact> contacts = [];
  List<SosRecord> history = [];
  Map<String, dynamic>? latency;
  int battery = 100;
  bool charging = false;
  String network = 'unknown';
  bool bleBeaconActive = false;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    deviceId = prefs.getString(K.pDeviceId) ?? '';
    username = prefs.getString(K.pUsername) ?? '';
    phone = prefs.getString(K.pPhone) ?? '';
    if (deviceId.isEmpty) {
      phase = AppPhase.unregistered;
    } else {
      phase = AppPhase.home;
      _loadCaches();
      _syncDevice();
      _pingServer();
      if (prefs.getBool(K.pGuardianOn) ?? false) _startGuardian(silent: true);
    }
    notifyListeners();
  }

  Future<void> _syncDevice() async {
    await DeviceSvc.refresh();
    battery = DeviceSvc.battery;
    charging = DeviceSvc.charging;
    network = DeviceSvc.network;
    notifyListeners();
  }

  Future<void> _pingServer() async {
    online = await Api.ping();
    notifyListeners();
  }

  void _loadCaches() {
    Api.loadCachedContacts().then((v) { contacts = v; notifyListeners(); });
    Api.loadCachedHistory().then((v) { history = v; notifyListeners(); });
  }

  Future<void> register(String name, String ph) async {
    sendState = SendState.sending;
    sendMsg = 'Creating profile...';
    notifyListeners();
    try {
      final id = const Uuid().v4();
      await Api.register(username: name, deviceId: id, phone: ph);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(K.pDeviceId, id);
      await prefs.setString(K.pUsername, name);
      await prefs.setString(K.pPhone, ph);
      deviceId = id; username = name; phone = ph;
      phase = AppPhase.home; online = true;
      sendState = SendState.idle;
      _loadCaches(); _syncDevice();
    } catch (e) {
      sendState = SendState.failed;
      sendMsg = 'Failed: $e';
    }
    notifyListeners();
  }

  Future<void> sendSos(String type) async {
    if (sendState == SendState.sending) return;
    showFakeShutdown = true;
    sendState = SendState.sending;
    sendMsg = _sendingLabel(type);
    notifyListeners();

    // 1. Generate a unique ID for this specific SOS session
    final sessionId = 'SOS-${const Uuid().v4().substring(0, 8).toUpperCase()}';
    
    // 2. Pre-calculate the audio URL for the contacts
    final audioUrl = '${K.baseUrl}/recordings/$sessionId.m4a';

    // 3. Start recording using this ID
    AudioRecordSvc.startEmergencyRecording(sessionId);

    final t0 = DateTime.now().millisecondsSinceEpoch;
    Position? pos = await LocationSvc.get();
    lastPos = pos;
    final lat = pos?.latitude ?? 0.0;
    final lon = pos?.longitude ?? 0.0;

    if (online || await Api.ping()) {
      try {
        // 4. Send SOS to server with the same session ID
        final res = await Api.sendSos(
          deviceId: deviceId,
          sessionId: sessionId,
          sosType: type,
          lat: lat,
          lon: lon,
          battery: battery,
          t0Ms: t0,
        );
        sendState = SendState.done;
        sendMsg = res['message'] ?? 'SOS Sent';
      } catch (e) {
        sendState = SendState.failed;
      }
    }

    // 5. Send SMS with the Audio Link to all contacts
    if (contacts.isNotEmpty) {
      SmsSvc.sendToAll(
        contacts,
        lat: lat,
        lon: lon,
        sosType: type,
        username: username,
        audioUrl: audioUrl,
      );
    }
    notifyListeners();
  }

  void stopFakeShutdown() { showFakeShutdown = false; sendState = SendState.idle; notifyListeners(); }

  void toggleGuardian() => guardianPhase == GuardianPhase.off ? _startGuardian() : _stopGuardian();

  void _startGuardian({bool silent = false}) {
    guardianPhase = GuardianPhase.ticking;
    nextCheckIn = DateTime.now().add(Duration(minutes: K.guardianIntervalMin));
    _guardianTick?.cancel();
    _guardianTick = Timer.periodic(Duration(minutes: K.guardianIntervalMin), (_) => _beginCheckIn());
    _uiTick?.cancel();
    _uiTick = Timer.periodic(const Duration(seconds: 1), (_) => notifyListeners());
    if (!silent) sendMsg = 'Guardian On';
    notifyListeners();
  }

  void _stopGuardian() {
    _guardianTick?.cancel(); _checkInTick?.cancel(); guardianPhase = GuardianPhase.off;
    notifyListeners();
  }

  void _beginCheckIn() {
    guardianPhase = GuardianPhase.awaitingCheckin;
    checkInCountdown = K.guardianWindowSec;
    _checkInTick = Timer.periodic(const Duration(seconds: 1), (t) {
      if (checkInCountdown-- <= 0) { t.cancel(); sendSos('guardian'); }
      notifyListeners();
    });
  }

  void confirmCheckIn() { _checkInTick?.cancel(); guardianPhase = GuardianPhase.ticking; notifyListeners(); }

  void onCrashSignal() {
    if (crashPending || !crashEnabled) return;
    crashPending = true;
    crashCountdown = K.crashCancelSec;
    _crashTick = Timer.periodic(const Duration(seconds: 1), (t) {
      if (crashCountdown-- <= 0) { t.cancel(); crashPending = false; sendSos('crash'); }
      notifyListeners();
    });
  }

  void cancelCrash() { _crashTick?.cancel(); crashPending = false; notifyListeners(); }
  void setCrashEnabled(bool v) { crashEnabled = v; notifyListeners(); }
  Duration get timeToNextCheckIn => nextCheckIn?.difference(DateTime.now()) ?? Duration.zero;

  // Additional required methods
  Future<void> loadContacts() async { contacts = await Api.fetchContacts(deviceId); notifyListeners(); }
  Future<void> removeContact(String id) async { await Api.deleteContact(id); contacts.removeWhere((c) => c.id == id); notifyListeners(); }
  Future<String?> addContact(String n, String p, String? r) async {
    final c = await Api.addContact(deviceId: deviceId, name: n, phone: p, relationship: r);
    contacts.add(c); notifyListeners(); return null;
  }
  Future<void> refreshHistory() async { history = await Api.fetchHistory(deviceId); notifyListeners(); }
  Future<void> refreshLatency() async { latency = await Api.fetchLatency(deviceId); notifyListeners(); }
  Future<void> refreshServer() async { online = await Api.ping(); notifyListeners(); }
  Future<void> resetAll() async {
    final p = await SharedPreferences.getInstance(); await p.clear();
    phase = AppPhase.unregistered; notifyListeners();
  }

  String _sendingLabel(String t) => "Sending $t SOS...";
}
import 'dart:async';
import 'dart:convert';
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
import '../utils/constants.dart';

// ── Enums ─────────────────────────────────────────────────────────────────────

enum AppPhase { boot, unregistered, home }

enum SendState { idle, sending, done, failed }

enum GuardianPhase { off, ticking, awaitingCheckin }

// ── State class ───────────────────────────────────────────────────────────────

class AppState extends ChangeNotifier {
  // ── Identity ────────────────────────────────────────────────────────────────
  AppPhase phase     = AppPhase.boot;
  String   deviceId  = '';
  String   username  = '';
  String   phone     = '';

  // ── Server ──────────────────────────────────────────────────────────────────
  bool   online      = false;

  // ── SOS ─────────────────────────────────────────────────────────────────────
  SendState  sendState = SendState.idle;
  String     sendMsg   = '';
  Position?  lastPos;
  SosRecord? lastSos;

  // ── Guardian ─────────────────────────────────────────────────────────────────
  GuardianPhase guardianPhase   = GuardianPhase.off;
  DateTime?     nextCheckIn;
  int           checkInCountdown = 0;         // seconds remaining in window
  Timer?        _guardianTick;
  Timer?        _checkInTick;
  Timer?        _uiTick;

  // ── Crash detection ──────────────────────────────────────────────────────────
  bool   crashEnabled  = false;
  bool   crashPending  = false;
  int    crashCountdown = K.crashCancelSec;
  Timer? _crashTick;

  // ── Data ─────────────────────────────────────────────────────────────────────
  List<Contact>   contacts = [];
  List<SosRecord> history  = [];
  Map<String, dynamic>? latency;

  // ── Device ───────────────────────────────────────────────────────────────────
  int    battery  = 100;
  bool   charging = false;
  String network  = 'unknown';

  // ── BLE ──────────────────────────────────────────────────────────────────────
  bool bleBeaconActive = false;

  // ─────────────────────────────────────────────────────────────────────────────
  // INIT
  // ─────────────────────────────────────────────────────────────────────────────

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    deviceId = prefs.getString(K.pDeviceId) ?? '';
    username = prefs.getString(K.pUsername) ?? '';
    phone    = prefs.getString(K.pPhone)    ?? '';

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
    battery  = DeviceSvc.battery;
    charging = DeviceSvc.charging;
    network  = DeviceSvc.network;
    notifyListeners();
  }

  Future<void> _pingServer() async {
    online = await Api.ping();
    notifyListeners();
  }

  void _loadCaches() {
    Api.loadCachedContacts().then((v) { contacts = v; notifyListeners(); });
    Api.loadCachedHistory().then((v)  { history  = v; notifyListeners(); });
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // REGISTRATION
  // ─────────────────────────────────────────────────────────────────────────────

  Future<void> register(String name, String ph) async {
    sendState = SendState.sending;
    sendMsg   = 'Creating your profile…';
    notifyListeners();

    try {
      final id = const Uuid().v4();
      await Api.register(username: name, deviceId: id, phone: ph);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(K.pDeviceId, id);
      await prefs.setString(K.pUsername, name);
      await prefs.setString(K.pPhone, ph);

      deviceId  = id;
      username  = name;
      phone     = ph;
      phase     = AppPhase.home;
      online    = true;
      sendState = SendState.idle;
      sendMsg   = '';

      _loadCaches();
      _syncDevice();
    } catch (e) {
      sendState = SendState.failed;
      sendMsg   = 'Registration failed: $e\n\nIs the server running?';
    }
    notifyListeners();
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // SOS
  // ─────────────────────────────────────────────────────────────────────────────

  Future<void> sendSos(String type) async {
    if (sendState == SendState.sending) return;
    sendState = SendState.sending;
    sendMsg   = _sendingLabel(type);
    notifyListeners();

    final t0 = DateTime.now().millisecondsSinceEpoch;
    await _syncDevice();

    Position? pos = await LocationSvc.get();
    lastPos = pos;
    final lat = pos?.latitude  ?? 0.0;
    final lon = pos?.longitude ?? 0.0;

    // Start BLE beacon if SOS is sent
    if (!bleBeaconActive) {
      bleBeaconActive = true;
      await DeviceSvc.startBleBeacon(username);
      // Auto-stop beacon after 60 s (Kotlin side already limits to 60s)
      Future<void>.delayed(const Duration(seconds: 65))
          .then((_) { bleBeaconActive = false; notifyListeners(); });
    }

    Map<String, dynamic>? result;
    String? errMsg;

    // ── Try server ─────────────────────────────────────────────────────────
    if (online || await Api.ping()) {
      online = true;
      try {
        result = await Api.sendSos(
          deviceId: deviceId,
          sosType:  type,
          lat:      lat,
          lon:      lon,
          battery:  battery,
          t0Ms:     t0,
        );
      } catch (e) {
        errMsg = e.toString();
      }
    } else {
      errMsg = 'Server unreachable';
    }

    // ── SMS fallback (always fires if contacts exist) ───────────────────────
    if (contacts.isNotEmpty) {
      SmsSvc.sendToAll(
        contacts,
        lat:      lat,
        lon:      lon,
        sosType:  type,
        username: username,
      );
    }

    if (result != null) {
      final rec = SosRecord.fromJson({
        'session_id': result['session_id'],
        'sos_type':   type,
        'status':     'active',
        'latitude':   lat,
        'longitude':  lon,
        'battery':    battery,
        'message':    result['message'],
        'created_at': DateTime.now().toIso8601String(),
        'net_ms':     result['latency']?['network_ms'],
        'e2e_ms':     result['latency']?['e2e_ms'],
      });
      lastSos = rec;
      history.insert(0, rec);
      if (history.length > 50) history.removeLast();
      Api.cacheHistory(history);

      await NotifSvc.sosSent(rec.sessionId);
      sendState = SendState.done;
      sendMsg   = result['message'] as String? ?? '🆘 SOS sent.';
    } else {
      sendState = SendState.failed;
      sendMsg   = '⚠️ Server unreachable — SMS sent to ${contacts.length} contact(s).\n$errMsg';
    }

    notifyListeners();

    // Reset after 5 s
    Timer(const Duration(seconds: 5), () {
      sendState = SendState.idle;
      notifyListeners();
    });
  }

  String _sendingLabel(String t) => switch (t) {
        'crash'    => '🚗 Crash detected — sending SOS…',
        'guardian' => '⏰ No check-in — sending guardian SOS…',
        'fall'     => '🏔️ Fall detected — sending SOS…',
        _          => '🆘 Sending emergency SOS…',
      };

  // ─────────────────────────────────────────────────────────────────────────────
  // GUARDIAN MODE
  // ─────────────────────────────────────────────────────────────────────────────

  Future<void> toggleGuardian() async {
    if (guardianPhase == GuardianPhase.off) {
      _startGuardian();
    } else {
      _stopGuardian();
    }
  }

  void _startGuardian({bool silent = false}) {
    guardianPhase = GuardianPhase.ticking;
    _rescheduleNext();

    _guardianTick?.cancel();
    _guardianTick = Timer.periodic(
      Duration(minutes: K.guardianIntervalMin),
      (_) => _beginCheckIn(),
    );

    _uiTick?.cancel();
    _uiTick = Timer.periodic(const Duration(seconds: 1), (_) => notifyListeners());

    SharedPreferences.getInstance()
        .then((p) => p.setBool(K.pGuardianOn, true));

    if (!silent) {
      sendMsg = '🛡️ Guardian on — check-in every ${K.guardianIntervalMin} min';
      notifyListeners();
    }

    NotifSvc.guardianActive(K.guardianIntervalMin);
  }

  void _stopGuardian() {
    _guardianTick?.cancel();
    _checkInTick?.cancel();
    _uiTick?.cancel();
    NotifSvc.cancel(K.notifGuardian);

    guardianPhase   = GuardianPhase.off;
    checkInCountdown = 0;
    nextCheckIn      = null;
    sendMsg          = '🛡️ Guardian off';

    SharedPreferences.getInstance()
        .then((p) => p.setBool(K.pGuardianOn, false));
    notifyListeners();
  }

  void _rescheduleNext() {
    nextCheckIn = DateTime.now().add(Duration(minutes: K.guardianIntervalMin));
  }

  void _beginCheckIn() {
    guardianPhase    = GuardianPhase.awaitingCheckin;
    checkInCountdown = K.guardianWindowSec;
    notifyListeners();
    NotifSvc.guardianCheckIn(checkInCountdown);

    _checkInTick?.cancel();
    _checkInTick = Timer.periodic(const Duration(seconds: 1), (t) {
      checkInCountdown--;
      if (checkInCountdown % 60 == 0 && checkInCountdown > 0) {
        NotifSvc.guardianCheckIn(checkInCountdown);
      }
      notifyListeners();
      if (checkInCountdown <= 0) {
        t.cancel();
        _autoSos();
      }
    });
  }

  void confirmCheckIn() {
    _checkInTick?.cancel();
    NotifSvc.cancel(K.notifGuardian);
    guardianPhase    = GuardianPhase.ticking;
    checkInCountdown = 0;
    _rescheduleNext();
    sendMsg = '✅ Check-in confirmed — stay safe!';
    NotifSvc.guardianActive(K.guardianIntervalMin);
    notifyListeners();
  }

  Future<void> _autoSos() async {
    guardianPhase = GuardianPhase.ticking;
    _rescheduleNext();
    await sendSos('guardian');
  }

  Duration get timeToNextCheckIn {
    if (nextCheckIn == null) return Duration.zero;
    final d = nextCheckIn!.difference(DateTime.now());
    return d.isNegative ? Duration.zero : d;
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // CRASH DETECTION (called from CrashNotifier)
  // ─────────────────────────────────────────────────────────────────────────────

  void onCrashSignal() {
    if (crashPending || !crashEnabled) return;
    crashPending   = true;
    crashCountdown = K.crashCancelSec;
    notifyListeners();
    NotifSvc.crashWarning(crashCountdown);

    _crashTick?.cancel();
    _crashTick = Timer.periodic(const Duration(seconds: 1), (t) {
      crashCountdown--;
      if (crashCountdown % 3 == 0 && crashCountdown > 0) {
        NotifSvc.crashWarning(crashCountdown);
      }
      notifyListeners();
      if (crashCountdown <= 0) {
        t.cancel();
        crashPending = false;
        sendSos('crash');
      }
    });
  }

  void cancelCrash() {
    _crashTick?.cancel();
    NotifSvc.cancel(K.notifCrash);
    crashPending   = false;
    crashCountdown = K.crashCancelSec;
    sendMsg        = "✅ Crash SOS cancelled — glad you're okay!";
    notifyListeners();
    Timer(const Duration(seconds: 3), () { sendMsg = ''; notifyListeners(); });
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // CONTACTS
  // ─────────────────────────────────────────────────────────────────────────────

  Future<void> loadContacts() async {
    if (deviceId.isEmpty) return;
    try {
      contacts = await Api.fetchContacts(deviceId);
      await Api.cacheContacts(contacts);
      notifyListeners();
    } catch (_) {
      contacts = await Api.loadCachedContacts();
      notifyListeners();
    }
  }

  Future<String?> addContact(String name, String phone, String? rel) async {
    try {
      final c = await Api.addContact(
        deviceId:     deviceId,
        name:         name,
        phone:        phone,
        relationship: rel,
      );
      contacts.add(c);
      await Api.cacheContacts(contacts);
      notifyListeners();
      return null; // null = success
    } catch (e) {
      return e.toString();
    }
  }

  Future<void> removeContact(String id) async {
    try {
      await Api.deleteContact(id);
    } catch (_) {}
    contacts.removeWhere((c) => c.id == id);
    await Api.cacheContacts(contacts);
    notifyListeners();
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // HISTORY & LATENCY
  // ─────────────────────────────────────────────────────────────────────────────

  Future<void> refreshHistory() async {
    if (deviceId.isEmpty) return;
    try {
      history = await Api.fetchHistory(deviceId);
      await Api.cacheHistory(history);
    } catch (_) {
      history = await Api.loadCachedHistory();
    }
    notifyListeners();
  }

  Future<void> refreshLatency() async {
    if (deviceId.isEmpty) return;
    latency = await Api.fetchLatency(deviceId);
    notifyListeners();
  }

  Future<void> refreshServer() async {
    online = await Api.ping();
    await _syncDevice();
    notifyListeners();
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // MISC
  // ─────────────────────────────────────────────────────────────────────────────

  void setCrashEnabled(bool v) {
    crashEnabled = v;
    notifyListeners();
  }

  Future<void> resetAll() async {
    _stopGuardian();
    _crashTick?.cancel();
    await NotifSvc.cancelAll();
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    deviceId  = '';
    username  = '';
    phone     = '';
    contacts  = [];
    history   = [];
    phase     = AppPhase.unregistered;
    sendState = SendState.idle;
    notifyListeners();
  }

  @override
  void dispose() {
    _guardianTick?.cancel();
    _checkInTick?.cancel();
    _crashTick?.cancel();
    _uiTick?.cancel();
    super.dispose();
  }
}

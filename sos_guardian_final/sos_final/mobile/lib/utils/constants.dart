// lib/utils/constants.dart

class K {
  // ── Server ─────────────────────────────────────────────────────────────────
  // Change this to your PC's local IP or use 10.0.2.2 for Android Emulator.
  static const String baseUrl = 'http://10.0.2.2:8000';

  // ── Guardian Mode ──────────────────────────────────────────────────────────
  static const int guardianIntervalMin   = 30;   // check-in every N minutes
  static const int guardianWindowSec     = 300;  // 5-min cancel window

  // ── Crash Detection ────────────────────────────────────────────────────────
  static const double crashThreshold     = 30.0; // m/s² spike magnitude
  static const double crashDeltaMin      = 20.0; // min Δ from previous sample
  static const int    crashCancelSec     = 10;   // cancel window in seconds

  // ── BLE ────────────────────────────────────────────────────────────────────
  static const String bleServiceUuid = '0000FF00-0000-1000-8000-00805F9B34FB';
  static const String bleChannel     = 'com.sosguardian.app/device';

  // ── Notification IDs ───────────────────────────────────────────────────────
  static const int notifGuardian = 2001;
  static const int notifSos      = 2002;
  static const int notifCrash    = 2003;

  // ── Notification channels ──────────────────────────────────────────────────
  static const String chGuardian = 'guardian_ch';
  static const String chSos      = 'sos_ch';
  static const String chCrash    = 'crash_ch';

  // ── SharedPreferences keys ─────────────────────────────────────────────────
  static const String pDeviceId   = 'device_id';
  static const String pUsername   = 'username';
  static const String pPhone      = 'phone';
  static const String pContacts   = 'contacts_json';
  static const String pHistory    = 'history_json';
  static const String pGuardianOn = 'guardian_on';
}

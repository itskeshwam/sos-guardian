# 🆘 SOS Guardian v3

End-to-end emergency alert system — Flutter + FastAPI + PostgreSQL.

---

## What's in this project

```
sos_final/
├── backend/               FastAPI server
│   ├── main.py            All API endpoints
│   ├── models.py          Database models
│   ├── schemas.py         Request/response shapes
│   ├── database.py        SQLAlchemy + PostgreSQL
│   ├── setup_db.py        One-click DB setup script
│   ├── latency_test.py    Academic benchmark tool
│   ├── requirements.txt
│   └── .env               DB URL + host/port config
│
└── mobile/                Flutter Android app
    ├── lib/
    │   ├── main.dart
    │   ├── utils/          constants.dart, theme.dart
    │   ├── models/         contact.dart, sos_record.dart
    │   ├── services/       api.dart, notif_svc.dart, sms_svc.dart,
    │   │                   location_svc.dart, device_svc.dart
    │   ├── providers/      app_state.dart, crash_notifier.dart
    │   └── screens/        home, guardian, contacts, history, settings
    └── android/
        ├── app/
        │   ├── build.gradle
        │   └── src/main/
        │       ├── AndroidManifest.xml
        │       ├── kotlin/.../MainActivity.kt
        │       └── res/              icons, splash, styles
        ├── build.gradle
        ├── settings.gradle
        └── gradle.properties
```

---

## ① Backend Setup (your PC)

### Prerequisites
- Python 3.10+
- PostgreSQL installed and running

### Step 1 — Install dependencies

```bash
cd backend
pip install -r requirements.txt
```

### Step 2 — Create database & tables (run once)

```bash
python setup_db.py --user postgres --password YOUR_POSTGRES_PASSWORD
```

This creates the `sos_guardian` database, writes `.env`, and creates all tables.

**If your Postgres uses a different password:**
```bash
python setup_db.py --user postgres --password mypassword --host localhost --port 5432
```

### Step 3 — Start the server

```bash
python main.py
```

Or with auto-reload for development:
```bash
uvicorn main:app --host 0.0.0.0 --port 8000 --reload
```

**API docs (auto-generated):** `http://localhost:8000/docs`

**Verify it's working:**
```bash
curl http://localhost:8000/
# Expected: {"status":"ok","service":"SOS Guardian","version":"3.0.0"}
```

---

## ② Flutter App Setup (your phone)

### Prerequisites
- Flutter 3.x installed
- Android phone with USB Debugging enabled
- Phone on the **same Wi-Fi** as your PC

### Step 1 — Set your PC's local IP

Edit `mobile/lib/utils/constants.dart`, line 5:

```dart
static const String baseUrl = 'http://192.168.1.5:8000';
//                                   ↑ your PC's IP
```

Your IP is `192.168.1.5` — already set.

**To verify your IP:**
- Windows: `ipconfig` → look for "IPv4 Address" under Wi-Fi
- Mac/Linux: `ifconfig` → look for `inet` under `en0` or `wlan0`

### Step 2 — Enable Developer Mode on Android

1. **Settings → About Phone**
2. Tap **Build Number** 7 times
3. Go back → **Developer Options** → enable **USB Debugging**
4. Connect phone via USB and accept the "Allow USB debugging?" prompt

### Step 3 — Install and run

```bash
cd mobile
flutter pub get
flutter run
```

The app will install and launch on your phone.

**Build a release APK (to share or sideload):**
```bash
flutter build apk --release
# APK at: build/app/outputs/flutter-apk/app-release.apk
```

---

## ③ How to use

### First launch
1. App shows the **Register** screen
2. Enter your name + phone number → tap **CREATE PROFILE**
3. Grant location and notification permissions when prompted

### SOS
- Tap the big red button on the home screen
- SOS is sent to the server + SMS to all your emergency contacts

### Emergency Contacts
- Go to **Contacts** tab → tap **+**
- Enter name, phone number, relationship
- On SOS trigger, all contacts get an SMS with your GPS Google Maps link

### Guardian Mode
- Go to **Guardian** tab → tap **ENABLE GUARDIAN**
- Every 30 minutes you'll get an alert: "Check In"
- Tap **"I'M SAFE"** to reset the timer
- If you miss the 5-minute window → SOS fires automatically
- Perfect for: solo treks, late-night drives, camping

### Crash Detection
- Enable via **Settings** or the quick-action button on Home
- If the accelerometer detects a sudden spike (>30 m/s²), a 10-second countdown starts
- Tap **"CANCEL — I'M OKAY"** to abort
- Otherwise SOS fires automatically

### BLE Beacon
- Automatically activates for 60 seconds whenever any SOS is sent
- Broadcasts a BLE advertisement with UUID `0000FF00-0000-1000-8000-00805F9B34FB`
- Nearby devices with BLE scanning can detect an SOS in progress even without internet

---

## ④ Latency Benchmark (for academic/research use)

### What it measures

| Timestamp | Captured at | Meaning |
|-----------|-------------|---------|
| **T0** | Flutter button tap | `DateTime.now().millisecondsSinceEpoch` |
| **T1** | FastAPI handler start | `int(time.time() * 1000)` |
| **T2** | After `db.commit()` | `int(time.time() * 1000)` |

| Metric | Formula | What it shows |
|--------|---------|---------------|
| Network latency | T1 − T0 | Time for data to travel phone → server |
| Processing latency | T2 − T1 | Time to decrypt, store, commit to DB |
| Total E2E | T2 − T0 | Button press → securely stored |

### Run the tests

**Condition A — Wi-Fi (home/office):**
```bash
python latency_test.py --label WiFi --runs 20
```

**Condition B — 4G LTE (mobile hotspot):**
```bash
python latency_test.py --label 4G-LTE --runs 20
```

**Condition C — 5G:**
```bash
python latency_test.py --label 5G --runs 20
```

**Stress test — 100 concurrent requests:**
```bash
python latency_test.py --stress 100
```

**Point at a remote server:**
```bash
python latency_test.py --url http://YOUR_SERVER_IP:8000 --label WiFi
```

### Sample output
```
==============================================================
  Condition: WiFi   |   Runs: 20
==============================================================
  01 ✓  Net=11ms  Proc=2ms  E2E=13ms  312B
  02 ✓  Net=9ms   Proc=2ms  E2E=11ms  312B
  ...
  ┌─ RESULTS (WiFi) ──────────────────────────────────────┐
  │  Network Latency  (T1−T0)     avg=10.4ms  min=7ms  max=18ms
  │  Processing       (T2−T1)     avg=2.1ms   min=1ms  max=5ms
  │  Total E2E        (T2−T0)     avg=12.5ms  min=8ms  max=22ms
  │  Payload Size                 avg=312B  (0.30 KB)
  │  Samples                      20/20
  └───────────────────────────────────────────────────────┘
```

---

## ⑤ API Reference

| Method | Endpoint | Description |
|--------|----------|-------------|
| `GET`  | `/` | Health check |
| `POST` | `/v1/register` | Register a new device/user |
| `POST` | `/v1/sos` | Send SOS event (returns T1, T2, latency) |
| `PATCH`| `/v1/sos/{id}/resolve` | Mark SOS as resolved |
| `GET`  | `/v1/history/{device_id}` | List past SOS events |
| `POST` | `/v1/contacts` | Add emergency contact |
| `GET`  | `/v1/contacts/{device_id}` | List contacts |
| `DELETE`| `/v1/contacts/{id}` | Remove contact |
| `GET`  | `/v1/latency/{device_id}` | Aggregated latency stats |
| `GET`  | `/v1/stress?n=100` | Simulate N concurrent requests |

Full interactive docs: `http://localhost:8000/docs`

---

## ⑥ Troubleshooting

**"Device not registered" when sending SOS**
→ The registration API call failed. Check the server is running and reachable. Tap the Ping button in Settings.

**App crashes / black screen on launch**
→ Run `flutter clean && flutter pub get && flutter run` to force a clean build.

**"Out of memory" / app killed immediately**
→ This was caused by `flutter_background_service` in older versions. This build does **not** use it. If you see this, you're running an old APK — rebuild.

**Location shows 0.0, 0.0**
→ Location permission was denied. Go to Android Settings → Apps → SOS Guardian → Permissions → Location → Allow.

**SMS doesn't send automatically**
→ The SMS fallback opens your phone's SMS app pre-filled. You need to tap Send. This is by design (Android 6+ restricts silent SMS sending).

**Server not reachable from phone**
→ Check both devices are on the same Wi-Fi. Try `curl http://192.168.1.5:8000/` from your phone browser. Check Windows Firewall allows port 8000: `netsh advfirewall firewall add rule name="SOS Guardian" protocol=TCP dir=in localport=8000 action=allow`

**BLE beacon not starting**
→ Grant Bluetooth permission in Android Settings → Apps → SOS Guardian → Permissions → Nearby devices.

---

## ⑦ Architecture

```
Flutter App
  │
  ├── AppState (ChangeNotifier)
  │     ├── Guardian timer (Timer.periodic — no background service)
  │     ├── Crash detection (accelerometer stream)
  │     └── SOS flow (GPS → POST /v1/sos → SMS fallback)
  │
  ├── CrashNotifier (ChangeNotifier)
  │     └── sensors_plus accelerometer stream
  │
  └── DeviceSvc (MethodChannel → Kotlin)
        ├── getBatteryLevel()
        ├── isCharging()
        ├── getNetworkType()
        ├── startBleAdvert()   → BluetoothLeAdvertiser
        └── stopBleAdvert()
```

**Why no `flutter_background_service`?**
It spawns a second full Dart VM isolate at startup, which doubles heap usage.
On a 2-3 GB RAM device, the main isolate + background isolate hit the per-process memory limit and Android kills the app. The guardian timer works perfectly as a foreground `Timer.periodic` — it survives as long as the screen is on or the app is in the foreground, which covers 99% of real use cases (trekking with phone in pocket, screen occasionally on).

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'package:cryptography/cryptography.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'background_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeService();
  runApp(const AiSosGuardianApp());
}

class AiSosGuardianApp extends StatelessWidget {
  const AiSosGuardianApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AI SOS Guardian',
      theme: ThemeData(
        primarySwatch: Colors.red,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.grey[900],
      ),
      home: const SosScreen(),
    );
  }
}

class SosScreen extends StatefulWidget {
  const SosScreen({super.key});
  @override
  State<SosScreen> createState() => _SosScreenState();
}

class _SosScreenState extends State<SosScreen> with WidgetsBindingObserver {
  final String backendUrl = 'http://10.0.2.2:8000';
  final String trustedContactNumber = '+919999900000';

  String _statusMessage = "Initializing...";
  bool _isRegistered = false;
  bool _isMonitoring = false;
  SimpleKeyPair? _identityKeyPair;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPermissions();
    _initializeIdentity();
  }

  Future<void> _checkPermissions() async {
    await [
      Permission.notification,
      Permission.location,
      Permission.locationAlways,
      Permission.ignoreBatteryOptimizations,
    ].request();
  }

  Future<void> _initializeIdentity() async {
    final prefs = await SharedPreferences.getInstance();
    final algorithm = X25519();

    if (prefs.containsKey('private_key_bytes')) {
      final privateBytes = base64Decode(prefs.getString('private_key_bytes')!);
      _identityKeyPair = await algorithm.newKeyPairFromSeed(privateBytes);
      setState(() {
        _isRegistered = prefs.getBool('is_registered') ?? false;
        _statusMessage = _isRegistered ? "Armed & Ready" : "Registering...";
      });
      if (!_isRegistered) _registerUser();
    } else {
      _identityKeyPair = await algorithm.newKeyPair();
      final privateBytes = await _identityKeyPair!.extractPrivateKeyBytes();
      await prefs.setString('private_key_bytes', base64Encode(privateBytes));
      setState(() => _statusMessage = "Keys Generated. Registering...");
      _registerUser();
    }
  }

  Future<void> _registerUser() async {
    if (_identityKeyPair == null) return;
    try {
      final publicKey = await _identityKeyPair!.extractPublicKey();
      final String pubKeyString = base64UrlEncode(publicKey.bytes);
      final username = "user_${DateTime.now().millisecondsSinceEpoch}";

      final response = await http.post(
        Uri.parse('$backendUrl/v1/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "username": username,
          "device_id": "android_id_${publicKey.bytes.first}",
          "identity_key_pub": pubKeyString
        }),
      );

      if (response.statusCode == 201) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('is_registered', true);
        setState(() {
          _isRegistered = true;
          _statusMessage = "System Online. (User: $username)";
        });
      }
    } catch (e) {
      setState(() => _statusMessage = "Connection Error: $e");
    }
  }

  Future<void> _toggleMonitoring(bool value) async {
    final service = FlutterBackgroundService();
    if (value) {
      if (await service.startService()) {
        setState(() => _isMonitoring = true);
        _showSnackBar("Guardian Mode Activated");
      }
    } else {
      service.invoke("stopService");
      setState(() => _isMonitoring = false);
      _showSnackBar("Guardian Mode Deactivated");
    }
  }

  Future<void> _onSosPressed() async {
    setState(() => _statusMessage = "Accessing GPS...");
    final pos = await _getCurrentLocation();

    if (pos == null) {
      _triggerFallback("GPS Failed");
      return;
    }

    setState(() => _statusMessage = "Encrypting Payload...");
    final success = await _sendSecureApiAlert(pos);

    if (!success) {
      _triggerFallback("API Unreachable");
    } else {
      setState(() => _statusMessage = "SOS SENT SUCCESSFULLY");
    }
  }

  Future<Position?> _getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return null;

    try {
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 5),
      );
    } catch (e) {
      return await Geolocator.getLastKnownPosition();
    }
  }

  Future<bool> _sendSecureApiAlert(Position pos) async {
    final payload = jsonEncode({
      "lat": pos.latitude,
      "lon": pos.longitude,
      "message": "Emergency! Immediate assistance required.",
      "timestamp": DateTime.now().toIso8601String()
    });

    try {
      final response = await http.post(
        Uri.parse('$backendUrl/v1/sos/init'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'creator_device_id': 'android_id',
          'encrypted_session_blob': base64Encode(utf8.encode(payload)),
        }),
      ).timeout(const Duration(seconds: 5));
      return response.statusCode == 201;
    } catch (e) {
      return false;
    }
  }

  Future<void> _triggerFallback(String reason) async {
    final Uri smsUri = Uri(
      scheme: 'sms',
      path: trustedContactNumber,
      queryParameters: {'body': 'SOS! I need help. System failed: $reason.'},
    );
    if (await canLaunchUrl(smsUri)) await launchUrl(smsUri);
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI SOS Guardian'), backgroundColor: Colors.red[900]),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            GestureDetector(
              onLongPress: _onSosPressed,
              child: Container(
                width: 220, height: 220,
                decoration: BoxDecoration(
                  color: Colors.red[700],
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: Colors.redAccent.withOpacity(0.4), blurRadius: 20, spreadRadius: 5)],
                ),
                alignment: Alignment.center,
                child: const Text('SOS', style: TextStyle(color: Colors.white, fontSize: 44, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 40),
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                  color: Colors.black45,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _isMonitoring ? Colors.green : Colors.grey)
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_isMonitoring ? "Guardian Mode ON " : "Guardian Mode OFF",
                      style: TextStyle(color: _isMonitoring ? Colors.greenAccent : Colors.grey, fontSize: 16)),
                  const SizedBox(width: 10),
                  Switch(
                    value: _isMonitoring,
                    onChanged: (val) => _toggleMonitoring(val),
                    activeColor: Colors.greenAccent,
                    inactiveTrackColor: Colors.grey,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text(_statusMessage, style: const TextStyle(color: Colors.white70)),
          ],
        ),
      ),
    );
  }
}
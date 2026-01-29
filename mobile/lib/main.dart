import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'package:cryptography/cryptography.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() => runApp(const AiSosGuardianApp());

class AiSosGuardianApp extends StatelessWidget {
  const AiSosGuardianApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AI SOS Guardian',
      theme: ThemeData(primarySwatch: Colors.red),
      home: const SosScreen(),
    );
  }
}

class SosScreen extends StatefulWidget {
  const SosScreen({super.key});
  @override
  State<SosScreen> createState() => _SosScreenState();
}

class _SosScreenState extends State<SosScreen> {
  // CONFIGURATION
  // ANDROID EMULATOR: Use 10.0.2.2
  // PHYSICAL DEVICE: Use your PC's LAN IP (e.g., 192.168.1.5)
  final String backendUrl = 'http://10.0.2.2:8000';
  final String trustedContactNumber = '+919999900000';

  String _statusMessage = "Initializing...";
  bool _isRegistered = false;
  SimpleKeyPair? _identityKeyPair;

  @override
  void initState() {
    super.initState();
    _initializeIdentity();
  }

  // 1. IDENTITY MANAGEMENT
  Future<void> _initializeIdentity() async {
    final prefs = await SharedPreferences.getInstance();
    final algorithm = X25519();

    // Check if we already have a key
    if (prefs.containsKey('private_key_bytes')) {
      final privateBytes = base64Decode(prefs.getString('private_key_bytes')!);
      _identityKeyPair = await algorithm.newKeyPairFromSeed(privateBytes);
      setState(() {
        _isRegistered = prefs.getBool('is_registered') ?? false;
        _statusMessage = _isRegistered ? "Armed & Ready" : "Identity Created. Registering...";
      });

      if (!_isRegistered) _registerUser();
    } else {
      // Generate new key pair
      _identityKeyPair = await algorithm.newKeyPair();
      final privateBytes = await _identityKeyPair!.extractPrivateKeyBytes();
      await prefs.setString('private_key_bytes', base64Encode(privateBytes));

      setState(() => _statusMessage = "Keys Generated. Registering...");
      _registerUser();
    }
  }

  // 2. BACKEND REGISTRATION
  Future<void> _registerUser() async {
    if (_identityKeyPair == null) return;

    try {
      final publicKey = await _identityKeyPair!.extractPublicKey();
      final String pubKeyString = base64UrlEncode(publicKey.bytes); // URL Safe Base64

      // Generate a random username for MVP (In real app, ask user)
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
      } else {
        // If 400, it might be "username taken", retry logic would go here
        setState(() => _statusMessage = "Registration Failed: ${response.body}");
      }
    } catch (e) {
      setState(() => _statusMessage = "Connection Error: $e");
    }
  }

  // 3. SOS TRIGGER
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

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return null;
    }
    return await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
  }

  Future<bool> _sendSecureApiAlert(Position pos) async {
    try {
      // TODO: In Phase 3, we will encrypt this with the SERVER'S public key.
      // For now, we sign it or just encode it to prove the pipeline works.
      final payloadPlain = 'LAT:${pos.latitude},LON:${pos.longitude},TS:${DateTime.now()}';

      final response = await http.post(
        Uri.parse('$backendUrl/v1/sos/init'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'creator_device_id': 'android_id',
          'encrypted_session_blob': base64Encode(utf8.encode(payloadPlain)), // Placeholder for encryption
        }),
      ).timeout(const Duration(seconds: 5));

      return response.statusCode == 201;
    } catch (e) {
      debugPrint("API Fail: $e");
      return false;
    }
  }

  Future<void> _triggerFallback(String reason) async {
    setState(() => _statusMessage = "Fallback: SMS ($reason)");
    final Uri smsUri = Uri(
      scheme: 'sms',
      path: trustedContactNumber,
      queryParameters: {'body': 'SOS! I need help. My location is unknown.'},
    );
    if (await canLaunchUrl(smsUri)) await launchUrl(smsUri);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[900],
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
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              color: Colors.black54,
              child: Text(_statusMessage, style: const TextStyle(color: Colors.white70)),
            )
          ],
        ),
      ),
    );
  }
}
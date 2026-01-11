import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;

void main() => runApp(const AiSosGuardianApp());

class AiSosGuardianApp extends StatelessWidget {
  const AiSosGuardianApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AI SOS Guardian MVP',
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
  // Use 10.0.2.2 for Android Emulator to hit localhost
  final Uri sosApiUri = Uri.parse('http://10.0.2.2:8000/v1/sos/init');
  final String trustedContactNumber = '+919999900000';

  Future<Position?> _getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return null;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return null;
    }

    if (permission == LocationPermission.deniedForever) return null;

    return await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
  }

  Future<void> _triggerSos() async {
    _showSnackBar("Initiating SOS...");

    final position = await _getCurrentLocation();
    if (position == null) {
      _showSnackBar("Location error. Check GPS permissions.");
      return;
    }

    final success = await _sendApiAlert(position);
    if (!success) {
      await _triggerSmsFallback(position);
    }
  }

  Future<bool> _sendApiAlert(Position pos) async {
    try {
      final payload = {
        'creator_device_id': 'device-uuid-mock-123',
        'encrypted_session_blob': base64Encode(utf8.encode(
            'LAT:${pos.latitude},LON:${pos.longitude},TS:${DateTime.now()}')),
      };

      final response = await http.post(
        sosApiUri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 201) {
        _showSnackBar("SOS initiated via API.");
        return true;
      }
    } catch (e) {
      debugPrint("API Error: $e");
    }
    return false;
  }

  Future<void> _triggerSmsFallback(Position pos) async {
    final googleMapsUrl = 'https://www.google.com/maps?q=${pos.latitude},${pos.longitude}';
    final message = 'EMERGENCY! My location: $googleMapsUrl';

    final Uri smsUri = Uri(
      scheme: 'sms',
      path: trustedContactNumber,
      queryParameters: {'body': message},
    );

    if (await canLaunchUrl(smsUri)) {
      await launchUrl(smsUri);
      _showSnackBar("API failed. SMS fallback prepared.");
    } else {
      _showSnackBar("CRITICAL: SMS launch failed.");
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI SOS Guardian')),
      body: Center(
        child: GestureDetector(
          onLongPress: _triggerSos,
          child: Container(
            width: 220,
            height: 220,
            decoration: const BoxDecoration(
              color: Colors.red,
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10, spreadRadius: 2)],
            ),
            alignment: Alignment.center,
            child: const Text('SOS',
                style: TextStyle(color: Colors.white, fontSize: 44, fontWeight: FontWeight.bold)),
          ),
        ),
      ),
    );
  }
}
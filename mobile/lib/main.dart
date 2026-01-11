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
    return await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
  }

  Future<void> _onSosPressed() async {
    final pos = await _getCurrentLocation();
    if (pos == null) return;

    final success = await _sendApiAlert(pos);
    if (!success) await _fallbackSms(pos);
  }

  Future<bool> _sendApiAlert(Position pos) async {
    try {
      final payload = {
        'creator_device_id': 'mock-device-uuid',
        'encrypted_session_blob': base64Encode(utf8.encode('LAT:${pos.latitude},LON:${pos.longitude}')),
      };
      final response = await http.post(
        sosApiUri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 5));
      return response.statusCode == 201;
    } catch (_) {
      return false;
    }
  }

  Future<void> _fallbackSms(Position pos) async {
    final url = 'https://www.google.com/maps/search/?api=1&query=${pos.latitude},${pos.longitude}';
    final Uri smsUri = Uri(scheme: 'sms', path: trustedContactNumber, queryParameters: {'body': 'SOS! My location: $url'});
    if (await canLaunchUrl(smsUri)) await launchUrl(smsUri);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI SOS Guardian')),
      body: Center(
        child: GestureDetector(
          onLongPress: _onSosPressed,
          child: Container(
            width: 200, height: 200,
            decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: const Text('SOS', style: TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.bold)),
          ),
        ),
      ),
    );
  }
}
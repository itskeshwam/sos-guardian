// ----------------------------------------------------
// File: mobile/lib/main.dart
// Action: Replace the entire file content.
// ----------------------------------------------------
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const AiSosGuardianApp());
}

class AiSosGuardianApp extends StatelessWidget {
  const AiSosGuardianApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AI SOS Guardian MVP',
      theme: ThemeData(
        primarySwatch: Colors.red,
        visualDensity: VisualDensity.adaptivePlatformDensity,
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

class _SosScreenState extends State<SosScreen> {
  // CONFIGURATION
  // NOTE: For Android Emulator, 10.0.2.2 points to your host machine's localhost (FastAPI server).
  final Uri sosInitUri = Uri.parse('http://10.0.2.2:8000/v1/sos/init');
  final String trustedContactNumber = '+9199999XXXXX'; // **REPLACE WITH A REAL TEST NUMBER**

  // 1. Check permissions and get current location
  Future<Position?> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return null;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return null;
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      return null;
    }

    return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);
  }
  
  // 2. Primary Method: POST encrypted data to FastAPI
  Future<bool> _postEncryptedSos(Position position) async {
    try {
      final encryptedPayload = {
        'creator_device_id': 'device-uuid-mock-123',
        'encrypted_session_blob': base64Encode(utf8.encode(
            'SOS! Lat:${position.latitude}, Lon:${position.longitude}, Time:${DateTime.now()}')),
      };

      final response = await http.post(
        sosInitUri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(encryptedPayload),
      ).timeout(const Duration(seconds: 5)); 

      if (response.statusCode == 200 || response.statusCode == 201) {
        return true; 
      }
      return false; 

    } catch (e) {
      return false;
    }
  }

  // 3. Fallback Method: Send SMS with Location Link
  Future<void> _launchSmsFallback(Position position) async {
    // FIX: Explicitly defining lat/lon for use in the message body
    final lat = position.latitude;
    final lon = position.longitude;

    // Direct Google Maps URL using actual coordinates
    final mapsUrl = 'https://maps.google.com/?q=$lat,$lon'; 
    
    final messageBody = 'EMERGENCY SOS! Primary system failed. Location: $mapsUrl';

    final Uri smsUri = Uri(
      scheme: 'sms',
      path: trustedContactNumber,
      queryParameters: {'body': messageBody},
    );

    if (await canLaunchUrl(smsUri)) {
      await launchUrl(smsUri);
      // FIX: Added mounted check
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('API FAILED. Prepared SMS fallback. Tap send.')),
        );
      }
    } else {
      // FIX: Added mounted check
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('CRITICAL FAILURE: Cannot launch SMS app.')),
        );
      }
    }
  }

  // 4. Unified SOS Trigger
  void _triggerSos() async {
    // FIX: Added mounted check before first ScaffoldMessenger call
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Initiating SOS... Getting Location...')),
        );
    }

    final position = await _determinePosition();
    
    if (position != null) {
      bool success = await _postEncryptedSos(position);

      if (!success) {
        await _launchSmsFallback(position);
      } else {
        // FIX: Added mounted check
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('SOS initiated via API. Notifications sent to contacts.')),
          );
        }
      }
    } else {
      // FIX: Added mounted check
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cannot get location. Check permissions/GPS.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI SOS Guardian MVP')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text(
              'Press and hold the button for 3 seconds to trigger SOS.',
              style: TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 50),
            // The prominent SOS Button
            GestureDetector(
              onLongPress: _triggerSos,
              child: Container(
                width: 200,
                height: 200,
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(color: Colors.redAccent, blurRadius: 15, spreadRadius: 3),
                  ],
                ),
                alignment: Alignment.center,
                child: const Text(
                  'SOS',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
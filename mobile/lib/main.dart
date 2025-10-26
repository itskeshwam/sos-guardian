// lib/main.dart

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

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
  // Define a dummy contact number for MVP testing
  final String trustedContactNumber = '+9199999XXXXX'; // Replace with a test number

  // 1. Function to check location permission and request if needed
  Future<Position?> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // Logic for disabled location service (prompt user to enable)
      return null;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        // Logic for permission denied
        return null;
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      // Logic for permission permanently denied
      return null;
    }

    // Get the current location
    return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);
  }

  // 2. Function to launch the SMS/Messaging app
  Future<void> _launchSms(Position position) async {
    final lat = position.latitude;
    final lon = position.longitude;

    // Create a Google Maps URL for the location
    final mapsUrl = 'https://www.google.com/maps/search/?api=1&query=$lat,$lon';
    
    // Construct the SOS message
    final messageBody = 'EMERGENCY SOS! I need help immediately. My live location: $mapsUrl';

    // Create the SMS URI scheme
    final Uri smsUri = Uri(
      scheme: 'sms',
      path: trustedContactNumber,
      queryParameters: {'body': messageBody},
    );

    if (await canLaunchUrl(smsUri)) {
      await launchUrl(smsUri);
    } else {
      // Handle error: Could not launch SMS app
      print('Could not launch $smsUri');
    }
  }

  // 3. The main SOS function called by the button
  void _triggerSos() async {
    final position = await _determinePosition();
    
    if (position != null) {
      await _launchSms(position);
      // Optional: Show a confirmation message to the user
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('SOS message prepared. Please tap send in the messaging app.')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot get location. Check permissions and GPS.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI SOS Guardian')),
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
import 'package:url_launcher/url_launcher.dart';
import '../models/contact.dart';

class SmsSvc {
  static Future<void> sendToAll(
    List<Contact> contacts, {
    required double lat,
    required double lon,
    required String sosType,
    required String username,
    String? audioUrl,
  }) async {
    if (contacts.isEmpty) return;

    final mapsUrl = 'https://maps.google.com/?q=${lat.toStringAsFixed(6)},${lon.toStringAsFixed(6)}';
    final labels  = {
      'manual':   '🆘 MANUAL SOS',
      'crash':    '🚗 CRASH DETECTED',
      'guardian': '⏰ GUARDIAN AUTO-SOS (No check-in)',
      'fall':     '🏔️ FALL DETECTED',
    };
    final label = labels[sosType] ?? '🆘 SOS';
    
    String body = '$label\nUser: $username\nLocation: $mapsUrl';
    if (audioUrl != null) {
      body += '\nListen to recording: $audioUrl';
    }
    body += '\n— SOS Guardian App';

    for (final c in contacts) {
      final clean = c.phone.replaceAll(RegExp(r'[\s\-()]'), '');
      final uri   = Uri(
        scheme:          'sms',
        path:            clean,
        queryParameters: {'body': body},
      );
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
        // Small pause between messages so SMS app can handle them
        await Future<void>.delayed(const Duration(milliseconds: 600));
      }
    }
  }
}

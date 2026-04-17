import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/contact.dart';
import '../models/sos_record.dart';
import '../utils/constants.dart';

class Api {
  static const _timeout = Duration(seconds: 15);
  static String get base => K.baseUrl;

  // ── Helpers ────────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> body,
  ) async {
    final res = await http
        .post(
          Uri.parse('$base$path'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(body),
        )
        .timeout(_timeout);
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode >= 400) {
      throw HttpException(
          data['detail']?.toString() ?? 'Error ${res.statusCode}');
    }
    return data;
  }

  static Future<dynamic> _get(String path) async {
    final res = await http
        .get(Uri.parse('$base$path'))
        .timeout(_timeout);
    if (res.statusCode >= 400) throw HttpException('Error ${res.statusCode}');
    return jsonDecode(res.body);
  }

  static Future<void> _delete(String path) async {
    await http.delete(Uri.parse('$base$path')).timeout(_timeout);
  }

  // ── Health ─────────────────────────────────────────────────────────────────

  static Future<bool> ping() async {
    try {
      final res = await http
          .get(Uri.parse('$base/'))
          .timeout(const Duration(seconds: 5));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // ── Registration ───────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> register({
    required String username,
    required String deviceId,
    String? phone,
  }) =>
      _post('/v1/register', {
        'username':  username,
        'device_id': deviceId,
        if (phone != null && phone.isNotEmpty) 'phone': phone,
      });

  // ── SOS ────────────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> sendSos({
    required String deviceId,
    required String sosType,
    required double lat,
    required double lon,
    int? battery,
    required int t0Ms,
  }) =>
      _post('/v1/sos', {
        'device_id':    deviceId,
        'sos_type':     sosType,
        'latitude':     lat,
        'longitude':    lon,
        if (battery != null) 'battery': battery,
        't0_client_ms': t0Ms,
      });

  // ── Contacts (server) ──────────────────────────────────────────────────────

  static Future<List<Contact>> fetchContacts(String deviceId) async {
    final data = await _get('/v1/contacts/$deviceId') as List<dynamic>;
    return data
        .map((e) => Contact.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<Contact> addContact({
    required String deviceId,
    required String name,
    required String phone,
    String? relationship,
  }) async {
    final data = await _post('/v1/contacts', {
      'device_id':    deviceId,
      'name':         name,
      'phone':        phone,
      if (relationship != null && relationship.isNotEmpty)
        'relationship': relationship,
    });
    return Contact.fromJson(data);
  }

  static Future<void> deleteContact(String id) => _delete('/v1/contacts/$id');

  // ── History ────────────────────────────────────────────────────────────────

  static Future<List<SosRecord>> fetchHistory(String deviceId) async {
    final data = await _get('/v1/history/$deviceId') as List<dynamic>;
    return data
        .map((e) => SosRecord.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ── Latency ────────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>?> fetchLatency(String deviceId) async {
    try {
      final data = await _get('/v1/latency/$deviceId');
      return data as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  // ── Local cache helpers ────────────────────────────────────────────────────

  static Future<void> cacheContacts(List<Contact> list) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(
        K.pContacts, jsonEncode(list.map((c) => c.toJson()).toList()));
  }

  static Future<List<Contact>> loadCachedContacts() async {
    final p   = await SharedPreferences.getInstance();
    final raw = p.getString(K.pContacts);
    if (raw == null) return [];
    return (jsonDecode(raw) as List<dynamic>)
        .map((e) => Contact.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<void> cacheHistory(List<SosRecord> list) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(
        K.pHistory, jsonEncode(list.map((r) => r.toJson()).toList()));
  }

  static Future<List<SosRecord>> loadCachedHistory() async {
    final p   = await SharedPreferences.getInstance();
    final raw = p.getString(K.pHistory);
    if (raw == null) return [];
    return (jsonDecode(raw) as List<dynamic>)
        .map((e) => SosRecord.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<void> prependHistory(SosRecord r) async {
    final list = await loadCachedHistory();
    list.insert(0, r);
    if (list.length > 50) list.removeLast();
    await cacheHistory(list);
  }
}

class SosRecord {
  final String sessionId;
  final String sosType;
  final String status;
  final double? latitude;
  final double? longitude;
  final int? battery;
  final String? message;
  final DateTime? createdAt;
  final int? netMs;
  final int? e2eMs;

  const SosRecord({
    required this.sessionId,
    required this.sosType,
    required this.status,
    this.latitude,
    this.longitude,
    this.battery,
    this.message,
    this.createdAt,
    this.netMs,
    this.e2eMs,
  });

  factory SosRecord.fromJson(Map<String, dynamic> j) => SosRecord(
        sessionId: (j['session_id'] as String?) ?? '',
        sosType:   (j['sos_type'] as String?) ?? 'manual',
        status:    (j['status'] as String?) ?? 'active',
        latitude:  (j['latitude'] as num?)?.toDouble(),
        longitude: (j['longitude'] as num?)?.toDouble(),
        battery:   j['battery'] as int?,
        message:   j['message'] as String?,
        createdAt: j['created_at'] != null
            ? DateTime.tryParse(j['created_at'] as String)
            : null,
        netMs: j['net_ms'] as int?,
        e2eMs: j['e2e_ms'] as int?,
      );

  Map<String, dynamic> toJson() => {
        'session_id': sessionId,
        'sos_type':   sosType,
        'status':     status,
        'latitude':   latitude,
        'longitude':  longitude,
        'battery':    battery,
        'message':    message,
        'created_at': createdAt?.toIso8601String(),
        'net_ms':     netMs,
        'e2e_ms':     e2eMs,
      };

  String get typeLabel => const {
        'manual':   'Manual SOS',
        'crash':    'Crash Detected',
        'guardian': 'Guardian Auto-SOS',
        'fall':     'Fall Detected',
      }[sosType] ??
      'SOS';

  String get typeIcon => const {
        'manual':   '🆘',
        'crash':    '🚗',
        'guardian': '⏰',
        'fall':     '🏔️',
      }[sosType] ??
      '🆘';
}

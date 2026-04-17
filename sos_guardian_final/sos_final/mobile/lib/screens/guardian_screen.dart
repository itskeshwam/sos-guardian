import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../utils/theme.dart';
import '../utils/constants.dart';

class GuardianScreen extends StatelessWidget {
  const GuardianScreen({super.key});

  String _fmt(Duration d) {
    if (d == Duration.zero) return '00:00';
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = (d.inSeconds.remainder(60)).toString().padLeft(2, '0');
    return '${d.inHours > 0 ? "${d.inHours}:" : ""}$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final on      = s.guardianPhase != GuardianPhase.off;
    final checkin = s.guardianPhase == GuardianPhase.awaitingCheckin;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Guardian Mode',
                style: TextStyle(
                    color: T.txt, fontSize: 24, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            const Text('Auto-SOS if you miss a check-in',
                style: TextStyle(color: T.txt2, fontSize: 13)),
            const SizedBox(height: 24),

            // ── Status card ────────────────────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: on ? T.blue.withAlpha(18) : T.card,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                    color: on ? T.blue : T.border, width: on ? 2 : 1),
              ),
              child: Column(
                children: [
                  Icon(
                    on ? Icons.shield_moon_rounded : Icons.shield_outlined,
                    color: on ? T.blue : T.txt3,
                    size: 52,
                  ),
                  const SizedBox(height: 12),

                  if (checkin) ...[
                    const Text('⚠️ CHECK-IN REQUIRED',
                        style: TextStyle(
                            color: T.orange,
                            fontSize: 16,
                            fontWeight: FontWeight.w900)),
                    const SizedBox(height: 6),
                    Text(
                      'Auto-SOS in ${s.checkInCountdown}s',
                      style: const TextStyle(
                          color: T.orange,
                          fontSize: 36,
                          fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => s.confirmCheckIn(),
                        icon: const Icon(Icons.check_circle_rounded,
                            color: Colors.white),
                        label: const Text("I'M SAFE — CHECK IN",
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 15)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: T.green,
                          padding:
                              const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ] else if (on) ...[
                    const Text('🛡️ ACTIVE',
                        style: TextStyle(
                            color: T.blue,
                            fontSize: 16,
                            fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    const Text('Next check-in in:',
                        style: TextStyle(color: T.txt2, fontSize: 12)),
                    const SizedBox(height: 4),
                    Text(
                      _fmt(s.timeToNextCheckIn),
                      style: const TextStyle(
                        color: T.blue,
                        fontSize: 46,
                        fontWeight: FontWeight.w900,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'You have ${K.guardianWindowSec ~/ 60} min to respond before auto-SOS',
                      style: const TextStyle(color: T.txt3, fontSize: 11),
                      textAlign: TextAlign.center,
                    ),
                  ] else ...[
                    const Text('INACTIVE',
                        style: TextStyle(
                            color: T.txt3,
                            fontSize: 16,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    const Text(
                      'Enable for treks, late drives, or solo outings',
                      style: TextStyle(color: T.txt3, fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ── Toggle ─────────────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => s.toggleGuardian(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: on ? T.cardHi : T.blue,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(
                        color: on ? T.red.withAlpha(120) : Colors.transparent),
                  ),
                ),
                child: Text(
                  on ? '⛔  DISABLE GUARDIAN' : '🛡️  ENABLE GUARDIAN',
                  style: TextStyle(
                      color: on ? T.red : Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 14),
                ),
              ),
            ),

            const SizedBox(height: 28),
            _sectionHeader('HOW IT WORKS'),
            const SizedBox(height: 10),

            _Step(1, 'Enable Guardian Mode',
                'Arm it before a trek or drive. The ${K.guardianIntervalMin}-min timer starts.',
                Icons.play_circle_fill_rounded, T.blue),
            _Step(2, 'Check In Every ${K.guardianIntervalMin} Min',
                'You get an alert. Tap "I\'m Safe" to reset the timer.',
                Icons.notifications_active_rounded, T.orange),
            _Step(3, 'Miss Check-In → Auto SOS',
                '${K.guardianWindowSec ~/ 60}-min response window. No reply = encrypted SOS sent.',
                Icons.emergency_share_rounded, T.red),
            _Step(4, 'SMS Fallback',
                'All emergency contacts get an SMS with your GPS link.',
                Icons.sms_rounded, T.green),

            const SizedBox(height: 20),
            _sectionHeader('PERFECT FOR'),
            const SizedBox(height: 10),

            Wrap(spacing: 8, runSpacing: 8, children: const [
              _Tag('🏔️ Solo trekking'),
              _Tag('🚗 Long drives'),
              _Tag('🌙 Late-night travel'),
              _Tag('🧗 Rock climbing'),
              _Tag('🚵 Mountain biking'),
              _Tag('🏊 Swimming'),
              _Tag('🏕️ Camping'),
            ]),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  static Widget _sectionHeader(String t) => Text(t,
      style: const TextStyle(
          color: T.txt2,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2));
}

class _Step extends StatelessWidget {
  final int num;
  final String title, desc;
  final IconData icon;
  final Color color;
  const _Step(this.num, this.title, this.desc, this.icon, this.color);

  @override
  Widget build(BuildContext ctx) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: T.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: T.border),
          ),
          child: Row(
            children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: color.withAlpha(25),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            color: T.txt,
                            fontWeight: FontWeight.w700,
                            fontSize: 13)),
                    const SizedBox(height: 2),
                    Text(desc,
                        style: const TextStyle(
                            color: T.txt2, fontSize: 11, height: 1.4)),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}

class _Tag extends StatelessWidget {
  final String label;
  const _Tag(this.label);
  @override
  Widget build(BuildContext ctx) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: T.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: T.border),
        ),
        child: Text(label,
            style: const TextStyle(color: T.txt2, fontSize: 12)),
      );
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../providers/crash_notifier.dart';
import '../utils/theme.dart';
import '../utils/constants.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s     = context.watch<AppState>();
    final crash = context.watch<CrashNotifier>();

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Settings',
                style: TextStyle(
                    color: T.txt, fontSize: 24, fontWeight: FontWeight.w800)),
            const SizedBox(height: 24),

            // ── Profile ──────────────────────────────────────────────────────
            _Section('PROFILE', [
              _InfoRow('Name',      s.username,  Icons.person_outline),
              _InfoRow('Phone',     s.phone.isEmpty ? 'Not set' : s.phone, Icons.phone_outlined),
              _InfoRow('Device ID', s.deviceId.length > 12
                  ? '${s.deviceId.substring(0, 12)}…'
                  : s.deviceId, Icons.phone_android_rounded),
            ]),

            // ── Detection ────────────────────────────────────────────────────
            _Section('DETECTION', [
              _SwitchRow(
                'Crash Detection',
                'Accelerometer spike > ${K.crashThreshold.toInt()} m/s²',
                Icons.directions_car_rounded,
                s.crashEnabled,
                T.orange,
                (v) {
                  s.setCrashEnabled(v);
                  if (v) crash.start(() => s.onCrashSignal());
                  else   crash.stop();
                },
              ),
              _SwitchRow(
                'Guardian Mode',
                'Auto-SOS every ${K.guardianIntervalMin} min without check-in',
                Icons.shield_moon_rounded,
                s.guardianPhase != GuardianPhase.off,
                T.blue,
                (_) => s.toggleGuardian(),
              ),
            ]),

            // ── Server ───────────────────────────────────────────────────────
            _Section('SERVER', [
              _InfoRow('URL', K.baseUrl, Icons.cloud_outlined),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: (s.online ? T.green : T.red).withAlpha(20),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        s.online
                            ? Icons.cloud_done_rounded
                            : Icons.cloud_off_rounded,
                        color: s.online ? T.green : T.red,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Status',
                              style: TextStyle(color: T.txt, fontSize: 13)),
                          Text(
                            s.online
                                ? 'Connected'
                                : 'Unreachable — SMS fallback active',
                            style: TextStyle(
                                color: s.online ? T.green : T.orange,
                                fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () => s.refreshServer(),
                      child: const Text('Ping',
                          style: TextStyle(color: T.blue, fontSize: 12)),
                    ),
                  ],
                ),
              ),
            ]),

            // ── Device ───────────────────────────────────────────────────────
            _Section('DEVICE', [
              _InfoRow(
                'Battery',
                '${s.battery}%${s.charging ? " (charging)" : ""}',
                Icons.battery_full_rounded,
              ),
              _InfoRow('Network', s.network, Icons.wifi_rounded),
            ]),

            // ── Benchmark ────────────────────────────────────────────────────
            _Section('LATENCY BENCHMARK', [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Run the Python script to measure T0→T1→T2 latency:',
                      style: TextStyle(color: T.txt2, fontSize: 12, height: 1.4),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: T.cardHi,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'python latency_test.py --label WiFi\n'
                        'python latency_test.py --label 4G\n'
                        'python latency_test.py --stress 100',
                        style: TextStyle(
                            color: T.green,
                            fontSize: 11,
                            fontFamily: 'monospace',
                            height: 1.8),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => s.sendSos('manual'),
                        icon: const Icon(Icons.speed_rounded,
                            color: Colors.white),
                        label: const Text('Send Benchmark SOS',
                            style: TextStyle(color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: T.blue,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ]),

            // ── Danger ───────────────────────────────────────────────────────
            const SizedBox(height: 8),
            const Text('DANGER ZONE',
                style: TextStyle(
                    color: T.red,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2)),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => _confirmReset(context, s),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: T.red),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('Reset & Wipe All Data',
                    style: TextStyle(
                        color: T.red, fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  void _confirmReset(BuildContext ctx, AppState s) {
    showDialog(
      context: ctx,
      builder: (_) => AlertDialog(
        backgroundColor: T.card,
        title: const Text('Reset All Data',
            style: TextStyle(
                color: T.red, fontWeight: FontWeight.w800)),
        content: const Text(
            'Clears device ID, contacts, and history. Cannot be undone.',
            style: TextStyle(color: T.txt2, height: 1.5)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel',
                  style: TextStyle(color: T.txt2))),
          ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                await s.resetAll();
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: T.red),
              child: const Text('WIPE',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w800))),
        ],
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _Section(this.title, this.children);

  @override
  Widget build(BuildContext ctx) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  color: T.txt2,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2)),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: T.card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: T.border),
            ),
            child: Column(
              children: List.generate(children.length, (i) => Column(children: [
                Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 2),
                    child: children[i]),
                if (i < children.length - 1)
                  const Divider(
                      color: T.border, height: 1, indent: 50),
              ])),
            ),
          ),
          const SizedBox(height: 20),
        ],
      );
}

class _InfoRow extends StatelessWidget {
  final String label, value;
  final IconData icon;
  const _InfoRow(this.label, this.value, this.icon);
  @override
  Widget build(BuildContext ctx) => ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: T.cardHi,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: T.txt2, size: 18),
        ),
        title: Text(label,
            style: const TextStyle(color: T.txt, fontSize: 13)),
        trailing: Text(value,
            style: const TextStyle(color: T.txt2, fontSize: 11),
            overflow: TextOverflow.ellipsis),
      );
}

class _SwitchRow extends StatelessWidget {
  final String label, subtitle;
  final IconData icon;
  final bool value;
  final Color activeColor;
  final ValueChanged<bool> onChanged;
  const _SwitchRow(this.label, this.subtitle, this.icon, this.value,
      this.activeColor, this.onChanged);

  @override
  Widget build(BuildContext ctx) => SwitchListTile(
        contentPadding: EdgeInsets.zero,
        secondary: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: (value ? activeColor : T.txt3).withAlpha(20),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon,
              color: value ? activeColor : T.txt3, size: 18),
        ),
        title: Text(label,
            style: const TextStyle(color: T.txt, fontSize: 13)),
        subtitle: Text(subtitle,
            style: const TextStyle(color: T.txt3, fontSize: 10)),
        value: value,
        onChanged: onChanged,
        activeColor: activeColor,
      );
}

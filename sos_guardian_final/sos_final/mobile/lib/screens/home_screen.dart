import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../providers/crash_notifier.dart';
import '../utils/theme.dart';
import '../utils/constants.dart';
import 'contacts_screen.dart';
import 'guardian_screen.dart';
import 'history_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeState();
}

class _HomeState extends State<HomeScreen> {
  int _tab = 0;

  final _pages = const [
    _SosPage(),
    GuardianScreen(),
    ContactsScreen(),
    HistoryScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: T.bg,
        body: IndexedStack(index: _tab, children: _pages),
        bottomNavigationBar: Container(
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: T.border)),
          ),
          child: BottomNavigationBar(
            currentIndex: _tab,
            onTap: (i) => setState(() => _tab = i),
            items: const [
              BottomNavigationBarItem(
                  icon: Icon(Icons.emergency_share_rounded), label: 'SOS'),
              BottomNavigationBarItem(
                  icon: Icon(Icons.shield_moon_rounded), label: 'Guardian'),
              BottomNavigationBarItem(
                  icon: Icon(Icons.contacts_rounded), label: 'Contacts'),
              BottomNavigationBarItem(
                  icon: Icon(Icons.history_rounded), label: 'History'),
              BottomNavigationBarItem(
                  icon: Icon(Icons.settings_rounded), label: 'Settings'),
            ],
          ),
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────

class _SosPage extends StatefulWidget {
  const _SosPage();
  @override
  State<_SosPage> createState() => _SosPageState();
}

class _SosPageState extends State<_SosPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  late final Animation<double> _scale;
  late final Animation<double> _glow;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1400))
      ..repeat(reverse: true);
    _scale = Tween(begin: 1.0, end: 1.07)
        .animate(CurvedAnimation(parent: _pulse, curve: Curves.easeInOut));
    _glow  = Tween(begin: 0.25, end: 0.65)
        .animate(CurvedAnimation(parent: _pulse, curve: Curves.easeInOut));

    WidgetsBinding.instance.addPostFrameCallback((_) => _hookCrash());
  }

  void _hookCrash() {
    final app   = context.read<AppState>();
    final crash = context.read<CrashNotifier>();
    if (app.crashEnabled && !crash.active) {
      crash.start(() => app.onCrashSignal());
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();

    return SafeArea(
      child: Column(
        children: [
          // ── Top bar ───────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: T.card,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: T.border),
                  ),
                  child: const Icon(Icons.shield_rounded,
                      color: T.red, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.username,
                          style: const TextStyle(
                              color: T.txt,
                              fontWeight: FontWeight.w800,
                              fontSize: 15)),
                      Text(
                        '${s.contacts.length} contact(s) · ${s.battery}%',
                        style:
                            const TextStyle(color: T.txt2, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                _OnlineDot(online: s.online),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // ── BLE beacon banner ─────────────────────────────────────────────
          if (s.bleBeaconActive)
            _Banner(
              color: T.blue,
              icon: Icons.bluetooth_rounded,
              text: '🔵 BLE SOS beacon broadcasting (60s)',
            ),

          // ── Low battery warning ───────────────────────────────────────────
          if (s.battery <= 20 && !s.charging)
            _Banner(
              color: T.orange,
              icon: Icons.battery_alert_rounded,
              text: '⚠️ Low battery ${s.battery}% — SOS may fail if phone dies',
            ),

          // ── Crash pending banner ──────────────────────────────────────────
          if (s.crashPending)
            _CrashBanner(secs: s.crashCountdown),

          // ── Guardian check-in banner ──────────────────────────────────────
          if (s.guardianPhase == GuardianPhase.awaitingCheckin)
            _CheckInBanner(secs: s.checkInCountdown),

          // ── Status message ────────────────────────────────────────────────
          if (s.sendMsg.isNotEmpty &&
              !s.crashPending &&
              s.guardianPhase != GuardianPhase.awaitingCheckin)
            _StatusBanner(state: s.sendState, msg: s.sendMsg),

          const Spacer(),

          // ── Guardian ticker ───────────────────────────────────────────────
          if (s.guardianPhase == GuardianPhase.ticking)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: T.blue.withAlpha(20),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: T.blue.withAlpha(70)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.shield_moon_rounded,
                        color: T.blue, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      'Guardian · next check-in in ${_fmt(s.timeToNextCheckIn)}',
                      style: const TextStyle(
                          color: T.blue, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),

          const SizedBox(height: 20),

          // ── SOS BUTTON ────────────────────────────────────────────────────
          AnimatedBuilder(
            animation: _pulse,
            builder: (_, __) => GestureDetector(
              onTap: () => s.sendSos('manual'),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Glow rings
                  for (int i = 0; i < 3; i++)
                    Container(
                      width:  196.0 + i * 30,
                      height: 196.0 + i * 30,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: T.red.withAlpha(
                          ((_glow.value * 25 * (3 - i)).round())
                              .clamp(0, 255),
                        ),
                      ),
                    ),
                  // Core
                  Transform.scale(
                    scale: s.sendState == SendState.sending
                        ? 0.96
                        : _scale.value,
                    child: Container(
                      width: 196, height: 196,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const RadialGradient(
                          colors: [
                            Color(0xFFFF4466),
                            T.red,
                            T.redDark,
                          ],
                          stops: [0.0, 0.5, 1.0],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: T.red.withAlpha(
                                (_glow.value * 170).round()),
                            blurRadius: 40,
                            spreadRadius: 6,
                          ),
                        ],
                      ),
                      child: s.sendState == SendState.sending
                          ? const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 34, height: 34,
                                  child: CircularProgressIndicator(
                                      color: Colors.white, strokeWidth: 3),
                                ),
                                SizedBox(height: 10),
                                Text('SENDING…',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 2)),
                              ],
                            )
                          : const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.emergency_share_rounded,
                                    color: Colors.white, size: 52),
                                SizedBox(height: 6),
                                Text('SOS',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 30,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 6)),
                              ],
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 14),
          const Text('Tap to send SOS',
              style: TextStyle(color: T.txt3, fontSize: 12)),

          const SizedBox(height: 28),

          // ── Quick actions ─────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                _Quick(
                  icon: Icons.shield_moon_rounded,
                  label: s.guardianPhase == GuardianPhase.off
                      ? 'Guardian\nOFF'
                      : 'Guardian\nON',
                  color: s.guardianPhase == GuardianPhase.off
                      ? T.txt3
                      : T.blue,
                  onTap: () => s.toggleGuardian(),
                ),
                const SizedBox(width: 10),
                _Quick(
                  icon: Icons.directions_car_rounded,
                  label: s.crashEnabled ? 'Crash\nON' : 'Crash\nOFF',
                  color: s.crashEnabled ? T.orange : T.txt3,
                  onTap: () {
                    final crash = context.read<CrashNotifier>();
                    final v = !s.crashEnabled;
                    s.setCrashEnabled(v);
                    if (v) {
                      crash.start(() => s.onCrashSignal());
                    } else {
                      crash.stop();
                    }
                  },
                ),
                const SizedBox(width: 10),
                _Quick(
                  icon: Icons.contacts_rounded,
                  label: '${s.contacts.length}\nContacts',
                  color: s.contacts.isEmpty ? T.txt3 : T.green,
                  onTap: () {},
                ),
                const SizedBox(width: 10),
                _Quick(
                  icon: Icons.bluetooth_rounded,
                  label: s.bleBeaconActive ? 'BLE\nON' : 'BLE\nOFF',
                  color: s.bleBeaconActive ? T.blue : T.txt3,
                  onTap: () {},
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

// ── Widget helpers ────────────────────────────────────────────────────────────

class _OnlineDot extends StatelessWidget {
  final bool online;
  const _OnlineDot({required this.online});
  @override
  Widget build(BuildContext ctx) => Row(children: [
        Container(
          width: 8, height: 8,
          decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: online ? T.green : T.red),
        ),
        const SizedBox(width: 5),
        Text(online ? 'Online' : 'Offline',
            style: TextStyle(
                color: online ? T.green : T.red,
                fontSize: 11,
                fontWeight: FontWeight.w600)),
      ]);
}

class _Banner extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String text;
  const _Banner({required this.color, required this.icon, required this.text});

  @override
  Widget build(BuildContext ctx) => Container(
        margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: color.withAlpha(22),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withAlpha(80)),
        ),
        child: Row(children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 8),
          Expanded(
              child: Text(text,
                  style: TextStyle(color: color, fontSize: 12))),
        ]),
      );
}

class _CrashBanner extends StatelessWidget {
  final int secs;
  const _CrashBanner({required this.secs});
  @override
  Widget build(BuildContext ctx) => Container(
        margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: T.red.withAlpha(30),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: T.red, width: 2),
        ),
        child: Column(children: [
          Text('🚗  CRASH DETECTED — SOS in ${secs}s',
              style: const TextStyle(
                  color: T.red, fontWeight: FontWeight.w900, fontSize: 15)),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => ctx.read<AppState>().cancelCrash(),
              style: ElevatedButton.styleFrom(
                  backgroundColor: T.green,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10))),
              child: const Text("CANCEL — I'M OKAY",
                  style: TextStyle(
                      color: Colors.black, fontWeight: FontWeight.w800)),
            ),
          ),
        ]),
      );
}

class _CheckInBanner extends StatelessWidget {
  final int secs;
  const _CheckInBanner({required this.secs});
  @override
  Widget build(BuildContext ctx) => Container(
        margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: T.orange.withAlpha(25),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: T.orange, width: 2),
        ),
        child: Column(children: [
          Text('⏰  GUARDIAN CHECK-IN — SOS in ${secs}s',
              style: const TextStyle(
                  color: T.orange, fontWeight: FontWeight.w900, fontSize: 14)),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => ctx.read<AppState>().confirmCheckIn(),
              style: ElevatedButton.styleFrom(
                  backgroundColor: T.blue,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10))),
              child: const Text("✅  I'M SAFE",
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w800)),
            ),
          ),
        ]),
      );
}

class _StatusBanner extends StatelessWidget {
  final SendState state;
  final String msg;
  const _StatusBanner({required this.state, required this.msg});

  Color get _c => switch (state) {
        SendState.done   => T.green,
        SendState.failed => T.orange,
        SendState.sending => T.blue,
        _                => T.txt2,
      };

  @override
  Widget build(BuildContext ctx) => Container(
        margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: _c.withAlpha(20),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _c.withAlpha(80)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(_icon, color: _c, size: 16),
            const SizedBox(width: 8),
            Expanded(
                child: Text(msg,
                    style:
                        TextStyle(color: _c, fontSize: 12, height: 1.4))),
          ],
        ),
      );

  IconData get _icon => switch (state) {
        SendState.done    => Icons.check_circle_rounded,
        SendState.failed  => Icons.warning_amber_rounded,
        SendState.sending => Icons.send_rounded,
        _                 => Icons.info_rounded,
      };
}

class _Quick extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _Quick(
      {required this.icon,
      required this.label,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext ctx) => Expanded(
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: T.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: T.border),
            ),
            child: Column(
              children: [
                Icon(icon, color: color, size: 22),
                const SizedBox(height: 5),
                Text(label,
                    style: TextStyle(
                        color: color,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        height: 1.3),
                    textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      );
}

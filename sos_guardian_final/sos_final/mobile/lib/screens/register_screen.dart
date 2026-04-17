import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../utils/theme.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _State();
}

class _State extends State<RegisterScreen> {
  final _name  = TextEditingController();
  final _phone = TextEditingController();
  final _form  = GlobalKey<FormState>();
  bool _busy   = false;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() => _busy = true);
    await context.read<AppState>().register(
          _name.text.trim(),
          _phone.text.trim(),
        );
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();

    return Scaffold(
      backgroundColor: T.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Form(
            key: _form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 32),
                // Hero icon
                Center(
                  child: Container(
                    width: 90, height: 90,
                    decoration: BoxDecoration(
                      color: T.redGlow,
                      shape: BoxShape.circle,
                      border: Border.all(color: T.red, width: 2),
                    ),
                    child: const Icon(Icons.shield_rounded,
                        color: T.red, size: 46),
                  ),
                ),
                const SizedBox(height: 24),
                const Center(
                  child: Text('SOS Guardian',
                      style: TextStyle(
                          color: T.txt,
                          fontSize: 28,
                          fontWeight: FontWeight.w900)),
                ),
                const SizedBox(height: 8),
                const Center(
                  child: Text(
                    'Emergency SOS · Guardian Mode · Crash Detection',
                    style: TextStyle(color: T.txt2, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 40),

                // Feature badges
                const Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _Badge('📡 GPS SOS'),
                    _Badge('⏰ Guardian Mode'),
                    _Badge('🚗 Crash Detection'),
                    _Badge('📱 SMS Fallback'),
                    _Badge('🔵 BLE Beacon'),
                  ],
                ),
                const SizedBox(height: 36),

                _Label('YOUR NAME'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _name,
                  style: const TextStyle(color: T.txt),
                  decoration: _dec('Full name', Icons.person_outline),
                  validator: (v) =>
                      (v == null || v.trim().length < 2) ? 'At least 2 characters' : null,
                ),
                const SizedBox(height: 20),

                _Label('PHONE  (optional — shows in SOS message)'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  style: const TextStyle(color: T.txt),
                  decoration: _dec('+91 98765 43210', Icons.phone_outlined),
                ),
                const SizedBox(height: 36),

                // Error message
                if (s.sendState == SendState.failed) ...[
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: T.red.withAlpha(25),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: T.red.withAlpha(80)),
                    ),
                    child: Text(s.sendMsg,
                        style: const TextStyle(
                            color: T.red, fontSize: 13, height: 1.5)),
                  ),
                  const SizedBox(height: 20),
                ],

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _busy ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: T.red,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                    child: _busy
                        ? const SizedBox(
                            width: 22, height: 22,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2.5))
                        : const Text('CREATE PROFILE',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                                letterSpacing: .8)),
                  ),
                ),

                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: T.card,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: T.border),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline_rounded,
                          color: T.blue, size: 16),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Make sure your backend server is running and reachable on the same Wi-Fi network.',
                          style: TextStyle(
                              color: T.txt2, fontSize: 12, height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static Widget _Label(String s) => Text(s,
      style: const TextStyle(
          color: T.txt2,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.1));

  static InputDecoration _dec(String hint, IconData icon) => InputDecoration(
        hintText:       hint,
        hintStyle:      const TextStyle(color: T.txt3),
        prefixIcon:     Icon(icon, color: T.txt3, size: 20),
        filled:         true,
        fillColor:      T.card,
        border:         _border(),
        enabledBorder:  _border(),
        focusedBorder:  _border(color: T.red),
        contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
      );

  static OutlineInputBorder _border({Color color = T.border}) =>
      OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: color));
}

class _Badge extends StatelessWidget {
  final String label;
  const _Badge(this.label);
  @override
  Widget build(BuildContext ctx) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: T.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: T.border),
        ),
        child: Text(label,
            style: const TextStyle(color: T.txt2, fontSize: 12)),
      );
}

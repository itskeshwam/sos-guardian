import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/contact.dart';
import '../providers/app_state.dart';
import '../utils/theme.dart';

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});
  @override
  State<ContactsScreen> createState() => _State();
}

class _State extends State<ContactsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
        (_) => context.read<AppState>().loadContacts());
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();

    return SafeArea(
      child: Column(
        children: [
          // ── Header ────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 0),
            child: Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Emergency Contacts',
                          style: TextStyle(
                              color: T.txt,
                              fontSize: 20,
                              fontWeight: FontWeight.w800)),
                      Text('Notified via SOS + SMS',
                          style: TextStyle(color: T.txt2, fontSize: 12)),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => _showAdd(context),
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: T.red,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.add, color: Colors.white, size: 20),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          if (s.contacts.isEmpty)
            Expanded(child: _Empty(onAdd: () => _showAdd(context)))
          else
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: s.contacts.length,
                itemBuilder: (_, i) => _Tile(
                  contact: s.contacts[i],
                  onDelete: () => s.removeContact(s.contacts[i].id),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showAdd(BuildContext ctx) {
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: T.card,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (_) => _AddSheet(
        onAdd: (name, phone, rel) async {
          final err = await ctx.read<AppState>().addContact(name, phone, rel);
          if (ctx.mounted) {
            Navigator.pop(ctx);
            if (err != null) {
              ScaffoldMessenger.of(ctx).showSnackBar(
                SnackBar(
                  content: Text('Error: $err'),
                  backgroundColor: T.red,
                ),
              );
            }
          }
        },
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _Empty extends StatelessWidget {
  final VoidCallback onAdd;
  const _Empty({required this.onAdd});
  @override
  Widget build(BuildContext ctx) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: T.card,
                shape: BoxShape.circle,
                border: Border.all(color: T.border),
              ),
              child: const Icon(Icons.contact_phone_rounded,
                  color: T.txt3, size: 44),
            ),
            const SizedBox(height: 20),
            const Text('No Emergency Contacts',
                style: TextStyle(
                    color: T.txt, fontWeight: FontWeight.w700, fontSize: 17)),
            const SizedBox(height: 8),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                'Add contacts who will receive your GPS location when SOS is triggered.',
                style: TextStyle(color: T.txt2, fontSize: 13, height: 1.5),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text('Add Contact',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w700)),
              style: ElevatedButton.styleFrom(
                backgroundColor: T.red,
                padding:
                    const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      );
}

// ── Contact tile ──────────────────────────────────────────────────────────────

class _Tile extends StatelessWidget {
  final Contact contact;
  final VoidCallback onDelete;
  const _Tile({required this.contact, required this.onDelete});

  @override
  Widget build(BuildContext ctx) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: T.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: T.border),
        ),
        child: Row(
          children: [
            Container(
              width: 46, height: 46,
              decoration: BoxDecoration(
                color: T.red.withAlpha(30),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(contact.initials,
                    style: const TextStyle(
                        color: T.red,
                        fontWeight: FontWeight.w800,
                        fontSize: 16)),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(contact.name,
                      style: const TextStyle(
                          color: T.txt,
                          fontWeight: FontWeight.w700,
                          fontSize: 14)),
                  Text(contact.phone,
                      style:
                          const TextStyle(color: T.txt2, fontSize: 12)),
                  if (contact.relationship != null)
                    Text(contact.relationship!,
                        style:
                            const TextStyle(color: T.txt3, fontSize: 11)),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded,
                  color: T.txt3, size: 20),
              onPressed: () => showDialog(
                context: ctx,
                builder: (_) => AlertDialog(
                  backgroundColor: T.card,
                  title: const Text('Remove Contact',
                      style: TextStyle(color: T.txt)),
                  content: Text('Remove ${contact.name}?',
                      style: const TextStyle(color: T.txt2)),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Cancel',
                            style: TextStyle(color: T.txt2))),
                    TextButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          onDelete();
                        },
                        child: const Text('Remove',
                            style: TextStyle(color: T.red))),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
}

// ── Add contact bottom sheet ──────────────────────────────────────────────────

class _AddSheet extends StatefulWidget {
  final Future<void> Function(String name, String phone, String? rel) onAdd;
  const _AddSheet({required this.onAdd});
  @override
  State<_AddSheet> createState() => _AddSheetState();
}

class _AddSheetState extends State<_AddSheet> {
  final _name  = TextEditingController();
  final _phone = TextEditingController();
  final _rel   = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _rel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20, right: 20, top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Add Emergency Contact',
                style: TextStyle(
                    color: T.txt, fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 18),
            _F(ctrl: _name,  hint: 'Full Name',        icon: Icons.person_outline),
            const SizedBox(height: 12),
            _F(ctrl: _phone, hint: 'Phone Number',     icon: Icons.phone_outlined, type: TextInputType.phone),
            const SizedBox(height: 12),
            _F(ctrl: _rel,   hint: 'Relationship (optional)', icon: Icons.people_outline),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving
                    ? null
                    : () async {
                        final name  = _name.text.trim();
                        final phone = _phone.text.trim();
                        if (name.isEmpty || phone.isEmpty) return;
                        setState(() => _saving = true);
                        await widget.onAdd(
                          name, phone,
                          _rel.text.trim().isEmpty ? null : _rel.text.trim(),
                        );
                        if (mounted) setState(() => _saving = false);
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: T.red,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Text('Add Contact',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800)),
              ),
            ),
          ],
        ),
      );
}

class _F extends StatelessWidget {
  final TextEditingController ctrl;
  final String hint;
  final IconData icon;
  final TextInputType? type;
  const _F({required this.ctrl, required this.hint, required this.icon, this.type});

  @override
  Widget build(BuildContext ctx) => TextField(
        controller: ctrl,
        keyboardType: type,
        style: const TextStyle(color: T.txt),
        decoration: InputDecoration(
          hintText:       hint,
          hintStyle:      const TextStyle(color: T.txt3, fontSize: 13),
          prefixIcon:     Icon(icon, color: T.txt3, size: 20),
          filled:         true,
          fillColor:      T.cardHi,
          border:         _b(),
          enabledBorder:  _b(),
          focusedBorder:  _b(T.red),
          contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
        ),
      );

  OutlineInputBorder _b([Color c = T.border]) =>
      OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: c));
}

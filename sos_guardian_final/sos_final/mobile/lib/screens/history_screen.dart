import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/sos_record.dart';
import '../providers/app_state.dart';
import '../utils/theme.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});
  @override
  State<HistoryScreen> createState() => _State();
}

class _State extends State<HistoryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppState>()
        ..refreshHistory()
        ..refreshLatency();
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 10),
            child: Row(
              children: [
                const Expanded(
                  child: Text('Activity',
                      style: TextStyle(
                          color: T.txt,
                          fontSize: 22,
                          fontWeight: FontWeight.w800)),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh_rounded, color: T.txt2),
                  onPressed: () {
                    context.read<AppState>()
                      ..refreshHistory()
                      ..refreshLatency();
                  },
                ),
              ],
            ),
          ),

          // Tab bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              decoration: BoxDecoration(
                color: T.card,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: T.border),
              ),
              child: TabBar(
                controller: _tabs,
                indicator: BoxDecoration(
                    color: T.red,
                    borderRadius: BorderRadius.circular(10)),
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                labelColor: Colors.white,
                unselectedLabelColor: T.txt2,
                labelStyle: const TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 13),
                tabs: const [
                  Tab(text: '📋  Events'),
                  Tab(text: '📊  Latency'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),

          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: const [_EventsList(), _LatencyPanel()],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Events list ───────────────────────────────────────────────────────────────

class _EventsList extends StatelessWidget {
  const _EventsList();
  @override
  Widget build(BuildContext ctx) {
    final list = ctx.watch<AppState>().history;
    if (list.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.history_rounded, color: T.txt3, size: 48),
            SizedBox(height: 14),
            Text('No SOS events yet',
                style: TextStyle(color: T.txt2, fontSize: 15)),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: list.length,
      itemBuilder: (_, i) => _EventCard(record: list[i]),
    );
  }
}

class _EventCard extends StatelessWidget {
  final SosRecord record;
  const _EventCard({required this.record});

  @override
  Widget build(BuildContext ctx) {
    final fmt = record.createdAt != null
        ? DateFormat('d MMM y  HH:mm').format(record.createdAt!.toLocal())
        : '—';
    final statusColor = record.status == 'resolved' ? T.green : T.orange;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: T.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: T.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(record.typeIcon,
                  style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(record.typeLabel,
                        style: const TextStyle(
                            color: T.txt,
                            fontWeight: FontWeight.w700,
                            fontSize: 13)),
                    Text(record.sessionId,
                        style: const TextStyle(
                            color: T.txt3,
                            fontSize: 10,
                            fontFamily: 'monospace')),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withAlpha(25),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(record.status.toUpperCase(),
                    style: TextStyle(
                        color: statusColor,
                        fontSize: 9,
                        fontWeight: FontWeight.w800)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(fmt,
              style: const TextStyle(color: T.txt3, fontSize: 11)),
          if (record.latitude != null) ...[
            const SizedBox(height: 3),
            Text(
              '📍 ${record.latitude!.toStringAsFixed(5)}, '
              '${record.longitude!.toStringAsFixed(5)}'
              '${record.battery != null ? "  🔋 ${record.battery}%" : ""}',
              style: const TextStyle(color: T.txt2, fontSize: 11),
            ),
          ],
          if (record.netMs != null) ...[
            const SizedBox(height: 6),
            Row(children: [
              _Chip('Net', '${record.netMs}ms', T.blue),
              const SizedBox(width: 6),
              _Chip('E2E', '${record.e2eMs}ms', T.green),
            ]),
          ],
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label, val;
  final Color color;
  const _Chip(this.label, this.val, this.color);
  @override
  Widget build(BuildContext ctx) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withAlpha(20),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text('$label: $val',
            style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.w700)),
      );
}

// ── Latency panel ─────────────────────────────────────────────────────────────

class _LatencyPanel extends StatelessWidget {
  const _LatencyPanel();
  @override
  Widget build(BuildContext ctx) {
    final data = ctx.watch<AppState>().latency;
    if (data == null || (data['count'] as int? ?? 0) == 0) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.bar_chart_rounded, color: T.txt3, size: 48),
            const SizedBox(height: 14),
            const Text('No latency data yet',
                style: TextStyle(color: T.txt2, fontSize: 15)),
            const SizedBox(height: 8),
            const Text('Send at least one SOS to see stats',
                style: TextStyle(color: T.txt3, fontSize: 12)),
            const SizedBox(height: 20),
            TextButton.icon(
              onPressed: () => ctx.read<AppState>().refreshLatency(),
              icon: const Icon(Icons.refresh_rounded, color: T.blue),
              label: const Text('Refresh',
                  style: TextStyle(color: T.blue)),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: T.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: T.border),
            ),
            child: Row(children: [
              const Icon(Icons.analytics_rounded, color: T.blue),
              const SizedBox(width: 10),
              Text('Based on ${data["count"]} sample(s)',
                  style: const TextStyle(
                      color: T.txt, fontWeight: FontWeight.w700)),
            ]),
          ),
          const SizedBox(height: 14),
          _LatRow('Network (T1 − T0)',    'Phone → Server',  T.blue,   data['network']),
          const SizedBox(height: 10),
          _LatRow('Processing (T2 − T1)', 'Server → DB',     T.orange, data['processing']),
          const SizedBox(height: 10),
          _LatRow('Total E2E (T2 − T0)',  'Button → Storage', T.green, data['e2e']),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: T.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: T.border),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('BENCHMARK GUIDE',
                    style: TextStyle(
                        color: T.txt2,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.0)),
                SizedBox(height: 8),
                Text(
                  'Run latency_test.py under 3 conditions:\n'
                  '  A) Wi-Fi    python latency_test.py --label WiFi\n'
                  '  B) 4G LTE  python latency_test.py --label 4G\n'
                  '  C) 5G      python latency_test.py --label 5G\n\n'
                  'Stress test (100 concurrent):\n'
                  '  python latency_test.py --stress 100',
                  style: TextStyle(
                      color: T.txt3,
                      fontSize: 11,
                      height: 1.7,
                      fontFamily: 'monospace'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LatRow extends StatelessWidget {
  final String title, sub;
  final Color color;
  final Map<String, dynamic>? stats;
  const _LatRow(this.title, this.sub, this.color, this.stats);

  @override
  Widget build(BuildContext ctx) {
    if (stats == null || stats!.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withAlpha(12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withAlpha(55)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: TextStyle(
                  color: color, fontWeight: FontWeight.w700, fontSize: 13)),
          Text(sub,
              style: const TextStyle(color: T.txt3, fontSize: 11)),
          const SizedBox(height: 10),
          Row(children: [
            _Stat('AVG', '${stats!["avg_ms"]} ms', color),
            const SizedBox(width: 8),
            _Stat('MIN', '${stats!["min_ms"]} ms', T.green),
            const SizedBox(width: 8),
            _Stat('MAX', '${stats!["max_ms"]} ms', T.red),
          ]),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label, val;
  final Color color;
  const _Stat(this.label, this.val, this.color);
  @override
  Widget build(BuildContext ctx) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: T.card,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(children: [
            Text(label,
                style: const TextStyle(
                    color: T.txt3, fontSize: 9, letterSpacing: .8)),
            const SizedBox(height: 4),
            Text(val,
                style: TextStyle(
                    color: color, fontWeight: FontWeight.w800, fontSize: 13)),
          ]),
        ),
      );
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../providers/app_state.dart';
import '../services/supabase_service.dart';

/// Mitarbeiter / Vorarbeiter – kendi görevleri
class FieldMyTasksScreen extends StatefulWidget {
  const FieldMyTasksScreen({super.key});

  @override
  State<FieldMyTasksScreen> createState() => _FieldMyTasksScreenState();
}

class _FieldMyTasksScreenState extends State<FieldMyTasksScreen> {
  List<Map<String, dynamic>> _plans = [];
  Map<String, dynamic>? _activeSession;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final appState = context.read<AppState>();
    try {
      final plans = await SupabaseService.getOperationPlans(
        userId: appState.userId,
        date: DateTime.now(),
      );
      final session = await SupabaseService.getActiveSession(appState.userId);
      if (mounted) {
        setState(() {
          _plans = plans;
          _activeSession = session;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _startWork(Map<String, dynamic> plan) async {
    final appState = context.read<AppState>();
    try {
      await SupabaseService.startWorkSession(
        orderId: plan['order_id'],
        userId: appState.userId,
        operationPlanId: plan['id'],
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ İşe başladınız!'), backgroundColor: AppTheme.success),
        );
        _load();
      }
    } catch (_) {}
  }

  Future<void> _endWork() async {
    if (_activeSession == null) return;
    final noteCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('İşi Tamamla', style: TextStyle(fontFamily: 'Inter')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('İşi tamamladığınızı onaylıyor musunuz?', style: TextStyle(fontFamily: 'Inter')),
            const SizedBox(height: 12),
            TextField(
              controller: noteCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Saha notu (opsiyonel)...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('İptal')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Tamamla')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await SupabaseService.endWorkSession(_activeSession!['id'], note: noteCtrl.text.trim());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Çalışma tamamlandı!'), backgroundColor: AppTheme.success),
        );
        _load();
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();

    return RefreshIndicator(
      onRefresh: _load,
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Aktif Seans ─────────────────────────
                  if (_activeSession != null) ...[
                    _ActiveSessionBanner(session: _activeSession!, onEnd: _endWork),
                    const SizedBox(height: 16),
                  ],

                  // ── Bugünkü Görevler ─────────────────────
                  Row(
                    children: [
                      const Icon(Icons.today, size: 18, color: AppTheme.textSub),
                      const SizedBox(width: 6),
                      const Text('Bugünkü Görevlerim',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'Inter')),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: AppTheme.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                        child: Text('${_plans.length}', style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold, fontFamily: 'Inter')),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  if (_plans.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppTheme.divider),
                      ),
                      child: const Center(child: Column(children: [
                        Icon(Icons.event_available, size: 48, color: AppTheme.textSub),
                        SizedBox(height: 8),
                        Text('Bugün için görev yok', style: TextStyle(color: AppTheme.textSub, fontFamily: 'Inter')),
                      ])),
                    )
                  else
                    ..._plans.map((plan) => _TaskCard(
                      plan: plan,
                      hasActiveSession: _activeSession != null,
                      onStartWork: () => _startWork(plan),
                    )),
                ],
              ),
            ),
    );
  }
}

class _ActiveSessionBanner extends StatelessWidget {
  final Map<String, dynamic> session;
  final VoidCallback onEnd;
  const _ActiveSessionBanner({required this.session, required this.onEnd});

  @override
  Widget build(BuildContext context) {
    final order = session['order'];
    final start = session['actual_start'] != null
        ? DateTime.parse(session['actual_start']).toLocal()
        : null;
    final elapsed = start != null ? DateTime.now().difference(start) : Duration.zero;
    final h = elapsed.inHours;
    final m = elapsed.inMinutes % 60;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [AppTheme.success, Color(0xFF1B5E20)]),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(children: [
            Icon(Icons.play_circle_filled, color: Colors.white, size: 20),
            SizedBox(width: 8),
            Text('Aktif Çalışma', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontFamily: 'Inter')),
          ]),
          const SizedBox(height: 8),
          Text(order?['title'] ?? '', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600, fontFamily: 'Inter')),
          if (order?['site_address'] != null) ...[
            const SizedBox(height: 4),
            Row(children: [
              const Icon(Icons.location_on_outlined, color: Colors.white70, size: 14),
              const SizedBox(width: 4),
              Expanded(child: Text(order!['site_address'], style: const TextStyle(color: Colors.white70, fontSize: 12, fontFamily: 'Inter'), maxLines: 1, overflow: TextOverflow.ellipsis)),
            ]),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(10)),
                child: Text('${h}s ${m}dk gecti', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontFamily: 'Inter')),
              ),
              const Spacer(),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppTheme.success,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                onPressed: onEnd,
                icon: const Icon(Icons.stop_circle_outlined, size: 18),
                label: const Text('Tamamla', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TaskCard extends StatelessWidget {
  final Map<String, dynamic> plan;
  final bool hasActiveSession;
  final VoidCallback onStartWork;
  const _TaskCard({required this.plan, required this.hasActiveSession, required this.onStartWork});

  @override
  Widget build(BuildContext context) {
    final order = plan['order'];
    final customer = order?['customer'];
    final start = plan['start_time'] ?? '';
    final end = plan['end_time'] ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.divider),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: AppTheme.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: Row(children: [
                  const Icon(Icons.access_time, size: 14, color: AppTheme.primary),
                  const SizedBox(width: 4),
                  Text('$start${end.isNotEmpty ? ' – $end' : ''}',
                    style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w600, fontSize: 13, fontFamily: 'Inter')),
                ]),
              ),
              const Spacer(),
              if (plan['notification_sent'] == true)
                const Icon(Icons.check_circle, color: AppTheme.success, size: 16),
            ],
          ),
          const SizedBox(height: 10),
          Text(order?['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16, fontFamily: 'Inter')),
          if (customer != null) ...[
            const SizedBox(height: 4),
            Row(children: [
              const Icon(Icons.business, size: 14, color: AppTheme.textSub),
              const SizedBox(width: 4),
              Text(customer['name'] ?? '', style: const TextStyle(fontSize: 13, color: AppTheme.textSub, fontFamily: 'Inter')),
            ]),
          ],
          if (order?['site_address'] != null) ...[
            const SizedBox(height: 4),
            Row(children: [
              const Icon(Icons.location_on_outlined, size: 14, color: AppTheme.textSub),
              const SizedBox(width: 4),
              Expanded(child: Text(order!['site_address'], style: const TextStyle(fontSize: 13, color: AppTheme.textSub, fontFamily: 'Inter'), maxLines: 1, overflow: TextOverflow.ellipsis)),
            ]),
          ],
          if (plan['site_instructions'] != null && (plan['site_instructions'] as String).isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.warning.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.warning.withOpacity(0.2)),
              ),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Icon(Icons.info_outline, size: 14, color: AppTheme.warning),
                const SizedBox(width: 6),
                Expanded(child: Text(plan['site_instructions'], style: const TextStyle(fontSize: 12, fontFamily: 'Inter'))),
              ]),
            ),
          ],
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: hasActiveSession ? null : onStartWork,
              icon: const Icon(Icons.play_arrow, size: 20),
              label: Text(hasActiveSession ? 'Başka aktif görev var' : 'İşe Başla',
                style: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600, fontSize: 15)),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

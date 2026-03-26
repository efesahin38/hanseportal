import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../providers/app_state.dart';
import '../services/supabase_service.dart';
import 'order_detail_screen.dart';

class PlanningScreen extends StatefulWidget {
  const PlanningScreen({super.key});

  @override
  State<PlanningScreen> createState() => _PlanningScreenState();
}

class _PlanningScreenState extends State<PlanningScreen> {
  DateTime _selectedDate = DateTime.now();
  List<Map<String, dynamic>> _plans = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await SupabaseService.getOperationPlans(date: _selectedDate);
      if (mounted) setState(() { _plans = data; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _prevDay() { setState(() => _selectedDate = _selectedDate.subtract(const Duration(days: 1))); _load(); }
  void _nextDay() { setState(() => _selectedDate = _selectedDate.add(const Duration(days: 1))); _load(); }

  @override
  Widget build(BuildContext context) {
    final isToday = _selectedDate.year == DateTime.now().year &&
        _selectedDate.month == DateTime.now().month &&
        _selectedDate.day == DateTime.now().day;

    return Scaffold(
      body: Column(
        children: [
          // ── Tarih Seçici ─────────────────────────────────
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                IconButton(onPressed: _prevDay, icon: const Icon(Icons.chevron_left)),
                Expanded(
                  child: GestureDetector(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _selectedDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                        locale: const Locale('de', 'DE'),
                      );
                      if (picked != null) { setState(() => _selectedDate = picked); _load(); }
                    },
                    child: Column(
                      children: [
                        Text(isToday ? 'Bugün' : '', style: const TextStyle(color: AppTheme.accent, fontFamily: 'Inter', fontSize: 12)),
                        Text(
                          '${_selectedDate.day}.${_selectedDate.month.toString().padLeft(2, '0')}.${_selectedDate.year}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Inter'),
                        ),
                        const Text('Yönlendirme için tıklayın', style: TextStyle(color: AppTheme.textSub, fontSize: 11, fontFamily: 'Inter')),
                      ],
                    ),
                  ),
                ),
                IconButton(onPressed: _nextDay, icon: const Icon(Icons.chevron_right)),
              ],
            ),
          ),

          // ── Plan Listesi ─────────────────────────────────
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _plans.isEmpty
                    ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        const Icon(Icons.event_busy, size: 56, color: AppTheme.textSub),
                        const SizedBox(height: 12),
                        Text(
                          isToday ? 'Bugün için plan yok' : 'Bu tarih için plan yok',
                          style: const TextStyle(color: AppTheme.textSub, fontFamily: 'Inter'),
                        ),
                      ]))
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: _plans.length,
                          itemBuilder: (_, i) => _PlanCard(plan: _plans[i], onTap: () {
                            final orderId = _plans[i]['order_id'];
                            if (orderId != null) {
                              Navigator.push(context, MaterialPageRoute(builder: (_) => OrderDetailScreen(orderId: orderId)));
                            }
                          }),
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  final Map<String, dynamic> plan;
  final VoidCallback onTap;
  const _PlanCard({required this.plan, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final order = plan['order'];
    final customer = order?['customer'];
    final supervisor = plan['site_supervisor'];
    final personnel = plan['operation_plan_personnel'] as List? ?? [];
    final status = plan['status'] ?? 'draft';
    final startTime = plan['start_time'] ?? '';
    final endTime = plan['end_time'] ?? '';

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(children: [
                      const Icon(Icons.access_time, size: 14, color: AppTheme.primary),
                      const SizedBox(width: 4),
                      Text('$startTime${endTime.isNotEmpty ? ' – $endTime' : ''}',
                        style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w600, fontSize: 13, fontFamily: 'Inter')),
                    ]),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.statusColor(status).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(AppTheme.statusLabel(status),
                      style: TextStyle(fontSize: 11, color: AppTheme.statusColor(status), fontFamily: 'Inter', fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(order?['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15, fontFamily: 'Inter')),
              if (customer != null) ...[
                const SizedBox(height: 4),
                Row(children: [
                  const Icon(Icons.business, size: 14, color: AppTheme.textSub),
                  const SizedBox(width: 4),
                  Text(customer['name'] ?? '', style: const TextStyle(fontSize: 13, color: AppTheme.textSub, fontFamily: 'Inter')),
                ]),
              ],
              const Divider(height: 16),
              Row(
                children: [
                  const Icon(Icons.people_outline, size: 15, color: AppTheme.textSub),
                  const SizedBox(width: 4),
                  Text('${personnel.length} personel atandı', style: const TextStyle(fontSize: 13, color: AppTheme.textSub, fontFamily: 'Inter')),
                  if (supervisor != null) ...[
                    const SizedBox(width: 12),
                    const Icon(Icons.star_outline, size: 15, color: AppTheme.warning),
                    const SizedBox(width: 2),
                    Text('${supervisor['first_name']} ${supervisor['last_name']}'.trim(),
                      style: const TextStyle(fontSize: 12, color: AppTheme.textSub, fontFamily: 'Inter')),
                  ],
                ],
              ),
              if (plan['site_instructions'] != null && (plan['site_instructions'] as String).isNotEmpty) ...[
                const SizedBox(height: 8),
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
                    Expanded(child: Text(plan['site_instructions'], style: const TextStyle(fontSize: 12, fontFamily: 'Inter'), maxLines: 2, overflow: TextOverflow.ellipsis)),
                  ]),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

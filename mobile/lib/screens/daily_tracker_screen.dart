import 'package:flutter/material.dart';
import '../services/supabase_service.dart';

class DailyTrackerScreen extends StatefulWidget {
  const DailyTrackerScreen({super.key});
  @override
  State<DailyTrackerScreen> createState() => _DailyTrackerScreenState();
}

class _DailyTrackerScreenState extends State<DailyTrackerScreen> {
  List<dynamic> _activity = [];
  bool _isLoading = true;
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() { super.initState(); _load(); }

  String _fmtISO(DateTime d) => '${d.year}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}';
  String _fmtDisplay(DateTime d) => '${d.day.toString().padLeft(2,'0')}.${d.month.toString().padLeft(2,'0')}.${d.year}';

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final dateStr = _fmtISO(_selectedDate);
      // Yeni şema: operation_plan_personnel + operation_plans
      final data = await SupabaseService.client
          .from('operation_plan_personnel')
          .select('''
            user_id, is_supervisor,
            users(id, first_name, last_name, role),
            operation_plans!inner(
              id, plan_date, start_time, end_time, status, site_instructions,
              order:orders(id, title, site_address, customer:customers(id, name)),
              company:orders(company:companies(name))
            )
          ''')
          .eq('operation_plans.plan_date', dateStr)
          .inFilter('operation_plans.status', ['sent', 'confirmed']);

      // Work session durumlarını al
      final planIds = (data as List).map((d) => d['operation_plans']?['id']).where((id) => id != null).toSet().toList();
      Map<String, dynamic> sessionMap = {};
      if (planIds.isNotEmpty) {
        final sessions = await SupabaseService.client
            .from('work_sessions')
            .select('user_id, operation_plan_id, status, actual_start, actual_end, actual_duration_h, note')
            .inFilter('operation_plan_id', planIds);
        for (final s in (sessions as List)) {
          final key = '${s['operation_plan_id']}_${s['user_id']}';
          sessionMap[key] = s;
        }
      }

      // Zenginleştirilmiş aktivite listesi
      final enriched = data.map((row) {
        final planId = row['operation_plans']?['id'];
        final userId = row['user_id'];
        final session = sessionMap['${planId}_$userId'];
        return {
          ...Map<String, dynamic>.from(row),
          'session': session,
        };
      }).toList();

      if (!mounted) return;
      setState(() { _activity = enriched; _isLoading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2024),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      locale: const Locale('tr', 'TR'),
    );
    if (d != null) { setState(() => _selectedDate = d); await _load(); }
  }

  bool get _isToday {
    final n = DateTime.now();
    return _selectedDate.year == n.year && _selectedDate.month == n.month && _selectedDate.day == n.day;
  }

  @override
  Widget build(BuildContext context) {
    final Map<String, List<dynamic>> byJob = {};
    for (final row in _activity) {
      final plan = row['operation_plans'];
      final order = plan?['order'];
      final jobKey = order?['title'] ?? 'Bilinmeyen İş';
      byJob.putIfAbsent(jobKey, () => []).add(row);
    }
    final sessionStarted  = _activity.where((r) => r['session']?['status'] == 'started').length;
    final sessionDone     = _activity.where((r) => r['session']?['status'] == 'completed').length;
    final sessionWaiting  = _activity.where((r) => r['session'] == null).length;
    final totalCount      = _activity.length;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFF),
      appBar: AppBar(
        backgroundColor: const Color(0xFF4F46E5),
        foregroundColor: Colors.white,
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Günlük Takip', style: TextStyle(fontWeight: FontWeight.bold)),
          Text(_fmtDisplay(_selectedDate), style: const TextStyle(fontSize: 11, color: Colors.white70)),
        ]),
        actions: [
          IconButton(icon: const Icon(Icons.calendar_today), onPressed: _pickDate),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: _isLoading
        ? const Center(child: CircularProgressIndicator(color: Color(0xFF4F46E5)))
        : RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Stats row
                Row(children: [
                  _statChip(sessionStarted.toString(), 'Sahada', Colors.green),
                  const SizedBox(width: 8),
                  _statChip(sessionDone.toString(), 'Bitti', Colors.grey),
                  const SizedBox(width: 8),
                  _statChip(sessionWaiting.toString(), 'Bekliyor', Colors.blue),
                  const SizedBox(width: 8),
                  _statChip(totalCount.toString(), 'Toplam', const Color(0xFF4F46E5)),
                ]),
                const SizedBox(height: 16),

                if (_isToday) Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.green.shade200)),
                  child: Row(children: [
                    Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle)),
                    const SizedBox(width: 10),
                    const Text('Bugünün canlı durumu görüntüleniyor.', style: TextStyle(color: Colors.green, fontWeight: FontWeight.w600)),
                  ]),
                ),

                if (_activity.isEmpty) Center(child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.event_busy, size: 60, color: Colors.grey.shade300),
                    const SizedBox(height: 12),
                    const Text('Bu gün için kayıt bulunamadı.', style: TextStyle(color: Colors.grey)),
                  ],
                )),

                // Group by job
                ...byJob.entries.map((entry) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Company header
                    Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)]),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(children: [
                        const Icon(Icons.business, color: Colors.white, size: 18),
                        const SizedBox(width: 8),
                        Text(entry.key, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                        const Spacer(),
                        Text('${entry.value.length} kişi', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                      ]),
                    ),
                    // Workers in this job
                    ...entry.value.map((row) {
                      final user = row['users'];
                      final plan = row['operation_plans'];
                      final sess = row['session'];
                      final isSupervisor = row['is_supervisor'] == true;
                      final sessStatus = sess?['status'] as String? ?? 'waiting';
                      Color statusColor;
                      IconData statusIcon;
                      switch(sessStatus) {
                        case 'started': statusColor = Colors.green; statusIcon = Icons.radio_button_checked; break;
                        case 'completed': statusColor = Colors.grey; statusIcon = Icons.check_circle_outline; break;
                        default: statusColor = Colors.blue; statusIcon = Icons.schedule;
                      }
                      final fullName = '${user?['first_name'] ?? ''} ${user?['last_name'] ?? ''}'.trim();
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
                          border: sessStatus == 'started' ? Border.all(color: Colors.green.shade200, width: 1) : null,
                        ),
                        child: Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 20,
                                    backgroundColor: isSupervisor ? Colors.amber.shade100 : const Color(0xFF4F46E5).withOpacity(0.08),
                                    child: Text(
                                      fullName.isNotEmpty ? fullName[0] : '?',
                                      style: TextStyle(fontWeight: FontWeight.bold, color: isSupervisor ? Colors.amber.shade800 : const Color(0xFF4F46E5)),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    Row(children: [
                                      Expanded(child: Text(fullName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15), overflow: TextOverflow.ellipsis)),
                                      if (isSupervisor) Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(color: Colors.amber.shade100, borderRadius: BorderRadius.circular(4)),
                                        child: const Text('SORUMLU', style: TextStyle(fontSize: 9, color: Colors.amber, fontWeight: FontWeight.bold)),
                                      ),
                                    ]),
                                    if (plan != null) Text(
                                      '${(plan['start_time'] ?? '--:--').toString().substring(0, 5)} – ${(plan['end_time'] ?? '--:--').toString().substring(0, 5)}',
                                      style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                                    ),
                                  ])),
                                  _statusBadge(sessStatus, statusColor, statusIcon),
                                ],
                              ),
                            ),

                            // Gerçekleşen bilgiler
                            if (sess != null && (sess['actual_start'] != null || sess['actual_end'] != null))
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade50.withValues(alpha: 0.5),
                                  borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(16), bottomRight: Radius.circular(16)),
                                ),
                                child: Row(children: [
                                  const Icon(Icons.bolt, size: 14, color: Color(0xFF4F46E5)),
                                  const SizedBox(width: 6),
                                  Expanded(child: Text(
                                    'Gerçekleşen: ${sess['actual_start'] != null ? DateTime.parse(sess['actual_start']).toLocal().toString().substring(11, 16) : '?'} – ${sess['actual_end'] != null ? DateTime.parse(sess['actual_end']).toLocal().toString().substring(11, 16) : 'Devam ediyor'}',
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF4F46E5)),
                                  )),
                                  if (sess['actual_duration_h'] != null)
                                    Text('${double.tryParse(sess['actual_duration_h'].toString())?.toStringAsFixed(1) ?? '?'} s', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                ]),
                              ),
                          ],
                        ),
                      );
                    }),
                    const SizedBox(height: 12),
                  ],
                )).toList(),
              ],
            ),
          ),
    );
  }

  Widget _miniAlert(String msg, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4), border: Border.all(color: color.withValues(alpha: 0.2))),
    child: Text(msg, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
  );

  Widget _statusBadge(String status, Color color, IconData icon) {
    String label = status == 'active' ? 'SAHADA' : (status == 'completed' ? 'BİTTİ' : 'BEKLİYOR');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
        ],
      ),
    );
  }

  Widget _statChip(String val, String label, Color color) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(14), border: Border.all(color: color.withValues(alpha: 0.3))),
      child: Column(children: [
        Text(val, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: color)),
        Text(label, style: TextStyle(fontSize: 10, color: color.withValues(alpha: 0.8), fontWeight: FontWeight.w600)),
      ]),
    ),
  );
}

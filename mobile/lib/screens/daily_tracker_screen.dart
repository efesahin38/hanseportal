import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';

class DailyTrackerScreen extends StatefulWidget {
  const DailyTrackerScreen({Key? key}) : super(key: key);
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
      final data = await context.read<AppState>().apiService.getTodayActivity(date: _fmtISO(_selectedDate));
      if (!mounted) return;
      setState(() { _activity = data; _isLoading = false; });
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
    // Group by company
    final Map<String, List<dynamic>> byCompany = {};
    for (final row in _activity) {
      final company = row['company_name'] ?? row['company_id'] ?? 'Bilinmiyor';
      byCompany.putIfAbsent(company, () => []).add(row);
    }

    final activeCount    = _activity.where((r) => r['shift_status'] == 'active').length;
    final completedCount = _activity.where((r) => r['shift_status'] == 'completed').length;
    final assignedCount  = _activity.where((r) => r['shift_status'] == 'assigned').length;
    final totalCount     = _activity.length;

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
                  _statChip(activeCount.toString(), 'Sahada', Colors.green),
                  const SizedBox(width: 8),
                  _statChip(completedCount.toString(), 'Bitti', Colors.grey),
                  const SizedBox(width: 8),
                  _statChip(assignedCount.toString(), 'Bekliyor', Colors.blue),
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

                // Group by company
                ...byCompany.entries.map((entry) => Column(
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
                    // Workers in this company
                    ...entry.value.map((row) {
                      final status = row['shift_status'] ?? 'assigned';
                      final isLeader = row['role_in_shift'] == 'leader';
                      Color statusColor;
                      String statusLabel;
                      IconData statusIcon;
                      switch(status) {
                        case 'active': statusColor = Colors.green; statusLabel = 'SAHADA'; statusIcon = Icons.radio_button_checked; break;
                        case 'completed': statusColor = Colors.grey; statusLabel = 'BİTTİ'; statusIcon = Icons.check_circle_outline; break;
                        default: statusColor = Colors.blue; statusLabel = 'BEKLİYOR'; statusIcon = Icons.schedule;
                      }
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4))],
                          border: status == 'active' ? Border.all(color: Colors.green.shade200, width: 1) : null,
                        ),
                        child: Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 20,
                                    backgroundColor: isLeader ? Colors.amber.shade100 : const Color(0xFF4F46E5).withValues(alpha: 0.08),
                                    child: Text(
                                      (row['worker_name'] as String? ?? '?').substring(0, 1),
                                      style: TextStyle(fontWeight: FontWeight.bold, color: isLeader ? Colors.amber.shade800 : const Color(0xFF4F46E5)),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Text(row['worker_name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                            const SizedBox(width: 6),
                                            Text('#${row['worker_id'] ?? ''}', style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontWeight: FontWeight.w500)),
                                            if (isLeader) ...[
                                              const SizedBox(width: 8),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(color: Colors.amber.shade100, borderRadius: BorderRadius.circular(4)),
                                                child: const Text('LİDER', style: TextStyle(fontSize: 9, color: Colors.amber, fontWeight: FontWeight.bold)),
                                              ),
                                            ],
                                          ],
                                        ),
                                        const SizedBox(height: 2),
                                        Row(
                                          children: [
                                            const Icon(Icons.access_time, size: 12, color: Colors.grey),
                                            const SizedBox(width: 4),
                                            Text(
                                              'Planlanan: ${(row['plan_start'] ?? '').toString().substring(0,5)} - ${(row['plan_end'] ?? '').toString().substring(0,5)}',
                                              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  _statusBadge(status, statusColor, statusIcon),
                                ],
                              ),
                            ),
                            
                            // Gerçekleşen bilgiler (Eğer varsa)
                            if (row['actual_start'] != null || row['actual_end'] != null)
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade50.withValues(alpha: 0.5),
                                  borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(16), bottomRight: Radius.circular(16)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(Icons.bolt, size: 14, color: Color(0xFF4F46E5)),
                                        const SizedBox(width: 6),
                                        Text(
                                          'Gerçekleşen: ${row['actual_start'] != null ? DateTime.parse(row['actual_start']).toLocal().toString().substring(11, 16) : '?'} - ${row['actual_end'] != null ? DateTime.parse(row['actual_end']).toLocal().toString().substring(11, 16) : 'Devam Ediyor'}',
                                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF4F46E5)),
                                        ),
                                      ],
                                    ),
                                    // Gecikme/Erken bitirme uyarıları
                                    Builder(builder: (ctx) {
                                      final List<Widget> alerts = [];
                                      if (row['actual_start'] != null && row['plan_start'] != null) {
                                        final act = DateTime.parse(row['actual_start']).toLocal();
                                        final planTimeParts = (row['plan_start'] as String).split(':');
                                        final plan = DateTime(act.year, act.month, act.day, int.parse(planTimeParts[0]), int.parse(planTimeParts[1]));
                                        final diff = act.difference(plan).inMinutes;
                                        if (diff > 5) alerts.add(_miniAlert('⚠️ $diff dk geç başladı', Colors.red));
                                        else if (diff < -5) alerts.add(_miniAlert('🚀 ${diff.abs()} dk erken başladı', Colors.green));
                                      }
                                      if (row['actual_end'] != null && row['plan_end'] != null) {
                                        final act = DateTime.parse(row['actual_end']).toLocal();
                                        final planTimeParts = (row['plan_end'] as String).split(':');
                                        final plan = DateTime(act.year, act.month, act.day, int.parse(planTimeParts[0]), int.parse(planTimeParts[1]));
                                        final diff = plan.difference(act).inMinutes;
                                        if (diff > 5) alerts.add(_miniAlert('⚠️ $diff dk erken bitirdi', Colors.orange));
                                        else if (diff < -5) alerts.add(_miniAlert('➕ ${diff.abs()} dk fazla çalıştı', Colors.blue));
                                      }
                                      if (alerts.isEmpty) return const SizedBox.shrink();
                                      return Padding(
                                        padding: const EdgeInsets.only(top: 6, left: 20),
                                        child: Wrap(spacing: 6, runSpacing: 4, children: alerts),
                                      );
                                    }),
                                    if (row['exit_note'] != null && (row['exit_note'] as String).isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 8, left: 20),
                                        child: Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(color: Colors.orange.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                                          child: Text(
                                            '📝 Not: ${row['exit_note']}',
                                            style: TextStyle(color: Colors.orange.shade900, fontSize: 11, fontStyle: FontStyle.italic, fontWeight: FontWeight.w600),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
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

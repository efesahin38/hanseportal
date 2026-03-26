import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../services/supabase_service.dart';
import 'login_screen.dart';

String _safeTime(String? time) {
  if (time == null || time.length < 5) return time ?? '--:--';
  return time.substring(0, 5);
}

class ManagerDashboardScreen extends StatefulWidget {
  @override
  _ManagerDashboardScreenState createState() => _ManagerDashboardScreenState();
}

class _ManagerDashboardScreenState extends State<ManagerDashboardScreen> {
  List<dynamic> _plans = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPlans();
  }

  Future<void> _loadPlans() async {
    setState(() => _isLoading = true);
    try {
      final plans = await SupabaseService.getOperationPlans();
      setState(() { _plans = plans; _isLoading = false; });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'approved': return Colors.green;
      case 'rejected': return Colors.red;
      default: return Colors.orange;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'approved': return 'ONAYLANDI ✓';
      case 'rejected': return 'REDDEDİLDİ ✗';
      default: return 'BEKLEMEDE...';
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.read<AppState>().currentUser;
    final companyName = user?['company_id'] ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFFF0FDF4),
      appBar: AppBar(
        backgroundColor: const Color(0xFF16A34A),
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(user?['name'] ?? '', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            Text('$companyName Yöneticisi', style: const TextStyle(fontSize: 11, color: Colors.white70)),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadPlans),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await context.read<AppState>().signOut();
              if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
            },
          )
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF16A34A),
        onPressed: _loadPlans,
        icon: const Icon(Icons.refresh, color: Colors.white),
        label: const Text('Yenile', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: _isLoading
        ? const Center(child: CircularProgressIndicator(color: Color(0xFF16A34A)))
        : RefreshIndicator(
            onRefresh: _loadPlans,
            child: _plans.isEmpty
              ? Center(child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.calendar_today, size: 64, color: Colors.green.shade200),
                    const SizedBox(height: 16),
                    const Text('Henüz plan oluşturulmadı.', style: TextStyle(color: Colors.grey, fontSize: 16)),
                    const SizedBox(height: 8),
                    const Text('Sağ alttaki + butonuna basın.', style: TextStyle(color: Colors.grey)),
                  ],
                ))
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                  itemCount: _plans.length,
                  itemBuilder: (ctx, i) {
                    final plan = _plans[i];
                    final status = plan['status'] ?? 'pending';
                    final assignments = List<dynamic>.from(plan['shift_assignments'] ?? []);
                    return Container(
                      margin: const EdgeInsets.only(bottom: 14),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)]),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: _statusColor(status).withOpacity(0.1),
                              borderRadius: const BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
                              border: Border(bottom: BorderSide(color: _statusColor(status).withOpacity(0.3))),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.calendar_month, size: 18, color: _statusColor(status)),
                                const SizedBox(width: 8),
                                Text(plan['work_date'] ?? '', style: TextStyle(fontWeight: FontWeight.bold, color: _statusColor(status))),
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(color: _statusColor(status).withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
                                  child: Text(_statusLabel(status), style: TextStyle(color: _statusColor(status), fontWeight: FontWeight.bold, fontSize: 11)),
                                )
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(children: [
                                  const Icon(Icons.access_time, size: 16, color: Colors.grey),
                                  const SizedBox(width: 6),
                                  Text('${_safeTime(plan['start_time'])} - ${_safeTime(plan['end_time'])}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                                ]),
                                if (status == 'rejected' && plan['rejection_note'] != null) ...[
                                  const SizedBox(height: 10),
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(10)),
                                    child: Row(children: [
                                      const Icon(Icons.info_outline, color: Colors.red, size: 16),
                                      const SizedBox(width: 8),
                                      Expanded(child: Text(plan['rejection_note'], style: const TextStyle(color: Colors.red, fontSize: 13))),
                                    ]),
                                  )
                                ],
                                const SizedBox(height: 12),
                                ...assignments.map((a) => Padding(
                                  padding: const EdgeInsets.only(bottom: 4),
                                  child: Row(children: [
                                    Icon(a['role_in_shift'] == 'leader' ? Icons.star : Icons.person_outline, size: 16, color: a['role_in_shift'] == 'leader' ? Colors.amber.shade700 : Colors.grey),
                                    const SizedBox(width: 6),
                                    Text(a['worker_name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
                                    const SizedBox(width: 6),
                                    Text(a['role_in_shift'] == 'leader' ? 'LİDER' : 'ÇALIŞAN', style: TextStyle(fontSize: 11, color: a['role_in_shift'] == 'leader' ? Colors.amber.shade700 : Colors.grey)),
                                  ]),
                                )).toList(),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
          ),
    );
  }
}

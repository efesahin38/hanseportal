import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../theme/web_utils.dart'; // WebUtils ekle
import '../providers/app_state.dart';
import '../services/supabase_service.dart';
import 'package:intl/intl.dart';

class WorkSessionApprovalScreen extends StatefulWidget {
  const WorkSessionApprovalScreen({super.key});

  @override
  State<WorkSessionApprovalScreen> createState() => _WorkSessionApprovalScreenState();
}

class _WorkSessionApprovalScreenState extends State<WorkSessionApprovalScreen> {
  Map<String, List<Map<String, dynamic>>> _groupedSessions = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final appState = context.read<AppState>();
      String? deptId = appState.isBereichsleiter ? appState.departmentId : null;
      final data = await SupabaseService.getWorkSessionsPendingApproval(departmentId: deptId);
      
      // Group by operation_plan_id or order_id
      Map<String, List<Map<String, dynamic>>> groups = {};
      for (var s in data) {
        final key = s['operation_plan_id'] ?? s['order_id'] ?? 'unknown';
        if (!groups.containsKey(key)) groups[key] = [];
        groups[key]!.add(s);
      }

      setState(() {
        _groupedSessions = groups;
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _approveExtraWork(String extraWorkId) async {
    setState(() => _loading = true);
    try {
      final appState = context.read<AppState>();
      await SupabaseService.approveExtraWork(extraWorkId, appState.userId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Ek iş onaylandı.'), backgroundColor: AppTheme.success));
        _load();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _approveGroup(List<Map<String, dynamic>> sessions, bool usePlanned) async {
    try {
      final appState = context.read<AppState>();
      for (var s in sessions) {
        final plan = s['operation_plan'];
        final plannedHours = (plan?['estimated_duration_h'] as num?)?.toDouble() ?? 0.0;
        final actualHours = (s['actual_duration_h'] as num?)?.toDouble() ?? 0.0;
        final approvedHours = usePlanned ? plannedHours : actualHours;
        
        await SupabaseService.approveWorkSession(s['id'], approvedHours, appState.userId);
      }
      
      // Siparişi tamamlandı olarak işaretle
      if (sessions.isNotEmpty) {
        final orderId = sessions.first['order_id'] ?? sessions.first['order']?['id'];
        if (orderId != null) {
          try {
            final order = await SupabaseService.client.from('orders').select('status').eq('id', orderId).single();
            if (order['status'] != 'completed' && order['status'] != 'invoiced') {
              await SupabaseService.updateOrderStatus(orderId, 'completed', 'Mesailer onaylandı', appState.userId);
            }
          } catch (e) {
            print('Status complete error: $e');
          }
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('✅ ${sessions.length} personelin mesaisi onaylandı.'), backgroundColor: AppTheme.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Toplu Mesai Onayı', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Inter')),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: WebContentWrapper(
        padding: EdgeInsets.zero,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _groupedSessions.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _groupedSessions.length,
                    itemBuilder: (context, index) {
                      final key = _groupedSessions.keys.elementAt(index);
                      final projectSessions = _groupedSessions[key]!;
                      return _ProjectApprovalCard(
                        sessions: projectSessions,
                        onApproveAll: (usePlanned) => _approveGroup(projectSessions, usePlanned),
                        onApproveExtraWork: _approveExtraWork,
                      );
                    },
                  ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.fact_check_outlined, size: 64, color: Colors.blue.withOpacity(0.3)),
          const SizedBox(height: 16),
          const Text('Onay bekleyen proje bulunmuyor.', style: TextStyle(color: AppTheme.textSub, fontFamily: 'Inter')),
        ],
      ),
    );
  }
}

class _ProjectApprovalCard extends StatefulWidget {
  final List<Map<String, dynamic>> sessions;
  final Future<void> Function(bool) onApproveAll;
  final Future<void> Function(String) onApproveExtraWork;

  const _ProjectApprovalCard({
    required this.sessions,
    required this.onApproveAll,
    required this.onApproveExtraWork,
  });

  @override
  State<_ProjectApprovalCard> createState() => _ProjectApprovalCardState();
}

class _ProjectApprovalCardState extends State<_ProjectApprovalCard> {
  bool _isApproved = false;
  bool _isLoading = false;
  final Set<String> _approvedExtraWorks = {};

  @override
  Widget build(BuildContext context) {
    if (widget.sessions.isEmpty) return const SizedBox.shrink();
    
    final first = widget.sessions.first;
    final order = first['order'];
    final plan = first['operation_plan'];
    final start = first['actual_start'] != null ? DateTime.parse(first['actual_start']).toLocal() : null;
    final dateStr = start != null ? DateFormat('dd.MM.yyyy').format(start) : '--';

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.blue.withOpacity(0.1)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 15, offset: const Offset(0, 5))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.05),
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(order?['title'] ?? 'İsimsiz Proje', 
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.primary)),
                      Text('Tarih: $dateStr • ${widget.sessions.length} Çalışan', 
                          style: const TextStyle(fontSize: 12, color: AppTheme.textSub)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Personnel List
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: widget.sessions.map((s) {
                final user = s['user'];
                final actual = (s['actual_duration_h'] as num?)?.toDouble() ?? 0.0;
                final planned = (plan?['estimated_duration_h'] as num?)?.toDouble() ?? 0.0;
                
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: AppTheme.secondary.withOpacity(0.1),
                        child: Text(user != null && user['first_name'] != null ? user['first_name'][0] : '?', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text('${user?['first_name'] ?? 'Bilinmeyen'} ${user?['last_name'] ?? ''}', 
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: Colors.blue.withOpacity(0.05), borderRadius: BorderRadius.circular(8)),
                        child: Text('P: ${planned.toStringAsFixed(1)}s', style: const TextStyle(fontSize: 11, color: Colors.blue)),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: Colors.orange.withOpacity(0.05), borderRadius: BorderRadius.circular(8)),
                        child: Text('G: ${actual.toStringAsFixed(1)}s', style: const TextStyle(fontSize: 11, color: Colors.orange)),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          
          // Pending Extra Works Section
          if (order != null && order['extra_works'] != null && (order['extra_works'] as List).isNotEmpty) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.add_circle_outline, size: 16, color: Colors.orange),
                      SizedBox(width: 8),
                      Text('Onay Bekleyen Ek İşler', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.orange)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ...(order['extra_works'] as List).where((ew) => ew['status'] == 'pending' || ew['status'] == 'recorded').map((ew) {
                    final recordedBy = ew['recorded_by_user'];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.orange.withOpacity(0.2)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(ew['title'] ?? 'Ek İş', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                if (ew['description'] != null && ew['description'].isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 2, bottom: 4),
                                    child: Text(ew['description'], style: const TextStyle(fontSize: 12, color: AppTheme.textMain, fontFamily: 'Inter')),
                                  ),
                                Row(
                                  children: [
                                    Text('Kaydeden: ${recordedBy?['first_name'] ?? ''} ${recordedBy?['last_name'] ?? ''}', 
                                        style: const TextStyle(fontSize: 11, color: AppTheme.textSub)),
                                    const Spacer(),
                                    if (ew['duration_h'] != null)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                                        child: Text('${ew['duration_h']} sa', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.orange)),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          _approvedExtraWorks.contains(ew['id'])
                            ? const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                child: Icon(Icons.check_circle, color: AppTheme.success, size: 24),
                              )
                            : ElevatedButton(
                                onPressed: () async {
                                  await widget.onApproveExtraWork(ew['id']);
                                  setState(() => _approvedExtraWorks.add(ew['id']));
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.success,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: const Text('Onayla', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                              ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ],
          
          const Divider(height: 1),
          
          // Actions
          Padding(
            padding: const EdgeInsets.all(12),
            child: _isApproved 
              ? Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: null,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          backgroundColor: Colors.grey.shade200,
                          disabledBackgroundColor: Colors.grey.shade200,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: const Icon(Icons.check_circle, color: AppTheme.success, size: 20),
                        label: const Text('Onaylandı', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.success, fontFamily: 'Inter')),
                      ),
                    ),
                  ],
                )
              : _isLoading
                  ? const Center(child: Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator()))
                  : Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () async {
                              setState(() => _isLoading = true);
                              await widget.onApproveAll(true);
                              if (mounted) setState(() { _isLoading = false; _isApproved = true; });
                            },
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              side: const BorderSide(color: AppTheme.primary),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            child: const Text('Planlananla Onayla', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'Inter')),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () async {
                              setState(() => _isLoading = true);
                              await widget.onApproveAll(false);
                              if (mounted) setState(() { _isLoading = false; _isApproved = true; });
                            },
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              backgroundColor: Colors.orange,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            child: const Text('Gerçekleşenle Onayla', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'Inter')),
                          ),
                        ),
                      ],
                    ),
          ),
        ],
      ),
    );
  }
}

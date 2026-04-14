import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../theme/web_utils.dart'; // WebUtils ekle
import '../providers/app_state.dart';
import '../services/supabase_service.dart';
import 'package:intl/intl.dart';
import '../services/localization_service.dart';

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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${tr('Hata')}: $e')));
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('Ek iş onaylandı.')), backgroundColor: AppTheme.success));
        _load();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${tr('Hata')}: $e')));
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
              await SupabaseService.updateOrderStatus(orderId, 'completed', tr('Mesailer onaylandı'), appState.userId);
            }
          } catch (e) {
            print('Status complete error: $e');
          }
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('{count} personelin mesaisi onaylandı.', args: {'count': sessions.length.toString()})), backgroundColor: AppTheme.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${tr('Hata')}: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(tr('Toplu Mesai Onayı'), style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Inter')),
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
          Text(tr('Onay bekleyen proje bulunmuyor.'), style: const TextStyle(color: AppTheme.textSub, fontFamily: 'Inter')),
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
  final Set<String> _approvedSessionIds = {};
  final Map<String, double> _editedHours = {};

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
                      Text(order?['title'] ?? tr('İsimsiz Proje'),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.primary)),
                      Text(tr('Tarih: {date} • {count} Çalışan', args: { 'date': dateStr, 'count': widget.sessions.length.toString() }),
                          style: const TextStyle(fontSize: 12, color: AppTheme.textSub)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Personnel List Table
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: widget.sessions.map((s) {
                final sessionId = s['id'].toString();
                final isSessionApproved = _approvedSessionIds.contains(sessionId);
                final user = s['user'];
                final actual = (s['actual_duration_h'] as num?)?.toDouble() ?? 0.0;
                final planned = (plan?['estimated_duration_h'] as num?)?.toDouble() ?? 0.0;

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isSessionApproved ? AppTheme.success.withOpacity(0.05) : AppTheme.bg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isSessionApproved ? AppTheme.success.withOpacity(0.2) : AppTheme.divider),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 14,
                            backgroundColor: AppTheme.primary.withOpacity(0.1),
                            child: Text(user != null && user['first_name'] != null ? user['first_name'][0] : '?', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text('${user?['first_name'] ?? tr('Bilinmeyen')} ${user?['last_name'] ?? ''}',
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                          ),
                          if (isSessionApproved)
                            const Icon(Icons.check_circle, color: AppTheme.success, size: 20)
                        ],
                      ),
                      const Divider(height: 16),
                      Row(
                        children: [
                          _buildActionBtn(
                            label: '${tr('Planlanan')}: ${planned.toStringAsFixed(1)}h',
                            color: Colors.blue,
                            isSelected: false,
                            onTap: isSessionApproved ? null : () => _approveIndividual(sessionId, planned),
                          ),
                          const SizedBox(width: 8),
                          _buildActionBtn(
                            label: '${tr('Gerçekleşen')}: ${actual.toStringAsFixed(1)}h',
                            color: Colors.orange,
                            isSelected: false,
                            onTap: isSessionApproved ? null : () => _approveIndividual(sessionId, actual),
                          ),
                          const SizedBox(width: 8),
                          _buildActionBtn(
                            label: tr('Düzenle'),
                            color: AppTheme.textSub,
                            icon: Icons.edit_outlined,
                            isSelected: false,
                            onTap: isSessionApproved ? null : () => _showEditDialog(sessionId, actual),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),

          // Pending Extra Works Section (Remains similar but styled)
          if (order != null && order['extra_works'] != null && (order['extra_works'] as List).where((ew) => ew['status'] == 'pending' || ew['status'] == 'recorded').isNotEmpty) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.add_circle_outline, size: 16, color: Colors.orange),
                      const SizedBox(width: 8),
                      Text(tr('Onay Bekleyen Ek İşler'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.orange)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ...(order['extra_works'] as List).where((ew) => ew['status'] == 'pending' || ew['status'] == 'recorded').map((ew) {
                    return _buildExtraWorkCard(ew);
                  }),
                ],
              ),
            ),
          ],

          const Divider(height: 1),

          // Project-level Action: Bulk Approval
          Padding(
            padding: const EdgeInsets.all(12),
            child: _isLoading ? const Center(child: CircularProgressIndicator()) : Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isLoading ? null : () => _bulkApprove(true),
                    child: Text(tr('Hepsini Planlananla Onayla'), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : () => _bulkApprove(false),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                    child: Text(tr('Hepsini Gerçekleşenle Onayla'), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionBtn({required String label, required Color color, IconData? icon, bool isSelected = false, VoidCallback? onTap}) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: onTap == null ? Colors.grey.withOpacity(0.1) : color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: onTap == null ? Colors.transparent : color.withOpacity(0.3)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[Icon(icon, size: 14, color: color), const SizedBox(width: 4)],
              Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: onTap == null ? AppTheme.textSub : color)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExtraWorkCard(Map<String, dynamic> ew) {
    bool isApproved = _approvedExtraWorks.contains(ew['id']);
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
                Text(ew['title'] ?? tr('Ek İş'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                Text(tr('Kaydeden: {name}', args: {'name': '${recordedBy?['first_name'] ?? ''} ${recordedBy?['last_name'] ?? ''}'}),
                    style: const TextStyle(fontSize: 10, color: AppTheme.textSub)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          isApproved
            ? const Icon(Icons.check_circle, color: AppTheme.success, size: 24)
            : ElevatedButton(
                onPressed: () async {
                  await widget.onApproveExtraWork(ew['id']);
                  setState(() => _approvedExtraWorks.add(ew['id']));
                },
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.success, minimumSize: const Size(60, 32)),
                child: Text(tr('Onayla'), style: const TextStyle(fontSize: 11, color: Colors.white)),
              ),
        ],
      ),
    );
  }

  void _showEditDialog(String sessionId, double initialValue) async {
    final ctrl = TextEditingController(text: initialValue.toString());
    final result = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('Çalışma Saatini Düzenle')),
        content: TextField(
          controller: ctrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(labelText: tr('Onaylanan Saat')),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(tr('İptal'))),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, double.tryParse(ctrl.text)), child: Text(tr('Onayla'))),
        ],
      ),
    );
    if (result != null) {
      _approveIndividual(sessionId, result);
    }
  }

  Future<void> _approveIndividual(String sessionId, double hours) async {
    final appState = context.read<AppState>();
    try {
      await SupabaseService.approveWorkSession(sessionId, hours, appState.userId);
      setState(() => _approvedSessionIds.add(sessionId));
      
      // Check if all sessions in this card are approved to show the overall success
      if (_approvedSessionIds.length == widget.sessions.length) {
         setState(() => _isApproved = true);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('Hata: {e}', args: {'e': e.toString()}))));
    }
  }

  Future<void> _bulkApprove(bool usePlanned) async {
    setState(() => _isLoading = true);
    await widget.onApproveAll(usePlanned);
    setState(() {
      _isLoading = false;
      _isApproved = true;
      for (var s in widget.sessions) {
        _approvedSessionIds.add(s['id'].toString());
      }
    });
  }
}


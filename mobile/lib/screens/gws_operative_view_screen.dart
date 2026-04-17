import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../theme/web_utils.dart';
import '../providers/app_state.dart';
import '../services/supabase_service.dart';
import '../services/localization_service.dart';
import 'gws_item_form_screen.dart';

class GwsOperativeViewScreen extends StatefulWidget {
  const GwsOperativeViewScreen({super.key});

  @override
  State<GwsOperativeViewScreen> createState() => _GwsOperativeViewScreenState();
}

class _GwsOperativeViewScreenState extends State<GwsOperativeViewScreen> {
  static const Color _color = AppTheme.gwsColor;
  bool _loading = true;
  List<Map<String, dynamic>> _tasks = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final appState = context.read<AppState>();
    setState(() => _loading = true);
    try {
      final tasks = await SupabaseService.getGwsTasksForUser(appState.userId);
      if (mounted) setState(() { _tasks = tasks; _loading = false; });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _updateStatus(Map<String, dynamic> task, String newStatus) async {
    try {
      await SupabaseService.updateGwsTaskStatus(
        type: task['type'],
        id: task['id'],
        status: newStatus,
      );
      _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e'), backgroundColor: AppTheme.error));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('GWS - Meine Aufgaben', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold)),
        backgroundColor: _color,
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _load)],
      ),
      body: WebContentWrapper(
        child: _loading 
          ? const Center(child: CircularProgressIndicator())
          : _tasks.isEmpty
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.bed_outlined, size: 64, color: _color.withOpacity(0.2)),
                    const SizedBox(height: 16),
                    const Text('Keine zugewiesenen Aufgaben für heute.', style: TextStyle(color: AppTheme.textSub)),
                  ],
                ),
              )
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _tasks.length,
                  itemBuilder: (context, i) {
                    final t = _tasks[i];
                    final isRoom = t['type'] == 'room';
                    final plan = t['plan'] as Map<String, dynamic>?;
                    final object = plan?['object'] as Map<String, dynamic>?;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(color: _color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                                  child: Icon(isRoom ? Icons.bed : Icons.location_city, color: _color, size: 20),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(object?['name'] ?? 'Objekt', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textSub)),
                                      Text(isRoom ? 'Zimmer ${t['room_number']}' : '${t['area_name']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                                    ],
                                  ),
                                ),
                                _statusBadge(t['status']),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text('${t['category'] ?? t['area_type'] ?? ''} - ${t['service_type'] ?? ''}', style: const TextStyle(color: AppTheme.textSub, fontSize: 14)),
                            if (t['notes'] != null && t['notes'].toString().isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text('Hinweis: ${t['notes']}', style: const TextStyle(color: AppTheme.error, fontSize: 12, fontWeight: FontWeight.w600)),
                            ],
                            const Divider(height: 24),
                            Row(
                              children: [
                                if (t['status'] == 'todo')
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(backgroundColor: _color, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                                      onPressed: () => _updateStatus(t, 'doing'),
                                      icon: const Icon(Icons.play_arrow),
                                      label: const Text('Beginnen'),
                                    ),
                                  )
                                else if (t['status'] == 'doing')
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(backgroundColor: AppTheme.success, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => GwsItemFormScreen(item: t, type: isRoom ? 'room' : 'area', planId: t['plan_id'] ?? t['plan']?['id'] ?? ''))).then((_) => _load()),
                                      icon: const Icon(Icons.assignment_turned_in),
                                      label: const Text('Formular & Abschliessen'),
                                    ),
                                  )
                                else if (t['status'] == 'done')
                                  // Eğer takım lideriyse onaylayabilir
                                  _buildLeaderApprovalButton(t)
                                else
                                  const Expanded(child: Center(child: Text('Geprüft ✓', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)))),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
      ),
    );
  }

  Widget _buildLeaderApprovalButton(Map<String, dynamic> t) {
    final assignments = t['plan']?['assignments'] as List?;
    final isLeader = assignments?.any((a) => a['is_team_leader'] == true) ?? false;
    final isRoom = t['type'] == 'room';

    if (!isLeader) {
       return const Expanded(child: Center(child: Text('Wartet auf Kontrolle...', style: TextStyle(color: AppTheme.success, fontWeight: FontWeight.bold, fontSize: 13))));
    }

    return Expanded(
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => GwsItemFormScreen(item: t, type: isRoom ? 'room' : 'area', planId: t['plan_id'] ?? t['plan']?['id'] ?? ''))).then((_) => _load()),
        icon: const Icon(Icons.verified_user),
        label: const Text('Kontrol Et & Onayla'),
      ),
    );
  }

  Widget _statusBadge(String? s) {
    Color c = Colors.grey;
    String txt = s ?? 'todo';
    if (s == 'doing') { c = Colors.orange; txt = 'Bearbeitung'; }
    if (s == 'done') { c = AppTheme.success; txt = 'Fertig'; }
    if (s == 'checked') { c = Colors.blue; txt = 'Geprüft'; }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: c.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
      child: Text(txt, style: TextStyle(color: c, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }
}

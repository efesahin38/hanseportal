import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../theme/web_utils.dart';
import '../services/supabase_service.dart';

class GwsProgressDetailScreen extends StatefulWidget {
  final String planId;
  final String objectName;
  const GwsProgressDetailScreen({super.key, required this.planId, required this.objectName});

  @override
  State<GwsProgressDetailScreen> createState() => _GwsProgressDetailScreenState();
}

class _GwsProgressDetailScreenState extends State<GwsProgressDetailScreen> {
  static const Color _color = AppTheme.gwsColor;
  bool _loading = true;
  List<Map<String, dynamic>> _rooms = [];
  List<Map<String, dynamic>> _areas = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final rooms = await SupabaseService.getGwsPlanRooms(widget.planId);
      final areas = await SupabaseService.getGwsPlanAreas(widget.planId);
      if (mounted) setState(() { _rooms = rooms; _areas = areas; _loading = false; });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  double get _progress {
    final total = _rooms.length + _areas.length;
    if (total == 0) return 0;
    final done = _rooms.where((r) => r['status'] == 'done' || r['status'] == 'checked').length +
                 _areas.where((a) => a['status'] == 'done' || a['status'] == 'checked').length;
    return done / total;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: _color,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Canlı İş Takibi / Fortschritt', style: TextStyle(fontSize: 16)),
            Text(widget.objectName, style: const TextStyle(fontSize: 12, color: Colors.white70)),
          ],
        ),
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _load)],
      ),
      body: WebContentWrapper(
        child: _loading 
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildProgressBar(),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      if (_rooms.isNotEmpty) ...[
                        const Text('Zimmer', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 8),
                        ..._rooms.map((r) => _buildItemTile(r, true)),
                        const SizedBox(height: 24),
                      ],
                      if (_areas.isNotEmpty) ...[
                        const Text('Bereiche', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 8),
                        ..._areas.map((a) => _buildItemTile(a, false)),
                      ],
                    ],
                  ),
                ),
              ],
            ),
      ),
    );
  }

  Widget _buildProgressBar() {
    final perc = (_progress * 100).toInt();
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: _color.withOpacity(0.05), border: Border(bottom: BorderSide(color: _color.withOpacity(0.1)))),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Gesamtfortschritt', style: TextStyle(fontWeight: FontWeight.bold, color: _color)),
              Text('%$perc', style: TextStyle(fontWeight: FontWeight.bold, color: _color, fontSize: 18)),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: _progress,
              minHeight: 12,
              backgroundColor: _color.withOpacity(0.1),
              valueColor: const AlwaysStoppedAnimation(AppTheme.success),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemTile(Map<String, dynamic> item, bool isRoom) {
    final status = item['status'] ?? 'todo';
    Color c = Colors.grey;
    IconData icon = Icons.pending_actions;
    String label = 'Wartet';

    if (status == 'doing') { c = Colors.orange; icon = Icons.play_circle_outline; label = 'Bearbeitung'; }
    if (status == 'done') { c = AppTheme.success; icon = Icons.check_circle_outline; label = 'Erledigt'; }
    if (status == 'checked') { c = Colors.blue; icon = Icons.verified_user_outlined; label = 'Geprüft'; }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.divider)),
      child: Row(
        children: [
          Icon(isRoom ? Icons.bed : Icons.room_service, size: 20, color: AppTheme.textSub),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              isRoom ? 'Zimmer ${item['room_number']}' : '${item['area_name']}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Row(
            children: [
              Icon(icon, size: 14, color: c),
              const SizedBox(width: 4),
              Text(label, style: TextStyle(color: c, fontSize: 12, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }
}

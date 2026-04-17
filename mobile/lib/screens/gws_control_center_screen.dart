import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../theme/web_utils.dart';
import '../services/supabase_service.dart';

class GwsControlCenterScreen extends StatefulWidget {
  const GwsControlCenterScreen({super.key});

  @override
  State<GwsControlCenterScreen> createState() => _GwsControlCenterScreenState();
}

class _GwsControlCenterScreenState extends State<GwsControlCenterScreen> {
  static const Color _color = AppTheme.gwsColor;
  bool _loading = true;
  List<Map<String, dynamic>> _doneTasks = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      // Get all tasks with status 'done' (awaiting control)
      final rooms = await SupabaseService.getAllGwsRoomsByStatus('done');
      if (mounted) setState(() { _doneTasks = rooms; _loading = false; });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _approve(Map<String, dynamic> task) async {
    try {
      await SupabaseService.updateGwsTaskStatus(
        type: 'room',
        id: task['id'],
        status: 'checked',
      );
      _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: _color,
        title: const Text('Kontroll- & Freigabe-Center', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold)),
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _load)],
      ),
      body: WebContentWrapper(
        child: _loading 
          ? const Center(child: CircularProgressIndicator())
          : _doneTasks.isEmpty
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.verified_outlined, size: 64, color: _color.withOpacity(0.2)),
                    const SizedBox(height: 16),
                    const Text('Alle fertigen Aufgaben sind geprüft.', style: TextStyle(color: AppTheme.textSub)),
                  ],
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _doneTasks.length,
                itemBuilder: (ctx, i) {
                  final t = _doneTasks[i];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      leading: CircleAvatar(backgroundColor: AppTheme.success.withOpacity(0.1), child: const Icon(Icons.check, color: AppTheme.success)),
                      title: Text('Zimmer ${t['room_number']} - ${t['plan']?['object']?['name'] ?? ''}'),
                      subtitle: Text('Gereinigt von: ${t['assigned_user']?['first_name'] ?? 'Unbekannt'}'),
                      trailing: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: _color),
                        onPressed: () => _approve(t),
                        child: const Text('Freigeben (Check)'),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}

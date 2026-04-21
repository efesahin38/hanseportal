import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../theme/web_utils.dart';
import '../services/localization_service.dart';
import '../services/supabase_service.dart';

class GwsPersonnelPlanningScreen extends StatefulWidget {
  final String planId;
  final String objectName;
  const GwsPersonnelPlanningScreen({super.key, required this.planId, required this.objectName});

  @override
  State<GwsPersonnelPlanningScreen> createState() => _GwsPersonnelPlanningScreenState();
}

class _GwsPersonnelPlanningScreenState extends State<GwsPersonnelPlanningScreen> {
  static const Color _color = AppTheme.gwsColor;
  bool _loading = true;
  bool _saving = false;
  List<Map<String, dynamic>> _personnel = [];
  List<Map<String, dynamic>> _assignments = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final personnel = await SupabaseService.getGwsPersonnel();
      final currentAssignments = await SupabaseService.getGwsPlanAssignments(widget.planId);
      if (mounted) {
        setState(() {
          _personnel = personnel;
          _assignments = currentAssignments.map((a) => {
            'user_id': a['user_id'],
            'role_in_plan': a['role_in_plan'],
            'is_team_leader': a['is_team_leader'] ?? false,
            'name': '${a['user']?['first_name'] ?? ''} ${a['user']?['last_name'] ?? ''}',
          }).toList();
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await SupabaseService.assignGwsPersonnel(
        planId: widget.planId,
        assignments: _assignments,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('Personalplanung gespeichert ✓')), backgroundColor: AppTheme.success));
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fehler: $e'), backgroundColor: AppTheme.error));
        setState(() => _saving = false);
      }
    }
  }

  void _addPersonnelDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('Personal Hinzufügen')),
        content: SizedBox(
          width: 400,
          height: 500,
          child: ListView.builder(
            itemCount: _personnel.length,
            itemBuilder: (ctx, i) {
              final p = _personnel[i];
              final pId = p['id'].toString();
              final isAssigned = _assignments.any((a) => a['user_id'] == pId);

              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: _color.withOpacity(0.1),
                  child: Text(p['first_name']?[0] ?? '', style: const TextStyle(color: _color)),
                ),
                title: Text('${p['first_name']} ${p['last_name']}'),
                subtitle: Text(AppTheme.roleLabel(p['role'] ?? '')),
                trailing: isAssigned ? const Icon(Icons.check_circle, color: AppTheme.success) : const Icon(Icons.add_circle_outline),
                onTap: isAssigned ? null : () {
                  setState(() {
                    _assignments.add({
                      'user_id': pId,
                      'role_in_plan': 'Reinigung',
                      'is_team_leader': false,
                      'name': '${p['first_name']} ${p['last_name']}',
                    });
                  });
                  Navigator.pop(ctx);
                },
              );
            },
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Schließen'))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: _color,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Personalplanung', style: TextStyle(fontSize: 16)),
            Text(widget.objectName, style: const TextStyle(fontSize: 12, color: Colors.white70)),
          ],
        ),
        actions: [
          if (_saving)
            const Center(child: Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))))
          else
            TextButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.check, color: Colors.white),
              label: const Text('Fertig', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: _color,
        onPressed: _addPersonnelDialog,
        child: const Icon(Icons.person_add),
      ),
      body: WebContentWrapper(
        child: _loading 
          ? const Center(child: CircularProgressIndicator())
          : _assignments.isEmpty
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.people_outline, size: 64, color: _color.withOpacity(0.2)),
                    const SizedBox(height: 16),
                    const Text('Noch kein Personal zugewiesen', style: TextStyle(color: AppTheme.textSub)),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: _color),
                      onPressed: _addPersonnelDialog,
                      icon: const Icon(Icons.add),
                      label: Text(tr('Personal auswählen')),
                    ),
                  ],
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _assignments.length,
                itemBuilder: (ctx, i) {
                  final a = _assignments[i];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          // Team Leader Star (Yıldız)
                          IconButton(
                            icon: Icon(
                              a['is_team_leader'] == true ? Icons.star : Icons.star_border,
                              color: a['is_team_leader'] == true ? Colors.orange : Colors.grey,
                            ),
                            onPressed: () {
                              setState(() {
                                // Sadece bir takım lideri olsun
                                for (var item in _assignments) {
                                  item['is_team_leader'] = false;
                                }
                                a['is_team_leader'] = true;
                              });
                            },
                            tooltip: 'Team Leader (Yıldız)',
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(a['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    _roleChip(a['role_in_plan'], (val) {
                                      setState(() => a['role_in_plan'] = val);
                                    }),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: AppTheme.error),
                            onPressed: () => setState(() => _assignments.removeAt(i)),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }

  Widget _roleChip(String current, Function(String) onSelect) {
    const roles = ['Reinigung', 'Checker', 'Vorarbeiter', 'Service'];
    return Row(
      children: roles.map((r) {
        final isSelected = current == r;
        return Padding(
          padding: const EdgeInsets.only(right: 6),
          child: ChoiceChip(
            label: Text(r, style: TextStyle(fontSize: 10, color: isSelected ? Colors.white : AppTheme.textSub)),
            selected: isSelected,
            selectedColor: _color,
            backgroundColor: Colors.grey.withOpacity(0.1),
            onSelected: (val) { if (val) onSelect(r); },
          ),
        );
      }).toList(),
    );
  }
}

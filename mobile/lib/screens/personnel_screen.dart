import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../theme/web_utils.dart';
import '../providers/app_state.dart';
import '../services/supabase_service.dart';
import 'personnel_form_screen.dart';

class PersonnelScreen extends StatefulWidget {
  const PersonnelScreen({super.key});

  @override
  State<PersonnelScreen> createState() => _PersonnelScreenState();
}

class _PersonnelScreenState extends State<PersonnelScreen> {
  List<Map<String, dynamic>> _all = [];
  List<Map<String, dynamic>> _filtered = [];
  bool _loading = true;
  String _search = '';
  String? _roleFilter;

  final _roles = {
    'Tümü': null,
    'Geschäftsführer': 'geschaeftsfuehrer',
    'Betriebsleiter': 'betriebsleiter',
    'Bereichsleiter': 'bereichsleiter',
    'Vorarbeiter': 'vorarbeiter',
    'Mitarbeiter': 'mitarbeiter',
    'Muhasebe': 'buchhaltung',
    'Backoffice': 'backoffice',
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final appState = context.read<AppState>();
    try {
      final departmentId = appState.isBereichsleiter ? appState.departmentId : null;
      final data = await SupabaseService.getUsers(
        companyId: (appState.isGeschaeftsfuehrer || appState.isSystemAdmin) ? null : appState.companyId,
        departmentId: departmentId,
        role: _roleFilter,
        status: 'active',
      );
      if (mounted) setState(() { _all = data; _applyFilter(); _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _applyFilter() {
    if (_search.isEmpty) {
      _filtered = _all;
    } else {
      final q = _search.toLowerCase();
      _filtered = _all.where((u) =>
        ('${u['first_name']} ${u['last_name']}').toLowerCase().contains(q) ||
        (u['email'] ?? '').toLowerCase().contains(q) ||
        (u['position_title'] ?? '').toLowerCase().contains(q)
      ).toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    final canCreate = context.watch<AppState>().canManageUsers;

    return Scaffold(
      floatingActionButton: canCreate
          ? FloatingActionButton.extended(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PersonnelFormScreen())).then((_) => _load()),
              icon: const Icon(Icons.person_add),
              label: const Text('Yeni Personel', style: TextStyle(fontFamily: 'Inter')),
            )
          : null,
      body: WebContentWrapper(
        padding: EdgeInsets.zero,
        child: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Column(
              children: [
                TextField(
                  onChanged: (v) => setState(() { _search = v; _applyFilter(); }),
                  decoration: const InputDecoration(
                    hintText: 'Ad, e-posta, görev ara...',
                    prefixIcon: Icon(Icons.search),
                    contentPadding: EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 34,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: _roles.entries.map((e) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(e.key, style: TextStyle(fontFamily: 'Inter', fontSize: 11,
                          color: _roleFilter == e.value ? Colors.white : AppTheme.textSub)),
                        selected: _roleFilter == e.value,
                        selectedColor: AppTheme.primary,
                        backgroundColor: AppTheme.bg,
                        onSelected: (_) {
                          setState(() { _roleFilter = e.value; _loading = true; });
                          _load();
                        },
                      ),
                    )).toList(),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _filtered.isEmpty
                    ? const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(Icons.person_off_outlined, size: 56, color: AppTheme.textSub),
                        SizedBox(height: 12),
                        Text('Personel bulunamadı', style: TextStyle(color: AppTheme.textSub, fontFamily: 'Inter')),
                      ]))
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: _filtered.length,
                          itemBuilder: (_, i) {
                            final u = _filtered[i];
                            final name = '${u['first_name']} ${u['last_name']}';
                            final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
                            return Card(
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: AppTheme.accent.withOpacity(0.15),
                                  child: Text(initial, style: const TextStyle(color: AppTheme.accent, fontWeight: FontWeight.bold, fontFamily: 'Inter')),
                                ),
                                title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, fontFamily: 'Inter')),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(AppTheme.roleLabel(u['role'] ?? ''), style: const TextStyle(fontSize: 12, color: AppTheme.primary, fontFamily: 'Inter', fontWeight: FontWeight.w500)),
                                    if (u['position_title'] != null)
                                      Text(u['position_title'], style: const TextStyle(fontSize: 11, color: AppTheme.textSub, fontFamily: 'Inter')),
                                  ],
                                ),
                                trailing: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(u['company']?['short_name'] ?? '', style: const TextStyle(fontSize: 10, color: AppTheme.textSub, fontFamily: 'Inter')),
                                    const SizedBox(height: 4),
                                    const Icon(Icons.chevron_right, color: AppTheme.border),
                                  ],
                                ),
                                isThreeLine: true,
                                onTap: () => Navigator.push(context, MaterialPageRoute(
                                  builder: (_) => PersonnelFormScreen(userId: u['id']),
                                )).then((_) => _load()),
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../theme/web_utils.dart';
import '../providers/app_state.dart';
import '../services/supabase_service.dart';
import '../services/localization_service.dart';
import 'personnel_form_screen.dart';
import 'personnel_detail_dashboard.dart';
import 'work_session_approval_screen.dart';

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
  Map<String, String> _approvalStatuses = {}; // employee_id -> status

    final _roles = {
      tr('Tümü'): null,
      'Geschäftsführer': 'geschaeftsfuehrer',
      'Betriebsleiter': 'betriebsleiter',
      'Bereichsleiter': 'bereichsleiter',
      'Vorarbeiter': 'vorarbeiter',
      'Mitarbeiter': 'mitarbeiter',
      tr('Muhasebe'): 'buchhaltung',
      'Backoffice': 'backoffice',
    };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await context.read<AppState>().refreshProfile();
      _load();
    });
  }

  /// Hizmet alanı adını kısa bölüm etiketine çevirir (kart sağında gösterim için)
  String _shortBolumLabel(String saName) {
    final n = saName.toLowerCase();
    if (n.contains('gast') || n.contains('hotel') || n.contains('hospit')) return 'GWS';
    if (n.contains('rail') || n.contains('gleis') || n.contains('db')) return 'DB-Gleis';
    if (n.contains('gebäud') || n.contains('reinigung') || n.contains('bau')) return 'Gebäude';
    if (n.contains('personal') || n.contains('über') || n.contains('verwal')) return 'Personal';
    return saName.length > 10 ? '${saName.substring(0, 10)}…' : saName;
  }

  Future<void> _load() async {
    final appState = context.read<AppState>();
    try {
      // Eğer GF, BF, Admin, Accounting, Backoffice ise herşeyi görür (companyId: null, serviceAreaIds: null)
      // Bu roller holding üzerindeki tüm personelleri görebilmeli.
      final isHighLevel = appState.isGeschaeftsfuehrer || 
                         appState.isSystemAdmin || 
                         appState.isBetriebsleiter || 
                         appState.isBuchhaltung || 
                         appState.isBackoffice;

      final data = await SupabaseService.getUsers(
        companyId: (appState.canViewAllPersonnel || appState.isBereichsleiter) ? null : appState.companyId,
        departmentId: null, // v1.0.3: Relaxed filtering to ensure visibility via Service Areas
        role: _roleFilter,
        status: 'active',
        serviceAreaIds: appState.canViewAllPersonnel ? null : (appState.serviceAreaIds.isEmpty ? null : appState.serviceAreaIds),
      );

      // 2. Bu ayın onay durumlarını çek
      final now = DateTime.now();
      final monthStr = '${now.year}-${now.month.toString().padLeft(2, '0')}';
      final approvals = await SupabaseService.getMonthlyApprovalsSummary(monthStr);
      final statusMap = <String, String>{};
      for (final a in approvals) {
        statusMap[a['employee_id'].toString()] = a['status'].toString();
      }

      if (mounted) {
        setState(() { 
          _all = data; 
          _approvalStatuses = statusMap;
          _applyFilter(); 
          _loading = false; 
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _applyFilter() {
    List<Map<String, dynamic>> baseList = _all;

    // Bereichsleiter: Mitarbeiter + Vorarbeiter görür (kendisi haricindekileri de)
    // "canViewAllPersonnel" yoksa filtresiz
    // Not: Bereichsleiter başka bölüm personelini de görebilmeli –
    // filtre _load() içinde department_id bazında yapılmıştır.
    if (context.read<AppState>().isBereichsleiter) {
      baseList = _all.where((u) {
        final r = (u['role'] ?? '').toString().toLowerCase();
        return r == 'mitarbeiter' || r == 'vorarbeiter' || u['id'] == context.read<AppState>().userId;
      }).toList();
    }

    if (_search.isEmpty) {
      _filtered = baseList;
    } else {
      final q = _search.toLowerCase();
      _filtered = baseList.where((u) =>
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
              label: Text(tr('Yeni Personel'), style: const TextStyle(fontFamily: 'Inter')),
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
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        onChanged: (v) => setState(() { _search = v; _applyFilter(); }),
                        decoration: InputDecoration(
                          hintText: tr('Ad, e-posta, görev ara...'),
                          prefixIcon: const Icon(Icons.search),
                          contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                        ),
                      ),
                    ),
                    if (context.watch<AppState>().isGeschaeftsfuehrer || 
                        context.watch<AppState>().isBetriebsleiter || 
                        context.watch<AppState>().isBereichsleiter || 
                        context.watch<AppState>().isBackoffice || 
                        context.watch<AppState>().isBuchhaltung ||
                        context.watch<AppState>().isSystemAdmin) ...[
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WorkSessionApprovalScreen())),
                        icon: const Icon(Icons.access_time, size: 18),
                        label: const Text('Arbeitszeiterfassung', style: TextStyle(fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ],
                  ],
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
                    ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        const Icon(Icons.person_off_outlined, size: 56, color: AppTheme.textSub),
                        const SizedBox(height: 12),
                        Text(tr('Personel bulunamadı'), style: const TextStyle(color: AppTheme.textSub, fontFamily: 'Inter')),
                      ]))
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: _filtered.length,
                          itemBuilder: (_, i) {
                            final u = _filtered[i];
                            final firstName = (u['first_name'] ?? '').toString().trim();
                            final lastName = (u['last_name'] ?? '').toString().trim();
                            final name = '$firstName $lastName'.trim();
                            final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

                            // Hizmet alanı rengini belirle
                            final serviceAreas = u['user_service_areas'] as List?;
                            String? saName;
                            Color? saColorFromDb;
                            if (serviceAreas != null && serviceAreas.isNotEmpty) {
                              final sa = serviceAreas.first['service_areas'];
                              saName = sa?['name'] as String?;
                              final colorStr = sa?['color'] as String?;
                              if (colorStr != null && colorStr.isNotEmpty) {
                                try {
                                  saColorFromDb = Color(int.parse(colorStr.replaceFirst('#', '0xFF')));
                                } catch (_) {}
                              }
                            }
                            final saColor = saColorFromDb ?? AppTheme.accent;

                            return Card(
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: saColor.withOpacity(0.15),
                                  child: Text(initial, style: TextStyle(color: saColor, fontWeight: FontWeight.bold, fontFamily: 'Inter')),
                                ),
                                title: Text(
                                  name.isEmpty ? tr('İsimsiz Personel') : name,
                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, fontFamily: 'Inter'),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(AppTheme.roleLabel(u['role'] ?? ''), style: const TextStyle(fontSize: 12, color: AppTheme.primary, fontFamily: 'Inter', fontWeight: FontWeight.w500)),
                                    if (u['position_title'] != null)
                                      Text(tr(u['position_title']), style: const TextStyle(fontSize: 11, color: AppTheme.textSub, fontFamily: 'Inter')),
                                    const SizedBox(height: 4),
                                    const Icon(Icons.chevron_right, color: AppTheme.border),
                                  ],
                                ),
                                trailing: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    // Şirket kısa adı
                                    if ((u['company']?['short_name'] ?? '').isNotEmpty)
                                      Text(u['company']?['short_name'] ?? '', style: const TextStyle(fontSize: 10, color: AppTheme.textSub, fontFamily: 'Inter')),
                                    const SizedBox(height: 2),
                                    // Atandığı Bölüm(ler) – sağ tarafta
                                    if (serviceAreas != null && serviceAreas.isNotEmpty)
                                      ...serviceAreas.take(2).map((item) {
                                        final sa = item['service_areas'];
                                        final rawName = (sa?['name'] ?? '').toString();
                                        if (rawName.isEmpty) return const SizedBox.shrink();
                                        final bolum = _shortBolumLabel(rawName);
                                        return Container(
                                          margin: const EdgeInsets.only(top: 2),
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: saColor.withOpacity(0.12),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(bolum, style: TextStyle(fontSize: 9, color: saColor, fontWeight: FontWeight.w600, fontFamily: 'Inter')),
                                        );
                                      }).toList()
                                    else
                                      const Icon(Icons.chevron_right, color: AppTheme.border),
                                  ],
                                ),
                                isThreeLine: true,
                                onTap: () => Navigator.push(context, MaterialPageRoute(
                                  builder: (_) => PersonnelDetailDashboard(user: u),
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

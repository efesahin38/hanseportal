import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../theme/web_utils.dart';
import '../providers/app_state.dart';
import '../services/supabase_service.dart';
import '../services/localization_service.dart';

/// Bölüm 15 – Rol ve Yetki Yönetimi
class RoleManagementScreen extends StatefulWidget {
  const RoleManagementScreen({super.key});

  @override
  State<RoleManagementScreen> createState() => _RoleManagementScreenState();
}

class _RoleManagementScreenState extends State<RoleManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  List<Map<String, dynamic>> _users = [];
  bool _loading = true;
  String _statusFilter = 'active';

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this)
      ..addListener(() { if (mounted) setState(() {}); });
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final users = await SupabaseService.getUsers(status: _statusFilter);
      if (mounted) setState(() { _users = users; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();

    return Scaffold(
      appBar: AppBar(
        title: Text(tr('Berechtigungsverwaltung')),
        bottom: TabBar(
          controller: _tabs,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          indicatorColor: Colors.white,
          tabs: [
            Tab(text: tr('Benutzer')),
            Tab(text: tr('Rol Bilgileri')),
          ],
        ),
      ),
      body: WebContentWrapper(
        child: TabBarView(
          controller: _tabs,
          children: [
            _UsersTab(
              users: _users,
              loading: _loading,
              statusFilter: _statusFilter,
              currentUserId: appState.userId,
              canManage: appState.canManageRoles,
              onFilterChange: (s) => setState(() {
                _statusFilter = s;
                _loading = true;
                _load();
              }),
              onRefresh: _load,
              onChangeRole: (userId, role) => _changeRole(userId, role),
              onChangeStatus: (userId, status) => _changeStatus(userId, status),
            ),
            const _RoleInfoTab(),
          ],
        ),
      ),
    );
  }

  Future<void> _changeRole(String userId, String role) async {
    try {
      await SupabaseService.updateUserRole(userId, role);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('Rolle aktualisiert')), backgroundColor: AppTheme.success),
        );
        _load();
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('Fehler beim Aktualisieren der Rolle')), backgroundColor: AppTheme.error),
        );
      }
    }
  }

  Future<void> _changeStatus(String userId, String status) async {
    try {
      await SupabaseService.updateUserStatus(userId, status);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(status == 'active' ? tr('Benutzer aktiviert') : tr('Benutzer deaktiviert')),
            backgroundColor: status == 'active' ? AppTheme.success : AppTheme.warning,
          ),
        );
        _load();
      }
    } catch (_) {}
  }
}

// ── Kullanıcılar Sekmesi ──────────────────────────────────────
class _UsersTab extends StatelessWidget {
  final List<Map<String, dynamic>> users;
  final bool loading;
  final String statusFilter;
  final String currentUserId;
  final bool canManage;
  final void Function(String) onFilterChange;
  final Future<void> Function() onRefresh;
  final void Function(String, String) onChangeRole;
  final void Function(String, String) onChangeStatus;

  const _UsersTab({
    required this.users,
    required this.loading,
    required this.statusFilter,
    required this.currentUserId,
    required this.canManage,
    required this.onFilterChange,
    required this.onRefresh,
    required this.onChangeRole,
    required this.onChangeStatus,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Durum Filtresi
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              _FilterChip(
                label: tr('Aktif'),
                selected: statusFilter == 'active',
                color: AppTheme.success,
                onTap: () => onFilterChange('active'),
              ),
              const SizedBox(width: 8),
              _FilterChip(
                label: tr('Pasif'),
                selected: statusFilter == 'inactive',
                color: AppTheme.textSub,
                onTap: () => onFilterChange('inactive'),
              ),
              const SizedBox(width: 8),
              Text(tr('{count} kullanıcı', args: {'count': users.length.toString()}),
                  style: const TextStyle(fontSize: 12, color: AppTheme.textSub, fontFamily: 'Inter')),
            ],
          ),
        ),
        const Divider(height: 1),

        Expanded(
          child: loading
              ? const Center(child: CircularProgressIndicator())
              : users.isEmpty
                  ? Center(
                      child: Text(tr('Benutzer nicht gefunden'),
                          style: const TextStyle(color: AppTheme.textSub, fontFamily: 'Inter')),
                    )
                  : RefreshIndicator(
                      onRefresh: onRefresh,
                      child: ListView.separated(
                        padding: const EdgeInsets.all(12),
                        itemCount: users.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 4),
                        itemBuilder: (_, i) => _UserRoleCard(
                          user: users[i],
                          canManage: canManage,
                          isSelf: users[i]['id'] == currentUserId,
                          onChangeRole: (role) => onChangeRole(users[i]['id'], role),
                          onChangeStatus: (status) => onChangeStatus(users[i]['id'], status),
                        ),
                      ),
                    ),
        ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;
  const _FilterChip({required this.label, required this.selected, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? color : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? color : AppTheme.border),
        ),
        child: Text(label,
            style: TextStyle(
              color: selected ? Colors.white : AppTheme.textSub,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              fontFamily: 'Inter',
            )),
      ),
    );
  }
}

class _UserRoleCard extends StatelessWidget {
  final Map<String, dynamic> user;
  final bool canManage;
  final bool isSelf;
  final void Function(String) onChangeRole;
  final void Function(String) onChangeStatus;

  const _UserRoleCard({
    required this.user,
    required this.canManage,
    required this.isSelf,
    required this.onChangeRole,
    required this.onChangeStatus,
  });

  static const _roles = [
    ('geschaeftsfuehrer', 'Geschäftsführer'),
    ('betriebsleiter', 'Betriebsleiter'),
    ('bereichsleiter', 'Bereichsleiter'),
    ('vorarbeiter', 'Vorarbeiter'),
    ('mitarbeiter', 'Mitarbeiter'),
    ('buchhaltung', 'Buchhaltung'),
    ('backoffice', 'Backoffice'),
    ('system_admin', 'System Admin'),
  ];

  @override
  Widget build(BuildContext context) {
    final role = user['role'] as String? ?? '';
    final status = user['status'] as String? ?? 'active';
    final isActive = status == 'active';
    final company = user['company'];
    final dept = user['department'];
    final initials = [
      (user['first_name'] as String? ?? '').isNotEmpty ? (user['first_name'] as String)[0] : '',
      (user['last_name'] as String? ?? '').isNotEmpty ? (user['last_name'] as String)[0] : '',
    ].join();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: AppTheme.primary.withOpacity(0.1),
              child: Text(initials.toUpperCase(),
                  style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold, fontFamily: 'Inter')),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Text(
                    '${user['first_name'] ?? ''} ${user['last_name'] ?? ''}'.trim(),
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, fontFamily: 'Inter'),
                  ),
                  if (isSelf) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.accent.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(tr('Sen'), style: const TextStyle(fontSize: 10, color: AppTheme.accent, fontFamily: 'Inter')),
                    ),
                  ],
                ]),
                Text(user['email'] ?? '',
                    style: const TextStyle(fontSize: 12, color: AppTheme.textSub, fontFamily: 'Inter')),
              ]),
            ),
            Container(
              width: 10, height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isActive ? AppTheme.success : AppTheme.textSub,
              ),
            ),
          ]),

          const SizedBox(height: 10),
          const Divider(height: 1),
          const SizedBox(height: 10),

          // Rol + Şirket + Bölüm
          Wrap(spacing: 8, runSpacing: 6, children: [
            _InfoChip(icon: Icons.badge_outlined, label: AppTheme.roleLabel(role), color: AppTheme.primary),
            if (company != null)
              _InfoChip(icon: Icons.apartment_outlined, label: company['short_name'] ?? company['name'] ?? '', color: AppTheme.info),
            if (dept != null)
              _InfoChip(icon: Icons.groups_outlined, label: dept['name'] ?? '', color: AppTheme.accent),
          ]),

          if (canManage && !isSelf) ...[
            const SizedBox(height: 12),
            Row(children: [
              // Rol Değiştir
              Expanded(
                child: PopupMenuButton<String>(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppTheme.border),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      const Icon(Icons.swap_horiz, size: 16, color: AppTheme.primary),
                      const SizedBox(width: 4),
                      Text(tr('Rolle ändern'),
                          style: const TextStyle(fontSize: 12, color: AppTheme.primary, fontFamily: 'Inter', fontWeight: FontWeight.w600)),
                    ]),
                  ),
                  itemBuilder: (_) => _roles
                      .where((r) => r.$1 != role)
                      .map((r) => PopupMenuItem(value: r.$1, child: Text(r.$2, style: const TextStyle(fontFamily: 'Inter'))))
                      .toList(),
                  onSelected: onChangeRole,
                ),
              ),
              const SizedBox(width: 8),

              // Aktif/Pasif
              OutlinedButton.icon(
                onPressed: () => onChangeStatus(isActive ? 'inactive' : 'active'),
                icon: Icon(isActive ? Icons.pause_outlined : Icons.play_arrow_outlined, size: 16),
                label: Text(
                  isActive ? tr('Pasife Al') : tr('Aktif Et'),
                  style: const TextStyle(fontFamily: 'Inter', fontSize: 12),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: isActive ? AppTheme.warning : AppTheme.success,
                  side: BorderSide(color: isActive ? AppTheme.warning : AppTheme.success),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  minimumSize: Size.zero,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ]),
          ],
        ]),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _InfoChip({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600, fontFamily: 'Inter')),
      ]),
    );
  }
}

// ── Rol Bilgileri Sekmesi ──────────────────────────────────────
class _RoleInfoTab extends StatelessWidget {
  const _RoleInfoTab();

  static List<_RoleRow> get _roleInfo => [
    _RoleRow('geschaeftsfuehrer', 'Geschäftsführer', tr('Alle Module, alle Firmen, volle Berechtigungen.'), AppTheme.primary),
    _RoleRow('betriebsleiter', 'Betriebsleiter', tr('Operation, Planung, Berichte, alle Aufträge.'), const Color(0xFF1565C0)),
    _RoleRow('bereichsleiter', 'Bereichsleiter', tr('Eigene Abteilung: Aufträge, Planung, Zusatzarbeiten.'), const Color(0xFF6A1B9A)),
    _RoleRow('vorarbeiter', 'Vorarbeiter', tr('Eigene Aufgaben + Teamansicht.'), const Color(0xFF2E7D32)),
    _RoleRow('mitarbeiter', 'Mitarbeiter', tr('Nur zugewiesene Aufgaben und Außendienst-Ansicht.'), AppTheme.textSub),
    _RoleRow('buchhaltung', 'Buchhaltung', tr('Abgeschlossene Aufträge, Rechnungsentwürfe, Buchhaltung.'), const Color(0xFFF57F17)),
    _RoleRow('backoffice', 'Backoffice', tr('Kundenregistrierung, Dokumente, Unterstützung.'), const Color(0xFF00838F)),
    _RoleRow('system_admin', 'System Admin', tr('Technische Einstellungen, Benutzerverwaltung, Logs.'), const Color(0xFFC62828)),
  ];

  @override
  Widget build(BuildContext context) {
    final info = _roleInfo;
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: info.length,
      separatorBuilder: (_, __) => const SizedBox(height: 6),
      itemBuilder: (_, i) {
        final r = info[i];
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.only(top: 5),
                  decoration: BoxDecoration(color: r.color, shape: BoxShape.circle),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(r.label, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: r.color, fontFamily: 'Inter')),
                      const SizedBox(height: 4),
                      Text(r.description, style: const TextStyle(fontSize: 13, color: AppTheme.textSub, fontFamily: 'Inter')),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _RoleRow {
  final String key;
  final String label;
  final String description;
  final Color color;
  const _RoleRow(this.key, this.label, this.description, this.color);
}

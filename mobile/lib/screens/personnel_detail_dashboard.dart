import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../theme/web_utils.dart';
import '../providers/app_state.dart';
import '../services/supabase_service.dart';
import '../services/localization_service.dart';
import 'personnel_form_screen.dart';
import 'employee_folder_screen.dart';
import 'work_session_approval_screen.dart';
import 'personnel_stundenzettel_screen.dart';

class PersonnelDetailDashboard extends StatelessWidget {
  final Map<String, dynamic> user;
  const PersonnelDetailDashboard({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    final appState = context.read<AppState>();
    final isExternalManager = (user['role'] ?? '') == 'external_manager';
    final canManageLeave = (appState.isGeschaeftsfuehrer || appState.isBetriebsleiter || appState.isSystemAdmin) && !isExternalManager;
    // Üst yetkililer (GF, BL, Bereichsleiter, Buchhaltung, Admin) çalışanın
    // Stundenzettel'ini görebilir; ayrıca her çalışan kendi çizelgesini görebilir.
    final canViewStundenzettel = appState.isGeschaeftsfuehrer || appState.isBetriebsleiter ||
        appState.isBereichsleiter || appState.isBuchhaltung || appState.isSystemAdmin ||
        (user['id'] == appState.userId);

    return Scaffold(
      appBar: AppBar(title: Text('${user['first_name']} ${user['last_name']}')),
      body: WebContentWrapper(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // User Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [AppTheme.primary, AppTheme.accent], begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.white24,
                    child: () {
                      final f = (user['first_name'] ?? '').toString().trim();
                      final l = (user['last_name'] ?? '').toString().trim();
                      final initials = '${f.isNotEmpty ? f[0] : ''}${l.isNotEmpty ? l[0] : ''}';
                      return Text(initials.isEmpty ? '?' : initials.toUpperCase(), 
                        style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold));
                    }(),
                  ),

                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${user['first_name']} ${user['last_name']}', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold, fontFamily: 'Inter')),
                        Text(AppTheme.roleLabel(user['role'] ?? ''), style: const TextStyle(color: Colors.white70, fontSize: 13, fontFamily: 'Inter')),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            _MenuCard(
              icon: Icons.person,
              title: tr('Meine Stammdaten'),
              subtitle: tr('Persönliche Daten, Vertrag & Qualifikationen'),
              color: const Color(0xFF3B82F6),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PersonnelFormScreen(userId: user['id']))),
            ),

            if (!isExternalManager)
              _MenuCard(
                icon: Icons.folder,
                title: tr('Unterlagen / Dokumente'),
                subtitle: tr('Lohnabrechnungen, Urlaubsanträge, Krankmeldungen'),
                color: const Color(0xFF10B981),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => EmployeeFolderScreen(initialEmployee: user))),
              ),

            if (!isExternalManager)
              _MenuCard(
                icon: Icons.access_time,
                title: tr('Arbeitszeiterfassung'),
                subtitle: canViewStundenzettel
                    ? tr('Monatliche Stundenzettel & Zeiten ansehen')
                    : tr('Einsatzdaten & Stundenzettel'),
                color: const Color(0xFFF59E0B),
                onTap: () {
                  if (canViewStundenzettel) {
                    Navigator.push(context, MaterialPageRoute(
                      builder: (_) => PersonnelStundenzettelScreen(employee: user),
                    ));
                  } else {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const WorkSessionApprovalScreen()));
                  }
                },
              ),

            // ── Urlaubstage – Nur für GF und Betriebsleiter ──
            if (canManageLeave)
              _MenuCard(
                icon: Icons.beach_access,
                title: tr('Urlaubstage'),
                subtitle: tr('Urlaubstage verwalten & im Kalender eintragen'),
                color: const Color(0xFF06B6D4),
                onTap: () => _showLeaveManagementSheet(context, user, appState),
              ),

            // ── Danger Zone ──
            if (appState.isSystemAdmin || appState.isGeschaeftsfuehrer || appState.isBetriebsleiter || appState.isBuchhaltung) ...[
              const SizedBox(height: 32),
              const Divider(),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => _confirmDelete(context),
                icon: const Icon(Icons.person_remove),
                label: Text(tr('Kullanıcıyı Sil'), style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Inter')),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.error.withOpacity(0.1),
                  foregroundColor: AppTheme.error,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: AppTheme.error)),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('Kullanıcıyı Sil?')),
        content: Text(tr('Bu işlem bu personeli sistemden pasif hale getirecektir. Devam etmek istiyor musunuz?')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(tr('Abbrechen'))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            onPressed: () async {
              Navigator.pop(ctx);
              await SupabaseService.updateUserStatus(user['id'], 'passive');
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('Kullanıcı pasif yapıldı'))));
                Navigator.pop(context); // Detail dashboard'dan çık
              }
            },
            child: Text(tr('Sil (Pasif Yap)'), style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showLeaveManagementSheet(BuildContext context, Map<String, dynamic> user, AppState appState) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _LeaveManagementSheet(user: user, appState: appState),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Leave Management Bottom Sheet
// ─────────────────────────────────────────────────────────────────────────────
class _LeaveManagementSheet extends StatefulWidget {
  final Map<String, dynamic> user;
  final AppState appState;
  const _LeaveManagementSheet({required this.user, required this.appState});

  @override
  State<_LeaveManagementSheet> createState() => _LeaveManagementSheetState();
}

class _LeaveManagementSheetState extends State<_LeaveManagementSheet> {
  List<Map<String, dynamic>> _leaves = [];
  bool _loading = true;
  bool _saving = false;

  DateTime? _startDate;
  DateTime? _endDate;
  String _leaveType = 'urlaub';
  final _noteCtrl = TextEditingController();

  static const _leaveTypes = {
    'urlaub': '🏖️ Urlaub',
    'krank': '🤒 Krankmeldung',
    'sonderurlaub': '⭐ Sonderurlaub',
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await SupabaseService.getLeaveRequests(userId: widget.user['id']);
      if (mounted) setState(() { _leaves = data; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (_startDate == null || _endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('Bitte Datum auswählen')), backgroundColor: AppTheme.error),
      );
      return;
    }
    if (_endDate!.isBefore(_startDate!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('Enddatum muss nach Startdatum liegen')), backgroundColor: AppTheme.error),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await SupabaseService.createLeaveRequest({
        'user_id': widget.user['id'],
        'department_id': widget.user['department_id'],
        'start_date': _startDate!.toIso8601String().split('T')[0],
        'end_date': _endDate!.toIso8601String().split('T')[0],
        'leave_type': _leaveType,
        'status': 'approved',
        'note': _noteCtrl.text.trim().isNotEmpty ? _noteCtrl.text.trim() : null,
        'created_by': widget.appState.userId,
      });
      // Formu sıfırla
      setState(() {
        _startDate = null;
        _endDate = null;
        _leaveType = 'urlaub';
        _noteCtrl.clear();
        _saving = false;
      });
      await _load();
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${tr('Fehler')}: $e'), backgroundColor: AppTheme.error),
        );
      }
    }
  }

  Future<void> _delete(String id) async {
    await SupabaseService.deleteLeaveRequest(id);
    await _load();
  }

  String _fmt(DateTime? d) => d == null ? tr('Auswählen') : '${d.day.toString().padLeft(2,'0')}.${d.month.toString().padLeft(2,'0')}.${d.year}';
  String _fmtStr(String? s) {
    if (s == null) return '-';
    final d = DateTime.tryParse(s);
    return d == null ? s : '${d.day.toString().padLeft(2,'0')}.${d.month.toString().padLeft(2,'0')}.${d.year}';
  }

  Color _typeColor(String type) {
    switch (type) {
      case 'krank': return const Color(0xFFEF4444);
      case 'sonderurlaub': return const Color(0xFF8B5CF6);
      default: return const Color(0xFF06B6D4);
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = '${widget.user['first_name']} ${widget.user['last_name']}';
    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.88),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40, height: 4,
            decoration: BoxDecoration(color: AppTheme.border, borderRadius: BorderRadius.circular(2)),
          ),
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: AppTheme.divider)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: const Color(0xFF06B6D4).withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.beach_access, color: Color(0xFF06B6D4), size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(tr('Urlaubsverwaltung'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, fontFamily: 'Inter')),
                    Text(name, style: const TextStyle(fontSize: 12, color: AppTheme.textSub, fontFamily: 'Inter')),
                  ]),
                ),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Yeni İzin Formu ──
                  Text(tr('Neue Urlaubseinträge'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, fontFamily: 'Inter')),
                  const SizedBox(height: 12),

                  // Tip seçici
                  Row(
                    children: _leaveTypes.entries.map((e) {
                      final sel = _leaveType == e.key;
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: GestureDetector(
                            onTap: () => setState(() => _leaveType = e.key),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: sel ? _typeColor(e.key) : AppTheme.bg,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: sel ? _typeColor(e.key) : AppTheme.border),
                              ),
                              child: Text(
                                e.value,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: sel ? FontWeight.bold : FontWeight.normal,
                                  color: sel ? Colors.white : AppTheme.textSub,
                                  fontFamily: 'Inter',
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),

                  // Tarih seçiciler
                  Row(
                    children: [
                      Expanded(
                        child: _DatePickerTile(
                          label: tr('Von'),
                          value: _fmt(_startDate),
                          onTap: () async {
                            final d = await showDatePicker(
                              context: context,
                              initialDate: DateTime.now(),
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2030),
                            );
                            if (d != null) setState(() => _startDate = d);
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _DatePickerTile(
                          label: tr('Bis'),
                          value: _fmt(_endDate),
                          onTap: () async {
                            final d = await showDatePicker(
                              context: context,
                              initialDate: _startDate ?? DateTime.now(),
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2030),
                            );
                            if (d != null) setState(() => _endDate = d);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Notiz
                  TextField(
                    controller: _noteCtrl,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: tr('Notiz (optional)'),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Kaydet butonu
                  ElevatedButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.check),
                    label: Text(tr('Eintragen & Im Kalender speichern')),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF06B6D4),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),

                  const SizedBox(height: 24),
                  // ── Mevcut İzin Kayıtları ──
                  Row(
                    children: [
                      Text(tr('Bisherige Einträge'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, fontFamily: 'Inter')),
                      const Spacer(),
                      if (_loading) const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (!_loading && _leaves.isEmpty)
                    Center(child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(tr('Keine Einträge vorhanden'), style: const TextStyle(color: AppTheme.textSub, fontFamily: 'Inter')),
                    )),
                  ..._leaves.map((leave) {
                    final type = leave['leave_type'] ?? 'urlaub';
                    final color = _typeColor(type);
                    final label = _leaveTypes[type] ?? type;
                    final from = _fmtStr(leave['start_date']);
                    final to = _fmtStr(leave['end_date']);
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: color.withOpacity(0.2)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 4, height: 36,
                            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(label, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: color, fontFamily: 'Inter')),
                              Text('$from – $to', style: const TextStyle(fontSize: 11, color: AppTheme.textSub, fontFamily: 'Inter')),
                              if (leave['note'] != null && (leave['note'] as String).isNotEmpty)
                                Text(leave['note'], style: const TextStyle(fontSize: 10, color: AppTheme.textSub, fontFamily: 'Inter')),
                            ]),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, size: 20),
                            color: AppTheme.error.withOpacity(0.6),
                            onPressed: () => _delete(leave['id']),
                          ),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DatePickerTile extends StatelessWidget {
  final String label, value;
  final VoidCallback onTap;
  const _DatePickerTile({required this.label, required this.value, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: AppTheme.border),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today, size: 16, color: AppTheme.textSub),
            const SizedBox(width: 8),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: const TextStyle(fontSize: 10, color: AppTheme.textSub, fontFamily: 'Inter')),
              Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, fontFamily: 'Inter')),
            ]),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
class _MenuCard extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final Color color;
  final VoidCallback onTap;
  const _MenuCard({required this.icon, required this.title, required this.subtitle, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppTheme.divider), boxShadow: [BoxShadow(color: color.withOpacity(0.08), blurRadius: 12, offset: const Offset(0, 4))]),
          child: Row(
            children: [
              Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: color, size: 28)),
              const SizedBox(width: 16),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, fontFamily: 'Inter')),
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(fontSize: 12, color: AppTheme.textSub, fontFamily: 'Inter'), maxLines: 2),
              ])),
              Icon(Icons.chevron_right, color: color.withOpacity(0.6)),
            ],
          ),
        ),
      ),
    );
  }
}

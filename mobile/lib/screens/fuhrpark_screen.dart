import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../theme/web_utils.dart';
import '../providers/app_state.dart';
import '../services/supabase_service.dart';
import '../services/localization_service.dart';
import 'interne_pq_screen.dart' show kDepartmentOptions;

class FuhrparkScreen extends StatefulWidget {
  const FuhrparkScreen({super.key});
  @override
  State<FuhrparkScreen> createState() => _FuhrparkScreenState();
}

class _FuhrparkScreenState extends State<FuhrparkScreen> {
  List<Map<String, dynamic>> _vehicles = [];
  bool _loading = true;

  // ── Bereichsleiter-Filterung ──────────────────────────────
  String? _bereichsleiterDepartment(AppState appState) {
    if (!appState.isBereichsleiter) return null;
    return appState.currentUser?['department']?['name'] as String?;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await context.read<AppState>().refreshProfile();
      _load();
    });
  }

  Future<void> _load() async {
    try {
      final appState = context.read<AppState>();
      final companyIds = appState.isGeschaeftsfuehrer || appState.isSystemAdmin ? null : appState.authorizedCompanyIds;
      final dept = _bereichsleiterDepartment(appState);
      final data = await SupabaseService.getVehicles(
        companyIds: dept != null ? null : companyIds,
        department: dept,
      );
      if (mounted) setState(() { _vehicles = data; _loading = false; });
    } catch (_) { if (mounted) setState(() => _loading = false); }
  }

  List<_Alert> _getAlerts(Map<String, dynamic> v) {
    final alerts = <_Alert>[];
    final now = DateTime.now();
    final tuev = DateTime.tryParse(v['tuev_date'] ?? '');
    if (tuev != null && tuev.difference(now).inDays < 30) alerts.add(_Alert('TÜV', tuev, tuev.isBefore(now)));
    final service = v['last_service_date'] != null ? DateTime.tryParse(v['last_service_date'])?.add(const Duration(days: 365)) : null;
    if (service != null && service.difference(now).inDays < 30) alerts.add(_Alert('Service', service, service.isBefore(now)));
    final tire = DateTime.tryParse(v['next_tire_change_date'] ?? '');
    if (tire != null && tire.difference(now).inDays < 30) alerts.add(_Alert(tr('Reifenwechsel'), tire, tire.isBefore(now)));
    final license = DateTime.tryParse(v['license_check_date'] ?? '');
    if (license != null && license.difference(now).inDays < 30) alerts.add(_Alert(tr('Führerscheinkontrolle'), license, license.isBefore(now)));
    return alerts;
  }

  void _showForm({Map<String, dynamic>? v}) {
    final lp = TextEditingController(text: v?['license_plate'] ?? '');
    final df = TextEditingController(text: v?['driver_first_name'] ?? '');
    final dl = TextEditingController(text: v?['driver_last_name'] ?? '');
    final vin = TextEditingController(text: v?['vehicle_ident_number'] ?? '');
    final sd = TextEditingController(text: v?['last_service_details'] ?? '');
    final n = TextEditingController(text: v?['notes'] ?? '');
    DateTime? fr = v?['first_registration_date'] != null ? DateTime.tryParse(v!['first_registration_date']) : null;
    DateTime? cr = v?['company_registration_date'] != null ? DateTime.tryParse(v!['company_registration_date']) : null;
    DateTime? td = v?['tuev_date'] != null ? DateTime.tryParse(v!['tuev_date']) : null;
    DateTime? ls = v?['last_service_date'] != null ? DateTime.tryParse(v!['last_service_date']) : null;
    DateTime? tc = v?['next_tire_change_date'] != null ? DateTime.tryParse(v!['next_tire_change_date']) : null;
    DateTime? lc = v?['license_check_date'] != null ? DateTime.tryParse(v!['license_check_date']) : null;

    final appState = context.read<AppState>();
    final bereichDept = _bereichsleiterDepartment(appState);
    String? selectedDept = v?['department'] ?? bereichDept ?? kDepartmentOptions.first;

    showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (ctx) => StatefulBuilder(
      builder: (ctx, ss) => Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.85),
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppTheme.border, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 16),
          Text(v == null ? tr('Neues Fahrzeug') : tr('Fahrzeug bearbeiten'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          TextField(controller: lp, decoration: InputDecoration(labelText: '${tr('Kennzeichen')} *')),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: TextField(controller: df, decoration: InputDecoration(labelText: tr('Fahrer Vorname')))),
            const SizedBox(width: 12),
            Expanded(child: TextField(controller: dl, decoration: InputDecoration(labelText: tr('Fahrer Nachname')))),
          ]),
          const SizedBox(height: 12),
          TextField(controller: vin, decoration: InputDecoration(labelText: tr('Fahrzeug-Identnummer'))),
          const SizedBox(height: 12),
          if (bereichDept != null)
            InputDecorator(
              decoration: InputDecoration(labelText: tr('Abteilung')),
              child: Text(bereichDept, style: const TextStyle(fontSize: 14)),
            )
          else
            DropdownButtonFormField<String>(
              value: selectedDept,
              decoration: InputDecoration(labelText: '${tr('Abteilung')} *'),
              items: kDepartmentOptions.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
              onChanged: (v) => ss(() => selectedDept = v),
            ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _db(ctx, tr('Erstzulassung'), fr, (d) => ss(() => fr = d))),
            const SizedBox(width: 12),
            Expanded(child: _db(ctx, tr('Zulassung Firma'), cr, (d) => ss(() => cr = d))),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _db(ctx, tr('TÜV-Termin'), td, (d) => ss(() => td = d))),
            const SizedBox(width: 12),
            Expanded(child: _db(ctx, tr('Letzter Service'), ls, (d) => ss(() => ls = d))),
          ]),
          const SizedBox(height: 12),
          TextField(controller: sd, decoration: InputDecoration(labelText: tr('Service-Inhalt')), maxLines: 2),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _db(ctx, tr('Reifenwechsel'), tc, (d) => ss(() => tc = d))),
            const SizedBox(width: 12),
            Expanded(child: _db(ctx, tr('FS-Kontrolle'), lc, (d) => ss(() => lc = d))),
          ]),
          const SizedBox(height: 12),
          TextField(controller: n, decoration: InputDecoration(labelText: tr('Notizen')), maxLines: 2),
          const SizedBox(height: 20),
          ElevatedButton(onPressed: () async {
            if (lp.text.trim().isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('Kennzeichen ist erforderlich'))));
              return;
            }
            try {
              await SupabaseService.upsertVehicle({
                if (v != null) 'id': v['id'],
                'company_id': context.read<AppState>().companyId, 'license_plate': lp.text.trim(),
                'driver_first_name': df.text.trim(), 'driver_last_name': dl.text.trim(),
                'vehicle_ident_number': vin.text.trim(),
                'first_registration_date': fr?.toIso8601String().split('T')[0],
                'company_registration_date': cr?.toIso8601String().split('T')[0],
                'tuev_date': td?.toIso8601String().split('T')[0],
                'last_service_date': ls?.toIso8601String().split('T')[0],
                'last_service_details': sd.text.trim(),
                'next_tire_change_date': tc?.toIso8601String().split('T')[0],
                'license_check_date': lc?.toIso8601String().split('T')[0],
                'notes': n.text.trim(),
                'department': bereichDept ?? selectedDept,
              });
              if (mounted) { Navigator.pop(ctx); _load(); }
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fehler: $e'), backgroundColor: AppTheme.error));
              }
            }
          }, child: Text(tr('Speichern'))),
        ])),
      ),
    ));
  }

  Widget _db(BuildContext ctx, String l, DateTime? d, Function(DateTime) f) => InkWell(
    onTap: () async { final x = await showDatePicker(context: ctx, initialDate: d ?? DateTime.now(), firstDate: DateTime(2000), lastDate: DateTime(2040)); if (x != null) f(x); },
    child: InputDecorator(decoration: InputDecoration(labelText: l, isDense: true), child: Text(d == null ? '-' : '${d.day}.${d.month}.${d.year}', style: const TextStyle(fontSize: 13))),
  );

  @override
  Widget build(BuildContext context) {
    final appState = context.read<AppState>();
    final companyName = appState.currentUser?['company']?['name'] ?? tr('Fuhrpark');
    
    return Scaffold(
      appBar: AppBar(
        title: Text(appState.isBereichsleiter ? '$companyName - Fuhrpark' : tr('Fuhrpark')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showForm(),
        icon: const Icon(Icons.add),
        label: Text(tr('Neues Fahrzeug')),
      ),
      body: WebContentWrapper(
        child: _loading 
          ? const Center(child: CircularProgressIndicator())
          : _vehicles.isEmpty 
              ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.directions_car_outlined, size: 56, color: AppTheme.textSub), const SizedBox(height: 12), Text(tr('Keine Fahrzeuge'), style: const TextStyle(color: AppTheme.textSub))]))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: Builder(builder: (context) {
                    final grouped = <String, List<Map<String, dynamic>>>{};
                    for (var v in _vehicles) {
                      final dep = v['department'] ?? 'Allgemein (Genel)';
                      grouped.putIfAbsent(dep, () => []).add(v);
                    }
                    return ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: grouped.keys.length,
                      itemBuilder: (_, i) {
                        final dep = grouped.keys.elementAt(i);
                        final depList = grouped[dep]!;
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: ExpansionTile(
                            leading: const Icon(Icons.folder_special, color: AppTheme.primary),
                            title: Text(dep, style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Inter')),
                            subtitle: Text('${depList.length} ${tr('Fahrzeuge')}', style: const TextStyle(fontSize: 12, color: AppTheme.textSub)),
                            initiallyExpanded: true,
                            children: depList.map((v) {
                              final alerts = _getAlerts(v);
                              return Card(
                                elevation: 0,
                                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                child: ExpansionTile(
                                  leading: Container(width: 44, height: 44, decoration: BoxDecoration(
                                    color: alerts.any((a) => a.overdue) ? AppTheme.error.withOpacity(0.1) : alerts.isNotEmpty ? AppTheme.warning.withOpacity(0.1) : AppTheme.primary.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ), child: Icon(Icons.directions_car, color: alerts.any((a) => a.overdue) ? AppTheme.error : alerts.isNotEmpty ? AppTheme.warning : AppTheme.primary)),
                                  title: Text(v['license_plate'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, fontFamily: 'Inter')),
                                  subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    Text('${v['driver_first_name'] ?? ''} ${v['driver_last_name'] ?? ''}'.trim(), style: const TextStyle(fontSize: 12, color: AppTheme.textSub)),
                                  ]),
                                  trailing: alerts.isNotEmpty ? Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(color: (alerts.any((a) => a.overdue) ? AppTheme.error : AppTheme.warning).withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                                    child: Text('${alerts.length} ⚠️', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: alerts.any((a) => a.overdue) ? AppTheme.error : AppTheme.warning)),
                                  ) : null,
                                  children: [
                                    if (alerts.isNotEmpty) ...alerts.map((a) => ListTile(
                                      dense: true,
                                      leading: Icon(a.overdue ? Icons.error : Icons.warning_amber, color: a.overdue ? AppTheme.error : AppTheme.warning, size: 18),
                                      title: Text(a.label, style: TextStyle(fontSize: 12, color: a.overdue ? AppTheme.error : AppTheme.warning, fontWeight: FontWeight.bold)),
                                      subtitle: Text('${a.date.day}.${a.date.month}.${a.date.year}', style: const TextStyle(fontSize: 11)),
                                    )),
                                    if (v['tuev_date'] != null) _infoRow(Icons.verified, 'TÜV', v['tuev_date']),
                                    if (v['vehicle_ident_number'] != null) _infoRow(Icons.confirmation_number, 'VIN', v['vehicle_ident_number']),
                                    Padding(padding: const EdgeInsets.all(12), child: Row(children: [
                                      TextButton.icon(onPressed: () => _showForm(v: v), icon: const Icon(Icons.edit, size: 16), label: Text(tr('Bearbeiten'))),
                                      const Spacer(),
                                      TextButton.icon(onPressed: () async {
                                        await SupabaseService.deleteVehicle(v['id']); _load();
                                      }, icon: const Icon(Icons.delete_outline, size: 16, color: AppTheme.error), label: Text(tr('Löschen'), style: const TextStyle(color: AppTheme.error))),
                                    ])),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        );
                      },
                    );
                  }),
                ),
      ),
    );
  }

  Widget _infoRow(IconData ic, String l, String? val) => val == null ? const SizedBox.shrink() : Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
    child: Row(children: [Icon(ic, size: 14, color: AppTheme.textSub), const SizedBox(width: 8), Text('$l: $val', style: const TextStyle(fontSize: 12))]),
  );
}

class _Alert {
  final String label;
  final DateTime date;
  final bool overdue;
  _Alert(this.label, this.date, this.overdue);
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../theme/web_utils.dart';
import '../providers/app_state.dart';
import '../services/supabase_service.dart';
import '../services/localization_service.dart';

class VertragsmanagementScreen extends StatefulWidget {
  const VertragsmanagementScreen({super.key});
  @override
  State<VertragsmanagementScreen> createState() => _VState();
}

class _VState extends State<VertragsmanagementScreen> {
  List<Map<String, dynamic>> _contracts = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final appState = context.read<AppState>();
      final companyIds = appState.isGeschaeftsfuehrer || appState.isSystemAdmin ? null : appState.authorizedCompanyIds;
      final data = await SupabaseService.getContracts(companyIds: companyIds);
      if (mounted) setState(() { _contracts = data; _loading = false; });
    } catch (_) { if (mounted) setState(() => _loading = false); }
  }

  Color _statusColor(Map<String, dynamic> c) {
    final end = DateTime.tryParse(c['end_date'] ?? '');
    if (end == null) return AppTheme.textSub;
    final d = end.difference(DateTime.now()).inDays;
    if (d < 0) return AppTheme.error;
    if (d < 30) return AppTheme.warning;
    return AppTheme.success;
  }

  String _statusLabel(Map<String, dynamic> c) {
    final end = DateTime.tryParse(c['end_date'] ?? '');
    if (end == null) return tr('Unbefristet');
    final d = end.difference(DateTime.now()).inDays;
    if (d < 0) return tr('Abgelaufen');
    if (d < 30) return '${tr('Läuft ab in')} $d ${tr('Tagen')}';
    return tr('Aktiv');
  }

  void _showForm({Map<String, dynamic>? contract}) {
    final t = TextEditingController(text: contract?['title'] ?? '');
    final p = TextEditingController(text: contract?['partner'] ?? '');
    final k = TextEditingController(text: contract?['cancellation_period'] ?? '');
    final co = TextEditingController(text: contract?['monthly_cost']?.toString() ?? '');
    final n = TextEditingController(text: contract?['notes'] ?? '');
    DateTime? sd = contract?['start_date'] != null ? DateTime.tryParse(contract!['start_date']) : null;
    DateTime? ed = contract?['end_date'] != null ? DateTime.tryParse(contract!['end_date']) : null;
    DateTime? rd = contract?['renewal_date'] != null ? DateTime.tryParse(contract!['renewal_date']) : null;
    String ct = contract?['contract_type'] ?? 'Vertrag';

    showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (ctx) => StatefulBuilder(
      builder: (ctx, ss) => Container(
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppTheme.border, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 16),
          Text(contract == null ? tr('Neuer Vertrag') : tr('Vertrag bearbeiten'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          TextField(controller: t, decoration: InputDecoration(labelText: '${tr('Vertragsbezeichnung')} *')),
          const SizedBox(height: 12),
          TextField(controller: p, decoration: InputDecoration(labelText: tr('Vertragspartner'))),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(value: ct, decoration: InputDecoration(labelText: tr('Vertragsart')),
            items: ['Vertrag', 'Mietvertrag', 'Abonnement', 'Mitgliedschaft', 'Versicherung', 'Lizenz', 'Sonstige'].map((x) => DropdownMenuItem(value: x, child: Text(x))).toList(),
            onChanged: (v) => ss(() => ct = v!)),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _db(ctx, tr('Beginn'), sd, (d) => ss(() => sd = d))),
            const SizedBox(width: 12),
            Expanded(child: _db(ctx, tr('Ende'), ed, (d) => ss(() => ed = d))),
          ]),
          const SizedBox(height: 12),
          _db(ctx, tr('Verlängerungsdatum'), rd, (d) => ss(() => rd = d)),
          const SizedBox(height: 12),
          TextField(controller: k, decoration: InputDecoration(labelText: tr('Kündigungsfrist'))),
          const SizedBox(height: 12),
          TextField(controller: co, decoration: InputDecoration(labelText: tr('Monatl. Kosten (€)')), keyboardType: TextInputType.number),
          const SizedBox(height: 12),
          TextField(controller: n, decoration: InputDecoration(labelText: tr('Notizen')), maxLines: 3),
          const SizedBox(height: 20),
          ElevatedButton(onPressed: () async {
            if (t.text.trim().isEmpty) return;
            await SupabaseService.upsertContract({
              if (contract != null) 'id': contract['id'],
              'company_id': context.read<AppState>().companyId, 'title': t.text.trim(), 'partner': p.text.trim(),
              'contract_type': ct, 'start_date': sd?.toIso8601String().split('T')[0],
              'end_date': ed?.toIso8601String().split('T')[0], 'renewal_date': rd?.toIso8601String().split('T')[0],
              'cancellation_period': k.text.trim(), 'monthly_cost': double.tryParse(co.text), 'notes': n.text.trim(),
              'created_by': context.read<AppState>().userId,
            });
            if (mounted) { Navigator.pop(ctx); _load(); }
          }, child: Text(tr('Speichern'))),
        ])),
      ),
    ));
  }

  Widget _db(BuildContext ctx, String l, DateTime? d, Function(DateTime) f) => InkWell(
    onTap: () async { final x = await showDatePicker(context: ctx, initialDate: d ?? DateTime.now(), firstDate: DateTime(2000), lastDate: DateTime(2040)); if (x != null) f(x); },
    child: InputDecorator(decoration: InputDecoration(labelText: l), child: Text(d == null ? tr('Auswählen') : '${d.day}.${d.month}.${d.year}', style: const TextStyle(fontSize: 14))),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(tr('Vertragsmanagement'))),
    floatingActionButton: FloatingActionButton.extended(onPressed: () => _showForm(), icon: const Icon(Icons.add), label: Text(tr('Neuer Vertrag'))),
    body: WebContentWrapper(child: _loading ? const Center(child: CircularProgressIndicator())
      : _contracts.isEmpty ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.description_outlined, size: 56, color: AppTheme.textSub), const SizedBox(height: 12), Text(tr('Keine Verträge vorhanden'), style: const TextStyle(color: AppTheme.textSub))]))
      : RefreshIndicator(onRefresh: _load, child: ListView.builder(padding: const EdgeInsets.all(12), itemCount: _contracts.length, itemBuilder: (_, i) {
          final c = _contracts[i]; final color = _statusColor(c);
          return Dismissible(key: Key(c['id']), direction: DismissDirection.endToStart,
            background: Container(alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 20), color: AppTheme.error, child: const Icon(Icons.delete, color: Colors.white)),
            onDismissed: (_) async { await SupabaseService.deleteContract(c['id']); _load(); },
            child: Card(child: ListTile(
              leading: Container(width: 44, height: 44, decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: Icon(Icons.description, color: color)),
              title: Text(c['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (c['partner'] != null && c['partner'].toString().isNotEmpty) Text(c['partner'], style: const TextStyle(fontSize: 12, color: AppTheme.textSub)),
                Row(children: [
                  Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                    child: Text(_statusLabel(c), style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold))),
                  if (c['monthly_cost'] != null) ...[const SizedBox(width: 8), Text('€${c['monthly_cost']}/Mon.', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textSub))],
                ]),
              ]),
              onTap: () => _showForm(contract: c), isThreeLine: true,
            )),
          );
        })),
    ),
  );
}

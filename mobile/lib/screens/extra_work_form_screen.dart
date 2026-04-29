import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../theme/web_utils.dart';
import '../providers/app_state.dart';
import '../services/supabase_service.dart';
import '../services/localization_service.dart';

/// Ek İş / Ek Hizmet kayıt formu (Bölüm 11)
class ExtraWorkFormScreen extends StatefulWidget {
  final String orderId;
  const ExtraWorkFormScreen({super.key, required this.orderId});

  @override
  State<ExtraWorkFormScreen> createState() => _ExtraWorkFormScreenState();
}

class _ExtraWorkFormScreenState extends State<ExtraWorkFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _durationH = TextEditingController();
  final _materialCost = TextEditingController();
  final _laborCost = TextEditingController();
  final _notes = TextEditingController();

  DateTime? _workDate; // v17.9: Boş bırakılabilir yaptık
  bool? _isBillable; // null = değerlendirmede
  String _approvalStatus = 'recorded';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _workDate = DateTime.now(); // Varsayılan bugün
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _workDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) setState(() => _workDate = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final appState = context.read<AppState>();
    setState(() => _saving = true);
    try {
      await SupabaseService.createExtraWork({
        'order_id': widget.orderId,
        'title': _title.text.trim(),
        'description': _description.text.trim(),
        'work_date': _workDate?.toIso8601String().split('T')[0],
        if (_durationH.text.isNotEmpty) 'duration_h': double.tryParse(_durationH.text),
        'is_billable': _isBillable,
        if (_materialCost.text.isNotEmpty) 'estimated_material_cost': double.tryParse(_materialCost.text),
        if (_laborCost.text.isNotEmpty) 'estimated_labor_cost': double.tryParse(_laborCost.text),
        'notes': _notes.text.trim(),
        'recorded_by': appState.userId,
        'status': _approvalStatus,
      });
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${tr('Fehler')}: $e')));
        setState(() => _saving = false);
      }
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _durationH.dispose();
    _materialCost.dispose();
    _laborCost.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(title: Text(tr('Zusatzleistung erfassen'))),
      body: WebContentWrapper(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _section(tr('Zusatzleistung Details')),
              _textField(tr('Titel der Zusatzleistung *'), _title, required: true),
              _textField(tr('Beschreibung'), _description, maxLines: 3),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: _pickDate,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: AppTheme.border),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(children: [
                    const Icon(Icons.calendar_today, size: 18, color: AppTheme.textSub),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(tr('Arbeitsdatum'), style: const TextStyle(fontSize: 12, color: AppTheme.textSub, fontFamily: 'Inter')),
                        Text(
                          _workDate == null ? tr('Auswählen') : '${_workDate!.day.toString().padLeft(2, '0')}.${_workDate!.month.toString().padLeft(2, '0')}.${_workDate!.year}',
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, fontFamily: 'Inter'),
                        ),
                      ]),
                    ),
                    if (_workDate != null)
                      GestureDetector(
                        onTap: () => setState(() => _workDate = null),
                        child: const Icon(Icons.delete_outline, color: AppTheme.error, size: 20),
                      ),
                  ]),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _durationH,
                decoration: InputDecoration(labelText: tr('Dauer der Zusatzleistung (Std.)'), hintText: tr('z.B. 2.5')),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              
              // Genehmigungsstatus und Kosten nur für Manager/Admins
              if (appState.isGeschaeftsfuehrer || appState.isBetriebsleiter || appState.isSystemAdmin) ...[
                const SizedBox(height: 20),
                _section(tr('Genehmigungsstatus')),
                DropdownButtonFormField<String>(
                  value: _approvalStatus,
                  decoration: InputDecoration(labelText: tr('Bearbeitungsstatus')),
                  items: [
                    DropdownMenuItem(value: 'recorded', child: Text(tr('Erfasst (Entwurf)'), style: const TextStyle(fontFamily: 'Inter'))),
                    DropdownMenuItem(value: 'pending_customer', child: Text(tr('Wartet auf Kundengenehmigung'), style: const TextStyle(fontFamily: 'Inter'))),
                    DropdownMenuItem(value: 'approved', child: Text(tr('Genehmigt / Bereit zur Abrechnung'), style: const TextStyle(fontFamily: 'Inter'))),
                    DropdownMenuItem(value: 'rejected', child: Text(tr('Abgelehnt'), style: const TextStyle(fontFamily: 'Inter'))),
                  ],
                  onChanged: (v) => setState(() => _approvalStatus = v!),
                ),
                const SizedBox(height: 20),
                _section(tr('Kostendaten (Nur Verwaltung)')),
                Row(children: [
                  Expanded(child: TextFormField(
                    controller: _materialCost,
                    decoration: InputDecoration(labelText: '${tr('Materialkosten')} (€)'),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  )),
                  const SizedBox(width: 12),
                  Expanded(child: TextFormField(
                    controller: _laborCost,
                    decoration: InputDecoration(labelText: '${tr('Lohnkosten')} (€)'),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  )),
                ]),
              ],
              const SizedBox(height: 16),
              _section(tr('Zusatzinformationen')),
              _textField(tr('Notizen'), _notes, maxLines: 3),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text(tr('Zusatzleistung speichern')),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _section(String title) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textSub, fontFamily: 'Inter')),
  );

  Widget _textField(String label, TextEditingController ctrl, {bool required = false, int maxLines = 1}) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
      controller: ctrl,
      maxLines: maxLines,
      decoration: InputDecoration(labelText: label),
      validator: required ? (v) => (v == null || v.isEmpty) ? tr('Pflichtfeld') : null : null,
    ),
  );
}

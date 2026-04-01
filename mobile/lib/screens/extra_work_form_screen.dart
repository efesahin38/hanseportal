import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../theme/web_utils.dart';
import '../providers/app_state.dart';
import '../services/supabase_service.dart';

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

  DateTime _workDate = DateTime.now();
  bool? _isBillable; // null = değerlendirmede
  String _approvalStatus = 'recorded';
  bool _saving = false;

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
        'work_date': _workDate.toIso8601String().split('T')[0],
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
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
      appBar: AppBar(title: const Text('Ek İş Kayıt')),
      body: WebContentWrapper(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _section('Ek İş Bilgisi'),
              _textField('Ek İş Başlığı *', _title, required: true),
              _textField('Açıklama', _description, maxLines: 3),
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
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('İş Tarihi', style: TextStyle(fontSize: 12, color: AppTheme.textSub, fontFamily: 'Inter')),
                      Text(
                        '${_workDate.day.toString().padLeft(2, '0')}.${_workDate.month.toString().padLeft(2, '0')}.${_workDate.year}',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, fontFamily: 'Inter'),
                      ),
                    ]),
                  ]),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _durationH,
                decoration: const InputDecoration(labelText: 'Ek İş Süresi (saat)', hintText: 'Ör: 2.5'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              
              // Onay Durumu ve Maliyet sadece yönetici/adminlere görünür
              if (appState.isGeschaeftsfuehrer || appState.isBetriebsleiter || appState.isSystemAdmin) ...[
                const SizedBox(height: 20),
                _section('Onay Durumu'),
                DropdownButtonFormField<String>(
                  value: _approvalStatus,
                  decoration: const InputDecoration(labelText: 'İşlem Durumu'),
                  items: const [
                    DropdownMenuItem(value: 'recorded', child: Text('Kaydedildi (Taslak)', style: TextStyle(fontFamily: 'Inter'))),
                    DropdownMenuItem(value: 'pending_customer', child: Text('Müşteri Onayı Bekliyor', style: TextStyle(fontFamily: 'Inter'))),
                    DropdownMenuItem(value: 'approved', child: Text('Onaylandı / İşleme Hazır', style: TextStyle(fontFamily: 'Inter'))),
                    DropdownMenuItem(value: 'rejected', child: Text('Reddedildi', style: TextStyle(fontFamily: 'Inter'))),
                  ],
                  onChanged: (v) => setState(() => _approvalStatus = v!),
                ),
                const SizedBox(height: 20),
                _section('Maliyet Bilgileri (Yönetici Özel)'),
                Row(children: [
                  Expanded(child: TextFormField(
                    controller: _materialCost,
                    decoration: const InputDecoration(labelText: 'Malzeme Maliyeti (€)'),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  )),
                  const SizedBox(width: 12),
                  Expanded(child: TextFormField(
                    controller: _laborCost,
                    decoration: const InputDecoration(labelText: 'İşçilik Maliyeti (€)'),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  )),
                ]),
              ],
              const SizedBox(height: 16),
              _section('Ek Bilgiler'),
              _textField('Notlar', _notes, maxLines: 3),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Ek İşi Kaydet'),
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
      validator: required ? (v) => (v == null || v.isEmpty) ? 'Zorunlu alan' : null : null,
    ),
  );
}

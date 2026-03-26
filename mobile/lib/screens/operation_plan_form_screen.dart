import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../providers/app_state.dart';
import '../services/supabase_service.dart';

/// Operasyon planı oluşturma / düzenleme ekranı (Bölüm 7 – Personel Planlama)
class OperationPlanFormScreen extends StatefulWidget {
  final String orderId;
  final String? planId; // null = yeni
  const OperationPlanFormScreen({super.key, required this.orderId, this.planId});

  @override
  State<OperationPlanFormScreen> createState() => _OperationPlanFormScreenState();
}

class _OperationPlanFormScreenState extends State<OperationPlanFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _siteInstructions = TextEditingController();
  final _equipmentNotes = TextEditingController();
  final _materialNotes = TextEditingController();
  final _notes = TextEditingController();
  final _estDuration = TextEditingController();

  DateTime _planDate = DateTime.now();
  TimeOfDay _startTime = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay? _endTime;
  String? _supervisorId;
  List<String> _selectedPersonnelIds = [];
  bool _saving = false;

  List<Map<String, dynamic>> _personnel = [];

  @override
  void initState() {
    super.initState();
    _loadData();
    if (widget.planId != null) _loadPlan();
  }

  Future<void> _loadData() async {
    final appState = context.read<AppState>();
    try {
      final users = await SupabaseService.getUsers(
        companyId: appState.companyId,
        status: 'active',
      );
      if (mounted) setState(() => _personnel = users);
    } catch (_) {}
  }

  Future<void> _loadPlan() async {
    try {
      final data = await SupabaseService.client
          .from('operation_plans')
          .select('*, operation_plan_personnel(user_id)')
          .eq('id', widget.planId!)
          .maybeSingle();
      if (data != null && mounted) {
        setState(() {
          _planDate = DateTime.parse(data['plan_date']);
          if (data['start_time'] != null) {
            final parts = (data['start_time'] as String).split(':');
            _startTime = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
          }
          if (data['end_time'] != null) {
            final parts = (data['end_time'] as String).split(':');
            _endTime = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
          }
          _supervisorId = data['site_supervisor_id'];
          _siteInstructions.text = data['site_instructions'] ?? '';
          _equipmentNotes.text = data['equipment_notes'] ?? '';
          _materialNotes.text = data['material_notes'] ?? '';
          _notes.text = data['notes'] ?? '';
          _estDuration.text = data['estimated_duration_h']?.toString() ?? '';
          final pp = data['operation_plan_personnel'] as List? ?? [];
          _selectedPersonnelIds = pp.map((e) => e['user_id'] as String).toList();
        });
      }
    } catch (_) {}
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _planDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) setState(() => _planDate = picked);
  }

  Future<void> _pickTime(bool isStart) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _startTime : (_endTime ?? const TimeOfDay(hour: 17, minute: 0)),
    );
    if (picked != null) {
      setState(() => isStart ? _startTime = picked : _endTime = picked);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final appState = context.read<AppState>();
    setState(() => _saving = true);
    try {
      final startStr = '${_startTime.hour.toString().padLeft(2, '0')}:${_startTime.minute.toString().padLeft(2, '0')}:00';
      final endStr = _endTime != null
          ? '${_endTime!.hour.toString().padLeft(2, '0')}:${_endTime!.minute.toString().padLeft(2, '0')}:00'
          : null;

      final planData = {
        if (widget.planId != null) 'id': widget.planId,
        'order_id': widget.orderId,
        'plan_date': _planDate.toIso8601String().split('T')[0],
        'start_time': startStr,
        if (endStr != null) 'end_time': endStr,
        if (_estDuration.text.isNotEmpty) 'estimated_duration_h': double.tryParse(_estDuration.text),
        if (_supervisorId != null) 'site_supervisor_id': _supervisorId,
        'planned_by': appState.userId,
        'site_instructions': _siteInstructions.text.trim(),
        'equipment_notes': _equipmentNotes.text.trim(),
        'material_notes': _materialNotes.text.trim(),
        'notes': _notes.text.trim(),
      };

      if (widget.planId == null) {
        final result = await SupabaseService.client.from('operation_plans').insert(planData).select().single();
        final newPlanId = result['id'] as String;
        if (_selectedPersonnelIds.isNotEmpty) {
          await SupabaseService.assignPersonnelToPlan(newPlanId, _selectedPersonnelIds, appState.userId);
        }
      } else {
        await SupabaseService.client.from('operation_plans').update(planData).eq('id', widget.planId!);
        // Remove old assignments and re-insert
        await SupabaseService.client.from('operation_plan_personnel').delete().eq('operation_plan_id', widget.planId!);
        if (_selectedPersonnelIds.isNotEmpty) {
          await SupabaseService.assignPersonnelToPlan(widget.planId!, _selectedPersonnelIds, appState.userId);
        }
      }

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
    _siteInstructions.dispose();
    _equipmentNotes.dispose();
    _materialNotes.dispose();
    _notes.dispose();
    _estDuration.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.planId == null ? 'Yeni Operasyon Planı' : 'Planı Düzenle')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _section('Tarih & Saat'),
            // Tarih
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
                    const Text('Plan Tarihi', style: TextStyle(fontSize: 12, color: AppTheme.textSub, fontFamily: 'Inter')),
                    Text(
                      '${_planDate.day.toString().padLeft(2, '0')}.${_planDate.month.toString().padLeft(2, '0')}.${_planDate.year}',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, fontFamily: 'Inter'),
                    ),
                  ]),
                ]),
              ),
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: _timeTile('Başlangıç Saati *', _startTime.format(context), () => _pickTime(true))),
              const SizedBox(width: 12),
              Expanded(child: _timeTile('Bitiş Saati', _endTime?.format(context) ?? 'Seçiniz', () => _pickTime(false))),
            ]),
            const SizedBox(height: 12),
            TextFormField(
              controller: _estDuration,
              decoration: const InputDecoration(labelText: 'Tahmini Süre (saat)', hintText: 'Ör: 4.5'),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 20),

            // Personel Atama
            _section('Personel Atama'),
            if (_personnel.isEmpty)
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: Text('Personel yükleniyor...', style: TextStyle(color: AppTheme.textSub, fontFamily: 'Inter')),
              )
            else
              ..._personnel.map((user) {
                final id = user['id'] as String;
                final name = '${user['first_name'] ?? ''} ${user['last_name'] ?? ''}'.trim();
                final role = AppTheme.roleLabel(user['role'] ?? '');
                final selected = _selectedPersonnelIds.contains(id);
                return CheckboxListTile(
                  value: selected,
                  onChanged: (v) {
                    setState(() {
                      if (v == true) {
                        _selectedPersonnelIds.add(id);
                      } else {
                        _selectedPersonnelIds.remove(id);
                        if (_supervisorId == id) _supervisorId = null;
                      }
                    });
                  },
                  title: Text(name, style: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w500)),
                  subtitle: Text(role, style: const TextStyle(fontSize: 12, color: AppTheme.textSub, fontFamily: 'Inter')),
                  secondary: selected && _selectedPersonnelIds.isNotEmpty
                      ? GestureDetector(
                          onTap: () => setState(() => _supervisorId = _supervisorId == id ? null : id),
                          child: Icon(
                            Icons.star,
                            color: _supervisorId == id ? AppTheme.warning : AppTheme.border,
                            size: 22,
                          ),
                        )
                      : null,
                  controlAffinity: ListTileControlAffinity.leading,
                  dense: true,
                );
              }),
            if (_selectedPersonnelIds.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8, top: 4),
                child: Text(
                  '⭐ Yıldıza tıklayarak saha sorumlusunu belirleyin',
                  style: const TextStyle(fontSize: 12, color: AppTheme.textSub, fontFamily: 'Inter'),
                ),
              ),
            const SizedBox(height: 16),

            // Saha Sorumlusu Özet
            if (_supervisorId != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.warning.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.warning.withOpacity(0.3)),
                ),
                child: Row(children: [
                  const Icon(Icons.star, color: AppTheme.warning, size: 18),
                  const SizedBox(width: 8),
                  Expanded(child: Text(
                    'Saha Sorumlusu: ${_personnel.firstWhere((u) => u['id'] == _supervisorId, orElse: () => {})['first_name'] ?? ''} ${_personnel.firstWhere((u) => u['id'] == _supervisorId, orElse: () => {})['last_name'] ?? ''}',
                    style: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w500),
                  )),
                ]),
              ),
              const SizedBox(height: 16),
            ],

            // Talimatlar
            _section('Saha Talimatları & Notlar'),
            TextFormField(
              controller: _siteInstructions,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Saha Talimatları',
                hintText: 'Giriş bilgisi, özel kurallar, dikkat edilmesi gerekenler...',
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _equipmentNotes,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Ekipman / Araç Notları', hintText: 'Gerekli ekipmanlar...'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _materialNotes,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Malzeme Notları', hintText: 'Götürülmesi gereken malzemeler...'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _notes,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'İç Notlar'),
            ),
            const SizedBox(height: 28),
            ElevatedButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Text(widget.planId == null ? 'Planı Oluştur' : 'Güncelle'),
            ),
            const SizedBox(height: 28),
          ],
        ),
      ),
    );
  }

  Widget _section(String title) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textSub, fontFamily: 'Inter')),
  );

  Widget _timeTile(String label, String value, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        border: Border.all(color: AppTheme.border),
        borderRadius: BorderRadius.circular(12),
        color: Colors.white,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.textSub, fontFamily: 'Inter')),
        const SizedBox(height: 2),
        Row(children: [
          const Icon(Icons.access_time, size: 16, color: AppTheme.primary),
          const SizedBox(width: 4),
          Text(value, style: const TextStyle(fontSize: 15, fontFamily: 'Inter', fontWeight: FontWeight.w500)),
        ]),
      ]),
    ),
  );
}

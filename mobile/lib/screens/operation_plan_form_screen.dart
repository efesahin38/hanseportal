import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../theme/web_utils.dart';
import '../providers/app_state.dart';
import '../services/supabase_service.dart';
import '../services/localization_service.dart';

/// Operasyon planı oluşturma / düzenleme ekranı (Bölüm 7 – Personel Planlama)
class OperationPlanFormScreen extends StatefulWidget {
  final String orderId;
  final String? planId; // null = yeni
  final DateTime? initialDate; // Planlama ekranından başlatıldığında tarih
  const OperationPlanFormScreen({super.key, required this.orderId, this.planId, this.initialDate});

  @override
  State<OperationPlanFormScreen> createState() => _OperationPlanFormScreenState();
}

class _OperationPlanFormScreenState extends State<OperationPlanFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _siteInstructions = TextEditingController();
  final _equipmentNotes = TextEditingController();
  final _materialNotes = TextEditingController();
  final _notes = TextEditingController();

  DateTime _planDate = DateTime.now();
  TimeOfDay _startTime = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay? _endTime;
  String? _supervisorId;
  List<String> _selectedPersonnelIds = [];
  bool _saving = false;
  bool _loadingPersonnel = true;
  String _selectedFilter = 'Tümü'; // Yeni filtre
  String _orderTitle = 'İş'; 
  String _status = 'draft';

  List<Map<String, dynamic>> _personnel = [];
  Set<String> _conflictingUserIds = {};

  @override
  void initState() {
    super.initState();
    if (widget.initialDate != null) {
      _planDate = widget.initialDate!;
    }
    _loadData();
    _loadOrderTitle();
    if (widget.planId != null) _loadPlan();
  }

  Future<void> _loadOrderTitle() async {
    try {
      final order = await SupabaseService.getOrder(widget.orderId);
      if (order != null && mounted) {
        setState(() => _orderTitle = order['title'] ?? tr('İş'));
      }
    } catch (_) {}
  }

  Future<void> _loadData() async {
    final appState = context.read<AppState>();
    try {
      // Tüm departmanları çekiyoruz
      var query = SupabaseService.client
          .from('users')
          .select('*, department:departments(name)')
          .eq('status', 'active');
          
      if (!appState.isGeschaeftsfuehrer && !appState.isSystemAdmin) {
        query = query.eq('company_id', appState.companyId);
      }

      final users = await query;
      
      final assignableUsers = (users as List).where((u) {
        final r = u['role'] ?? '';
        return r == 'mitarbeiter' || r == 'vorarbeiter';
      }).cast<Map<String, dynamic>>().toList();

      if (mounted) setState(() {
        _personnel = assignableUsers;
        _loadingPersonnel = false;
      });
      await _loadConflicts();
    } catch (_) {
      if (mounted) setState(() => _loadingPersonnel = false);
    }
  }

  Future<void> _loadConflicts() async {
    final dateStr = _planDate.toIso8601String().split('T')[0];
    try {
      final res = await SupabaseService.client
          .from('operation_plan_personnel')
          .select('user_id, operation_plans!inner(plan_date)')
          .eq('operation_plans.plan_date', dateStr);
          
      final ids = (res as List).map((row) => row['user_id'] as String).toSet();
      if (mounted) setState(() => _conflictingUserIds = ids);
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
          _status = data['status'] ?? 'draft';
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
    if (picked != null) {
      setState(() => _planDate = picked);
      await _loadConflicts();
    }
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

      double? calculatedDur;
      if (_endTime != null) {
        int hDiff = _endTime!.hour - _startTime.hour;
        int mDiff = _endTime!.minute - _startTime.minute;
        calculatedDur = hDiff + (mDiff / 60.0);
        if (calculatedDur < 0) calculatedDur += 24.0;
      }

      final planData = {
        if (widget.planId != null) 'id': widget.planId,
        'order_id': widget.orderId,
        'plan_date': _planDate.toIso8601String().split('T')[0],
        'start_time': startStr,
        if (endStr != null) 'end_time': endStr,
        if (calculatedDur != null) 'estimated_duration_h': calculatedDur,
        if (_supervisorId != null) 'site_supervisor_id': _supervisorId,
        'planned_by': appState.userId,
        'site_instructions': _siteInstructions.text.trim(),
        'equipment_notes': _equipmentNotes.text.trim(),
        'material_notes': _materialNotes.text.trim(),
        'status': _status,
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
        // Old assignments are removed/re-inserted if needed, but the UI logic handles it
        await SupabaseService.client.from('operation_plan_personnel').delete().eq('operation_plan_id', widget.planId!);
        if (_selectedPersonnelIds.isNotEmpty) {
          await SupabaseService.assignPersonnelToPlan(widget.planId!, _selectedPersonnelIds, appState.userId);
        }
      }

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${tr('Hata')}: $e')));
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.planId == null ? tr('Yeni Operasyon Planı') : tr('Planı Düzenle'))),
      body: WebContentWrapper(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _section(tr('Durum, Tarih & Saat')),
              DropdownButtonFormField<String>(
                value: _status,
                decoration: InputDecoration(labelText: tr('Plan Durumu')),
                items: [
                  DropdownMenuItem(value: 'draft', child: Text(tr('Taslak'))),
                  DropdownMenuItem(value: 'sent', child: Text(tr('Gönderildi'))),
                  DropdownMenuItem(value: 'confirmed', child: Text(tr('Onaylandı'))),
                  DropdownMenuItem(value: 'updated', child: Text(tr('Güncellendi'))),
                  DropdownMenuItem(value: 'cancelled', child: Text(tr('İptal Edildi'))),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _status = v);
                },
              ),
              const SizedBox(height: 12),
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
                      Text(tr('Plan Tarihi'), style: const TextStyle(fontSize: 12, color: AppTheme.textSub, fontFamily: 'Inter')),
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
                Expanded(child: _timeTile(tr('Başlangıç Saati *'), _startTime.format(context), () => _pickTime(true))),
                const SizedBox(width: 12),
                Expanded(child: _timeTile(tr('Bitiş Saati'), _endTime?.format(context) ?? tr('Seçiniz'), () => _pickTime(false))),
              ]),
              const SizedBox(height: 20),
  
              // Personel Atama
              _section(tr('Personel Atama')),
  
              // Filtre Barı
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.only(bottom: 16),
                child: Row(
                  children: ['Tümü', 'Temizlik', 'Hotel Servisi', 'Ray Servisi', 'İnşaat Servisi'].map((filter) {
                    final isSelected = _selectedFilter == filter;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(tr(filter), style: TextStyle(
                          fontFamily: 'Inter',
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                          color: isSelected ? Colors.white : AppTheme.textMain,
                        )),
                        selected: isSelected,
                        selectedColor: AppTheme.primary,
                        backgroundColor: Colors.white,
                        side: BorderSide(color: isSelected ? AppTheme.primary : AppTheme.border),
                        onSelected: (selected) {
                          if (selected) {
                            setState(() => _selectedFilter = filter);
                          }
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),
  
              if (_loadingPersonnel)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(tr('Personel listesi yükleniyor...'), style: const TextStyle(color: AppTheme.textSub, fontFamily: 'Inter')),
                )
              else if (_personnel.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppTheme.error.withOpacity(0.05),
                    border: Border.all(color: AppTheme.error.withOpacity(0.3)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    tr('Atanabilecek hiçbir "Çalışan" veya "İş Lideri" bulunamadı.\n(Lütfen ana menüdeki Personeller ekranından Yeni Personel ekleyin)'),
                    style: const TextStyle(color: AppTheme.textSub, fontFamily: 'Inter', fontSize: 13, height: 1.4),
                  ),
                )
              else
                Builder(
                  builder: (context) {
                    final filteredPersonnel = _personnel.where((user) {
                      if (_selectedFilter == 'Tümü') return true;
                      final posTitle = (user['position_title'] ?? '').toString().toLowerCase();
                      final depName = (user['department']?['name'] ?? '').toString().toLowerCase();
                      final filterLower = _selectedFilter.toLowerCase().replaceAll(' servisi', '').replaceAll(' servis', '');
                      return posTitle.contains(filterLower) || depName.contains(filterLower);
                    }).toList();
  
                    if (filteredPersonnel.isEmpty) {
                      return Padding(
                        padding: EdgeInsets.only(bottom: 16),
                        child: Text(tr('Bu departmanda personel bulunamadı.'), style: const TextStyle(color: AppTheme.textSub, fontFamily: 'Inter')),
                      );
                    }
  
                    return Column(
                      children: filteredPersonnel.map((user) {
                        final id = user['id'] as String;
                        final name = '${user['first_name'] ?? ''} ${user['last_name'] ?? ''}'.trim();
                        final role = user['position_title'] ?? AppTheme.roleLabel(user['role'] ?? '');
                        final selected = _selectedPersonnelIds.contains(id);
                        final hasConflict = _conflictingUserIds.contains(id);
                        
                        return Column(
                          children: [
                            CheckboxListTile(
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
                              title: Row(
                                children: [
                                  Text(name, style: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w500)),
                                  if (hasConflict) ...[
                                    const SizedBox(width: 6),
                                    const Icon(Icons.warning_amber_rounded, color: AppTheme.warning, size: 16),
                                  ]
                                ],
                              ),
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
                            ),
                            if (selected && hasConflict)
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(color: AppTheme.warning.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                                  child: Row(children: [
                                    const Icon(Icons.info_outline, color: AppTheme.warning, size: 14),
                                    const SizedBox(width: 8),
                                    Expanded(child: Text(tr('Bu personelin seçili tarihte başka bir departmanda / projede de mesaisi var!'), style: const TextStyle(fontSize: 11, color: AppTheme.warning))),
                                  ]),
                                ),
                              )
                          ],
                        );
                      }).toList(),
                    );
                  }
                ),
              if (_selectedPersonnelIds.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(bottom: 8, top: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.warning.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppTheme.warning.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.star, color: AppTheme.warning, size: 16),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          tr('İlgili personelin yanındaki yıldıza tıklayarak bu işin Saha Sorumlusunu (İş Lideri) atayabilirsiniz.'),
                          style: TextStyle(fontSize: 12, color: AppTheme.textMain, fontWeight: FontWeight.w500, fontFamily: 'Inter'),
                        ),
                      ),
                    ],
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
                      '${tr('Saha Sorumlusu')}: ${_personnel.firstWhere((u) => u['id'] == _supervisorId, orElse: () => {})['first_name'] ?? ''} ${_personnel.firstWhere((u) => u['id'] == _supervisorId, orElse: () => {})['last_name'] ?? ''}',
                      style: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w500),
                    )),
                  ]),
                ),
                const SizedBox(height: 16),
              ],
  
              // Talimatlar
              _section(tr('Saha Talimatları & Notlar')),
              TextFormField(
                controller: _siteInstructions,
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: tr('Saha Talimatları'),
                  hintText: tr('Giriş bilgisi, özel kurallar, dikkat edilmesi gerekenler...'),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _equipmentNotes,
                maxLines: 2,
                decoration: InputDecoration(labelText: tr('Ekipman / Araç Notları'), hintText: tr('Gerekli ekipmanlar...')),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _materialNotes,
                maxLines: 2,
                decoration: InputDecoration(labelText: tr('Malzeme Notları'), hintText: tr('Gerekli malzemeler...')),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _notes,
                maxLines: 2,
                decoration: InputDecoration(labelText: tr('İç Notlar')),
              ),
              const SizedBox(height: 28),
              ElevatedButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text(widget.planId == null ? tr('Planı Oluştur') : tr('Güncelle')),
              ),
              const SizedBox(height: 28),
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

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../theme/web_utils.dart';
import '../services/supabase_service.dart';
import '../providers/app_state.dart';

/// Yeni iş / mevcut iş düzenleme formu
class OrderFormScreen extends StatefulWidget {
  final String? orderId; // null = yeni oluştur
  final String? initialDepartmentId;
  const OrderFormScreen({super.key, this.orderId, this.initialDepartmentId});

  @override
  State<OrderFormScreen> createState() => _OrderFormScreenState();
}

class _OrderFormScreenState extends State<OrderFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _shortDesc = TextEditingController();
  final _siteAddress = TextEditingController();
  final _customerRef = TextEditingController();
  final _detailedDesc = TextEditingController();
  final _materialNotes = TextEditingController();
  final _notes = TextEditingController();

  String? _selectedCustomerId;
  String? _selectedServiceAreaId;
  String _priority = 'normal';
  double _minBillableHours = 4.0;
  DateTime? _startDate;
  DateTime? _endDate;
  bool _saving = false;

  List<Map<String, dynamic>> _customers = [];
  List<Map<String, dynamic>> _serviceAreas = [];
  List<Map<String, dynamic>> _departments = [];

  @override
  void initState() {
    super.initState();
    _loadDropdowns();
    if (widget.orderId != null) _loadOrder();
  }

  Future<void> _loadDropdowns() async {
    try {
      final appState = context.read<AppState>();
      final customers = await SupabaseService.getCustomers();
      final serviceAreas = await SupabaseService.getServiceAreas();
      
      String? defaultSAId;
      if (widget.initialDepartmentId != null) {
        // Bu departmana ait ilk hizmet alanını bul
        final matching = serviceAreas.where((s) => s['department_id'] == widget.initialDepartmentId).toList();
        if (matching.isNotEmpty) {
          defaultSAId = matching.first['id'].toString();
        }
      }

      if (mounted) {
        setState(() {
          _customers = customers;
          _serviceAreas = serviceAreas;
          if (widget.orderId == null && defaultSAId != null) {
            _selectedServiceAreaId = defaultSAId;
          }
        });
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Dropdown verileri yüklenemedi: $e')));
    }
  }

  Future<void> _loadOrder() async {
    final order = await SupabaseService.getOrder(widget.orderId!);
    if (order != null && mounted) {
      setState(() {
        _title.text = order['title'] ?? '';
        _shortDesc.text = order['short_description'] ?? '';
        _siteAddress.text = order['site_address'] ?? '';
        _customerRef.text = order['customer_ref_number'] ?? '';
        _detailedDesc.text = order['detailed_description'] ?? '';
        _materialNotes.text = order['material_notes'] ?? '';
        _notes.text = order['notes'] ?? '';
        _selectedCustomerId = order['customer_id'];
        _selectedServiceAreaId = order['service_area_id'];
        _priority = order['priority'] ?? 'normal';
        _minBillableHours = (order['minimum_billable_hours'] as num?)?.toDouble() ?? 4.0;
        if (order['planned_start_date'] != null) _startDate = DateTime.parse(order['planned_start_date']);
        if (order['planned_end_date'] != null) _endDate = DateTime.parse(order['planned_end_date']);
      });
    }
  }

  Future<void> _pickDate(bool isStart) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: (isStart ? _startDate : _endDate) ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() => isStart ? _startDate = picked : _endDate = picked);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCustomerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lütfen bir müşteri seçin')));
      return;
    }
    if (_selectedServiceAreaId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lütfen bir hizmet alanı seçin')));
      return;
    }
    
    // Sorumlu departmanı otomatik bul
    final selectedSA = _serviceAreas.firstWhere((s) => s['id'].toString() == _selectedServiceAreaId, orElse: () => <String, dynamic>{});
    final autoDeptId = selectedSA['department_id'];
    
    if (autoDeptId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Hata: Seçilen hizmet alanı için departman tanımlanmamış')));
      return;
    }

    setState(() => _saving = true);
    try {
      final companyIdOfDept = selectedSA['department']?['company_id'] ?? context.read<AppState>().companyId;

      final data = {
        if (widget.orderId != null) 'id': widget.orderId,
        'title': _title.text.trim(),
        'short_description': _shortDesc.text.trim(),
        'site_address': _siteAddress.text.trim(),
        'customer_ref_number': _customerRef.text.trim(),
        'detailed_description': _detailedDesc.text.trim(),
        'material_notes': _materialNotes.text.trim(),
        'notes': _notes.text.trim(),
        'company_id': companyIdOfDept,
        'department_id': autoDeptId,
        'customer_id': _selectedCustomerId,
        'service_area_id': _selectedServiceAreaId,
        'priority': _priority,
        'minimum_billable_hours': _minBillableHours,
        'status': 'draft',
        if (_startDate != null) 'planned_start_date': _startDate!.toIso8601String().split('T')[0],
        if (_endDate != null) 'planned_end_date': _endDate!.toIso8601String().split('T')[0],
      };
      if (widget.orderId == null) {
        await SupabaseService.createOrder(data);
      } else {
        await SupabaseService.client.from('orders').update(data).eq('id', widget.orderId!);
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
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.orderId == null ? 'Yeni İş' : 'İş Düzenle')),
      body: WebContentWrapper(
        child: Form(
          key: _formKey,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 500;
              final fieldWidth = isWide ? (constraints.maxWidth - 32 - 16) / 2 : constraints.maxWidth - 32;
  
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _section('1. Müşteri & Hizmet Bilgileri'),
                  Wrap(
                    spacing: 16,
                    runSpacing: 12,
                    children: [
                      SizedBox(
                        width: fieldWidth,
                        child: _dropdown('Müşteri *', _customers, _selectedCustomerId, 'name', (v) {
                          setState(() {
                            _selectedCustomerId = v;
                            if (v != null) {
                              final customer = _customers.firstWhere((c) => c['id'].toString() == v, orElse: () => <String, dynamic>{});
                              if (customer.isNotEmpty) {
                                if (customer['address'] != null && customer['address'].toString().isNotEmpty) {
                                  _siteAddress.text = customer['address'];
                                }
                                if (customer['notes'] != null && customer['notes'].toString().isNotEmpty) {
                                  _detailedDesc.text = customer['notes'];
                                }
                                if (customer['customer_service_areas'] != null) {
                                  final csa = customer['customer_service_areas'] as List;
                                  if (csa.isNotEmpty) {
                                    final sId = csa.first['service_area_id']?.toString();
                                    final sArea = _serviceAreas.firstWhere((s) => s['id']?.toString() == sId, orElse: () => <String, dynamic>{});
                                    if (sArea.isNotEmpty) {
                                      _selectedServiceAreaId = sId;
                                      _title.text = sArea['name'] ?? '';
                                    }
                                  }
                                }
                              }
                            }
                          });
                        }),
                      ),
                      SizedBox(
                        width: fieldWidth,
                        child: _dropdown('Hizmet Alanı *', _serviceAreas, _selectedServiceAreaId, 'name', (v) => setState(() => _selectedServiceAreaId = v)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  _section('2. Temel Bilgiler'),
                  Wrap(
                    spacing: 16,
                    runSpacing: 0,
                    children: [
                      SizedBox(width: fieldWidth, child: _textField('İş Başlığı *', _title, required: true)),
                      SizedBox(width: fieldWidth, child: _textField('Kısa Açıklama', _shortDesc, maxLines: 2)),
                    ],
                  ),
                  Wrap(
                    spacing: 16,
                    runSpacing: 0,
                    children: [
                      SizedBox(width: fieldWidth, child: _textField('Müşteri Sipariş No', _customerRef)),
                    ],
                  ),
                  const SizedBox(height: 16),

                  _section('3. Saha & Operasyon Detayları'),
                  _textField('Saha Adresi', _siteAddress),
                  _textField('Detaylı İş Açıklaması', _detailedDesc, maxLines: 4),
                  _textField('Malzeme/Ekipman Gereksinimi', _materialNotes, maxLines: 3),
                  const SizedBox(height: 16),
  
                  _section('4. Planlama & Öncelik'),
                  Wrap(
                    spacing: 16,
                    runSpacing: 12,
                    children: [
                      SizedBox(
                        width: fieldWidth,
                        child: DropdownButtonFormField<String>(
                          value: _priority,
                          decoration: const InputDecoration(labelText: 'Öncelik'),
                          items: const [
                            DropdownMenuItem(value: 'low', child: Text('Düşük')),
                            DropdownMenuItem(value: 'normal', child: Text('Normal')),
                            DropdownMenuItem(value: 'high', child: Text('Yüksek')),
                            DropdownMenuItem(value: 'urgent', child: Text('🔴 Acil')),
                          ],
                          onChanged: (v) => setState(() => _priority = v!),
                        ),
                      ),
                      SizedBox(
                        width: fieldWidth,
                        child: TextFormField(
                          initialValue: _minBillableHours.toString(),
                          decoration: const InputDecoration(labelText: 'Min. Faturalanacak Saat', hintText: 'Varsayılan: 4.0'),
                          keyboardType: TextInputType.number,
                          onChanged: (v) => _minBillableHours = double.tryParse(v) ?? 4.0,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(child: _dateTile('Başlangıç', _startDate, () => _pickDate(true))),
                    const SizedBox(width: 12),
                    Expanded(child: _dateTile('Bitiş', _endDate, () => _pickDate(false))),
                  ]),
                  const SizedBox(height: 24),
  
                  _section('5. Ek Notlar'),
                  _textField('Notlar', _notes, maxLines: 4),
                  const SizedBox(height: 32),
                  
                  ElevatedButton(
                    onPressed: _saving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: _saving
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Text(widget.orderId == null ? 'İş Oluştur' : 'Değişiklikleri Kaydet', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 24),
                ],
              );
            },
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

  Widget _dropdown(String label, List<Map<String, dynamic>> items, String? value, String nameKey, ValueChanged<String?> onChanged) {
    if (items.isEmpty) {
      return TextFormField(
        enabled: false,
        decoration: InputDecoration(
          labelText: label,
          hintText: 'Sistemde kayıtlı veri yok (Önce ekleme yapın)',
          hintStyle: const TextStyle(color: Colors.redAccent, fontSize: 13),
        ),
      );
    }
    
    // ID bazlı tekilleştirme yapalım (aynı ID'li müşteri gelirse hata vermemesi için)
    final Map<String, Map<String, dynamic>> uniqueItemsMap = {};
    for (var i in items) {
      if (i['id'] != null) uniqueItemsMap[i['id'].toString()] = i;
    }
    final uniqueItems = uniqueItemsMap.values.toList();
    
    // Eğer seçili değer mevcut listede yoksa, dropdown hata verir. Bunu engelleyelim.
    String? effectiveValue = value;
    if (value != null && !uniqueItemsMap.containsKey(value)) {
      effectiveValue = null;
    }

    return DropdownButtonFormField<String>(
      value: effectiveValue,
      decoration: InputDecoration(labelText: label),
      isExpanded: true,
      items: uniqueItems.map((i) => DropdownMenuItem<String>(
        value: i['id'].toString(),
        child: Text(i[nameKey] ?? '', style: const TextStyle(fontFamily: 'Inter', fontSize: 14), overflow: TextOverflow.ellipsis),
      )).toList(),
      onChanged: onChanged,
    );
  }

  Widget _dateTile(String label, DateTime? date, VoidCallback onTap) => GestureDetector(
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
        Text(
          date == null ? 'Seçiniz' : '${date.day}.${date.month.toString().padLeft(2, '0')}.${date.year}',
          style: TextStyle(fontSize: 14, fontFamily: 'Inter', color: date == null ? AppTheme.textSub : AppTheme.textMain),
        ),
      ]),
    ),
  );
}

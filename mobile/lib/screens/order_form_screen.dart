import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../theme/web_utils.dart';
import '../services/supabase_service.dart';
import '../providers/app_state.dart';
import '../services/localization_service.dart';

/// Yeni iş / mevcut iş düzenleme formu
class OrderFormScreen extends StatefulWidget {
  final String? orderId; // null = yeni oluştur
  final String? initialServiceAreaId;
  final String? initialDepartmentId;
  const OrderFormScreen({super.key, this.orderId, this.initialServiceAreaId, this.initialDepartmentId});

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
  final _streetCtrl = TextEditingController();
  final _houseNumberCtrl = TextEditingController();
  final _plzCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _personnelNeedCtrl = TextEditingController();
  final _materialNeedCtrl = TextEditingController();
  final _netAmountCtrl = TextEditingController();

  String? _selectedCustomerId;
  String? _selectedServiceAreaId;
  String _priority = 'normal';
  String _orderType = 'Standardauftrag';
  String _negotiationType = 'Pauschal';
  double _minBillableHours = 4.0;
  DateTime? _startDate;
  DateTime? _endDate;
  bool _saving = false;
  bool _loading = false;

  List<Map<String, dynamic>> _customers = [];
  List<Map<String, dynamic>> _serviceAreas = [];
  List<Map<String, dynamic>> _departments = [];

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    if (widget.orderId != null) _loadOrder();
  }

  Future<void> _loadInitialData() async {
    try {
      final depts = await SupabaseService.getDepartments();
      final serviceAreas = await SupabaseService.getServiceAreas();
      final List<Map<String, dynamic>> matchedAreas = [];
      
      for (var sa in serviceAreas) {
        final saName = (sa['name'] as String? ?? '').toLowerCase();
        final deptId = sa['department_id']?.toString() ?? '';
        
        // Departman adını bul
        final dept = depts.firstWhere((d) => d['id']?.toString() == deptId, orElse: () => {});
        final deptName = (dept['name'] as String? ?? '').toLowerCase();

        String? displayLabel;

        // 🛡️ NAILED MATCHING: Rail, Bina, Gast, Personel
        if (deptName.contains('rail') || deptName.contains('gleis') || saName.contains('rail') || saName.contains('gleis')) {
          displayLabel = 'Rail Service';
        } else if (deptName.contains('gebäud') || deptName.contains('reinigung') || saName.contains('gebäud') || saName.contains('reinigung')) {
          displayLabel = 'Gebäudedienstleistungen';
        } else if (deptName.contains('gast') || deptName.contains('hotel') || deptName.contains('otel') || saName.contains('gast') || saName.contains('hotel') || saName.contains('otel')) {
          displayLabel = 'Gastwirtschaftsservice';
        } else if (deptName.contains('personal') || deptName.contains('überlassung') || deptName.contains('verwal') || saName.contains('personal') || saName.contains('überlassung') || saName.contains('verwal')) {
          displayLabel = 'Personalüberlassung';
        }

        if (displayLabel != null) {
          if (!matchedAreas.any((m) => m['display_name'] == displayLabel)) {
            matchedAreas.add({...sa, 'display_name': displayLabel});
          }
        }
      }

      var filteredServiceAreas = matchedAreas;
      
      // 🛡️ NAILED ISOLATION: Eğer departman belliyse sadece o departmanın SA'larını göster
      if (widget.initialDepartmentId != null) {
        filteredServiceAreas = filteredServiceAreas.where((sa) => sa['department_id'] == widget.initialDepartmentId).toList();
      }
      
      String? defaultSAId;
      if (widget.initialServiceAreaId != null) {
        final matching = serviceAreas.where((s) => s['id']?.toString() == widget.initialServiceAreaId).toList();
        if (matching.isNotEmpty) {
          defaultSAId = matching.first['id'].toString();
        }
      } else if (widget.initialDepartmentId != null && filteredServiceAreas.isNotEmpty) {
        // Eğer SP belirtilmemişse ama departman varsa, departmanın ilk SA'sını seç
        defaultSAId = filteredServiceAreas.first['id'].toString();
      }

      // 🛡️ NAILED ISOLATION: İlk yüklemede, departman bazlı müşterileri getir (Kesin İzolasyon)
      final customers = await SupabaseService.getCustomers(
        departmentId: widget.initialDepartmentId,
        serviceAreaId: widget.initialDepartmentId == null ? defaultSAId : null,
      );

      if (mounted) {
        setState(() {
          _customers = customers;
          _serviceAreas = filteredServiceAreas;
          
          if (widget.orderId == null && defaultSAId != null) {
            _selectedServiceAreaId = defaultSAId;
          }
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
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
        _streetCtrl.text = order['street'] ?? '';
        _houseNumberCtrl.text = order['house_number'] ?? '';
        _plzCtrl.text = order['postal_code'] ?? '';
        _cityCtrl.text = order['city'] ?? '';
        _personnelNeedCtrl.text = order['personnel_need']?.toString() ?? '';
        _materialNeedCtrl.text = order['material_need'] ?? '';
        _netAmountCtrl.text = order['net_amount']?.toString() ?? '';
        _orderType = order['order_type'] ?? 'Standardauftrag';
        _negotiationType = order['negotiation_type'] ?? 'Pauschal';
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('Lütfen bir müşteri seçin'))));
      return;
    }
    if (_selectedServiceAreaId == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('Lütfen bir hizmet alanı seçin'))));
      return;
    }
    
    // Sorumlu departmanı otomatik bul
    final selectedSA = _serviceAreas.firstWhere((s) => s['id'].toString() == _selectedServiceAreaId, orElse: () => <String, dynamic>{});
    final autoDeptId = selectedSA['department_id'];
    
    if (autoDeptId == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('Hata: Seçilen hizmet alanı için departman tanımlanmamış'))));
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
        'order_type': _orderType,
        'negotiation_type': _negotiationType,
        'street': _streetCtrl.text.trim(),
        'house_number': _houseNumberCtrl.text.trim(),
        'postal_code': _plzCtrl.text.trim(),
        'city': _cityCtrl.text.trim(),
        'personnel_need': int.tryParse(_personnelNeedCtrl.text),
        'material_need': _materialNeedCtrl.text.trim(),
        'net_amount': double.tryParse(_netAmountCtrl.text),
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${tr('Hata')}: $e')));
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.orderId == null ? tr('Yeni İş') : tr('İş Düzenle'))),
      body: WebContentWrapper(
        child: _loading 
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 500;
              final fieldWidth = isWide ? (constraints.maxWidth - 32 - 16) / 2 : constraints.maxWidth - 32;
  
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _section(tr('Müşteri & Hizmet Bilgileri')),
                  Wrap(
                    spacing: 16,
                    runSpacing: 12,
                    children: [
                      SizedBox(
                        width: fieldWidth,
                        child: _dropdown(tr('Müşteri *'), _customers, _selectedCustomerId, 'name', (v) {
                          setState(() {
                            _selectedCustomerId = v;
                            if (v != null) {
                              final customer = _customers.firstWhere((c) => c['id'].toString() == v, orElse: () => <String, dynamic>{});
                              if (customer.isNotEmpty) {
                                // 1. Auto-fill address
                                final addr = customer['address']?.toString() ?? '';
                                final street = addr; // Simple mapping if street isn't separate in customer object
                                final plz = customer['postal_code']?.toString() ?? '';
                                final city = customer['city']?.toString() ?? '';
                                
                                if (addr.isNotEmpty) _siteAddress.text = addr;
                                if (plz.isNotEmpty) _plzCtrl.text = plz;
                                if (city.isNotEmpty) _cityCtrl.text = city;
                                
                                // 2. Auto-fill Service Area if customer has one defined
                                if (customer['customer_service_areas'] != null) {
                                  final csa = customer['customer_service_areas'] as List;
                                  if (csa.isNotEmpty) {
                                    final sId = csa.first['service_area_id']?.toString();
                                    final sArea = _serviceAreas.firstWhere((s) => s['id']?.toString() == sId, orElse: () => <String, dynamic>{});
                                    if (sArea.isNotEmpty) {
                                      _selectedServiceAreaId = sId;
                                      if (_title.text.isEmpty) {
                                        _title.text = sArea['name'] ?? '';
                                      }
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
                        child: _dropdown(tr('Hizmet Alanı *'), _serviceAreas, _selectedServiceAreaId, 'name', (v) async {
                          setState(() {
                            _selectedServiceAreaId = v;
                            _loading = true; // Müşteriler yüklenirken gösterge
                          });
                          
                          // 🛡️ NAILED ISOLATION: Bölüm içindeki tüm müşterileri göstermeye devam et 
                          // (Sadece SA seçince daraltmak yerine departman seviyesinde tutuyoruz)
                          // Eğer departman bilgisi varsa departman bazlı, yoksa SA bazlı getir
                          final filteredCustomers = await SupabaseService.getCustomers(
                            departmentId: widget.initialDepartmentId,
                            serviceAreaId: widget.initialDepartmentId == null ? v : null,
                          );
                          if (mounted) {
                            setState(() {
                              _customers = filteredCustomers;
                              // Eğer önceden seçili müşteri yeni listede yoksa seçimi temizle
                              if (_selectedCustomerId != null && !filteredCustomers.any((c) => c['id'] == _selectedCustomerId)) {
                                _selectedCustomerId = null;
                              }
                              _loading = false;
                              
                              if (v != null) {
                                final sArea = _serviceAreas.firstWhere((s) => s['id']?.toString() == v, orElse: () => <String, dynamic>{});
                                if (sArea.isNotEmpty) {
                                  _title.text = sArea['name'] ?? '';
                                }
                              }
                            });
                          }
                        }),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  _section(tr('Temel Bilgiler')),
                  Wrap(
                    spacing: 16,
                    runSpacing: 0,
                    children: [
                      SizedBox(width: fieldWidth, child: _textField(tr('İş Başlığı *'), _title, required: true)),
                      SizedBox(width: fieldWidth, child: _textField(tr('Kısa Açıklama'), _shortDesc, maxLines: 2)),
                    ],
                  ),
                  Wrap(
                    spacing: 16,
                    runSpacing: 0,
                    children: [
                      SizedBox(width: fieldWidth, child: _textField(tr('Müşteri Sipariş No'), _customerRef)),
                    ],
                  ),
                  const SizedBox(height: 16),

                  _section(tr('Saha & Operasyon Detayları')),
                  _textField(tr('Saha Adresi'), _siteAddress),
                  Wrap(spacing: 16, runSpacing: 0, children: [
                    SizedBox(width: fieldWidth, child: _textField(tr('Straße'), _streetCtrl)),
                    SizedBox(width: fieldWidth * 0.4, child: _textField(tr('Hausnr.'), _houseNumberCtrl)),
                    SizedBox(width: fieldWidth * 0.35, child: _textField(tr('PLZ'), _plzCtrl)),
                    SizedBox(width: fieldWidth * 0.6, child: _textField(tr('Ort'), _cityCtrl)),
                  ]),
                  _textField(tr('Detaylı İş Açıklaması'), _detailedDesc, maxLines: 4),
                  _textField(tr('Malzeme/Ekipman Gereksinimi'), _materialNotes, maxLines: 3),
                  const SizedBox(height: 16),

                  _section(tr('Auftragsart & Verhandlung')),
                  Wrap(spacing: 16, runSpacing: 12, children: [
                    SizedBox(width: fieldWidth, child: DropdownButtonFormField<String>(
                      value: _orderType,
                      decoration: InputDecoration(labelText: tr('Auftragsart')),
                      items: ['Standardauftrag', 'Rahmenvertrag', 'Einzelauftrag', 'Notfall', 'Sonderauftrag']
                          .map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                      onChanged: (v) => setState(() => _orderType = v!),
                    )),
                    SizedBox(width: fieldWidth, child: DropdownButtonFormField<String>(
                      value: _negotiationType,
                      decoration: InputDecoration(labelText: tr('Verhandlungsart')),
                      items: ['Pauschal', 'Stundenverrechnungssatz', 'Summe netto']
                          .map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                      onChanged: (v) => setState(() => _negotiationType = v!),
                    )),
                    if (_negotiationType == 'Summe netto')
                      SizedBox(width: fieldWidth, child: _textField(tr('Summe netto (€)'), _netAmountCtrl)),
                    SizedBox(width: fieldWidth, child: _textField(tr('Personalbedarf (Anzahl)'), _personnelNeedCtrl)),
                    SizedBox(width: fieldWidth, child: _textField(tr('Materialbedarf'), _materialNeedCtrl, maxLines: 2)),
                  ]),
                  const SizedBox(height: 16),
  
                  _section(tr('Planlama & Öncelik')),
                  Wrap(
                    spacing: 16,
                    runSpacing: 12,
                    children: [
                      SizedBox(
                        width: fieldWidth,
                        child: DropdownButtonFormField<String>(
                          value: _priority,
                          decoration: InputDecoration(labelText: tr('Öncelik')),
                          items: [
                            DropdownMenuItem(value: 'low', child: Text(tr('Düşük'))),
                            DropdownMenuItem(value: 'normal', child: Text(tr('Normal'))),
                            DropdownMenuItem(value: 'high', child: Text(tr('Yüksek'))),
                            DropdownMenuItem(value: 'urgent', child: Text('🔴 ${tr('Acil')}')),
                          ],
                          onChanged: (v) => setState(() => _priority = v!),
                        ),
                      ),
                      SizedBox(
                        width: fieldWidth,
                        child: TextFormField(
                          initialValue: _minBillableHours.toString(),
                          decoration: InputDecoration(labelText: tr('Min. Faturalanacak Saat'), hintText: '${tr('Varsayılan')}: 4.0'),
                          keyboardType: TextInputType.number,
                          onChanged: (v) => _minBillableHours = double.tryParse(v) ?? 4.0,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(child: _dateTile(tr('Başlangıç'), _startDate, () => _pickDate(true))),
                    const SizedBox(width: 12),
                    Expanded(child: _dateTile(tr('Bitiş'), _endDate, () => _pickDate(false))),
                  ]),
                  const SizedBox(height: 24),
  
                  _section(tr('Ek Notlar')),
                  _textField(tr('Notlar'), _notes, maxLines: 4),
                  const SizedBox(height: 32),
                  
                  ElevatedButton(
                    onPressed: _saving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: _saving
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Text(widget.orderId == null ? tr('İş Oluştur') : tr('Değişiklikleri Kaydet'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
      validator: required ? (v) => (v == null || v.isEmpty) ? tr('Zorunlu alan') : null : null,
    ),
  );

  Widget _dropdown(String label, List<Map<String, dynamic>> items, String? value, String nameKey, ValueChanged<String?> onChanged) {
    if (items.isEmpty) {
      return TextFormField(
        enabled: false,
        decoration: InputDecoration(
          labelText: label,
          hintText: tr('Sistemde kayıtlı veri yok (Önce ekleme yapın)'),
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
        Text('v16.8', style: const TextStyle(color: Colors.white70, fontSize: 12, fontFamily: 'Inter')),
        const SizedBox(height: 2),
        Text(
          date == null ? tr('Seçiniz') : '${date.day}.${date.month.toString().padLeft(2, '0')}.${date.year}',
          style: TextStyle(fontSize: 14, fontFamily: 'Inter', color: date == null ? AppTheme.textSub : AppTheme.textMain),
        ),
      ]),
    ),
  );
}

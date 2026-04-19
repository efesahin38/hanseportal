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
  String? _selectedContactId;       // Muhattap (ExtManager)
  String? _selectedSachbearbeiterContactId; // Sachbearbeiter contact
  String? _responsibleUserId;       // Internal responsible user
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
  List<Map<String, dynamic>> _muhattapContacts = [];     // ExtManager type
  List<Map<String, dynamic>> _sachbearbeiterContacts = []; // Sachbearbeiter type
  List<Map<String, dynamic>> _internalUsers = [];

  static List<Map<String, dynamic>>? _cachedAllServiceAreas;
  static List<Map<String, dynamic>>? _cachedAllInternalUsers;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    if (widget.orderId != null) _loadOrder();
  }

  Future<void> _loadInitialData() async {
    try {
      if (mounted) setState(() => _loading = true);

      final List<Map<String, dynamic>> areas = _cachedAllServiceAreas ?? await SupabaseService.getServiceAreas(activeOnly: false);
      _cachedAllServiceAreas = areas;

      final List<Map<String, dynamic>> consolidatedAreas = [];
      
      // v19.2.4: 7 ANA KATEGORİ (GWS eklendi/düzeltildi)
      final categories = [
        {'key': 'Rail', 'label': 'DB-Gleisbausicherung', 'kw': ['rail', 'gleis']},
        {'key': 'Gebäude', 'label': 'Gebäudedienstleistungen', 'kw': ['gebäud', 'reinigung']},
        {'key': 'Personal', 'label': 'Personalüberlassung', 'kw': ['personal', 'über', 'verwal']},
        {'key': 'BauLogistik', 'label': 'Bau-Logistik', 'kw': ['bau-logistik', 'baulogistik', 'bau logistik', 'logistik']},
        {'key': 'Hausmeister', 'label': 'Hausmeisterservice', 'kw': ['hausmeister']},
        {'key': 'Garten', 'label': 'Gartenpflege', 'kw': ['garten', 'grün']},
        {'key': 'Gastwirtschaft', 'label': 'Gastwirtschaftsservice', 'kw': ['gast', 'hotel', 'hospitality', 'gws']},
      ];

      for (var cat in categories) {
        final label = cat['label'] as String;
        final kws = cat['kw'] as List<String>;
        
        var sa = areas.firstWhere((s) {
          final sName = (s['name'] as String? ?? '').toLowerCase();
          return kws.any((kw) => sName.contains(kw));
        }, orElse: () => {});

        if (sa.isNotEmpty) {
          consolidatedAreas.add({...sa, 'display_name': label});
        } else {
          // Eğer tam eşleşme yoksa ama departman ismi uyuyorsa jenerik bir ekle
          consolidatedAreas.add({
            'id': 'dept_${cat['key']}',
            'name': label,
            'display_name': label,
            'department_id': cat['key'], // Fallback
          });
        }
      }

      var filteredServiceAreas = consolidatedAreas;
      
      if (widget.initialDepartmentId != null) {
        final deptIdStr = widget.initialDepartmentId!.toString();
        filteredServiceAreas = filteredServiceAreas.where((sa) => 
          sa['department_id']?.toString() == deptIdStr || 
          sa['id']?.toString().contains(deptIdStr) == true
        ).toList();
      }
      
      String? defaultSAId;
      if (widget.initialServiceAreaId != null) {
        final matching = areas.where((s) => s['id']?.toString() == widget.initialServiceAreaId).toList();
        if (matching.isNotEmpty) {
          defaultSAId = matching.first['id'].toString();
        }
      } else if (widget.initialDepartmentId != null && filteredServiceAreas.isNotEmpty) {
        defaultSAId = filteredServiceAreas.first['id'].toString();
      }

      // 🛡️ NAILED ISOLATION: İlk yüklemede, departman bazlı müşterileri getir (Kesin İzolasyon)
      final customers = await SupabaseService.getCustomers(
        departmentId: widget.initialDepartmentId,
        serviceAreaId: widget.initialDepartmentId == null ? defaultSAId : null,
      );

      // Internal Users fetch (Sachbearbeiterlar için)
      final internalUsers = _cachedAllInternalUsers ?? await SupabaseService.getUsers(status: 'active');
      _cachedAllInternalUsers = internalUsers;
      
      final filteredInternal = internalUsers.where((u) => 
        ['geschaeftsfuehrer', 'betriebsleiter', 'bereichsleiter', 'backoffice', 'buchhaltung'].contains(u['role']?.toString().toLowerCase())
      ).toList();

      if (mounted) {
        setState(() {
          _customers = customers;
          _serviceAreas = filteredServiceAreas;
          _internalUsers = filteredInternal;
          
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
        _selectedContactId = order['customer_contact_id'];
        _responsibleUserId = order['responsible_user_id'];

        if (order['planned_start_date'] != null) _startDate = DateTime.parse(order['planned_start_date']);
        if (order['planned_end_date'] != null) _endDate = DateTime.parse(order['planned_end_date']);
        
        if (_selectedCustomerId != null) _loadCustomerContacts(_selectedCustomerId!);
      });
    }
  }

  Future<void> _loadCustomerContacts(String customerId) async {
    try {
      final contacts = await SupabaseService.getCustomerContacts(customerId);
      if (mounted) {
        setState(() {
          // Muhattap = ExtManager tipi kontaklar
          _muhattapContacts = contacts.where((c) {
            final r = (c['role'] ?? '').toString().toLowerCase();
            return r == 'extmanager' || r == 'external_manager' || r == 'muhattap';
          }).toList();
          // Sachbearbeiter = Sachbearbeiter tipi kontaklar
          _sachbearbeiterContacts = contacts.where((c) {
            final r = (c['role'] ?? '').toString().toLowerCase();
            return r == 'sachbearbeiter';
          }).toList();
          // Reset selections if no longer valid
          if (!_muhattapContacts.any((c) => c['id'] == _selectedContactId)) {
            _selectedContactId = null;
          }
          if (!_sachbearbeiterContacts.any((c) => c['id'] == _selectedSachbearbeiterContactId)) {
            _selectedSachbearbeiterContactId = null;
          }
        });
      }
    } catch (_) {}
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
        'customer_contact_id': _selectedContactId,
        if (_selectedSachbearbeiterContactId != null)
          'sachbearbeiter_contact_id': _selectedSachbearbeiterContactId,
        'responsible_user_id': _responsibleUserId,
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
                        child: _customerSearchField(),
                      ),
                      SizedBox(
                        width: fieldWidth,
                        child: _dropdown(tr('Hizmet Alanı *'), _serviceAreas, _selectedServiceAreaId, 'name', (v) async {
                          setState(() {
                            _selectedServiceAreaId = v;
                            _loading = true;
                          });
                          
                          final filteredCustomers = await SupabaseService.getCustomers(
                            departmentId: widget.initialDepartmentId,
                            serviceAreaId: widget.initialDepartmentId == null ? v : null,
                          );
                          if (mounted) {
                            setState(() {
                              _customers = filteredCustomers;
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
                      SizedBox(
                        width: fieldWidth,
                        child: _contactDropdown(
                          tr('External Management'),
                          _muhattapContacts,
                          _selectedContactId,
                          Icons.person_pin_outlined,
                          (v) => setState(() => _selectedContactId = v),
                        ),
                      ),
                      SizedBox(
                        width: fieldWidth,
                        child: _contactDropdown(
                          tr('Sachbearbeiter (Kunde)'),
                          _sachbearbeiterContacts,
                          _selectedSachbearbeiterContactId,
                          Icons.manage_accounts_outlined,
                          (v) => setState(() => _selectedSachbearbeiterContactId = v),
                        ),
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

                  // ── Finansal alanlar: sadece GF, BL, Muhasebe, Backoffice görebilir ──
                  if (context.read<AppState>().canSeeFinancialDetails) ...[
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
                    ]),
                    const SizedBox(height: 16),
                  ],
                  // Personalbedarf ve Materialbedarf herkes görebilir
                  Wrap(spacing: 16, runSpacing: 12, children: [
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
                      // Min. billable hours sadece finansal yetkiye sahip roller
                      if (context.read<AppState>().canSeeFinancialDetails)
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
                    Expanded(child: _dateTile(tr('Başlangıç'), _startDate, () => _pickDate(true), onClear: () => setState(() => _startDate = null))),
                    const SizedBox(width: 12),
                    Expanded(child: _dateTile(tr('Bitiş'), _endDate, () => _pickDate(false), onClear: () => setState(() => _endDate = null))),
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

  /// v19.2.1: Arama motorlu müşteri seçici
  Widget _customerSearchField() {
    final selectedCustomer = _selectedCustomerId != null
        ? _customers.firstWhere((c) => c['id'].toString() == _selectedCustomerId, orElse: () => <String, dynamic>{})
        : null;
    final hasCustomer = selectedCustomer != null && selectedCustomer.isNotEmpty;

    return GestureDetector(
      onTap: () => _showCustomerSearchDialog(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: hasCustomer ? AppTheme.primary.withOpacity(0.5) : AppTheme.border),
          borderRadius: BorderRadius.circular(12),
          color: Colors.white,
        ),
        child: Row(
          children: [
            Icon(
              hasCustomer ? Icons.business : Icons.search,
              color: hasCustomer ? AppTheme.primary : AppTheme.textSub,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                hasCustomer ? (selectedCustomer['name'] ?? '') : tr('Müşteri seç veya ara...'),
                style: TextStyle(
                  fontSize: 14,
                  fontFamily: 'Inter',
                  color: hasCustomer ? AppTheme.textMain : AppTheme.textSub,
                  fontWeight: hasCustomer ? FontWeight.w600 : FontWeight.normal,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (hasCustomer)
              GestureDetector(
                onTap: () => setState(() => _selectedCustomerId = null),
                child: Icon(Icons.close, size: 16, color: AppTheme.textSub),
              )
            else
              Icon(Icons.arrow_drop_down, color: AppTheme.textSub),
          ],
        ),
      ),
    );
  }

  void _showCustomerSearchDialog() {
    String searchQuery = '';
    List<Map<String, dynamic>> filteredList = List.from(_customers);
    final searchCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          void filterList(String q) {
            setDialogState(() {
              searchQuery = q;
              filteredList = _customers.where((c) {
                final name = (c['name'] ?? '').toString().toLowerCase();
                final city = (c['city'] ?? '').toString().toLowerCase();
                final email = (c['email'] ?? '').toString().toLowerCase();
                return name.contains(q.toLowerCase()) ||
                    city.contains(q.toLowerCase()) ||
                    email.contains(q.toLowerCase());
              }).toList();
            });
          }

          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Container(
              constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.75, maxWidth: 500),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Başlık
                  Container(
                    padding: const EdgeInsets.fromLTRB(20, 16, 16, 12),
                    decoration: BoxDecoration(
                      color: AppTheme.primary,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.business, color: Colors.white, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(tr('Müşteri Seç'), style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'Inter')),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white, size: 20),
                          onPressed: () => Navigator.pop(ctx),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  ),
                  // Arama alanı
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                    child: TextField(
                      controller: searchCtrl,
                      autofocus: true,
                      onChanged: filterList,
                      decoration: InputDecoration(
                        hintText: tr('İsim, şehir veya e-posta ile ara...'),
                        prefixIcon: const Icon(Icons.search, size: 20),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        suffixIcon: searchCtrl.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () {
                                  searchCtrl.clear();
                                  filterList('');
                                },
                              )
                            : null,
                      ),
                    ),
                  ),
                  // Liste
                  Flexible(
                    child: filteredList.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.business_outlined, size: 40, color: AppTheme.textSub),
                                const SizedBox(height: 8),
                                Text(tr('Müşteri bulunamadı'), style: const TextStyle(color: AppTheme.textSub, fontFamily: 'Inter')),
                              ],
                            ),
                          )
                        : ListView.builder(
                            shrinkWrap: true,
                            itemCount: filteredList.length,
                            itemBuilder: (_, i) {
                              final c = filteredList[i];
                              final isSelected = c['id'].toString() == _selectedCustomerId;
                              return InkWell(
                                onTap: () {
                                  Navigator.pop(ctx);
                                  setState(() {
                                    _selectedCustomerId = c['id'].toString();
                                    _loadCustomerContacts(_selectedCustomerId!);
                                    
                                    // Adres otomatik doldur
                                    final addr = c['address']?.toString() ?? '';
                                    final plz = c['postal_code']?.toString() ?? '';
                                    final city = c['city']?.toString() ?? '';
                                    if (addr.isNotEmpty) _siteAddress.text = addr;
                                    if (plz.isNotEmpty) _plzCtrl.text = plz;
                                    if (city.isNotEmpty) _cityCtrl.text = city;
                                    // Hizmet alanı otomatik doldur (Gelişmiş eşleştirme)
                                    if (c['customer_service_areas'] != null) {
                                      final csa = c['customer_service_areas'] as List;
                                      final availableSIds = csa.map((e) => e['service_area_id']?.toString()).toSet();
                                      
                                      // 1. Adım: Mevcut departman kısıtı içindeki service area'lar arasından bak
                                      var matchedSA = _serviceAreas.where((sa) => availableSIds.contains(sa['id']?.toString())).toList();
                                      
                                      // 2. Adım: Eğer departman içinde eşleşme yoksa ama müşteri genel bir SA'ya bağlıysa, 
                                      // dropdown'da görünmesi için o SA'yı geçici olarak _serviceAreas'a ekle veya kısıtı boşalt.
                                      if (matchedSA.isEmpty && availableSIds.isNotEmpty) {
                                        // Eğer bu bir 'Hotelservice' veya 'GWS' karışıklığı ise, isme göre fuzzy match dene
                                        final customerSaNames = csa.map((e) => (e['service_area']?['name'] ?? '').toString().toLowerCase()).toSet();
                                        matchedSA = _serviceAreas.where((sa) {
                                          final name = (sa['name'] ?? '').toString().toLowerCase();
                                          return customerSaNames.any((cn) => cn.contains(name) || name.contains(cn));
                                        }).toList();
                                      }

                                      if (matchedSA.isNotEmpty) {
                                        _selectedServiceAreaId = matchedSA.first['id']?.toString();
                                      } else if (availableSIds.isNotEmpty) {
                                        // Hiç eşleşmediyse bile ilkini seçmeye çalış (dropdown'da yoksa bile state'de kalsın, dropdown null gösterir)
                                        _selectedServiceAreaId = availableSIds.first;
                                      } else {
                                        _selectedServiceAreaId = null;
                                      }
                                    } else {
                                      _selectedServiceAreaId = null;
                                    }
                                  });
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: isSelected ? AppTheme.primary.withOpacity(0.08) : Colors.transparent,
                                    border: Border(bottom: BorderSide(color: AppTheme.divider, width: 0.5)),
                                  ),
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 16,
                                        backgroundColor: AppTheme.primary.withOpacity(0.1),
                                        child: Text(
                                          (c['name']?.toString().trim().isEmpty ?? true) ? '?' : c['name'].toString().trim()[0].toUpperCase(),
                                          style: const TextStyle(color: AppTheme.primary, fontSize: 12, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(c['name'] ?? '', style: TextStyle(fontFamily: 'Inter', fontSize: 14, fontWeight: isSelected ? FontWeight.bold : FontWeight.w500)),
                                            if (c['city'] != null)
                                              Text(c['city'], style: const TextStyle(fontSize: 12, color: AppTheme.textSub, fontFamily: 'Inter')),
                                          ],
                                        ),
                                      ),
                                      if (isSelected)
                                        const Icon(Icons.check_circle, color: AppTheme.primary, size: 18),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                  // Alt çizgi + buton
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Text('${filteredList.length} ${tr('müşteri')}', style: const TextStyle(fontSize: 12, color: AppTheme.textSub, fontFamily: 'Inter')),
                        const Spacer(),
                        TextButton.icon(
                          onPressed: () {
                            Navigator.pop(ctx);
                            // TODO: CustomerFormScreen push eklenebilir
                          },
                          icon: const Icon(Icons.add, size: 16),
                          label: Text(tr('Yeni Müşteri Ekle'), style: const TextStyle(fontSize: 12, fontFamily: 'Inter')),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _dateTile(String label, DateTime? date, VoidCallback onTap, {VoidCallback? onClear}) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        border: Border.all(color: AppTheme.border),
        borderRadius: BorderRadius.circular(12),
        color: Colors.white,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.textSub, fontFamily: 'Inter')),
              const SizedBox(height: 2),
              Text(
                date == null ? tr('Seçiniz') : '${date.day}.${date.month.toString().padLeft(2, '0')}.${date.year}',
                style: TextStyle(fontSize: 14, fontFamily: 'Inter', color: date == null ? AppTheme.textSub : AppTheme.textMain),
              ),
            ]),
          ),
          if (date != null && onClear != null)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: GestureDetector(
                onTap: onClear,
                child: const Icon(Icons.delete_outline, size: 20, color: AppTheme.error),
              ),
            ),
        ],
      ),
    ),
  );

  Widget _contactDropdown(
    String label,
    List<Map<String, dynamic>> contacts,
    String? selectedId,
    IconData icon,
    void Function(String?) onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<String>(
        value: selectedId,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: contacts.isEmpty ? '$label (—)' : label,
          prefixIcon: Icon(icon, size: 20),
        ),
        items: [
          const DropdownMenuItem<String>(value: null, child: Text('— Kein Ansprechpartner —', style: TextStyle(fontFamily: 'Inter', color: Colors.grey))),
          ...contacts.map((c) => DropdownMenuItem<String>(
            value: c['id'].toString(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(c['name'] ?? '', style: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600, fontSize: 13)),
                if (c['email'] != null && (c['email'] as String).isNotEmpty)
                  Text(c['email'], style: const TextStyle(fontFamily: 'Inter', fontSize: 11, color: AppTheme.textSub)),
              ],
            ),
          )),
        ],
        onChanged: onChanged,
      ),
    );
  }
}

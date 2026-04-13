import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../theme/web_utils.dart';
import '../services/supabase_service.dart';
import '../providers/app_state.dart';
import '../services/localization_service.dart';

/// Yeni müşteri / mevcut müşteri düzenleme formu
class CustomerFormScreen extends StatefulWidget {
  final String? customerId;
  const CustomerFormScreen({super.key, this.customerId});

  @override
  State<CustomerFormScreen> createState() => _CustomerFormScreenState();
}

class _CustomerFormScreenState extends State<CustomerFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _address = TextEditingController();
  final _postalCode = TextEditingController();
  final _city = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _taxNumber = TextEditingController();
  final _notes = TextEditingController();
  final _specialAccess = TextEditingController();
  final _billingAddress = TextEditingController();
  final _bankName = TextEditingController();
  final _iban = TextEditingController();
  final _bic = TextEditingController();
  final _vatNumber = TextEditingController();
  String _type = 'company';
  String _status = 'active';

  List<Map<String, dynamic>> _sachbearbeiters = [];
  final List<String> _deletedSachbearbeiters = [];
  String? _selectedServiceAreaId;
  List<Map<String, dynamic>> _serviceAreas = [];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    try {
      final depts = await SupabaseService.getDepartments();
      final allAreas = await SupabaseService.getServiceAreas(activeOnly: false);
      
      final List<Map<String, dynamic>> consolidatedAreas = [];
      
      final categories = [
        {'key': 'Rail', 'label': 'DB-Gleisbausicherung', 'kw': ['rail', 'gleis']},
        {'key': 'Gebäude', 'label': 'Gebäudedienstleistungen', 'kw': ['gebäud', 'reinigung']},
        {'key': 'Personal', 'label': 'Personalüberlassung', 'kw': ['personal', 'über', 'verwal']},
        {'key': 'BauLogistik', 'label': 'Bau-Logistik', 'kw': ['bau-logistik', 'baulogistik', 'bau logistik', 'logistik']},
        {'key': 'Hausmeister', 'label': 'Hausmeisterservice', 'kw': ['hausmeister']},
        {'key': 'Garten', 'label': 'Gartenpflege', 'kw': ['garten', 'grün']},
      ];

      for (var cat in categories) {
        final label = cat['label'] as String;
        final kws = cat['kw'] as List<String>;
        
        var sa = allAreas.firstWhere((s) {
          final sName = (s['name'] as String? ?? '').toLowerCase();
          return kws.any((kw) => sName.contains(kw));
        }, orElse: () => {});

        if (sa.isNotEmpty) {
          consolidatedAreas.add({
            ...sa,
            'display_name': label,
          });
        }
      }

      if (mounted) {
        setState(() {
          _serviceAreas = consolidatedAreas;
        });
      }
    } catch (e) {
      debugPrint('Hizmet alanları yüklenemedi: $e');
    }
    if (widget.customerId != null) {
      await _loadCustomer();
    }
  }

  Future<void> _loadCustomer() async {
    final data = await SupabaseService.getCustomer(widget.customerId!);
    if (data != null && mounted) {
      setState(() {
        _name.text = data['name'] ?? '';
        _address.text = data['address'] ?? '';
        _postalCode.text = data['postal_code'] ?? '';
        _city.text = data['city'] ?? '';
        _phone.text = data['phone'] ?? '';
        _email.text = data['email'] ?? '';
        _taxNumber.text = data['tax_number'] ?? '';
        _notes.text = data['notes'] ?? '';
        _specialAccess.text = data['special_access_info'] ?? '';
        _billingAddress.text = data['billing_address'] ?? '';
        _bankName.text = data['bank_name'] ?? '';
        _iban.text = data['iban'] ?? '';
        _bic.text = data['bic'] ?? '';
        _vatNumber.text = data['vat_number'] ?? '';
        _type = data['customer_type'] ?? 'company';

        if (data['customer_contacts'] != null) {
          _sachbearbeiters = List<Map<String, dynamic>>.from(
            (data['customer_contacts'] as List).where((c) => c['role'] == 'Sachbearbeiter')
          );
        }
        _status = data['status'] ?? 'active';

        if (data['customer_service_areas'] != null) {
          final csa = data['customer_service_areas'] as List;
          if (csa.isNotEmpty) {
            final sId = csa.first['service_area_id']?.toString();
            if (sId != null) _selectedServiceAreaId = sId;
          }
        }
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    
    final companyId = context.read<AppState>().currentUser?['company_id'];
    if (companyId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('Hata: Kullanıcı şirket bilgisi bulunamadı.'))));
        setState(() => _saving = false);
      }
      return;
    }

    try {
      final newId = await SupabaseService.upsertCustomer({
        if (widget.customerId != null) 'id': widget.customerId,
        'name': _name.text.trim(),
        'address': _address.text.trim(),
        'postal_code': _postalCode.text.trim(),
        'city': _city.text.trim(),
        'phone': _phone.text.trim(),
        'email': _email.text.trim(),
        'tax_number': _taxNumber.text.trim(),
        'notes': _notes.text.trim(),
        'special_access_info': _specialAccess.text.trim(),
        'billing_address': _billingAddress.text.trim().isEmpty ? _address.text.trim() : _billingAddress.text.trim(),
        'bank_name': _bankName.text.trim(),
        'iban': _iban.text.trim(),
        'bic': _bic.text.trim(),
        'vat_number': _vatNumber.text.trim(),
        'customer_type': _type,
        'status': _status,
        'company_id': companyId,
        'country': 'Deutschland',
      }, serviceAreaId: _selectedServiceAreaId);

      for (final id in _deletedSachbearbeiters) {
        if (!id.startsWith('new_')) await SupabaseService.deleteCustomerContact(id);
      }

      for (final s in _sachbearbeiters) {
        final dataToSave = Map<String, dynamic>.from(s);
        if (dataToSave['id']?.toString().startsWith('new_') == true) {
          dataToSave.remove('id');
        }
        dataToSave['customer_id'] = newId;
        dataToSave['role'] = 'Sachbearbeiter';
        await SupabaseService.upsertCustomerContact(dataToSave);
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
      appBar: AppBar(title: Text(widget.customerId == null ? tr('Yeni Müşteri') : tr('Müşteri Düzenle'))),
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
                  _section(tr('Temel Bilgiler')),
                  Wrap(
                    spacing: 16,
                    runSpacing: 0,
                    children: [
                      SizedBox(width: fieldWidth, child: _textField(tr('Müşteri / Şirket Adı *'), _name, required: true)),
                      SizedBox(
                        width: fieldWidth,
                        child: DropdownButtonFormField<String>(
                          value: _type,
                          decoration: InputDecoration(labelText: tr('Müşteri Tipi')),
                          items: [
                            DropdownMenuItem(value: 'company', child: Text(tr('Firma / Şirket'), style: const TextStyle(fontFamily: 'Inter'))),
                            DropdownMenuItem(value: 'public_institution', child: Text(tr('Kamu Kurumu'), style: const TextStyle(fontFamily: 'Inter'))),
                            DropdownMenuItem(value: 'individual', child: Text(tr('Şahıs / Bireysel'), style: const TextStyle(fontFamily: 'Inter'))),
                            DropdownMenuItem(value: 'other', child: Text(tr('Diğer'), style: const TextStyle(fontFamily: 'Inter'))),
                          ],
                          onChanged: (v) => setState(() => _type = v!),
                        ),
                      ),
                      SizedBox(
                        width: fieldWidth,
                        child: DropdownButtonFormField<String>(
                          value: _selectedServiceAreaId,
                          decoration: InputDecoration(labelText: tr('Zuständige Bereiche (Hizmet Alanları)')),
                          items: _serviceAreas.map((s) => DropdownMenuItem(
                            value: s['id'].toString(),
                            child: Text(s['display_name'] ?? s['name'] ?? '', style: const TextStyle(fontFamily: 'Inter')),
                          )).toList(),
                          onChanged: (v) => setState(() => _selectedServiceAreaId = v),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  _section(tr('Müşteri Durumu')),
                  Wrap(
                    spacing: 16,
                    children: [
                      SizedBox(width: fieldWidth, child: _statusDropdown()),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  _section(tr('Adres')),
                  _textField(tr('Adres'), _address),
                  Wrap(
                    spacing: 12,
                    children: [
                      SizedBox(width: isWide ? (constraints.maxWidth - 32 - 12) * 0.3 : (constraints.maxWidth - 32 - 12) * 0.3, child: _textField(tr('Posta Kodu'), _postalCode)),
                      SizedBox(width: isWide ? (constraints.maxWidth - 32 - 12) * 0.7 : (constraints.maxWidth - 32 - 12) * 0.7, child: _textField(tr('Şehir'), _city)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  _section(tr('İletişim')),
                  Wrap(
                    spacing: 16,
                    runSpacing: 0,
                    children: [
                      SizedBox(width: fieldWidth, child: _textField(tr('Telefon'), _phone)),
                      SizedBox(width: fieldWidth, child: _textField(tr('E-posta'), _email)),
                      SizedBox(width: fieldWidth, child: _textField(tr('Vergi Numarası'), _taxNumber)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  _section(tr('Ek Bilgiler')),
                  Wrap(
                    spacing: 16,
                    runSpacing: 0,
                    children: [
                      SizedBox(width: fieldWidth, child: _textField(tr('Notlar'), _notes, maxLines: 3)),
                      SizedBox(width: fieldWidth, child: _textField(tr('Saha Erişim Bilgisi'), _specialAccess, maxLines: 2)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  _section(tr('Fatura Adresi')),
                  _textField(tr('Fatura Adresi (Boşsa İş Adresi kullanılır)'), _billingAddress, maxLines: 2),
                  const SizedBox(height: 16),
                  
                  // Finansal Bilgiler
                  if (context.read<AppState>().canSeeFinancialDetails) ...[
                    _section(tr('Finansal Bilgiler (Yetkili)')),
                    Wrap(
                      spacing: 16,
                      runSpacing: 0,
                      children: [
                        SizedBox(width: fieldWidth, child: _textField(tr('USt-IdNr. (KDV No)'), _vatNumber)),
                        SizedBox(width: fieldWidth, child: _textField(tr('Banka Adı'), _bankName)),
                        SizedBox(width: fieldWidth, child: _textField(tr('IBAN'), _iban)),
                        SizedBox(width: fieldWidth, child: _textField(tr('BIC / SWIFT'), _bic)),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
  
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _section('Sachbearbeiter'),
                      IconButton(
                        icon: const Icon(Icons.add_circle, color: AppTheme.primary),
                        onPressed: _showAddSachbearbeiterDialog,
                      )
                    ],
                  ),
                  if (_sachbearbeiters.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 16.0),
                      child: Text('Henüz eklenmemiş', style: TextStyle(color: AppTheme.textSub, fontFamily: 'Inter')),
                    ),
                  ..._sachbearbeiters.map((s) => Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      title: Text(s['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Inter')),
                      subtitle: Text('${s['phone'] ?? ''}\n${s['email'] ?? ''}', style: const TextStyle(fontFamily: 'Inter')),
                      isThreeLine: true,
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () {
                          setState(() {
                            if (s['id'] != null) _deletedSachbearbeiters.add(s['id'].toString());
                            _sachbearbeiters.remove(s);
                          });
                        },
                      ),
                    ),
                  )),
                  
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Text(widget.customerId == null ? tr('Müşteri Oluştur') : tr('Kaydet')),
                  ),
                  const SizedBox(height: 24),
                  const Center(child: Text('HansePortal v16.9', style: TextStyle(color: AppTheme.textSub, fontSize: 10))),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  void _showAddSachbearbeiterDialog() {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final emailCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('Sachbearbeiter Ekle')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: InputDecoration(labelText: tr('İsim Soyisim'))),
            TextField(controller: phoneCtrl, decoration: InputDecoration(labelText: tr('Telefon'))),
            TextField(controller: emailCtrl, decoration: InputDecoration(labelText: tr('E-posta'))),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(tr('İptal'))),
          ElevatedButton(
            onPressed: () {
              if (nameCtrl.text.isEmpty) return;
              setState(() {
                _sachbearbeiters.add({
                  'id': 'new_${DateTime.now().millisecondsSinceEpoch}',
                  'name': nameCtrl.text.trim(),
                  'phone': phoneCtrl.text.trim(),
                  'email': emailCtrl.text.trim(),
                });
              });
              Navigator.pop(ctx);
            },
            child: Text(tr('Ekle')),
          ),
        ],
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
      validator: required ? (v) => (v == null || v.trim().isEmpty) ? tr('Zorunlu alan') : null : null,
    ),
  );

  Widget _statusDropdown() {
    final canEditStatus = context.read<AppState>().canManageCustomers;
    return DropdownButtonFormField<String>(
      value: _status,
      decoration: InputDecoration(labelText: tr('Müşteri Durumu')),
      items: [
        DropdownMenuItem(value: 'active', child: Text('✅ ${tr('Aktif')}', style: const TextStyle(fontFamily: 'Inter'))),
        DropdownMenuItem(value: 'passive', child: Text('⚠️ ${tr('Pasif')}', style: const TextStyle(fontFamily: 'Inter'))),
        DropdownMenuItem(value: 'potential', child: Text('✨ ${tr('Potansiyel')}', style: const TextStyle(fontFamily: 'Inter'))),
        DropdownMenuItem(value: 'archived', child: Text('📁 ${tr('Arşiv')}', style: const TextStyle(fontFamily: 'Inter'))),
      ],
      onChanged: canEditStatus ? (v) => setState(() => _status = v!) : null,
    );
  }
}

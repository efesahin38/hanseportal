import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../theme/web_utils.dart';
import '../services/supabase_service.dart';
import '../providers/app_state.dart';

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
  final _contactName2 = TextEditingController();
  final _contactPhone2 = TextEditingController();
  String _type = 'company';
  String _status = 'active';
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
      final areas = await SupabaseService.getServiceAreas();
      if (mounted) {
        setState(() {
          _serviceAreas = areas;
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
        _contactName2.text = data['secondary_contact_name'] ?? '';
        _contactPhone2.text = data['secondary_contact_phone'] ?? '';
        _type = data['customer_type'] ?? 'company';
        _status = data['status'] ?? 'active';

        if (data['customer_service_areas'] != null) {
          final csa = data['customer_service_areas'] as List;
          if (csa.isNotEmpty) {
            final sId = csa.first['service_area_id']?.toString();
            if (_serviceAreas.any((s) => s['id']?.toString() == sId)) {
              _selectedServiceAreaId = sId;
            }
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
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Hata: Kullanıcı şirket bilgisi bulunamadı.')));
        setState(() => _saving = false);
      }
      return;
    }

    try {
      await SupabaseService.upsertCustomer({
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
        'secondary_contact_name': _contactName2.text.trim(),
        'secondary_contact_phone': _contactPhone2.text.trim(),
        'customer_type': _type,
        'status': _status,
        'company_id': companyId,
        'country': 'Deutschland',
      }, serviceAreaId: _selectedServiceAreaId);
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
      appBar: AppBar(title: Text(widget.customerId == null ? 'Yeni Müşteri' : 'Müşteri Düzenle')),
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
                  _section('Temel Bilgiler'),
                  Wrap(
                    spacing: 16,
                    runSpacing: 0,
                    children: [
                      SizedBox(width: fieldWidth, child: _textField('Müşteri / Şirket Adı *', _name, required: true)),
                      SizedBox(
                        width: fieldWidth,
                        child: DropdownButtonFormField<String>(
                          value: _type,
                          decoration: const InputDecoration(labelText: 'Müşteri Tipi'),
                          items: const [
                            DropdownMenuItem(value: 'company', child: Text('Firma / Şirket', style: TextStyle(fontFamily: 'Inter'))),
                            DropdownMenuItem(value: 'public_institution', child: Text('Kamu Kurumu', style: TextStyle(fontFamily: 'Inter'))),
                            DropdownMenuItem(value: 'individual', child: Text('Şahıs / Bireysel', style: TextStyle(fontFamily: 'Inter'))),
                            DropdownMenuItem(value: 'other', child: Text('Diğer', style: TextStyle(fontFamily: 'Inter'))),
                          ],
                          onChanged: (v) => setState(() => _type = v!),
                        ),
                      ),
                      SizedBox(
                        width: fieldWidth,
                        child: DropdownButtonFormField<String>(
                          value: _selectedServiceAreaId,
                          decoration: const InputDecoration(labelText: 'Varsayılan Hizmet Alanı'),
                          items: _serviceAreas.map((s) => DropdownMenuItem(
                            value: s['id'].toString(),
                            child: Text(s['name'] ?? '', style: const TextStyle(fontFamily: 'Inter')),
                          )).toList(),
                          onChanged: (v) => setState(() => _selectedServiceAreaId = v),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  _section('Müşteri Durumu'),
                  Wrap(
                    spacing: 16,
                    children: [
                      SizedBox(width: fieldWidth, child: _statusDropdown()),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  _section('Adres'),
                  _textField('Adres', _address),
                  Wrap(
                    spacing: 12,
                    children: [
                      SizedBox(width: isWide ? (constraints.maxWidth - 32 - 12) * 0.3 : (constraints.maxWidth - 32 - 12) * 0.3, child: _textField('Posta Kodu', _postalCode)),
                      SizedBox(width: isWide ? (constraints.maxWidth - 32 - 12) * 0.7 : (constraints.maxWidth - 32 - 12) * 0.7, child: _textField('Şehir', _city)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  _section('İletişim'),
                  Wrap(
                    spacing: 16,
                    runSpacing: 0,
                    children: [
                      SizedBox(width: fieldWidth, child: _textField('Telefon', _phone)),
                      SizedBox(width: fieldWidth, child: _textField('E-posta', _email)),
                      SizedBox(width: fieldWidth, child: _textField('Vergi Numarası', _taxNumber)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  _section('Ek Bilgiler'),
                  Wrap(
                    spacing: 16,
                    runSpacing: 0,
                    children: [
                      SizedBox(width: fieldWidth, child: _textField('Notlar', _notes, maxLines: 3)),
                      SizedBox(width: fieldWidth, child: _textField('Saha Erişim Bilgisi', _specialAccess, maxLines: 2)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  _section('Fatura Adresi'),
                  _textField('Fatura Adresi (Boşsa İş Adresi kullanılır)', _billingAddress, maxLines: 2),
                  const SizedBox(height: 16),
                  
                  // Finansal Bilgiler
                  if (context.read<AppState>().canSeeFinancialDetails) ...[
                    _section('Finansal Bilgiler (Yetkili)'),
                    Wrap(
                      spacing: 16,
                      runSpacing: 0,
                      children: [
                        SizedBox(width: fieldWidth, child: _textField('USt-IdNr. (KDV No)', _vatNumber)),
                        SizedBox(width: fieldWidth, child: _textField('Banka Adı', _bankName)),
                        SizedBox(width: fieldWidth, child: _textField('IBAN', _iban)),
                        SizedBox(width: fieldWidth, child: _textField('BIC / SWIFT', _bic)),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
  
                  _section('İkinci İletişim Kişisi'),
                  Wrap(
                    spacing: 16,
                    runSpacing: 0,
                    children: [
                      SizedBox(width: fieldWidth, child: _textField('İsim Soyisim', _contactName2)),
                      SizedBox(width: fieldWidth, child: _textField('Telefon', _contactPhone2)),
                    ],
                  ),
                  
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Text(widget.customerId == null ? 'Müşteri Oluştur' : 'Kaydet'),
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

  Widget _statusDropdown() {
    final role = context.read<AppState>().role;
    final canEditStatus = role == 'geschaeftsfuehrer' || role == 'betriebsleiter';

    return DropdownButtonFormField<String>(
      value: _status,
      decoration: const InputDecoration(labelText: 'Müşteri Durumu'),
      items: const [
        DropdownMenuItem(value: 'active', child: Text('✅ Aktif (Active)', style: TextStyle(fontFamily: 'Inter'))),
        DropdownMenuItem(value: 'passive', child: Text('⚠️ Pasif (Passive)', style: TextStyle(fontFamily: 'Inter'))),
        DropdownMenuItem(value: 'potential', child: Text('✨ Potansiyel (Potential)', style: TextStyle(fontFamily: 'Inter'))),
        DropdownMenuItem(value: 'archived', child: Text('📁 Arşiv (Archived)', style: TextStyle(fontFamily: 'Inter'))),
      ],
      onChanged: canEditStatus ? (v) => setState(() => _status = v!) : null,
    );
  }
}

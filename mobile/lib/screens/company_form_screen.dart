import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/supabase_service.dart';

/// Şirket Oluşturma / Düzenleme Formu (Bölüm 1)
class CompanyFormScreen extends StatefulWidget {
  final Map<String, dynamic>? company; // null = yeni
  const CompanyFormScreen({super.key, this.company});

  @override
  State<CompanyFormScreen> createState() => _CompanyFormScreenState();
}

class _CompanyFormScreenState extends State<CompanyFormScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _name = TextEditingController();
  final _shortName = TextEditingController();
  final _address = TextEditingController();
  final _postalCode = TextEditingController();
  final _city = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _website = TextEditingController();
  final _taxNumber = TextEditingController();
  final _vatNumber = TextEditingController();
  final _tradeRegNumber = TextEditingController();
  final _tradeRegCourt = TextEditingController();
  final _bankName = TextEditingController();
  final _iban = TextEditingController();
  final _bic = TextEditingController();
  final _serviceDesc = TextEditingController();
  final _notes = TextEditingController();

  String _companyType = 'GmbH';
  String _status = 'active';
  String _relationshipType = 'subsidiary';
  bool _saving = false;

  final _companyTypes = ['GmbH', 'UG', 'KG', 'GbR', 'Einzelunternehmen', 'AG', 'other'];
  final _relationTypes = ['parent', 'subsidiary', 'affiliate'];

  @override
  void initState() {
    super.initState();
    if (widget.company != null) _prefill(widget.company!);
  }

  void _prefill(Map<String, dynamic> c) {
    _name.text = c['name'] ?? '';
    _shortName.text = c['short_name'] ?? '';
    _address.text = c['address'] ?? '';
    _postalCode.text = c['postal_code'] ?? '';
    _city.text = c['city'] ?? '';
    _phone.text = c['phone'] ?? '';
    _email.text = c['email'] ?? '';
    _website.text = c['website'] ?? '';
    _taxNumber.text = c['tax_number'] ?? '';
    _vatNumber.text = c['vat_number'] ?? '';
    _tradeRegNumber.text = c['trade_register_number'] ?? '';
    _tradeRegCourt.text = c['trade_register_court'] ?? '';
    _bankName.text = c['bank_name'] ?? '';
    _iban.text = c['iban'] ?? '';
    _bic.text = c['bic'] ?? '';
    _serviceDesc.text = c['service_description'] ?? '';
    _notes.text = c['notes'] ?? '';
    _companyType = c['company_type'] ?? 'GmbH';
    _status = c['status'] ?? 'active';
    _relationshipType = c['relation_type'] ?? 'subsidiary';
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final data = {
        if (widget.company?['id'] != null) 'id': widget.company!['id'],
        'name': _name.text.trim(),
        'short_name': _shortName.text.trim(),
        'address': _address.text.trim(),
        'postal_code': _postalCode.text.trim(),
        'city': _city.text.trim(),
        'country': 'Deutschland',
        'phone': _phone.text.trim(),
        'email': _email.text.trim(),
        'website': _website.text.trim(),
        'tax_number': _taxNumber.text.trim(),
        'vat_number': _vatNumber.text.trim(),
        'trade_register_number': _tradeRegNumber.text.trim(),
        'trade_register_court': _tradeRegCourt.text.trim(),
        'bank_name': _bankName.text.trim(),
        'iban': _iban.text.trim(),
        'bic': _bic.text.trim(),
        'service_description': _serviceDesc.text.trim(),
        'notes': _notes.text.trim(),
        'company_type': _companyType,
        'status': _status,
        'relation_type': _relationshipType,
      };
      await SupabaseService.upsertCompany(data);
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
    for (final c in [_name, _shortName, _address, _postalCode, _city, _phone,
      _email, _website, _taxNumber, _vatNumber, _tradeRegNumber, _tradeRegCourt,
      _bankName, _iban, _bic, _serviceDesc, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.company != null;
    return Scaffold(
      appBar: AppBar(title: Text(isEdit ? 'Şirketi Düzenle' : 'Yeni Şirket')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _section('Temel Bilgiler'),
            _field('Ticari Unvan *', _name, required: true),
            _field('Kısa İsim / Sistem Adı', _shortName),
            Row(children: [
              Expanded(child: DropdownButtonFormField<String>(
                value: _companyType,
                decoration: const InputDecoration(labelText: 'Şirket Türü'),
                items: _companyTypes.map((t) => DropdownMenuItem(value: t, child: Text(t, style: const TextStyle(fontFamily: 'Inter')))).toList(),
                onChanged: (v) => setState(() => _companyType = v!),
              )),
              const SizedBox(width: 12),
              Expanded(child: DropdownButtonFormField<String>(
                value: _status,
                decoration: const InputDecoration(labelText: 'Durum'),
                items: const [
                  DropdownMenuItem(value: 'active', child: Text('Aktif', style: TextStyle(fontFamily: 'Inter'))),
                  DropdownMenuItem(value: 'inactive', child: Text('Pasif', style: TextStyle(fontFamily: 'Inter'))),
                ],
                onChanged: (v) => setState(() => _status = v!),
              )),
            ]),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _relationshipType,
              decoration: const InputDecoration(labelText: 'Grup İlişkisi'),
              items: [
                const DropdownMenuItem(value: 'parent', child: Text('Ana Şirket', style: TextStyle(fontFamily: 'Inter'))),
                const DropdownMenuItem(value: 'subsidiary', child: Text('Bağlı Şirket', style: TextStyle(fontFamily: 'Inter'))),
                const DropdownMenuItem(value: 'affiliate', child: Text('İlişkili Şirket', style: TextStyle(fontFamily: 'Inter'))),
              ],
              onChanged: (v) => setState(() => _relationshipType = v!),
            ),
            const SizedBox(height: 20),

            _section('Adres'),
            _field('Adres', _address, maxLines: 2),
            Row(children: [
              Expanded(flex: 2, child: Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: TextFormField(controller: _postalCode, decoration: const InputDecoration(labelText: 'PLZ')),
              )),
              const SizedBox(width: 12),
              Expanded(flex: 3, child: Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: TextFormField(controller: _city, decoration: const InputDecoration(labelText: 'Şehir')),
              )),
            ]),
            const SizedBox(height: 8),

            _section('İletişim'),
            Row(children: [
              Expanded(child: _field('Telefon', _phone)),
              const SizedBox(width: 12),
              Expanded(child: _field('E-posta', _email)),
            ]),
            _field('Web Sitesi', _website),
            const SizedBox(height: 8),

            _section('Vergi & Hukuki Bilgiler'),
            Row(children: [
              Expanded(child: _field('Vergi No', _taxNumber)),
              const SizedBox(width: 12),
              Expanded(child: _field('USt-IdNr.', _vatNumber)),
            ]),
            Row(children: [
              Expanded(child: _field('Ticaret Tescil No', _tradeRegNumber)),
              const SizedBox(width: 12),
              Expanded(child: _field('Tescil Mahkemesi', _tradeRegCourt)),
            ]),
            const SizedBox(height: 8),

            _section('Banka Bilgileri'),
            _field('Banka Adı', _bankName),
            _field('IBAN', _iban),
            _field('BIC / SWIFT', _bic),
            const SizedBox(height: 8),

            _section('Faaliyet & Notlar'),
            _field('Hizmet Açıklaması', _serviceDesc, maxLines: 3),
            _field('Notlar', _notes, maxLines: 3),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Text(isEdit ? 'Kaydet' : 'Şirket Oluştur'),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _section(String title) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textSub, fontFamily: 'Inter')),
  );

  Widget _field(String label, TextEditingController ctrl, {bool required = false, int maxLines = 1}) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
      controller: ctrl,
      maxLines: maxLines,
      decoration: InputDecoration(labelText: label),
      validator: required ? (v) => (v == null || v.isEmpty) ? 'Zorunlu alan' : null : null,
    ),
  );
}

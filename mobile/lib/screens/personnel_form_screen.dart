import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/supabase_service.dart';

/// Yeni personel / mevcut personel düzenleme formu
class PersonnelFormScreen extends StatefulWidget {
  final String? userId;
  const PersonnelFormScreen({super.key, this.userId});

  @override
  State<PersonnelFormScreen> createState() => _PersonnelFormScreenState();
}

class _PersonnelFormScreenState extends State<PersonnelFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _position = TextEditingController();
  final _pin = TextEditingController();
  final _employeeNumber = TextEditingController();
  final _weeklyHours = TextEditingController();

  String _role = 'mitarbeiter';
  String _employmentType = 'Vollzeit';
  String? _companyId;
  String? _departmentId;
  bool _saving = false;

  List<Map<String, dynamic>> _companies = [];
  List<Map<String, dynamic>> _departments = [];

  final _roles = {
    'mitarbeiter': 'Mitarbeiter',
    'vorarbeiter': 'Vorarbeiter',
    'bereichsleiter': 'Bereichsleiter',
    'betriebsleiter': 'Betriebsleiter',
    'buchhaltung': 'Buchhaltung',
    'backoffice': 'Backoffice',
    'geschaeftsfuehrer': 'Geschäftsführer',
    'system_admin': 'System Admin',
  };

  @override
  void initState() {
    super.initState();
    _loadCompanies();
    if (widget.userId != null) _loadUser();
  }

  Future<void> _loadCompanies() async {
    final data = await SupabaseService.getCompanies(status: 'active');
    if (mounted) setState(() => _companies = data);
  }

  Future<void> _loadDepartments() async {
    if (_companyId == null) return;
    final data = await SupabaseService.getDepartments(_companyId!);
    if (mounted) setState(() { _departments = data; _departmentId = null; });
  }

  Future<void> _loadUser() async {
    final data = await SupabaseService.getUserById(widget.userId!);
    if (data != null && mounted) {
      setState(() {
        _firstName.text = data['first_name'] ?? '';
        _lastName.text = data['last_name'] ?? '';
        _email.text = data['email'] ?? '';
        _phone.text = data['phone'] ?? '';
        _position.text = data['position_title'] ?? '';
        _pin.text = data['pin_code'] ?? '';
        _employeeNumber.text = data['employee_number'] ?? '';
        _weeklyHours.text = data['weekly_hours']?.toString() ?? '';
        _role = data['role'] ?? 'mitarbeiter';
        _employmentType = data['employment_type'] ?? 'Vollzeit';
        _companyId = data['company_id'];
        _departmentId = data['department_id'];
      });
      _loadDepartments();
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_companyId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lütfen bir şirket seçin')));
      return;
    }
    setState(() => _saving = true);
    try {
      await SupabaseService.upsertUser({
        if (widget.userId != null) 'id': widget.userId,
        'first_name': _firstName.text.trim(),
        'last_name': _lastName.text.trim(),
        'email': _email.text.trim(),
        'phone': _phone.text.trim(),
        'position_title': _position.text.trim(),
        'pin_code': _pin.text.trim(),
        'employee_number': _employeeNumber.text.trim().isEmpty ? null : _employeeNumber.text.trim(),
        'weekly_hours': double.tryParse(_weeklyHours.text),
        'role': _role,
        'employment_type': _employmentType,
        'company_id': _companyId,
        'department_id': _departmentId,
        'status': 'active',
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
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.userId == null ? 'Yeni Personel' : 'Personel Düzenle')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _section('Kimlik Bilgileri'),
            Row(children: [
              Expanded(child: _textField('Ad *', _firstName, required: true)),
              const SizedBox(width: 12),
              Expanded(child: _textField('Soyad *', _lastName, required: true)),
            ]),
            _textField('E-posta *', _email, required: true, type: TextInputType.emailAddress),
            _textField('Telefon', _phone, type: TextInputType.phone),
            const SizedBox(height: 16),

            _section('Organizasyon'),
            DropdownButtonFormField<String>(
              value: _companyId,
              decoration: const InputDecoration(labelText: 'Şirket *'),
              isExpanded: true,
              items: _companies.map((c) => DropdownMenuItem<String>(
                value: c['id'].toString(),
                child: Text(c['name'] ?? '', overflow: TextOverflow.ellipsis, style: const TextStyle(fontFamily: 'Inter', fontSize: 14)),
              )).toList(),
              onChanged: (v) { setState(() => _companyId = v); _loadDepartments(); },
            ),
            const SizedBox(height: 12),
            if (_departments.isNotEmpty) ...[
              DropdownButtonFormField<String>(
                value: _departmentId,
                decoration: const InputDecoration(labelText: 'Bölüm'),
                isExpanded: true,
                items: [
                  const DropdownMenuItem<String>(value: null, child: Text('Seçilmedi')),
                  ..._departments.map((d) => DropdownMenuItem<String>(
                    value: d['id'].toString(),
                    child: Text(d['name'] ?? '', style: const TextStyle(fontFamily: 'Inter', fontSize: 14)),
                  )),
                ],
                onChanged: (v) => setState(() => _departmentId = v),
              ),
              const SizedBox(height: 12),
            ],
            DropdownButtonFormField<String>(
              value: _role,
              decoration: const InputDecoration(labelText: 'Rol *'),
              items: _roles.entries.map((e) => DropdownMenuItem<String>(
                value: e.key,
                child: Text(e.value, style: const TextStyle(fontFamily: 'Inter', fontSize: 14)),
              )).toList(),
              onChanged: (v) => setState(() => _role = v!),
            ),
            const SizedBox(height: 12),
            _textField('Pozisyon Başlığı', _position),
            const SizedBox(height: 16),

            _section('Çalışma Bilgileri'),
            DropdownButtonFormField<String>(
              value: _employmentType,
              decoration: const InputDecoration(labelText: 'İstihdam Tipi'),
              items: ['Vollzeit', 'Teilzeit', 'Minijob', 'Werkvertrag', 'Sonstiges'].map((e) =>
                DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontFamily: 'Inter', fontSize: 14)))).toList(),
              onChanged: (v) => setState(() => _employmentType = v!),
            ),
            const SizedBox(height: 12),
            _textField('Haftalık Sözleşme Saati', _weeklyHours, type: TextInputType.number),
            _textField('Personel No', _employeeNumber),
            _textField('PIN (kiosk için)', _pin),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Text(widget.userId == null ? 'Personel Oluştur' : 'Kaydet'),
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

  Widget _textField(String label, TextEditingController ctrl, {bool required = false, TextInputType? type}) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
      controller: ctrl,
      keyboardType: type,
      decoration: InputDecoration(labelText: label),
      validator: required ? (v) => (v == null || v.isEmpty) ? 'Zorunlu alan' : null : null,
    ),
  );
}

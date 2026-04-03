import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../theme/web_utils.dart';
import '../services/supabase_service.dart';
import '../providers/app_state.dart';
import '../services/localization_service.dart';

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
  final _monthlyHours = TextEditingController();

  DateTime? _birthDate;
  DateTime? _entryDate;

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
    _companyId = context.read<AppState>().currentUser?['company_id'];
    _loadCompanies();
    if (widget.userId != null) _loadUser();
  }

  Future<void> _loadCompanies() async {
    // Şirket sabitlendiği için doğrudan bölümleri yükleyebiliriz
    _loadDepartments();
  }

  Future<void> _loadDepartments() async {
    if (_companyId == null) return;
    final data = await SupabaseService.getDepartments(companyId: _companyId!);
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
        _monthlyHours.text = data['monthly_hours']?.toString() ?? '';
        if (data['birth_date'] != null) _birthDate = DateTime.tryParse(data['birth_date']);
        if (data['entry_date'] != null) _entryDate = DateTime.tryParse(data['entry_date']);
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
        'monthly_hours': double.tryParse(_monthlyHours.text),
        'birth_date': _birthDate?.toIso8601String().split('T')[0],
        'entry_date': _entryDate?.toIso8601String().split('T')[0],
        'role': _role,
        'employment_type': _employmentType,
        'company_id': _companyId,
        'department_id': _departmentId,
        'status': 'active',
      });
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
      appBar: AppBar(title: Text(widget.userId == null ? tr('Yeni Personel') : tr('Personel Düzenle'))),
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
                  _section(tr('Kimlik Bilgileri')),
                  Wrap(
                    spacing: 16,
                    runSpacing: 0,
                    children: [
                      SizedBox(width: fieldWidth, child: _textField(tr('Ad *'), _firstName, required: true)),
                      SizedBox(width: fieldWidth, child: _textField(tr('Soyad *'), _lastName, required: true)),
                      SizedBox(width: fieldWidth, child: _textField(tr('E-posta *'), _email, required: true, type: TextInputType.emailAddress)),
                      SizedBox(width: fieldWidth, child: _textField(tr('Telefon'), _phone, type: TextInputType.phone)),
                    ],
                  ),
                  const SizedBox(height: 16),
  
                  _section(tr('Organizasyon')),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 16,
                    runSpacing: 12,
                    children: [
                      if (_departments.isNotEmpty)
                        SizedBox(
                          width: fieldWidth,
                          child: DropdownButtonFormField<String>(
                            value: _departmentId,
                            items: [
                              DropdownMenuItem<String>(value: null, child: Text(tr('Seçilmedi'))),
                              ..._departments.map((d) => DropdownMenuItem<String>(
                                value: d['id'].toString(),
                                child: Text(tr(d['name'] ?? ''), style: const TextStyle(fontFamily: 'Inter', fontSize: 14)),
                              )),
                            ],
                            onChanged: (v) => setState(() => _departmentId = v),
                          ),
                        ),
                      SizedBox(
                        width: fieldWidth,
                        child: DropdownButtonFormField<String>(
                          value: _role,
                          decoration: InputDecoration(labelText: tr('Rol *')),
                          items: _roles.entries.map((e) => DropdownMenuItem<String>(
                            value: e.key,
                            child: Text(e.value, style: const TextStyle(fontFamily: 'Inter', fontSize: 14)),
                          )).toList(),
                          onChanged: (v) => setState(() => _role = v!),
                        ),
                      ),
                      SizedBox(width: fieldWidth, child: _textField(tr('Pozisyon Başlığı'), _position)),
                    ],
                  ),
                  const SizedBox(height: 16),
  
                  _section(tr('Çalışma Bilgileri')),
                  Wrap(
                    spacing: 16,
                    runSpacing: 12,
                    children: [
                      SizedBox(
                        width: fieldWidth,
                        child: DropdownButtonFormField<String>(
                          value: _employmentType,
                          decoration: InputDecoration(labelText: tr('İstihdam Tipi')),
                          items: ['Vollzeit', 'Teilzeit', 'Minijob', 'Werkvertrag', 'Sonstiges'].map((e) =>
                            DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontFamily: 'Inter', fontSize: 14)))).toList(),
                          onChanged: (v) => setState(() => _employmentType = v!),
                        ),
                      ),
                      SizedBox(width: fieldWidth, child: _textField(tr('Haftalık Saat'), _weeklyHours, type: TextInputType.number)),
                      SizedBox(width: fieldWidth, child: _textField(tr('Aylık Saat'), _monthlyHours, type: TextInputType.number)),
                      SizedBox(width: fieldWidth, child: _dateField(tr('Doğum Tarihi'), _birthDate, (d) => setState(() => _birthDate = d))),
                      SizedBox(width: fieldWidth, child: _dateField(tr('İşe Giriş Tarihi'), _entryDate, (d) => setState(() => _entryDate = d))),
                      SizedBox(width: fieldWidth, child: _textField(tr('Personel No'), _employeeNumber)),
                      SizedBox(width: fieldWidth, child: _textField(tr('PIN (kiosk için)'), _pin)),
                    ],
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Text(widget.userId == null ? tr('Personel Oluştur') : tr('Kaydet')),
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

  Widget _textField(String label, TextEditingController ctrl, {bool required = false, TextInputType? type}) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
      controller: ctrl,
      keyboardType: type,
      decoration: InputDecoration(labelText: label),
      validator: required ? (v) => (v == null || v.isEmpty) ? tr('Zorunlu alan') : null : null,
    ),
  );

  Widget _dateField(String label, DateTime? value, Function(DateTime) onPicked) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: InkWell(
      onTap: () async {
        final d = await showDatePicker(
          context: context,
          initialDate: value ?? DateTime.now().subtract(const Duration(days: 365 * 20)),
          firstDate: DateTime(1900),
          lastDate: DateTime.now().add(const Duration(days: 365 * 10)),
        );
        if (d != null) onPicked(d);
      },
      child: InputDecorator(
        decoration: InputDecoration(labelText: label),
        child: Text(
          value == null ? tr('Seçilmedi') : '${value.day}.${value.month}.${value.year}',
          style: const TextStyle(fontFamily: 'Inter', fontSize: 14),
        ),
      ),
    ),
  );
}

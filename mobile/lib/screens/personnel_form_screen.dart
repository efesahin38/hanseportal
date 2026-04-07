import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../theme/web_utils.dart';
import '../services/supabase_service.dart';
import '../providers/app_state.dart';
import '../services/localization_service.dart';

class PersonnelFormScreen extends StatefulWidget {
  final String? userId;
  const PersonnelFormScreen({super.key, this.userId});
  @override
  State<PersonnelFormScreen> createState() => _PersonnelFormScreenState();
}

class _PersonnelFormScreenState extends State<PersonnelFormScreen> {
  final _formKey = GlobalKey<FormState>();
  // Persönliche Daten
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _street = TextEditingController();
  final _houseNumber = TextEditingController();
  final _postalCode = TextEditingController();
  final _city = TextEditingController();
  final _nationality = TextEditingController();
  final _idNumber = TextEditingController();
  // Versicherung & Finanzen
  final _ssn = TextEditingController();
  final _taxId = TextEditingController();
  final _bankName = TextEditingController();
  final _bankIban = TextEditingController();
  final _bankBic = TextEditingController();
  final _hiName = TextEditingController();
  final _hiNumber = TextEditingController();
  // Vertrag
  final _position = TextEditingController();
  final _positionAs = TextEditingController();
  final _activities = TextEditingController();
  final _pin = TextEditingController();
  final _employeeNumber = TextEditingController();
  final _weeklyHours = TextEditingController();
  final _monthlyHours = TextEditingController();
  final _drivingLicenseClass = TextEditingController();
  final _qualifications = TextEditingController();
  final _childrenCount = TextEditingController();

  DateTime? _birthDate, _entryDate, _idIssueDate, _idValidUntil, _trialPeriodUntil, _drivingLicenseSince;
  String _role = 'mitarbeiter';
  String _employmentType = 'Vollzeit';
  String _contractType = 'Vollzeit';
  String _compensationType = 'Stundenlohn';
  String _idType = 'Ausweis';
  String? _companyId, _departmentId;
  bool _saving = false;
  bool _workPermit = false, _maritalStatus = false, _hasChildren = false, _hasDrivingLicense = false, _hasQualifications = false;
  List<Map<String, dynamic>> _departments = [];

  final _roles = {'mitarbeiter': 'Mitarbeiter', 'vorarbeiter': 'Vorarbeiter', 'bereichsleiter': 'Bereichsleiter', 'betriebsleiter': 'Betriebsleiter', 'buchhaltung': 'Buchhaltung', 'backoffice': 'Backoffice', 'geschaeftsfuehrer': 'Geschäftsführer', 'system_admin': 'System Admin'};

  @override
  void initState() {
    super.initState();
    _companyId = context.read<AppState>().currentUser?['company_id'];
    _loadDepartments();
    if (widget.userId != null) _loadUser();
  }

  Future<void> _loadDepartments() async {
    if (_companyId == null) return;
    final data = await SupabaseService.getDepartments(companyId: _companyId!);
    if (mounted) setState(() { _departments = data; });
  }

  Future<void> _loadUser() async {
    final d = await SupabaseService.getUserById(widget.userId!);
    if (d != null && mounted) setState(() {
      _firstName.text = d['first_name'] ?? ''; _lastName.text = d['last_name'] ?? '';
      _email.text = d['email'] ?? ''; _phone.text = d['phone'] ?? '';
      _street.text = d['street'] ?? ''; _houseNumber.text = d['house_number'] ?? '';
      _postalCode.text = d['postal_code'] ?? ''; _city.text = d['city'] ?? '';
      _nationality.text = d['nationality'] ?? ''; _idNumber.text = d['id_number'] ?? '';
      _ssn.text = d['social_security_number'] ?? ''; _taxId.text = d['tax_id'] ?? '';
      _bankName.text = d['bank_name'] ?? ''; _bankIban.text = d['bank_iban'] ?? ''; _bankBic.text = d['bank_bic'] ?? '';
      _hiName.text = d['health_insurance_name'] ?? ''; _hiNumber.text = d['health_insurance_number'] ?? '';
      _position.text = d['position_title'] ?? ''; _positionAs.text = d['position_as'] ?? '';
      _activities.text = d['activities'] ?? ''; _pin.text = d['pin_code'] ?? '';
      _employeeNumber.text = d['employee_number'] ?? '';
      _weeklyHours.text = d['weekly_hours']?.toString() ?? ''; _monthlyHours.text = d['monthly_hours']?.toString() ?? '';
      _drivingLicenseClass.text = d['driving_license_class'] ?? ''; _qualifications.text = d['qualifications'] ?? '';
      _childrenCount.text = d['children_count']?.toString() ?? '0';
      if (d['birth_date'] != null) _birthDate = DateTime.tryParse(d['birth_date']);
      if (d['entry_date'] != null) _entryDate = DateTime.tryParse(d['entry_date']);
      if (d['id_issue_date'] != null) _idIssueDate = DateTime.tryParse(d['id_issue_date']);
      if (d['id_valid_until'] != null) _idValidUntil = DateTime.tryParse(d['id_valid_until']);
      if (d['trial_period_until'] != null) _trialPeriodUntil = DateTime.tryParse(d['trial_period_until']);
      if (d['driving_license_since'] != null) _drivingLicenseSince = DateTime.tryParse(d['driving_license_since']);
      _role = d['role'] ?? 'mitarbeiter'; _employmentType = d['employment_type'] ?? 'Vollzeit';
      _contractType = d['contract_type'] ?? 'Vollzeit'; _compensationType = d['compensation_type'] ?? 'Stundenlohn';
      _idType = d['id_type'] ?? 'Ausweis'; _companyId = d['company_id']; _departmentId = d['department_id'];
      _workPermit = d['work_permit'] == true; _maritalStatus = d['marital_status'] == true;
      _hasChildren = d['has_children'] == true; _hasDrivingLicense = d['has_driving_license'] == true;
      _hasQualifications = d['has_qualifications'] == true;
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await SupabaseService.upsertUser({
        if (widget.userId != null) 'id': widget.userId,
        'first_name': _firstName.text.trim(), 'last_name': _lastName.text.trim(),
        'email': _email.text.trim(), 'phone': _phone.text.trim(),
        'street': _street.text.trim(), 'house_number': _houseNumber.text.trim(),
        'postal_code': _postalCode.text.trim(), 'city': _city.text.trim(),
        'nationality': _nationality.text.trim(), 'id_type': _idType,
        'id_number': _idNumber.text.trim(),
        'id_issue_date': _idIssueDate?.toIso8601String().split('T')[0],
        'id_valid_until': _idValidUntil?.toIso8601String().split('T')[0],
        'work_permit': _workPermit, 'marital_status': _maritalStatus,
        'has_children': _hasChildren, 'children_count': int.tryParse(_childrenCount.text) ?? 0,
        'social_security_number': _ssn.text.trim(), 'tax_id': _taxId.text.trim(),
        'bank_name': _bankName.text.trim(), 'bank_iban': _bankIban.text.trim(), 'bank_bic': _bankBic.text.trim(),
        'health_insurance_name': _hiName.text.trim(), 'health_insurance_number': _hiNumber.text.trim(),
        'position_title': _position.text.trim(), 'position_as': _positionAs.text.trim(),
        'activities': _activities.text.trim(), 'pin_code': _pin.text.trim(),
        'employee_number': _employeeNumber.text.trim().isEmpty ? null : _employeeNumber.text.trim(),
        'weekly_hours': double.tryParse(_weeklyHours.text), 'monthly_hours': double.tryParse(_monthlyHours.text),
        'birth_date': _birthDate?.toIso8601String().split('T')[0],
        'entry_date': _entryDate?.toIso8601String().split('T')[0],
        'trial_period_until': _trialPeriodUntil?.toIso8601String().split('T')[0],
        'role': _role, 'employment_type': _employmentType,
        'contract_type': _contractType, 'compensation_type': _compensationType,
        'has_driving_license': _hasDrivingLicense,
        'driving_license_class': _drivingLicenseClass.text.trim(),
        'driving_license_since': _drivingLicenseSince?.toIso8601String().split('T')[0],
        'has_qualifications': _hasQualifications, 'qualifications': _qualifications.text.trim(),
        'company_id': _companyId, 'department_id': _departmentId, 'status': 'active',
      });
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${tr('Fehler')}: $e'))); setState(() => _saving = false); }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.userId == null ? tr('Neues Personal') : tr('Personal bearbeiten'))),
      body: WebContentWrapper(child: Form(key: _formKey, child: LayoutBuilder(builder: (context, constraints) {
        final isWide = constraints.maxWidth > 500;
        final fw = isWide ? (constraints.maxWidth - 32 - 16) / 2 : constraints.maxWidth - 32;
        return ListView(padding: const EdgeInsets.all(16), children: [
          _sec(tr('Persönliche Daten')),
          Wrap(spacing: 16, runSpacing: 0, children: [
            SizedBox(width: fw, child: _tf(tr('Vorname *'), _firstName, req: true)),
            SizedBox(width: fw, child: _tf(tr('Nachname *'), _lastName, req: true)),
            SizedBox(width: fw, child: _tf(tr('E-Mail *'), _email, req: true, type: TextInputType.emailAddress)),
            SizedBox(width: fw, child: _tf(tr('Telefon'), _phone, type: TextInputType.phone)),
            SizedBox(width: fw, child: _tf(tr('Staatsangehörigkeit'), _nationality)),
            SizedBox(width: fw, child: _df(tr('Geburtsdatum'), _birthDate, (d) => setState(() => _birthDate = d))),
          ]),
          const SizedBox(height: 16),
          _sec(tr('Adresse')),
          Wrap(spacing: 16, runSpacing: 0, children: [
            SizedBox(width: fw, child: _tf(tr('Straße'), _street)),
            SizedBox(width: fw * 0.4, child: _tf(tr('Hausnr.'), _houseNumber)),
            SizedBox(width: fw * 0.4, child: _tf(tr('PLZ'), _postalCode)),
            SizedBox(width: fw, child: _tf(tr('Ort'), _city)),
          ]),
          const SizedBox(height: 16),
          _sec(tr('Arbeitserlaubnis & Ausweis')),
          Wrap(spacing: 16, runSpacing: 12, children: [
            SizedBox(width: fw, child: SwitchListTile(title: Text(tr('Arbeitserlaubnis')), value: _workPermit, onChanged: (v) => setState(() => _workPermit = v))),
            SizedBox(width: fw, child: DropdownButtonFormField<String>(value: _idType, decoration: InputDecoration(labelText: tr('Ausweisart')),
              items: ['Ausweis', 'Reisepass'].map((x) => DropdownMenuItem(value: x, child: Text(x))).toList(), onChanged: (v) => setState(() => _idType = v!))),
            SizedBox(width: fw, child: _tf(tr('Dokumentnummer'), _idNumber)),
            SizedBox(width: fw, child: _df(tr('Ausstellungsdatum'), _idIssueDate, (d) => setState(() => _idIssueDate = d))),
            SizedBox(width: fw, child: _df(tr('Gültig bis'), _idValidUntil, (d) => setState(() => _idValidUntil = d))),
          ]),
          const SizedBox(height: 16),
          _sec(tr('Familienstand')),
          Wrap(spacing: 16, runSpacing: 12, children: [
            SizedBox(width: fw, child: SwitchListTile(title: Text(tr('Verheiratet')), value: _maritalStatus, onChanged: (v) => setState(() => _maritalStatus = v))),
            SizedBox(width: fw, child: SwitchListTile(title: Text(tr('Kinder')), value: _hasChildren, onChanged: (v) => setState(() => _hasChildren = v))),
            if (_hasChildren) SizedBox(width: fw, child: _tf(tr('Anzahl Kinder'), _childrenCount, type: TextInputType.number)),
          ]),
          const SizedBox(height: 16),
          _sec(tr('Sozialversicherung & Steuern')),
          Wrap(spacing: 16, runSpacing: 0, children: [
            SizedBox(width: fw, child: _tf(tr('Sozialversicherungsnr.'), _ssn)),
            SizedBox(width: fw, child: _tf(tr('Steuer-ID'), _taxId)),
          ]),
          const SizedBox(height: 16),
          _sec(tr('Bankverbindung')),
          Wrap(spacing: 16, runSpacing: 0, children: [
            SizedBox(width: fw, child: _tf(tr('Bank'), _bankName)),
            SizedBox(width: fw, child: _tf(tr('IBAN'), _bankIban)),
            SizedBox(width: fw, child: _tf(tr('BIC'), _bankBic)),
          ]),
          const SizedBox(height: 16),
          _sec(tr('Krankenkasse')),
          Wrap(spacing: 16, runSpacing: 0, children: [
            SizedBox(width: fw, child: _tf(tr('Krankenkasse Name'), _hiName)),
            SizedBox(width: fw, child: _tf(tr('Versicherungsnr.'), _hiNumber)),
          ]),
          const SizedBox(height: 16),
          _sec(tr('Organisation & Vertrag')),
          Wrap(spacing: 16, runSpacing: 12, children: [
            if (_departments.isNotEmpty) SizedBox(width: fw, child: DropdownButtonFormField<String>(value: _departmentId,
              items: [DropdownMenuItem<String>(value: null, child: Text(tr('Nicht ausgewählt'))), ..._departments.map((d) => DropdownMenuItem<String>(value: d['id'].toString(), child: Text(tr(d['name'] ?? ''))))],
              onChanged: (v) => setState(() => _departmentId = v))),
            SizedBox(width: fw, child: DropdownButtonFormField<String>(value: _role, decoration: InputDecoration(labelText: tr('Rolle *')),
              items: _roles.entries.map((e) => DropdownMenuItem<String>(value: e.key, child: Text(e.value))).toList(), onChanged: (v) => setState(() => _role = v!))),
            SizedBox(width: fw, child: DropdownButtonFormField<String>(value: _contractType, decoration: InputDecoration(labelText: tr('Vertragsart')),
              items: ['Vollzeit', 'Teilzeit', 'Aushilfe'].map((x) => DropdownMenuItem(value: x, child: Text(x))).toList(), onChanged: (v) => setState(() => _contractType = v!))),
            SizedBox(width: fw, child: DropdownButtonFormField<String>(value: _compensationType, decoration: InputDecoration(labelText: tr('Vergütungsart')),
              items: ['Festlohn', 'Stundenlohn'].map((x) => DropdownMenuItem(value: x, child: Text(x))).toList(), onChanged: (v) => setState(() => _compensationType = v!))),
            SizedBox(width: fw, child: _tf(tr('Anstellung als'), _positionAs)),
            SizedBox(width: fw, child: _tf(tr('Tätigkeiten'), _activities)),
            SizedBox(width: fw, child: _df(tr('Arbeitsbeginn'), _entryDate, (d) => setState(() => _entryDate = d))),
            SizedBox(width: fw, child: _df(tr('Probezeit bis'), _trialPeriodUntil, (d) => setState(() => _trialPeriodUntil = d))),
            SizedBox(width: fw, child: _tf(tr('Wochenstunden'), _weeklyHours, type: TextInputType.number)),
            SizedBox(width: fw, child: _tf(tr('Monatsstunden'), _monthlyHours, type: TextInputType.number)),
            SizedBox(width: fw, child: _tf(tr('Personalnummer'), _employeeNumber)),
            SizedBox(width: fw, child: _tf(tr('PIN (Kiosk)'), _pin)),
          ]),
          const SizedBox(height: 16),
          _sec(tr('Führerschein & Qualifikationen')),
          Wrap(spacing: 16, runSpacing: 12, children: [
            SizedBox(width: fw, child: SwitchListTile(title: Text(tr('Führerschein')), value: _hasDrivingLicense, onChanged: (v) => setState(() => _hasDrivingLicense = v))),
            if (_hasDrivingLicense) ...[
              SizedBox(width: fw, child: _tf(tr('Führerscheinklasse'), _drivingLicenseClass)),
              SizedBox(width: fw, child: _df(tr('Führerschein seit'), _drivingLicenseSince, (d) => setState(() => _drivingLicenseSince = d))),
            ],
            SizedBox(width: fw, child: SwitchListTile(title: Text(tr('Qualifikationen')), value: _hasQualifications, onChanged: (v) => setState(() => _hasQualifications = v))),
            if (_hasQualifications) SizedBox(width: fw, child: _tf(tr('Welche Qualifikationen'), _qualifications, maxLines: 3)),
          ]),
          const SizedBox(height: 24),
          ElevatedButton(onPressed: _saving ? null : _save, child: _saving
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : Text(widget.userId == null ? tr('Personal erstellen') : tr('Speichern'))),
          const SizedBox(height: 24),
        ]);
      }))),
    );
  }

  Widget _sec(String t) => Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(t, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textSub, fontFamily: 'Inter')));
  Widget _tf(String l, TextEditingController c, {bool req = false, TextInputType? type, int maxLines = 1}) => Padding(padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(controller: c, keyboardType: type, maxLines: maxLines, decoration: InputDecoration(labelText: l), validator: req ? (v) => (v == null || v.isEmpty) ? tr('Pflichtfeld') : null : null));
  Widget _df(String l, DateTime? v, Function(DateTime) f) => Padding(padding: const EdgeInsets.only(bottom: 12), child: InkWell(
    onTap: () async { final d = await showDatePicker(context: context, initialDate: v ?? DateTime.now().subtract(const Duration(days: 7300)), firstDate: DateTime(1900), lastDate: DateTime.now().add(const Duration(days: 3650))); if (d != null) f(d); },
    child: InputDecorator(decoration: InputDecoration(labelText: l), child: Text(v == null ? tr('Auswählen') : '${v.day}.${v.month}.${v.year}', style: const TextStyle(fontSize: 14)))));
}

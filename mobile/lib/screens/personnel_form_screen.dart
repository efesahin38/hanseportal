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

  final _grossWage = TextEditingController(); // Brutto saatlik/aylık ücret

  DateTime? _birthDate, _entryDate, _idIssueDate, _idValidUntil, _trialPeriodUntil, _drivingLicenseSince, _contractEndDate;
  String _role = 'mitarbeiter';
  String _employmentType = 'Vollzeit';
  String _contractType = 'Vollzeit';
  String _compensationType = 'Stundenlohn';
  String _idType = 'Ausweis';
  String? _companyId;
  bool _saving = false;
  bool _workPermit = false, _maritalStatus = false, _hasChildren = false, _hasDrivingLicense = false, _hasQualifications = false;
  List<Map<String, dynamic>> _serviceAreas = [];
  List<String> _selectedServiceAreaIds = [];

  final _roles = {'mitarbeiter': 'Mitarbeiter', 'vorarbeiter': 'Vorarbeiter', 'bereichsleiter': 'Bereichsleiter', 'betriebsleiter': 'Betriebsleiter', 'buchhaltung': 'Buchhaltung', 'backoffice': 'Backoffice', 'geschaeftsfuehrer': 'Geschäftsführer', 'system_admin': 'System Admin', 'external_manager': 'Externer Manager'};

  // v19.8.0: DB-Gleisbausicherung spezifische Rolle
  String? _dbGleisbauRole;
  static const _dbGleisbauRoles = {
    'sakra':              'SAKRA – Sicherungsaufsicht',
    'sipo':               'SiPO – Sicherungsposten',
    'buep':               'BÜP – Bahnübergangsposten',
    'sesi':               'SeSi – Selbstsicherer',
    'sas':                'SAS – Schaltantragsteller',
    'hib':                'HIB – Helfer im Bahnbetrieb',
    'bahnerder':          'Bahnerder',
    'sbahn_kurzschliess': 'S-Bahn-Kurzschließer',
    'bediener_monteur':   'Bediener / Monteur',
    'raeumer':            'Räumer',
    'planer_pruefer':     'Planer / Prüfer',
  };

  bool get _isGleisbauSelected => _selectedServiceAreaIds.any((id) {
    final sa = _serviceAreas.firstWhere((s) => s['id'].toString() == id, orElse: () => {});
    final name = (sa['display_name'] ?? sa['name'] ?? '').toString().toLowerCase();
    return name.contains('gleis') || name.contains('db') || name.contains('rail');
  });

  @override
  void initState() {
    super.initState();
    _companyId = context.read<AppState>().currentUser?['company_id'];
    _loadServiceAreas();
    if (widget.userId != null) _loadUser();
  }

  /// Hizmet alanı adından standart bölüm etiketini döndürür (GWS değişikenleri için kritik)
  static String resolveBolumLabel(String saName) {
    final n = saName.toLowerCase();
    if (n.contains('gast') || n.contains('hotel') || n.contains('hospit')) return 'Gastwirtschaftsservice';
    if (n.contains('rail') || n.contains('gleis') || n.contains('db')) return 'DB-Gleisbausicherung';
    if (n.contains('gebäud') || n.contains('reinigung') || n.contains('bau')) return 'Gebäudedienstleistungen';
    if (n.contains('personal') || n.contains('über') || n.contains('verwal')) return 'Personalüberlassung';
    return saName;
  }

  Future<void> _loadServiceAreas() async {
    final areas = await SupabaseService.getServiceAreas(activeOnly: false);
    final List<Map<String, dynamic>> consolidatedAreas = [];
    
    // 4 ANA KATEGORİ — keyword matching ile bulunur
    final categories = [
      {'label': 'DB-Gleisbausicherung',    'kw': ['rail', 'gleis', 'db']},
      {'label': 'Gebäudedienstleistungen', 'kw': ['gebäud', 'reinigung']},
      {'label': 'Personalüberlassung',     'kw': ['personal', 'über', 'verwal']},
      {'label': 'Gastwirtschaftsservice',  'kw': ['gast', 'hotel', 'hospit']},
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
        // Veritabanında bulunamazsa placeholder olarak ekle (UI'da görünsün)
        consolidatedAreas.add({'id': 'missing_${label.toLowerCase()}', 'display_name': label, 'name': label});
      }
    }
    
    if (mounted) setState(() { _serviceAreas = consolidatedAreas; });
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
      if (d['contract_end_date'] != null) _contractEndDate = DateTime.tryParse(d['contract_end_date']);
      if (d['driving_license_since'] != null) _drivingLicenseSince = DateTime.tryParse(d['driving_license_since']);
      _role = d['role'] ?? 'mitarbeiter'; _employmentType = d['employment_type'] ?? 'Vollzeit';
      _contractType = d['contract_type'] ?? 'Vollzeit'; _compensationType = d['compensation_type'] ?? 'Stundenlohn';
      _idType = d['id_type'] ?? 'Ausweis'; _companyId = d['company_id'];
      _dbGleisbauRole = d['db_gleisbau_role'];
      _workPermit = d['work_permit'] == true; _maritalStatus = d['marital_status'] == true;
      _hasChildren = d['has_children'] == true; _hasDrivingLicense = d['has_driving_license'] == true;
      _hasQualifications = d['has_qualifications'] == true;
      // v19.3.8: Brutto ücret yükle
      if (_compensationType == 'Stundenlohn') {
        _grossWage.text = d['hourly_gross_wage']?.toString() ?? '';
      } else {
        _grossWage.text = d['monthly_gross_salary']?.toString() ?? '';
      }
      
      final usa = d['user_service_areas'] as List?;
      if (usa != null) {
        _selectedServiceAreaIds = usa.map((u) => u['service_area_id'].toString()).toList();
      }
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
        'activities': _activities.text.trim(), 
        'pin_code': _pin.text.trim(),
        'password': _pin.text.trim().isEmpty ? '1111' : _pin.text.trim(),
        'employee_number': _employeeNumber.text.trim().isEmpty ? null : _employeeNumber.text.trim(),
        // 🛡️ AUTO-DEPARTMENT: Seçilen ilk hizmet alanının departmanını otomatik ata (İzolasyon için şart)
        'department_id': _selectedServiceAreaIds.isNotEmpty 
            ? _serviceAreas.firstWhere((sa) => _selectedServiceAreaIds.contains(sa['id'].toString()))['department_id']
            : null,
        'weekly_hours': double.tryParse(_weeklyHours.text), 'monthly_hours': double.tryParse(_monthlyHours.text),
        'birth_date': _birthDate?.toIso8601String().split('T')[0],
        'entry_date': _entryDate?.toIso8601String().split('T')[0],
        'trial_period_until': _trialPeriodUntil?.toIso8601String().split('T')[0],
        'contract_end_date': _contractEndDate?.toIso8601String().split('T')[0],
        'role': _role, 'employment_type': _employmentType,
        'contract_type': _contractType, 'compensation_type': _compensationType,
        'has_driving_license': _hasDrivingLicense,
        'driving_license_class': _drivingLicenseClass.text.trim(),
        'driving_license_since': _drivingLicenseSince?.toIso8601String().split('T')[0],
        'has_qualifications': _hasQualifications, 'qualifications': _qualifications.text.trim(),
        'company_id': _companyId, 'status': 'active',
        // v19.8.0: DB-Gleisbausicherung Rolle
        'db_gleisbau_role': _isGleisbauSelected ? _dbGleisbauRole : null,
        // v19.3.8: Brutto ücret kaydet
        if (_compensationType == 'Stundenlohn' && _grossWage.text.isNotEmpty)
          'hourly_gross_wage': double.tryParse(_grossWage.text),
        if (_compensationType == 'Festlohn' && _grossWage.text.isNotEmpty)
          'monthly_gross_salary': double.tryParse(_grossWage.text),
      }, serviceAreaIds: _selectedServiceAreaIds);
      // Vertragsende → takvimde kırmızı (sadece GF/BL görebilir)
      final appState = context.read<AppState>();
      if (widget.userId != null) {
        await SupabaseService.upsertContractEndEvent(
          employeeId: widget.userId!,
          employeeName: '${_firstName.text.trim()} ${_lastName.text.trim()}',
          createdBy: appState.userId,
          contractEndDate: _contractEndDate,
        );
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${tr('Fehler')}: $e'))); setState(() => _saving = false); }
    }
  }

  // v19.8.0: Gleisbau-Rolle Hilfsmethoden
  static IconData _gleisbauRoleIcon(String role) {
    switch (role) {
      case 'sakra': return Icons.security;
      case 'sipo':  return Icons.shield;
      case 'buep':  return Icons.traffic;
      case 'sesi':  return Icons.person_pin;
      case 'sas':   return Icons.electrical_services;
      case 'hib':   return Icons.support_agent;
      case 'bahnerder': return Icons.bolt;
      case 'sbahn_kurzschliess': return Icons.flash_on;
      case 'bediener_monteur': return Icons.build;
      case 'raeumer': return Icons.directions_run;
      case 'planer_pruefer': return Icons.fact_check;
      default: return Icons.train;
    }
  }

  static String _gleisbauRoleDescription(String role) {
    switch (role) {
      case 'sakra': return 'Führt die Sicherungsaufsicht. Leitet die Unterweisung, verantwortet den Leitstand, meldet den Abschluss. Vollzugriff auf alle Einsatzfunktionen.';
      case 'sipo':  return 'Überwacht den Gleisbereich, sichert das Personal. Mobilansicht: eigener Auftrag, Dokumente, Bestätigungen, Meldungen.';
      case 'buep':  return 'Sichert Bahnübergänge während des Einsatzes. Mobilansicht mit Auftrags- und Ansprechpartnerinfo.';
      case 'sesi':  return 'Gesichert durch eigene Maßnahmen. Mobilansicht mit Pflichtbestätigungen und Meldungen.';
      case 'sas':   return 'Schaltantragsteller. Erweiterte Ferngespräch-Erfassungsrechte und Zugang zu Schaltunterlagen.';
      case 'hib':   return 'Unterstützt operative Tätigkeiten im Bahnbetrieb. Mobilansicht mit Auftrags- und Dokumentenzugang.';
      case 'bahnerder': return 'Erdungsarbeiten im Gleisbereich. Zugang zu technischen Unterlagen und Bestätigungsfunktionen.';
      case 'sbahn_kurzschliess': return 'Kurzschlussarbeiten im S-Bahn-Bereich. Spezifische Gerätedokumentation und Bestätigungen.';
      case 'bediener_monteur': return 'Bedient oder montiert Geräte und Maschinen. Erweiterte Gerätedokumentation.';
      case 'raeumer': return 'Räumt Materialien und Rüstzeug. Einfache Mobilansicht mit Bestätigungen.';
      case 'planer_pruefer': return 'Prüft Unterlagen auf Vollständigkeit und Plausibilität. Kommentarrechte, keine Einsatzführung.';
      default: return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final isSelf = widget.userId == appState.userId;
    // Admin, BL ve GF her şeyi düzenleyebilir.
    final canEditSensitive = appState.isGeschaeftsfuehrer || appState.isBetriebsleiter || appState.isSystemAdmin || appState.isBackoffice || appState.isBuchhaltung;
    
    // Kendisi düzenliyorsa ama admin değilse bazı alanlar kısıtlı
    final restrictSensitive = isSelf && !canEditSensitive;


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
            SizedBox(width: fw, child: SwitchListTile(title: Text(tr('Arbeitserlaubnis')), value: _workPermit, onChanged: restrictSensitive ? null : (v) => setState(() => _workPermit = v))),
            SizedBox(width: fw, child: DropdownButtonFormField<String>(value: _idType, decoration: InputDecoration(labelText: tr('Ausweisart')),
              items: ['Ausweis', 'Reisepass'].map((x) => DropdownMenuItem(value: x, child: Text(x))).toList(), onChanged: restrictSensitive ? null : (v) => setState(() => _idType = v!))),
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
            SizedBox(width: fw * 2 + 16, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(tr('Zuständige Bereiche (Hizmet Alanları)'), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textSub)),
              const SizedBox(height: 8),
              if (_serviceAreas.isEmpty)
                const Text('Ladevorgang...')
              else
                Wrap(
                  spacing: 8, runSpacing: 8,
                  children: _serviceAreas.map((sa) {
                    final id = sa['id'].toString();
                    final name = (sa['display_name'] ?? sa['name'] ?? '').toString();
                    final isSel = _selectedServiceAreaIds.contains(id);
                    return FilterChip(
                      label: Text(name, style: const TextStyle(fontFamily: 'Inter', fontSize: 12)),
                      selected: isSel,
                      selectedColor: AppTheme.primary.withOpacity(0.15),
                      checkmarkColor: AppTheme.primary,
                      onSelected: (restrictSensitive || id.startsWith('missing_')) ? null : (v) {
                        setState(() {
                          if (v) _selectedServiceAreaIds.add(id);
                          else _selectedServiceAreaIds.remove(id);
                        });
                      },
                    );
                  }).toList(),
                ),
              // Seçilen bölümlerin özeti – sağ tarafta bölüm adları listelenir
              if (_selectedServiceAreaIds.isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.primary.withOpacity(0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(tr('Atanan Bölümler:'),
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primary, fontFamily: 'Inter')),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: _selectedServiceAreaIds.map((selId) {
                          final sa = _serviceAreas.firstWhere(
                            (s) => s['id'].toString() == selId,
                            orElse: () => {},
                          );
                          if (sa.isEmpty) return const SizedBox.shrink();
                          final label = (sa['display_name'] ?? sa['name'] ?? '').toString();
                          return Chip(
                            label: Text(label, style: const TextStyle(fontSize: 11, fontFamily: 'Inter', color: Colors.white)),
                            backgroundColor: AppTheme.primary,
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            visualDensity: VisualDensity.compact,
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ],
            ])),
            SizedBox(width: fw, child: DropdownButtonFormField<String>(
              value: _role,
              decoration: InputDecoration(labelText: tr('Rolle *')),
              items: _roles.entries.where((e) {
                // Sadece yetkili rolleri göster
                if (context.read<AppState>().isBereichsleiter) {
                  return e.key == 'mitarbeiter' || e.key == 'vorarbeiter';
                }
                return true;
              }).map((e) => DropdownMenuItem<String>(value: e.key, child: Text(e.value))).toList(),
              onChanged: restrictSensitive ? null : (v) => setState(() => _role = v!),
            )),

            // v19.8.0: DB-Gleisbausicherung spezifische Rolle (nur wenn Gleisbau-Bereich gewählt)
            if (_isGleisbauSelected) ...[
              SizedBox(width: fw * 2 + 16, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [const Color(0xFF0D47A1).withOpacity(0.08), const Color(0xFF1565C0).withOpacity(0.04)]),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF0D47A1).withOpacity(0.25)),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: const Color(0xFF0D47A1), borderRadius: BorderRadius.circular(6)), child: const Text('DB-Gleisbausicherung', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'Inter'))),
                      const SizedBox(width: 8),
                      const Text('Einsatzrolle im Gleisbereich', style: TextStyle(fontSize: 12, color: AppTheme.textSub, fontFamily: 'Inter')),
                    ]),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      value: _dbGleisbauRole,
                      decoration: const InputDecoration(
                        labelText: 'Gleisbausicherung-Rolle',
                        helperText: 'Qualifikationsgebundene Funktion im Gleiseinsatz',
                        prefixIcon: Icon(Icons.train, color: Color(0xFF0D47A1), size: 18),
                      ),
                      onChanged: restrictSensitive ? null : (v) => setState(() => _dbGleisbauRole = v),
                      items: [
                        const DropdownMenuItem<String>(value: null, child: Text('– Keine Gleisbau-Funktion –', style: TextStyle(color: AppTheme.textSub))),
                        ..._dbGleisbauRoles.entries.map((e) => DropdownMenuItem<String>(
                          value: e.key,
                          child: Row(children: [
                            Icon(_gleisbauRoleIcon(e.key), size: 16, color: const Color(0xFF0D47A1)),
                            const SizedBox(width: 8),
                            Text(e.value, style: const TextStyle(fontFamily: 'Inter', fontSize: 13)),
                          ]),
                        )),
                      ],
                    ),
                    if (_dbGleisbauRole != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: const Color(0xFF0D47A1).withOpacity(0.08), borderRadius: BorderRadius.circular(8)),
                        child: Text(_gleisbauRoleDescription(_dbGleisbauRole!), style: const TextStyle(fontSize: 11, color: Color(0xFF0D47A1), fontFamily: 'Inter')),
                      ),
                    ],
                  ]),
                ),
              ])),
            ],
            SizedBox(width: fw, child: DropdownButtonFormField<String>(value: _contractType, decoration: InputDecoration(labelText: tr('Vertragsart')),
              items: ['Vollzeit', 'Teilzeit', 'Aushilfe'].map((x) => DropdownMenuItem(value: x, child: Text(x))).toList(), onChanged: restrictSensitive ? null : (v) => setState(() => _contractType = v!))),
            SizedBox(width: fw, child: DropdownButtonFormField<String>(value: _compensationType, decoration: InputDecoration(labelText: tr('Vergütungsart')),
              items: ['Festlohn', 'Stundenlohn'].map((x) => DropdownMenuItem(value: x, child: Text(x))).toList(),
              onChanged: restrictSensitive ? null : (v) => setState(() => _compensationType = v!))),
            // v19.2.1: Vergütungsart'a göre Brutto ücret alanı
            if (_compensationType == 'Stundenlohn')
              SizedBox(width: fw, child: Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: TextFormField(
                  controller: _grossWage,
                  enabled: !restrictSensitive,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: tr('Brutto-Stundenlohn (€/Std.)'),
                    prefixText: '€ ',
                    helperText: tr('Brutto saatlik ücret – rapora yansır'),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              )),
            if (_compensationType == 'Festlohn')
              SizedBox(width: fw, child: Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: TextFormField(
                  controller: _grossWage,
                  enabled: !restrictSensitive,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: tr('Brutto-Festlohn (€/Monat)'),
                    prefixText: '€ ',
                    helperText: tr('Brutto aylık ücret'),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              )),
            SizedBox(width: fw, child: _tf(tr('Anstellung als'), _positionAs, enabled: !restrictSensitive)),
            SizedBox(width: fw, child: _tf(tr('Tätigkeiten'), _activities, enabled: !restrictSensitive)),
            SizedBox(width: fw, child: _df(tr('Arbeitsbeginn'), _entryDate, restrictSensitive ? (d)=>{} : (d) => setState(() => _entryDate = d))),
            SizedBox(width: fw, child: _df(tr('Probezeit bis'), _trialPeriodUntil, restrictSensitive ? (d)=>{} : (d) => setState(() => _trialPeriodUntil = d))),
            SizedBox(width: fw, child: _df(tr('Vertragsende'), _contractEndDate, restrictSensitive ? (d)=>{} : (d) => setState(() => _contractEndDate = d))),
            SizedBox(width: fw, child: _tf(tr('Wochenstunden'), _weeklyHours, type: TextInputType.number, enabled: !restrictSensitive)),
            SizedBox(width: fw, child: _tf(tr('Monatsstunden'), _monthlyHours, type: TextInputType.number, enabled: !restrictSensitive)),
            SizedBox(width: fw, child: _tf(tr('Personalnummer'), _employeeNumber, enabled: !restrictSensitive)),
            SizedBox(width: fw, child: _tf(tr('PIN (Kiosk)'), _pin, enabled: !restrictSensitive)),
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
          const Center(child: Text('HansePortal v1.0.2', style: TextStyle(color: AppTheme.textSub, fontSize: 10))),
        ]);
      }))),
    );
  }

  Widget _sec(String t) => Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(t, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textSub, fontFamily: 'Inter')));
  Widget _tf(String l, TextEditingController c, {bool req = false, TextInputType? type, int maxLines = 1, bool enabled = true}) => Padding(padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(controller: c, keyboardType: type, maxLines: maxLines, enabled: enabled, decoration: InputDecoration(labelText: l), validator: req ? (v) => (v == null || v.isEmpty) ? tr('Pflichtfeld') : null : null));
  Widget _df(String l, DateTime? v, Function(DateTime?) f) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: InkWell(
      onTap: () async {
        final d = await showDatePicker(
          context: context,
          initialDate: v ?? DateTime.now(),
          firstDate: DateTime(1900),
          lastDate: DateTime.now().add(const Duration(days: 3650)),
        );
        if (d != null) f(d);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: l,
          suffixIcon: v != null
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: () => f(null),
                )
              : null,
        ),
        child: Text(
          v == null ? tr('Auswählen') : '${v.day}.${v.month}.${v.year}',
          style: const TextStyle(fontSize: 14),
        ),
      ),
    ),
  );
}

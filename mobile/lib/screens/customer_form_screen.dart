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
        {'key': 'Gastwirtschaft', 'label': 'Gastwirtschaftsservice', 'kw': ['gast', 'hotel', 'hospitality', 'beherber']},
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

      final appState = context.read<AppState>();
      final isDeptHead = appState.role == 'bereichsleiter';
      final userDeptId = appState.currentUser?['department_id'];

      if (mounted) {
        setState(() {
          if (isDeptHead && userDeptId != null) {
            _serviceAreas = consolidatedAreas.where((sa) => sa['department_id'] == userDeptId).toList();
          } else {
            _serviceAreas = consolidatedAreas;
          }
        });
      }
    } catch (e) {
      debugPrint('Leistungsbereiche konnten nicht geladen werden: $e');
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
          // v19.7.5: Sadece Sachbearbeiter değil, tüm kontak rollerini yükle
          _sachbearbeiters = List<Map<String, dynamic>>.from(data['customer_contacts']);
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('Fehler: Firmeninformationen des Benutzers nicht gefunden.'))));
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
        // v19.7.5: Hardcoded 'Sachbearbeiter' rolünü kaldır, kontaktın kendi rolünü kullan
        // Eğer rol yoksa varsayılan olarak Sachbearbeiter ata
        dataToSave['role'] = s['role'] ?? 'Sachbearbeiter';
        await SupabaseService.upsertCustomerContact(dataToSave);
      }

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${tr('Fehler')}: $e')));
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.customerId == null ? tr('Neuer Kunde') : tr('Kunde bearbeiten'))),
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
                  _section(tr('Grunddaten')),
                  Wrap(
                    spacing: 16,
                    runSpacing: 0,
                    children: [
                       SizedBox(width: fieldWidth, child: _textField(tr('Kundenname / Firmenname *'), _name, required: true)),
                       SizedBox(
                         width: fieldWidth,
                         child: DropdownButtonFormField<String>(
                           value: _type,
                           decoration: InputDecoration(labelText: tr('Kundentyp')),
                           items: [
                             DropdownMenuItem(value: 'company', child: Text(tr('Firma / Unternehmen'), style: const TextStyle(fontFamily: 'Inter'))),
                             DropdownMenuItem(value: 'public_institution', child: Text(tr('Behörde / öffentl. Einrichtung'), style: const TextStyle(fontFamily: 'Inter'))),
                             DropdownMenuItem(value: 'individual', child: Text(tr('Einzelperson / Privat'), style: const TextStyle(fontFamily: 'Inter'))),
                             DropdownMenuItem(value: 'other', child: Text(tr('Sonstiges'), style: const TextStyle(fontFamily: 'Inter'))),
                           ],
                          onChanged: (v) => setState(() => _type = v!),
                        ),
                      ),
                      SizedBox(
                        width: fieldWidth,
                        child: DropdownButtonFormField<String>(
                          value: _selectedServiceAreaId,
                          decoration: InputDecoration(labelText: tr('Zuständige Bereiche')),
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
                  
                  _section(tr('Kundenstatus')),
                  Wrap(
                    spacing: 16,
                    children: [
                      SizedBox(width: fieldWidth, child: _statusDropdown()),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  _section(tr('Adresse')),
                  _textField(tr('Adresse'), _address),
                  Wrap(
                    spacing: 12,
                    children: [
                       SizedBox(width: isWide ? (constraints.maxWidth - 32 - 12) * 0.3 : (constraints.maxWidth - 32 - 12) * 0.3, child: _textField(tr('Postleitzahl'), _postalCode)),
                       SizedBox(width: isWide ? (constraints.maxWidth - 32 - 12) * 0.7 : (constraints.maxWidth - 32 - 12) * 0.7, child: _textField(tr('Stadt'), _city)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  _section(tr('Kontakt')),
                  Wrap(
                    spacing: 16,
                    runSpacing: 0,
                    children: [
                       SizedBox(width: fieldWidth, child: _textField(tr('Telefon'), _phone)),
                       SizedBox(width: fieldWidth, child: _textField(tr('E-Mail'), _email)),
                       SizedBox(width: fieldWidth, child: _textField(tr('Steuernummer'), _taxNumber)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  _section(tr('Zusatzinformationen')),
                  Wrap(
                    spacing: 16,
                    runSpacing: 0,
                    children: [
                       SizedBox(width: fieldWidth, child: _textField(tr('Notizen'), _notes, maxLines: 3)),
                       SizedBox(width: fieldWidth, child: _textField(tr('Zugangsinfo / Schlüssel'), _specialAccess, maxLines: 2)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  _section(tr('Rechnungsadresse')),
                  _textField(tr('Rechnungsadresse (leer = Geschäftsadresse wird verwendet)'), _billingAddress, maxLines: 2),
                  const SizedBox(height: 16),
                  
                  // Finansal Bilgiler
                  if (context.read<AppState>().canSeeFinancialDetails) ...[
                    _section(tr('Finanzdaten (Autorisiert)')),
                    Wrap(
                      spacing: 16,
                      runSpacing: 0,
                      children: [
                         SizedBox(width: fieldWidth, child: _textField(tr('USt-IdNr. (MwSt.-Nr.)'), _vatNumber)),
                         SizedBox(width: fieldWidth, child: _textField(tr('Bankname'), _bankName)),
                         SizedBox(width: fieldWidth, child: _textField(tr('IBAN'), _iban)),
                         SizedBox(width: fieldWidth, child: _textField(tr('BIC / SWIFT'), _bic)),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
  
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _section(tr('Ansprechpartner / Kontakte')),
                      IconButton(
                        icon: const Icon(Icons.add_circle, color: AppTheme.primary),
                        onPressed: _showAddSachbearbeiterDialog,
                      )
                    ],
                  ),
                  if (_sachbearbeiters.isEmpty)
                    Padding(
                      padding: EdgeInsets.only(bottom: 16.0),
                      child: Text(tr('Noch nicht hinzugefügt'), style: TextStyle(color: AppTheme.textSub, fontFamily: 'Inter')),
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
                        : Text(widget.customerId == null ? tr('Kunden anlegen') : tr('Speichern')),
                  ),
                  const SizedBox(height: 24),
                  const Center(child: Text('HansePortal v1.0.0', style: TextStyle(color: AppTheme.textSub, fontSize: 10))),
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
    String contactType = 'Sachbearbeiter';

    // v19.7.5: Portal erişimi (ExtManager) hem Gastwirtschaft hem de Gebäudedienstleistungen (Temizlik) için geçerlidir
    final selectedSa = _serviceAreas.where((sa) => sa['id'].toString() == _selectedServiceAreaId).firstOrNull;
    final saNameLower = (selectedSa?['display_name'] ?? selectedSa?['name'] ?? '').toString().toLowerCase();
    
    // GWS veya Temizlik (Gebäude/Reinigung) departmanları portal yetkisine sahip olabilir
    final isPortalEnabled = saNameLower.contains('gast') || saNameLower.contains('hospit') || saNameLower.contains('hotel') ||
                           saNameLower.contains('gebäud') || saNameLower.contains('reinigung');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(tr('Ansprechpartner hinzufügen')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: contactType,
                decoration: InputDecoration(labelText: tr('Typ'), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                items: [
                  const DropdownMenuItem(value: 'Sachbearbeiter', child: Text('Kaufmännischer Ansprechpartner')),
                  if (isPortalEnabled)
                    const DropdownMenuItem(value: 'ExtManager', child: Text('🏨 AG Ansprechpartner (Kundenportal)')),
                ],
                onChanged: (v) => setLocal(() => contactType = v!),
              ),
              const SizedBox(height: 12),
              TextField(controller: nameCtrl, decoration: InputDecoration(labelText: tr('Vor- und Nachname *'), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
              const SizedBox(height: 8),
              TextField(controller: phoneCtrl, keyboardType: TextInputType.phone, decoration: InputDecoration(labelText: tr('Telefon'), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
              const SizedBox(height: 8),
              TextField(controller: emailCtrl, keyboardType: TextInputType.emailAddress, decoration: InputDecoration(
                labelText: contactType == 'ExtManager' ? tr('E-Mail * (für Portal-Zugang)') : tr('E-Mail'),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                suffixIcon: contactType == 'ExtManager' ? const Icon(Icons.vpn_key_outlined, color: AppTheme.gwsColor) : null,
              )),
              if (contactType == 'ExtManager') ...
                [const SizedBox(height: 8), Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: AppTheme.gwsColor.withOpacity(0.08), borderRadius: BorderRadius.circular(10)),
                  child: Row(children: [
                    Icon(Icons.info_outline, color: AppTheme.gwsColor, size: 16),
                    SizedBox(width: 8),
                    Expanded(child: Text(tr('Bei Angabe der E-Mail wird automatisch ein Portal-Konto erstellt.'), style: TextStyle(fontSize: 12, color: AppTheme.gwsColor, fontFamily: 'Inter'))),
                  ]),
                )],
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(tr('Abbrechen'))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: contactType == 'ExtManager' ? AppTheme.gwsColor : AppTheme.primary),
              onPressed: () async {
                if (nameCtrl.text.isEmpty) return;
                Navigator.pop(ctx);

                final nameParts = nameCtrl.text.trim().split(' ');
                final firstName = nameParts.isNotEmpty ? nameParts.first : nameCtrl.text.trim();
                final lastName = nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '';

                // Externer Manager ise otomatik kullanıcı oluştur
                String? autoUserId;
                String? autoPassword;
                if (contactType == 'ExtManager' && emailCtrl.text.trim().isNotEmpty) {
                  try {
                    final companyId = context.read<AppState>().currentUser?['company_id'];
                    final result = await SupabaseService.createExternalManagerUser(
                      firstName: firstName,
                      lastName: lastName,
                      email: emailCtrl.text.trim(),
                      phone: phoneCtrl.text.trim(),
                      companyId: companyId ?? '',
                    );
                    autoUserId = result['userId'];
                    autoPassword = result['password'];

                    if (mounted) {
                      showDialog(
                        context: context,
                        builder: (_) => AlertDialog(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          title: Row(children: [const Icon(Icons.check_circle, color: AppTheme.success), const SizedBox(width: 8), Text(tr('Portal-Konto erstellt'), style: const TextStyle(fontFamily: 'Inter', fontSize: 15))]),
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(tr('Der AG Ansprechpartner kann sich mit diesen Daten anmelden:'), style: const TextStyle(fontFamily: 'Inter')),
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(color: AppTheme.gwsColor.withOpacity(0.08), borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.gwsColor.withOpacity(0.3))),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(children: [const Icon(Icons.email_outlined, size: 16, color: AppTheme.gwsColor), const SizedBox(width: 6), Text(emailCtrl.text.trim(), style: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold))]),
                                    const SizedBox(height: 6),
                                    Row(children: [const Icon(Icons.lock_outlined, size: 16, color: AppTheme.gwsColor), const SizedBox(width: 6), Text('Passwort: $autoPassword', style: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold, fontSize: 18, color: AppTheme.gwsColor))]),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text('Bitte das Passwort dem AG Ansprechpartner mitteilen!', style: TextStyle(fontSize: 12, color: AppTheme.textSub, fontFamily: 'Inter')),
                            ],
                          ),
                          actions: [ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: AppTheme.gwsColor), onPressed: () => Navigator.pop(context), child: const Text('OK'))],
                        ),
                      );
                    }
                  } catch (e) {
                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${tr('Fehler beim Erstellen des Portal-Kontos:')} $e'), backgroundColor: AppTheme.error));
                  }
                }

                setState(() {
                  _sachbearbeiters.add({
                    'id': 'new_${DateTime.now().millisecondsSinceEpoch}',
                    'name': nameCtrl.text.trim(),
                    'phone': phoneCtrl.text.trim(),
                    'email': emailCtrl.text.trim(),
                    'role': contactType,
                    if (autoUserId != null) 'user_id': autoUserId,
                  });
                });
              },
              child: Text(contactType == 'ExtManager' ? tr('Hinzufügen + Konto erstellen') : tr('Hinzufügen')),
            ),
          ],
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
      validator: required ? (v) => (v == null || v.trim().isEmpty) ? tr('Pflichtfeld') : null : null,
    ),
  );

  Widget _statusDropdown() {
    final canEditStatus = context.read<AppState>().canManageCustomers;
    return DropdownButtonFormField<String>(
      value: _status,
      decoration: InputDecoration(labelText: tr('Kundenstatus')),
      items: [
        DropdownMenuItem(value: 'active', child: Text('✅ ${tr('Aktiv')}', style: const TextStyle(fontFamily: 'Inter'))),
        DropdownMenuItem(value: 'passive', child: Text('⚠️ ${tr('Passiv')}', style: const TextStyle(fontFamily: 'Inter'))),
        DropdownMenuItem(value: 'potential', child: Text('✨ ${tr('Potentiell')}', style: const TextStyle(fontFamily: 'Inter'))),
        DropdownMenuItem(value: 'subunternehmen', child: Text('🔄 Subunternehmen', style: const TextStyle(fontFamily: 'Inter'))),
        DropdownMenuItem(value: 'archived', child: Text('📁 ${tr('Archiv')}', style: const TextStyle(fontFamily: 'Inter'))),
      ],
      onChanged: canEditStatus ? (v) => setState(() => _status = v!) : null,
    );
  }
}

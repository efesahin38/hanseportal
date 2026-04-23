import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../theme/web_utils.dart';
import '../providers/app_state.dart';
import '../services/supabase_service.dart';
import '../services/localization_service.dart';
import '../theme/string_utils.dart';
import 'company_form_screen.dart';

/// Meine Stammdaten – Hub-Screen
class StammdatenScreen extends StatefulWidget {
  const StammdatenScreen({super.key});

  @override
  State<StammdatenScreen> createState() => _StammdatenScreenState();
}

class _StammdatenScreenState extends State<StammdatenScreen> {
  Map<String, dynamic>? _selectedCompany;
  List<Map<String, dynamic>> _authorizedCompanies = [];
  List<Map<String, dynamic>> _bankAccounts = [];
  List<Map<String, dynamic>> _serviceAreas = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    // Profile'ı tazeleyip en güncel company_id'yi aldığımızdan emin olalım
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await context.read<AppState>().refreshProfile();
      _load();
    });
  }

  Future<void> _load() async {
    try {
      final appState = context.read<AppState>();

      var companies = await SupabaseService.getCompanies(serviceAreaIds: null);

      // v17.2: İstenen 3 şirket filtrelemesi
      final targetUuids = [
        'aaaaaaaa-0000-0000-0000-000000000003', // HANSE KOLLEKTIV GMBH
        '88888888-0000-0000-0000-000000000001', // hako gastwirtschaftsservice
        '88888888-0000-0000-0000-000000000002', // Safari Dienstleistungen Gmbh
      ];
      
      companies = companies.where((c) => targetUuids.contains(c['id'].toString())).toList();

      if (companies.isNotEmpty) {
        _authorizedCompanies = companies;
        if (_selectedCompany == null) {
          _selectedCompany = companies.first;
        } else {
          try {
            _selectedCompany = companies.firstWhere((c) => c['id'] == _selectedCompany!['id']);
          } catch (_) {
            _selectedCompany = companies.first;
          }
        }
      } else {
        _authorizedCompanies = [];
        _selectedCompany = null;
      }

      if (_selectedCompany != null) {
        _bankAccounts = await SupabaseService.getCompanyBankAccounts(_selectedCompany!['id']);
        _serviceAreas = await SupabaseService.getServiceAreas();
        _serviceAreas = _serviceAreas.where((sa) => sa['department']?['company_id'] == _selectedCompany!['id']).toList();
      }

      if (mounted) setState(() => _loading = false);
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      body: WebContentWrapper(
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Header – Hanse Kollektiv GmbH (v19.2.1: tek şirket, dropdown yok)
              Builder(
                builder: (context) {
                  final appState = context.read<AppState>();
                  final canEdit = appState.isGeschaeftsfuehrer || appState.isSystemAdmin || appState.isBetriebsleiter;
                  if (_selectedCompany == null)
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 40.0),
                        child: Column(
                          children: [
                            const Icon(Icons.error_outline, size: 48, color: Colors.white70),
                            const SizedBox(height: 12),
                            Text(
                              tr('Unternehmenskonfiguration fehlt'),
                              style: const TextStyle(color: Colors.white, fontSize: 16),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              tr('Bitte kontaktieren Sie den Administrator'),
                              style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    );

                  return Container(
                    padding: const EdgeInsets.all(20),
                    decoration: AppTheme.gradientBox().copyWith(borderRadius: BorderRadius.circular(20)),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(Icons.business, color: Colors.white, size: 28),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _authorizedCompanies.isEmpty
                                  ? const Text('Şirket Bulunamadı', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold, fontFamily: 'Inter'))
                                  : DropdownButtonHideUnderline(
                                      child: DropdownButton<String>(
                                        isExpanded: true,
                                        dropdownColor: AppTheme.primary,
                                        icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white),
                                        style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold, fontFamily: 'Inter'),
                                        value: _selectedCompany?['id']?.toString(),
                                        items: _authorizedCompanies.map((c) {
                                          String name = c['name'] ?? '';
                                          if (name.toLowerCase().contains('hanse kollektiv gmbh')) {
                                            name = 'Hanse Kollektiv GmbH';
                                          } else if (name.toLowerCase().contains('hako')) {
                                            name = 'Hako Gastwirtschaftsservice';
                                          } else if (name.toLowerCase().contains('safari')) {
                                            name = 'Safari Dienstleistungen GmbH';
                                          }
                                          return DropdownMenuItem<String>(
                                            value: c['id'].toString(),
                                            child: Text(name, overflow: TextOverflow.ellipsis),
                                          );
                                        }).toList(),
                                        onChanged: (newId) async {
                                          if (newId != null && _selectedCompany?['id'] != newId) {
                                            setState(() {
                                              _selectedCompany = _authorizedCompanies.firstWhere((c) => c['id'].toString() == newId);
                                              _loading = true;
                                            });
                                            _load();
                                          }
                                        },
                                      ),
                                    ),
                              Text(
                                tr('Meine Stammdaten'),
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.8),
                                  fontSize: 13,
                                  fontFamily: 'Inter',
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (canEdit)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.edit, color: Colors.white, size: 14),
                                SizedBox(width: 4),
                                Text('Bearbeiten', style: TextStyle(color: Colors.white, fontSize: 12, fontFamily: 'Inter')),
                              ],
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 20),

              // Section Cards
              Builder(builder: (context) {
                final appState = context.read<AppState>();
                // Bereichsleiter sadece görüntüleyebilir, düzenleyemez. Buchhaltung da sadece görüntüler.
                final canEdit = appState.isGeschaeftsfuehrer || appState.isSystemAdmin || appState.isBetriebsleiter;
                return Column(
                  children: [
                    _SectionCard(
                      icon: Icons.apartment,
                      title: tr('Unternehmensdaten'),
                      subtitle: formatCompanyName(_selectedCompany?['name'] ?? '-'),
                      color: const Color(0xFF3B82F6),
                      readOnly: !canEdit,
                      onTap: canEdit
                          ? () => Navigator.push(context, MaterialPageRoute(builder: (_) => CompanyFormScreen(company: _selectedCompany))).then((ok) { if (ok == true) _load(); })
                          : () {},
                    ),

                    _SectionCard(
                      icon: Icons.person,
                      title: tr('Geschäftsführer'),
                      subtitle: '${_selectedCompany?['ceo_first_name'] ?? ''} ${_selectedCompany?['ceo_last_name'] ?? ''}'.trim().isEmpty ? tr('Nicht hinterlegt') : '${_selectedCompany?['ceo_first_name'] ?? ''} ${_selectedCompany?['ceo_last_name'] ?? ''}'.trim(),
                      color: const Color(0xFF10B981),
                      readOnly: !canEdit,
                      onTap: canEdit ? () => _showGfDialog() : () {},
                    ),

                    _SectionCard(
                      icon: Icons.gavel,
                      title: tr('Rechtliche Firmendaten'),
                      subtitle: '${tr('HR')}: ${_selectedCompany?['trade_register_number'] ?? '-'} | ${tr('St.Nr.')}: ${_selectedCompany?['tax_number'] ?? '-'}',
                      color: const Color(0xFFF59E0B),
                      readOnly: !canEdit,
                      onTap: canEdit
                          ? () => Navigator.push(context, MaterialPageRoute(builder: (_) => CompanyFormScreen(company: _selectedCompany))).then((ok) { if (ok == true) _load(); })
                          : () {},
                    ),

                    _SectionCard(
                      icon: Icons.account_balance,
                      title: tr('Bankverbindungen'),
                      subtitle: '${_bankAccounts.length} ${tr('Bankverbindung(en)')}',
                      color: const Color(0xFF6366F1),
                      onTap: () => _showBankAccounts(),
                      trailingIcon: Icons.add_circle,
                      onTrailingTap: () {
                        _showAddBankDialog(context, null);
                      },
                    ),

                    if (canEdit)
                      _SectionCard(
                        icon: Icons.category,
                        title: tr('Branchen / Unternehmensbereiche'),
                        subtitle: _serviceAreas.map((s) => s['name']).join(', '),
                        color: const Color(0xFFEF4444),
                        onTap: () => _showServiceAreas(),
                      ),
                  ],
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  void _showGfDialog() {
    final firstNameCtrl = TextEditingController(text: _selectedCompany?['ceo_first_name'] ?? '');
    final lastNameCtrl = TextEditingController(text: _selectedCompany?['ceo_last_name'] ?? '');
    final addressCtrl = TextEditingController(text: _selectedCompany?['ceo_address'] ?? '');
    final phoneCtrl = TextEditingController(text: _selectedCompany?['ceo_phone'] ?? '');
    final emailCtrl = TextEditingController(text: _selectedCompany?['ceo_email'] ?? '');

    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Container(
          decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
          padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppTheme.border, borderRadius: BorderRadius.circular(2)))),
                const SizedBox(height: 16),
                Text(tr('Geschäftsführer'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Inter')),
                const SizedBox(height: 16),
                _dialogField(tr('Vorname'), firstNameCtrl),
                _dialogField(tr('Nachname'), lastNameCtrl),
                _dialogField(tr('Adresse'), addressCtrl),
                _dialogField(tr('Telefon'), phoneCtrl),
                _dialogField(tr('E-Mail'), emailCtrl),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: isSaving ? null : () async {
                    setModalState(() => isSaving = true);
                    try {
                      await SupabaseService.upsertCompany({
                        'id': _selectedCompany!['id'],
                        'ceo_first_name': firstNameCtrl.text.trim(),
                        'ceo_last_name': lastNameCtrl.text.trim(),
                        'ceo_address': addressCtrl.text.trim(),
                        'ceo_phone': phoneCtrl.text.trim(),
                        'ceo_email': emailCtrl.text.trim(),
                      });
                      if (mounted) { Navigator.pop(ctx); _load(); }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red));
                      }
                    } finally {
                      setModalState(() => isSaving = false);
                    }
                  },
                  child: isSaving ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : Text(tr('Speichern')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showBankAccounts() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Container(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.7),
          decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(tr('Bankverbindungen'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Inter')),
                  IconButton(icon: const Icon(Icons.add_circle, color: AppTheme.primary), onPressed: () => _showAddBankDialog(ctx, setSheetState)),
                ],
              ),
              const Divider(),
              if (_bankAccounts.isEmpty)
                Padding(padding: const EdgeInsets.all(20), child: Center(child: Text(tr('Keine Bankverbindungen'), style: const TextStyle(color: AppTheme.textSub))))
              else
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _bankAccounts.length,
                    itemBuilder: (_, i) {
                      final b = _bankAccounts[i];
                      return Card(
                        child: ListTile(
                          leading: const Icon(Icons.account_balance, color: AppTheme.primary),
                          title: Text(b['bank_name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontFamily: 'Inter')),
                          subtitle: Text('${b['iban'] ?? ''}\n${b['bic'] ?? ''}', style: const TextStyle(fontSize: 12, fontFamily: 'Inter')),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline, color: AppTheme.error, size: 20),
                            onPressed: () async {
                              await SupabaseService.deleteCompanyBankAccount(b['id']);
                              _load();
                              final banks = await SupabaseService.getCompanyBankAccounts(_selectedCompany!['id']);
                              setSheetState(() => _bankAccounts = banks);
                            },
                          ),
                          isThreeLine: true,
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddBankDialog(BuildContext parentCtx, StateSetter? setSheetState) {
    final bankCtrl = TextEditingController();
    final ibanCtrl = TextEditingController();
    final bicCtrl = TextEditingController();

    showDialog(
      context: parentCtx,
      builder: (ctx) => AlertDialog(
        title: Text(tr('Neue Bankverbindung')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: bankCtrl, decoration: InputDecoration(labelText: tr('Bankname'))),
            TextField(controller: ibanCtrl, decoration: InputDecoration(labelText: tr('IBAN'))),
            TextField(controller: bicCtrl, decoration: InputDecoration(labelText: tr('BIC'))),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(tr('Abbrechen'))),
          ElevatedButton(
            onPressed: () async {
              await SupabaseService.upsertCompanyBankAccount({
                'company_id': _selectedCompany!['id'],
                'bank_name': bankCtrl.text.trim(),
                'iban': ibanCtrl.text.trim(),
                'bic': bicCtrl.text.trim(),
              });
              if (mounted) {
                Navigator.pop(ctx);
                _load();
                if (setSheetState != null) {
                  final banks = await SupabaseService.getCompanyBankAccounts(_selectedCompany!['id']);
                  setSheetState(() => _bankAccounts = banks);
                }
              }
            },
            child: Text(tr('Speichern')),
          ),
        ],
      ),
    );
  }

  void _showServiceAreas() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Container(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.7),
          decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(tr('Unternehmensbereiche'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Inter')),
                  IconButton(icon: const Icon(Icons.add_circle, color: AppTheme.primary), onPressed: () => _showAddAreaDialog(ctx, setSheetState)),
                ],
              ),
              const Divider(),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _serviceAreas.length,
                  itemBuilder: (_, i) {
                    final s = _serviceAreas[i];
                    final color = Color(int.parse((s['color'] ?? '#607D8B').replaceAll('#', '0xFF')));
                    return Card(
                      child: ListTile(
                        leading: Container(
                          width: 40, height: 40,
                          decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                          child: Icon(Icons.folder, color: color),
                        ),
                        title: Text(s['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontFamily: 'Inter')),
                        subtitle: Text(s['code'] ?? '', style: const TextStyle(fontSize: 12, color: AppTheme.textSub)),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline, color: AppTheme.error, size: 20),
                          onPressed: () async {
                            await SupabaseService.deleteServiceArea(s['id']);
                            final areas = await SupabaseService.getServiceAreas();
                            setSheetState(() => _serviceAreas = areas);
                            _load();
                          },
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddAreaDialog(BuildContext parentCtx, StateSetter setSheetState) {
    final nameCtrl = TextEditingController();
    final codeCtrl = TextEditingController();
    showDialog(
      context: parentCtx,
      builder: (ctx) => AlertDialog(
        title: Text(tr('Neuer Bereich')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: InputDecoration(labelText: tr('Name (z.B. Gebäudeservice)'))),
            TextField(controller: codeCtrl, decoration: InputDecoration(labelText: tr('Code (z.B. gebaeudeservice)'))),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(tr('Abbrechen'))),
          ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty) return;
              await SupabaseService.upsertServiceArea({
                'name': nameCtrl.text.trim(),
                'code': codeCtrl.text.trim().isEmpty ? nameCtrl.text.trim().toLowerCase().replaceAll(' ', '_') : codeCtrl.text.trim(),
                'is_active': true,
              });
              if (mounted) {
                Navigator.pop(ctx);
                final areas = await SupabaseService.getServiceAreas();
                setSheetState(() => _serviceAreas = areas);
                _load();
              }
            },
            child: Text(tr('Speichern')),
          ),
        ],
      ),
    );
  }

  Widget _dialogField(String label, TextEditingController ctrl) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextField(controller: ctrl, decoration: InputDecoration(labelText: label)),
  );
}

class _SectionCard extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final Color color;
  final VoidCallback onTap;
  final bool readOnly;
  final IconData? trailingIcon;
  final VoidCallback? onTrailingTap;
  const _SectionCard({required this.icon, required this.title, required this.subtitle, required this.color, required this.onTap, this.readOnly = false, this.trailingIcon, this.onTrailingTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: readOnly ? null : onTap,
        borderRadius: BorderRadius.circular(16),
        child: Opacity(
          opacity: readOnly ? 0.85 : 1.0,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.divider),
              boxShadow: [BoxShadow(color: color.withOpacity(0.08), blurRadius: 12, offset: const Offset(0, 4))],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                  child: Icon(icon, color: color, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, fontFamily: 'Inter')),
                      const SizedBox(height: 2),
                      Text(subtitle, style: const TextStyle(fontSize: 12, color: AppTheme.textSub, fontFamily: 'Inter'), maxLines: 2, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                if (trailingIcon != null) ...[
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: Icon(trailingIcon, color: color, size: 28),
                    onPressed: onTrailingTap,
                  ),
                  const SizedBox(width: 8),
                ],
                if (readOnly)
                  Icon(Icons.visibility_outlined, color: color.withOpacity(0.4), size: 20)
                else
                  Icon(Icons.chevron_right, color: color.withOpacity(0.6)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

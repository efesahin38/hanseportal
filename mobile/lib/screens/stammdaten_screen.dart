import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../theme/web_utils.dart';
import '../providers/app_state.dart';
import '../services/supabase_service.dart';
import '../services/localization_service.dart';
import 'company_form_screen.dart';

/// Meine Stammdaten – Hub-Screen
class StammdatenScreen extends StatefulWidget {
  const StammdatenScreen({super.key});

  @override
  State<StammdatenScreen> createState() => _StammdatenScreenState();
}

class _StammdatenScreenState extends State<StammdatenScreen> {
  Map<String, dynamic>? _company;
  List<Map<String, dynamic>> _bankAccounts = [];
  List<Map<String, dynamic>> _serviceAreas = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final companyId = context.read<AppState>().companyId;
      final companies = await SupabaseService.getCompanies();
      final company = companies.isNotEmpty ? companies.first : null;
      final banks = company != null ? await SupabaseService.getCompanyBankAccounts(company['id']) : <Map<String, dynamic>>[];
      final areas = await SupabaseService.getServiceAreas();
      if (mounted) {
        setState(() {
          _company = company;
          _bankAccounts = banks;
          _serviceAreas = areas;
          _loading = false;
        });
      }
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
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: AppTheme.gradientBox().copyWith(borderRadius: BorderRadius.circular(20)),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(14)),
                      child: const Icon(Icons.business, color: Colors.white, size: 28),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_company?['name'] ?? 'Hanse Kollektiv GmbH', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold, fontFamily: 'Inter')),
                          Text(tr('Meine Stammdaten'), style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13, fontFamily: 'Inter')),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Section Cards
              _SectionCard(
                icon: Icons.apartment,
                title: tr('Unternehmensdaten'),
                subtitle: _company?['name'] ?? '-',
                color: const Color(0xFF3B82F6),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CompanyFormScreen(company: _company))).then((ok) { if (ok == true) _load(); }),
              ),

              _SectionCard(
                icon: Icons.person,
                title: tr('Geschäftsführer'),
                subtitle: '${_company?['ceo_first_name'] ?? ''} ${_company?['ceo_last_name'] ?? ''}'.trim().isEmpty ? tr('Nicht hinterlegt') : '${_company?['ceo_first_name'] ?? ''} ${_company?['ceo_last_name'] ?? ''}'.trim(),
                color: const Color(0xFF10B981),
                onTap: () => _showGfDialog(),
              ),

              _SectionCard(
                icon: Icons.gavel,
                title: tr('Rechtliche Firmendaten'),
                subtitle: '${tr('HR')}: ${_company?['trade_register_number'] ?? '-'} | ${tr('St.Nr.')}: ${_company?['tax_number'] ?? '-'}',
                color: const Color(0xFFF59E0B),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CompanyFormScreen(company: _company))).then((ok) { if (ok == true) _load(); }),
              ),

              _SectionCard(
                icon: Icons.account_balance,
                title: tr('Bankverbindungen'),
                subtitle: '${_bankAccounts.length} ${tr('Bankverbindung(en)')}',
                color: const Color(0xFF6366F1),
                onTap: () => _showBankAccounts(),
              ),

              _SectionCard(
                icon: Icons.category,
                title: tr('Branchen / Unternehmensbereiche'),
                subtitle: _serviceAreas.map((s) => s['name']).join(', '),
                color: const Color(0xFFEF4444),
                onTap: () => _showServiceAreas(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showGfDialog() {
    final firstNameCtrl = TextEditingController(text: _company?['ceo_first_name'] ?? '');
    final lastNameCtrl = TextEditingController(text: _company?['ceo_last_name'] ?? '');
    final addressCtrl = TextEditingController(text: _company?['ceo_address'] ?? '');
    final phoneCtrl = TextEditingController(text: _company?['ceo_phone'] ?? '');
    final emailCtrl = TextEditingController(text: _company?['ceo_email'] ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
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
                onPressed: () async {
                  await SupabaseService.upsertCompany({
                    'id': _company!['id'],
                    'ceo_first_name': firstNameCtrl.text.trim(),
                    'ceo_last_name': lastNameCtrl.text.trim(),
                    'ceo_address': addressCtrl.text.trim(),
                    'ceo_phone': phoneCtrl.text.trim(),
                    'ceo_email': emailCtrl.text.trim(),
                  });
                  if (mounted) { Navigator.pop(ctx); _load(); }
                },
                child: Text(tr('Speichern')),
              ),
            ],
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
                              final banks = await SupabaseService.getCompanyBankAccounts(_company!['id']);
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

  void _showAddBankDialog(BuildContext parentCtx, StateSetter setSheetState) {
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
                'company_id': _company!['id'],
                'bank_name': bankCtrl.text.trim(),
                'iban': ibanCtrl.text.trim(),
                'bic': bicCtrl.text.trim(),
              });
              if (mounted) {
                Navigator.pop(ctx);
                _load();
                final banks = await SupabaseService.getCompanyBankAccounts(_company!['id']);
                setSheetState(() => _bankAccounts = banks);
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
  const _SectionCard({required this.icon, required this.title, required this.subtitle, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
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
              Icon(Icons.chevron_right, color: color.withOpacity(0.6)),
            ],
          ),
        ),
      ),
    );
  }
}

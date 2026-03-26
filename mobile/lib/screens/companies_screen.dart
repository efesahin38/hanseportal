import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../providers/app_state.dart';
import '../services/supabase_service.dart';
import 'company_form_screen.dart';

class CompaniesScreen extends StatefulWidget {
  const CompaniesScreen({super.key});

  @override
  State<CompaniesScreen> createState() => _CompaniesScreenState();
}

class _CompaniesScreenState extends State<CompaniesScreen> {
  List<Map<String, dynamic>> _companies = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await SupabaseService.getCompanies();
      if (mounted) setState(() { _companies = data; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canCreate = context.watch<AppState>().canManageCompanies;

    return Scaffold(
      floatingActionButton: canCreate
          ? FloatingActionButton.extended(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CompanyFormScreen()),
              ).then((ok) { if (ok == true) _load(); }),
              icon: const Icon(Icons.add),
              label: const Text('Yeni Şirket', style: TextStyle(fontFamily: 'Inter')),
            )
          : null,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: _companies.isEmpty
                  ? const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.apartment_outlined, size: 56, color: AppTheme.textSub),
                      SizedBox(height: 12),
                      Text('Şirket bulunamadı', style: TextStyle(color: AppTheme.textSub, fontFamily: 'Inter')),
                    ]))
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: _companies.length,
                      itemBuilder: (_, i) {
                        final c = _companies[i];
                        final status = c['status'] ?? 'active';
                        final relation = c['relation_type'] ?? 'subsidiary';
                        return Card(
                          child: Theme(
                            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                            child: ExpansionTile(
                              leading: Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: (relation == 'parent' ? AppTheme.primary : AppTheme.accent).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  relation == 'parent' ? Icons.account_balance : Icons.apartment,
                                  color: relation == 'parent' ? AppTheme.primary : AppTheme.accent,
                                  size: 22,
                                ),
                              ),
                              title: Text(c['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, fontFamily: 'Inter')),
                              subtitle: Row(
                                children: [
                                  Text(c['company_type'] ?? '', style: const TextStyle(fontSize: 11, color: AppTheme.textSub, fontFamily: 'Inter')),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: AppTheme.statusColor(status).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(AppTheme.statusLabel(status),
                                      style: TextStyle(fontSize: 10, color: AppTheme.statusColor(status), fontFamily: 'Inter', fontWeight: FontWeight.w600)),
                                  ),
                                ],
                              ),
                              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                              children: [
                                _DetailRow(icon: Icons.location_on_outlined, label: 'Adres', value: '${c['address'] ?? ''}, ${c['postal_code'] ?? ''} ${c['city'] ?? ''} ${c['country'] ?? ''}'),
                                _DetailRow(icon: Icons.phone_outlined, label: 'Telefon', value: c['phone']),
                                _DetailRow(icon: Icons.email_outlined, label: 'E-posta', value: c['email']),
                                _DetailRow(icon: Icons.receipt_outlined, label: 'Vergi No', value: c['tax_number']),
                                _DetailRow(icon: Icons.account_balance_outlined, label: 'IBAN', value: c['iban']),
                                _DetailRow(icon: Icons.business_center_outlined, label: 'Hizmet Alanı', value: c['service_description']),
                                if (canCreate)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: Row(
                                      children: [
                                        TextButton.icon(
                                          onPressed: () => Navigator.push(
                                            context,
                                            MaterialPageRoute(builder: (_) => CompanyFormScreen(company: c)),
                                          ).then((ok) { if (ok == true) _load(); }),
                                          icon: const Icon(Icons.edit_outlined, size: 16),
                                          label: const Text('Düzenle', style: TextStyle(fontFamily: 'Inter', fontSize: 13)),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
    );
  }

  bool get canCreate => context.read<AppState>().canManageCompanies;

  void _showCompanyDialog(BuildContext context, {Map<String, dynamic>? company}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CompanyFormSheet(company: company, onSaved: _load),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? value;
  const _DetailRow({required this.icon, required this.label, this.value});

  @override
  Widget build(BuildContext context) {
    if (value == null || value!.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AppTheme.textSub),
          const SizedBox(width: 8),
          Text('$label: ', style: const TextStyle(fontSize: 12, color: AppTheme.textSub, fontFamily: 'Inter')),
          Expanded(child: Text(value!, style: const TextStyle(fontSize: 12, fontFamily: 'Inter'), maxLines: 2, overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }
}

class _CompanyFormSheet extends StatefulWidget {
  final Map<String, dynamic>? company;
  final VoidCallback onSaved;
  const _CompanyFormSheet({this.company, required this.onSaved});

  @override
  State<_CompanyFormSheet> createState() => _CompanyFormSheetState();
}

class _CompanyFormSheetState extends State<_CompanyFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _shortName = TextEditingController();
  final _city = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _taxNumber = TextEditingController();
  final _iban = TextEditingController();
  String _type = 'GmbH';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.company != null) {
      final c = widget.company!;
      _name.text = c['name'] ?? '';
      _shortName.text = c['short_name'] ?? '';
      _city.text = c['city'] ?? '';
      _phone.text = c['phone'] ?? '';
      _email.text = c['email'] ?? '';
      _taxNumber.text = c['tax_number'] ?? '';
      _iban.text = c['iban'] ?? '';
      _type = c['company_type'] ?? 'GmbH';
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final data = {
        if (widget.company != null) 'id': widget.company!['id'],
        'name': _name.text.trim(),
        'short_name': _shortName.text.trim(),
        'city': _city.text.trim(),
        'phone': _phone.text.trim(),
        'email': _email.text.trim(),
        'tax_number': _taxNumber.text.trim(),
        'iban': _iban.text.trim(),
        'company_type': _type,
        'country': 'Deutschland',
      };
      await SupabaseService.upsertCompany(data);
      if (mounted) { Navigator.pop(context); widget.onSaved(); }
    } catch (_) {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppTheme.border, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 16),
              Text(widget.company == null ? 'Yeni Şirket' : 'Şirket Düzenle',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Inter')),
              const SizedBox(height: 20),
              _field('Şirket Adı *', _name, required: true),
              _field('Kısa Ad', _shortName),
              DropdownButtonFormField<String>(
                value: _type,
                decoration: const InputDecoration(labelText: 'Şirket Türü'),
                items: ['GmbH', 'UG', 'KG', 'GbR', 'AG', 'Einzelunternehmen', 'other']
                    .map((t) => DropdownMenuItem(value: t, child: Text(t, style: const TextStyle(fontFamily: 'Inter'))))
                    .toList(),
                onChanged: (v) => setState(() => _type = v!),
              ),
              const SizedBox(height: 12),
              _field('Şehir', _city),
              _field('Telefon', _phone),
              _field('E-posta', _email),
              _field('Vergi Numarası', _taxNumber),
              _field('IBAN', _iban),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Kaydet'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(String label, TextEditingController ctrl, {bool required = false}) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
      controller: ctrl,
      decoration: InputDecoration(labelText: label),
      validator: required ? (v) => (v == null || v.isEmpty) ? 'Zorunlu alan' : null : null,
    ),
  );
}

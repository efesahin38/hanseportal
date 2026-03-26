import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import 'company_form_screen.dart';

class CompanyDetailScreen extends StatefulWidget {
  final String companyId;
  final String companyName;
  const CompanyDetailScreen({super.key, required this.companyId, required this.companyName});

  @override
  State<CompanyDetailScreen> createState() => _CompanyDetailScreenState();
}

class _CompanyDetailScreenState extends State<CompanyDetailScreen> {
  Map<String, dynamic>? _company;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await SupabaseService.getCompany(widget.companyId);
      if (mounted) setState(() { _company = data; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        title: Text(widget.companyName, style: const TextStyle(fontFamily: 'Inter')),
        actions: [
          if (!_loading && _company != null)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => CompanyFormScreen(company: _company)),
              ).then((_) => _load()),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _company == null
              ? const Center(child: Text('Şirket bulunamadı', style: TextStyle(fontFamily: 'Inter', color: AppTheme.textSub)))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Durum Badge
                        _StatusBanner(company: _company!),
                        const SizedBox(height: 16),

                        // Temel Bilgiler
                        _SectionCard(
                          title: 'Temel Bilgiler',
                          icon: Icons.business_outlined,
                          children: [
                            _InfoRow('Tam Unvan', _company!['name']),
                            _InfoRow('Kısa Ad', _company!['short_name']),
                            _InfoRow('Şirket Türü', _company!['company_type']),
                            _InfoRow('Yapı', _company!['relation_type'] == 'parent' ? 'Ana Şirket' : _company!['relation_type'] == 'subsidiary' ? 'Bağlı Şirket' : 'İştirak'),
                            if (_company!['service_description'] != null)
                              _InfoRow('Faaliyet Alanı', _company!['service_description']),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Adres
                        _SectionCard(
                          title: 'Adres',
                          icon: Icons.location_on_outlined,
                          children: [
                            _InfoRow('Adres', _company!['address']),
                            _InfoRow('Posta Kodu', _company!['postal_code']),
                            _InfoRow('Şehir', _company!['city']),
                            _InfoRow('Ülke', _company!['country']),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // İletişim
                        _SectionCard(
                          title: 'İletişim',
                          icon: Icons.contact_phone_outlined,
                          children: [
                            _InfoRow('Telefon', _company!['phone'], isLink: true, linkPrefix: 'tel:'),
                            _InfoRow('E-posta', _company!['email'], isLink: true, linkPrefix: 'mailto:'),
                            _InfoRow('Web Sitesi', _company!['website'], isLink: true, linkPrefix: ''),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Vergi & Hukuki
                        _SectionCard(
                          title: 'Vergi & Hukuki Bilgiler',
                          icon: Icons.gavel_outlined,
                          children: [
                            _InfoRow('Vergi No', _company!['tax_number']),
                            _InfoRow('USt-IdNr.', _company!['vat_number']),
                            _InfoRow('Handelsregister', _company!['trade_register_number']),
                            _InfoRow('Amtsgericht', _company!['trade_register_court']),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Banka
                        _SectionCard(
                          title: 'Banka Bilgileri',
                          icon: Icons.account_balance_outlined,
                          children: [
                            _InfoRow('Banka', _company!['bank_name']),
                            _InfoRow('IBAN', _company!['iban']),
                            _InfoRow('BIC', _company!['bic']),
                          ],
                        ),

                        if (_company!['notes'] != null && (_company!['notes'] as String).isNotEmpty) ...[
                          const SizedBox(height: 12),
                          _SectionCard(
                            title: 'Notlar',
                            icon: Icons.notes_outlined,
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                child: Text(_company!['notes'], style: const TextStyle(fontFamily: 'Inter', color: AppTheme.textSub, fontSize: 14)),
                              ),
                            ],
                          ),
                        ],

                        const SizedBox(height: 24),
                        // Meta Bilgiler
                        Text(
                          'Oluşturulma: ${_formatDate(_company!['created_at'])}',
                          style: const TextStyle(fontSize: 11, color: AppTheme.textSub, fontFamily: 'Inter'),
                        ),
                      ],
                    ),
                  ),
                ),
    );
  }

  String _formatDate(dynamic val) {
    if (val == null) return '-';
    try {
      final dt = DateTime.parse(val.toString()).toLocal();
      return '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}';
    } catch (_) {
      return val.toString();
    }
  }
}

class _StatusBanner extends StatelessWidget {
  final Map<String, dynamic> company;
  const _StatusBanner({required this.company});

  @override
  Widget build(BuildContext context) {
    final status = company['status'] ?? 'active';
    final isActive = status == 'active';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: (isActive ? AppTheme.success : AppTheme.error).withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: (isActive ? AppTheme.success : AppTheme.error).withOpacity(0.3)),
      ),
      child: Row(children: [
        Icon(isActive ? Icons.check_circle_outline : Icons.cancel_outlined,
            color: isActive ? AppTheme.success : AppTheme.error, size: 18),
        const SizedBox(width: 8),
        Text(
          isActive ? 'Aktif Şirket' : 'Pasif Şirket',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontFamily: 'Inter',
            color: isActive ? AppTheme.success : AppTheme.error,
          ),
        ),
        const Spacer(),
        Text(
          company['company_type'] ?? '',
          style: const TextStyle(fontSize: 12, color: AppTheme.textSub, fontFamily: 'Inter'),
        ),
      ]),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;
  const _SectionCard({required this.title, required this.icon, required this.children});

  @override
  Widget build(BuildContext context) {
    final nonEmpty = children.whereType<_InfoRow>().where((w) => w.value != null && w.value!.isNotEmpty).toList();
    if (nonEmpty.isEmpty && !children.any((c) => c is! _InfoRow)) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.divider),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Row(children: [
              Icon(icon, size: 18, color: AppTheme.primary),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, fontFamily: 'Inter', color: AppTheme.textMain)),
            ]),
          ),
          const Divider(height: 1),
          ...children,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String? value;
  final bool isLink;
  final String linkPrefix;

  const _InfoRow(this.label, this.value, {this.isLink = false, this.linkPrefix = ''});

  @override
  Widget build(BuildContext context) {
    if (value == null || value!.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: const TextStyle(fontSize: 13, color: AppTheme.textSub, fontFamily: 'Inter')),
          ),
          Expanded(
            child: Text(
              value!,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, fontFamily: 'Inter', color: AppTheme.textMain),
            ),
          ),
        ],
      ),
    );
  }
}

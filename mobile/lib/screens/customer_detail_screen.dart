import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/supabase_service.dart';
import 'customer_form_screen.dart';

class CustomerDetailScreen extends StatefulWidget {
  final String customerId;
  const CustomerDetailScreen({super.key, required this.customerId});

  @override
  State<CustomerDetailScreen> createState() => _CustomerDetailScreenState();
}

class _CustomerDetailScreenState extends State<CustomerDetailScreen> {
  Map<String, dynamic>? _customer;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await SupabaseService.getCustomer(widget.customerId);
      if (mounted) setState(() { _customer = data; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_customer == null) return Scaffold(appBar: AppBar(title: const Text('Müşteri')), body: const Center(child: Text('Bulunamadı')));

    final c = _customer!;
    final contacts = c['customer_contacts'] as List? ?? [];
    final status = c['status'] ?? '';

    return Scaffold(
      appBar: AppBar(
        title: Text(c['name'] ?? '', style: const TextStyle(fontFamily: 'Inter', fontSize: 16)),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => CustomerFormScreen(customerId: widget.customerId),
            )).then((_) => _load()),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // ── Başlık ─────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.divider),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: AppTheme.primary.withOpacity(0.1),
                    child: Text((c['name'] ?? '?')[0].toUpperCase(),
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.primary, fontFamily: 'Inter')),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(c['name'] ?? '', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, fontFamily: 'Inter')),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppTheme.statusColor(status).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(AppTheme.statusLabel(status),
                          style: TextStyle(fontSize: 11, color: AppTheme.statusColor(status), fontFamily: 'Inter', fontWeight: FontWeight.w600)),
                      ),
                    ]),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // ── İletişim ───────────────────────────────────
            _InfoSection('İletişim', [
              _InfoRow(Icons.phone_outlined, 'Telefon', c['phone']),
              _InfoRow(Icons.email_outlined, 'E-posta', c['email']),
              _InfoRow(Icons.language_outlined, 'Web', c['website']),
            ]),
            const SizedBox(height: 12),

            // ── Adres ──────────────────────────────────────
            _InfoSection('Adres', [
              _InfoRow(Icons.location_on_outlined, 'Adres', c['address']),
              _InfoRow(Icons.location_city_outlined, 'Şehir', c['city']),
              _InfoRow(Icons.map_outlined, 'Saha Adresi', c['site_address']),
            ]),
            const SizedBox(height: 12),

            // ── Muhataplar ─────────────────────────────────
            if (contacts.isNotEmpty) ...[
              _InfoSection('Muhataplar', [
                for (final contact in contacts)
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.bg,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: AppTheme.accent.withOpacity(0.15),
                          child: Text((contact['name'] ?? '?')[0].toUpperCase(),
                            style: const TextStyle(color: AppTheme.accent, fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(width: 10),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(contact['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontFamily: 'Inter', fontSize: 13)),
                          if (contact['role'] != null) Text(contact['role'], style: const TextStyle(fontSize: 11, color: AppTheme.textSub, fontFamily: 'Inter')),
                          if (contact['phone'] != null) Text(contact['phone'], style: const TextStyle(fontSize: 11, color: AppTheme.textSub, fontFamily: 'Inter')),
                        ])),
                      ],
                    ),
                  ),
              ]),
              const SizedBox(height: 12),
            ],

            // ── Ek Bilgiler ────────────────────────────────
            if (c['notes'] != null || c['special_access_info'] != null)
              _InfoSection('Özel Notlar', [
                if (c['notes'] != null) _InfoRow(Icons.note_outlined, 'Not', c['notes']),
                if (c['special_access_info'] != null) _InfoRow(Icons.security_outlined, 'Saha Erişim', c['special_access_info']),
              ]),
          ],
        ),
      ),
    );
  }
}

class _InfoSection extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _InfoSection(this.title, this.children);

  @override
  Widget build(BuildContext context) {
    final nonEmpty = children.whereType<_InfoRow>().where((r) => r.value != null && r.value!.isNotEmpty).isNotEmpty;
    if (!nonEmpty && children.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppTheme.divider)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, fontFamily: 'Inter')),
        const SizedBox(height: 12),
        ...children,
      ]),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? value;
  const _InfoRow(this.icon, this.label, this.value);

  @override
  Widget build(BuildContext context) {
    if (value == null || value!.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        Icon(icon, size: 16, color: AppTheme.textSub),
        const SizedBox(width: 8),
        Text('$label: ', style: const TextStyle(fontSize: 12, color: AppTheme.textSub, fontFamily: 'Inter')),
        Expanded(child: Text(value!, style: const TextStyle(fontSize: 13, fontFamily: 'Inter'), maxLines: 2, overflow: TextOverflow.ellipsis)),
      ]),
    );
  }
}

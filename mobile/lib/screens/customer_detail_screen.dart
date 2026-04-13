import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../theme/web_utils.dart';
import '../services/localization_service.dart';
import '../services/supabase_service.dart';
import '../providers/app_state.dart';
import 'customer_form_screen.dart';
import 'order_detail_screen.dart';

class CustomerDetailScreen extends StatefulWidget {
  final String customerId;
  const CustomerDetailScreen({super.key, required this.customerId});

  @override
  State<CustomerDetailScreen> createState() => _CustomerDetailScreenState();
}

class _CustomerDetailScreenState extends State<CustomerDetailScreen> {
  Map<String, dynamic>? _customer;
  List<Map<String, dynamic>> _orders = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await SupabaseService.getCustomer(widget.customerId);
      final orders = await SupabaseService.getOrders(customerId: widget.customerId);
      // Sort orders: planned first, active second, completed last
      orders.sort((a, b) {
        final stA = _statusWeight(a['status']);
        final stB = _statusWeight(b['status']);
        if (stA != stB) return stA.compareTo(stB);
        return (b['created_at'] ?? '').compareTo(a['created_at'] ?? '');
      });

      if (mounted) setState(() { _customer = data; _orders = orders; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  int _statusWeight(String? status) {
    if (status == 'planned') return 1;
    if (status == 'active') return 2;
    if (status == 'completed') return 3;
    return 4;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_customer == null) return Scaffold(appBar: AppBar(title: Text(tr('Müşteri'))), body: Center(child: Text(tr('Bulunamadı'))));

    final c = _customer!;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(c['name'] ?? '', style: const TextStyle(fontFamily: 'Inter', fontSize: 16)),
          actions: [
            // 🏠 Ana sayfaya git
            IconButton(
              icon: const Icon(Icons.home_outlined),
              tooltip: 'Zur Startseite (Aufträge)',
              onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
            ),
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => Navigator.push(context, MaterialPageRoute(
                builder: (_) => CustomerFormScreen(customerId: widget.customerId),
              )).then((_) => _load()),
            ),
          ],
          bottom: TabBar(
            labelColor: AppTheme.primary,
            unselectedLabelColor: AppTheme.textSub,
            indicatorColor: AppTheme.primary,
            tabs: [
              Tab(text: tr('Stammdaten')),
              Tab(text: tr('Aufträge')),
            ],
          ),
        ),
        body: WebContentWrapper(
          child: TabBarView(
            children: [
              _buildStammdaten(c),
              _buildOrders(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStammdaten(Map<String, dynamic> c) {
    final contacts = c['customer_contacts'] as List? ?? [];
    final status = c['status'] ?? '';
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Basic Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppTheme.divider)),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: AppTheme.primary.withOpacity(0.1),
                  child: Text((c['name']?.toString().trim().isEmpty ?? true) ? '?' : c['name'].toString().trim()[0].toUpperCase(), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.primary, fontFamily: 'Inter')),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(c['name'] ?? '', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, fontFamily: 'Inter')),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: AppTheme.statusColor(status).withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                      child: Text(AppTheme.statusLabel(status), style: TextStyle(fontSize: 11, color: AppTheme.statusColor(status), fontFamily: 'Inter', fontWeight: FontWeight.w600)),
                    ),
                  ]),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _InfoSection(tr('İletişim'), [
            _InfoRow(Icons.phone_outlined, tr('Telefon'), c['phone']),
            _InfoRow(Icons.email_outlined, tr('E-posta'), c['email']),
            _InfoRow(Icons.language_outlined, tr('Web'), c['website']),
          ]),
          const SizedBox(height: 12),
          _InfoSection(tr('Adres'), [
            _InfoRow(Icons.location_on_outlined, tr('Adres'), c['address']),
            _InfoRow(Icons.location_city_outlined, tr('Şehir'), c['city']),
            _InfoRow(Icons.map_outlined, tr('Saha Adresi'), c['site_address']),
          ]),
          const SizedBox(height: 12),
          if (contacts.isNotEmpty) ...[
            _InfoSection(tr('Sachbearbeiter (Muhataplar)'), [
              for (final contact in contacts)
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: AppTheme.bg, borderRadius: BorderRadius.circular(10)),
                  child: Row(
                    children: [
                      CircleAvatar(radius: 16, backgroundColor: AppTheme.accent.withOpacity(0.15), child: Text((contact['name']?.toString().trim().isEmpty ?? true) ? '?' : contact['name'].toString().trim()[0].toUpperCase(), style: const TextStyle(color: AppTheme.accent, fontSize: 12, fontWeight: FontWeight.bold))),
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
        ],
      ),
    );
  }

  Widget _buildOrders() {
    if (_orders.isEmpty) {
      return Center(child: Text(tr('Keine Aufträge vorhanden'), style: const TextStyle(fontFamily: 'Inter')));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _orders.length,
      itemBuilder: (_, i) {
        final o = _orders[i];
        final status = o['status'] ?? '';
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: Icon(Icons.work_outline, color: AppTheme.statusColor(status)),
            title: Text(o['title'] ?? tr('Aufgabe'), style: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600)),
            subtitle: Text(AppTheme.statusLabel(status), style: TextStyle(color: AppTheme.statusColor(status), fontSize: 12)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => OrderDetailScreen(orderId: o['id']))),
          ),
        );
      },
    );
  }
}

class _InfoSection extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _InfoSection(this.title, this.children);

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();
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

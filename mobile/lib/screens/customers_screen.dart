import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../providers/app_state.dart';
import '../services/supabase_service.dart';
import 'customer_detail_screen.dart';
import 'customer_form_screen.dart';

class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key});

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  List<Map<String, dynamic>> _all = [];
  List<Map<String, dynamic>> _filtered = [];
  bool _loading = true;
  String _search = '';
  String? _statusFilter;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await SupabaseService.getCustomers(status: _statusFilter);
      if (mounted) setState(() { _all = data; _applyFilter(); _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _applyFilter() {
    if (_search.isEmpty) {
      _filtered = _all;
    } else {
      final q = _search.toLowerCase();
      _filtered = _all.where((c) =>
        (c['name'] ?? '').toLowerCase().contains(q) ||
        (c['city'] ?? '').toLowerCase().contains(q) ||
        (c['email'] ?? '').toLowerCase().contains(q)
      ).toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    final canCreate = context.watch<AppState>().canManageCustomers;

    return Scaffold(
      floatingActionButton: canCreate
          ? FloatingActionButton.extended(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CustomerFormScreen())).then((_) => _load()),
              icon: const Icon(Icons.add),
              label: const Text('Yeni Müşteri', style: TextStyle(fontFamily: 'Inter')),
            )
          : null,
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Column(
              children: [
                TextField(
                  onChanged: (v) => setState(() { _search = v; _applyFilter(); }),
                  decoration: const InputDecoration(
                    hintText: 'Müşteri adı, şehir, e-posta ara...',
                    prefixIcon: Icon(Icons.search),
                    contentPadding: EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 34,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      for (final entry in {'Tümü': null, 'Aktif': 'active', 'Pasif': 'inactive', 'Potansiyel': 'potential', 'Arşiv': 'archived'}.entries)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(entry.key, style: TextStyle(fontFamily: 'Inter', fontSize: 12,
                              color: _statusFilter == entry.value ? Colors.white : AppTheme.textSub)),
                            selected: _statusFilter == entry.value,
                            selectedColor: AppTheme.primary,
                            backgroundColor: AppTheme.bg,
                            onSelected: (_) {
                              setState(() { _statusFilter = entry.value; _loading = true; });
                              _load();
                            },
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _filtered.isEmpty
                    ? const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(Icons.business_outlined, size: 56, color: AppTheme.textSub),
                        SizedBox(height: 12),
                        Text('Müşteri bulunamadı', style: TextStyle(color: AppTheme.textSub, fontFamily: 'Inter')),
                      ]))
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: _filtered.length,
                          itemBuilder: (_, i) {
                            final c = _filtered[i];
                            return Card(
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: AppTheme.primary.withOpacity(0.1),
                                  child: Text(
                                    (c['name'] ?? '?')[0].toUpperCase(),
                                    style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold, fontFamily: 'Inter'),
                                  ),
                                ),
                                title: Text(c['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, fontFamily: 'Inter')),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (c['city'] != null)
                                      Row(children: [
                                        const Icon(Icons.location_on_outlined, size: 12, color: AppTheme.textSub),
                                        const SizedBox(width: 2),
                                        Text(c['city'], style: const TextStyle(fontSize: 11, fontFamily: 'Inter', color: AppTheme.textSub)),
                                      ]),
                                    if (c['phone'] != null)
                                      Row(children: [
                                        const Icon(Icons.phone_outlined, size: 12, color: AppTheme.textSub),
                                        const SizedBox(width: 2),
                                        Text(c['phone'], style: const TextStyle(fontSize: 11, fontFamily: 'Inter', color: AppTheme.textSub)),
                                      ]),
                                  ],
                                ),
                                trailing: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppTheme.statusColor(c['status'] ?? '').withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        AppTheme.statusLabel(c['status'] ?? ''),
                                        style: TextStyle(fontSize: 10, color: AppTheme.statusColor(c['status'] ?? ''), fontFamily: 'Inter', fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    const Icon(Icons.chevron_right, color: AppTheme.border),
                                  ],
                                ),
                                isThreeLine: true,
                                onTap: () => Navigator.push(context, MaterialPageRoute(
                                  builder: (_) => CustomerDetailScreen(customerId: c['id']),
                                )).then((_) => _load()),
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../theme/web_utils.dart';
import '../providers/app_state.dart';
import '../services/supabase_service.dart';
import '../services/localization_service.dart';
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
    final appState = context.read<AppState>();
    try {
      final depId = !appState.canViewAllCustomers ? appState.departmentId : null;
      final data = await SupabaseService.getCustomers(
        status: _statusFilter,
        departmentId: depId,
      );
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
      appBar: AppBar(
        title: Text(tr('Müşteri Yönetimi'), style: const TextStyle(fontFamily: 'Inter', fontSize: 18)),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.textMain,
      ),
      floatingActionButton: canCreate
          ? FloatingActionButton.extended(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CustomerFormScreen())).then((_) => _load()),
              icon: const Icon(Icons.add),
              label: Text(tr('Yeni Müşteri'), style: const TextStyle(fontFamily: 'Inter')),
            )
          : null,
      body: WebContentWrapper(
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Column(
                children: [
                  TextField(
                    onChanged: (v) => setState(() { _search = v; _applyFilter(); }),
                    decoration: InputDecoration(
                      hintText: tr('Müşteri adı, şehir, e-posta ara...'),
                      prefixIcon: const Icon(Icons.search),
                      contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 34,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        for (final entry in {tr('Tümü'): null, tr('Aktif'): 'active', tr('Pasif'): 'inactive', tr('Potansiyel'): 'potential', tr('Arşiv'): 'archived'}.entries)
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
                      ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Icon(Icons.business_outlined, size: 56, color: AppTheme.textSub),
                          SizedBox(height: 12),
                          Text(tr('Müşteri bulunamadı'), style: const TextStyle(color: AppTheme.textSub, fontFamily: 'Inter')),
                        ]))
                      : RefreshIndicator(
                          onRefresh: _load,
                          child: ListView.builder(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            itemCount: _filtered.length,
                            itemBuilder: (_, i) {
                              final c = _filtered[i];
                              return Dismissible(
                                key: ValueKey('customer-${c['id']}'),
                                direction: canCreate ? DismissDirection.horizontal : DismissDirection.none,
                                background: Container(
                                  alignment: Alignment.centerLeft,
                                  padding: const EdgeInsets.only(left: 20),
                                  decoration: BoxDecoration(color: AppTheme.error, borderRadius: BorderRadius.circular(16)),
                                  child: const Icon(Icons.delete_outline, color: Colors.white, size: 28),
                                ),
                                secondaryBackground: Container(
                                  alignment: Alignment.centerRight,
                                  padding: const EdgeInsets.only(right: 20),
                                  decoration: BoxDecoration(color: AppTheme.error, borderRadius: BorderRadius.circular(16)),
                                  child: const Icon(Icons.delete_outline, color: Colors.white, size: 28),
                                ),
                                confirmDismiss: (dir) async {
                                  return await showDialog(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      title: Text(tr('Müşteriyi Sil?')),
                                      content: Text(tr('Bu müşteriyi ve bağlı olan tüm verileri silmek istediğinize emin misiniz?')),
                                      actions: [
                                        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr('Vazgeç'))),
                                        TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(tr('Evet, Sil'), style: const TextStyle(color: AppTheme.error))),
                                      ],
                                    ),
                                  );
                                },
                                onDismissed: (dir) async {
                                  final customerId = c['id'];
                                  try {
                                    await SupabaseService.deleteCustomer(customerId);
                                    if (!mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('Müşteri başarıyla arşivlendi'))));
                                  } catch (e) {
                                    if (!mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${tr('Hata')}: $e')));
                                    _load(); // Restore list on error
                                  }
                                  _load(); // Ensure local state is consistent with DB
                                },
                                child: _CustomerListTile(
                                  customer: c,
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
      ),
    );
  }
}

class _CustomerListTile extends StatelessWidget {
  final Map<String, dynamic> customer;
  final VoidCallback onTap;
  const _CustomerListTile({required this.customer, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final status = customer['status'] ?? '';
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: AppTheme.primary.withOpacity(0.1),
                child: Text(
                  (customer['name'] ?? '?')[0].toUpperCase(),
                  style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold, fontFamily: 'Inter'),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      customer['name'] ?? '',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15, fontFamily: 'Inter'),
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    if (customer['city'] != null)
                      Row(children: [
                        const Icon(Icons.location_on_outlined, size: 12, color: AppTheme.textSub),
                        const SizedBox(width: 4),
                        Text(customer['city'], style: const TextStyle(fontSize: 12, color: AppTheme.textSub, fontFamily: 'Inter')),
                      ]),
                  ],
                ),
              ),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.statusColor(status).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.statusColor(status).withOpacity(0.3)),
                    ),
                    child: Text(
                      AppTheme.statusLabel(status),
                      style: TextStyle(fontSize: 11, color: AppTheme.statusColor(status), fontWeight: FontWeight.w600, fontFamily: 'Inter'),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Icon(Icons.chevron_right, size: 16, color: AppTheme.border),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

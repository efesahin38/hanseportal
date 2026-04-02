import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../theme/web_utils.dart';
import '../providers/app_state.dart';
import '../services/supabase_service.dart';
import '../services/localization_service.dart';
import 'order_detail_screen.dart';
import 'order_form_screen.dart';

class OrdersScreen extends StatefulWidget {
  final String? departmentId;
  final String? initialStatus;
  const OrdersScreen({super.key, this.departmentId, this.initialStatus});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  List<Map<String, dynamic>> _orders = [];
  List<Map<String, dynamic>> _filtered = [];
  bool _loading = true;
  String _search = '';
  String? _statusFilter;

    final _statuses = ['', 'draft', 'planning', 'in_progress', 'completed', 'invoiced', 'archived'];
    final _statusLabels = [tr('Tümü'), tr('Taslak'), tr('Planlamada'), tr('Devam Ediyor'), tr('Tamamlandı'), tr('Faturalandı'), tr('Arşivlendi')];

  @override
  void initState() {
    super.initState();
    if (widget.initialStatus != null) {
      _statusFilter = widget.initialStatus;
    }
    _load();
  }

  Future<void> _load() async {
    final appState = context.read<AppState>();
    try {
      // Yalnızca tüm SIPARIŞLERI görme yetkisi olmayan yetkililer için (ör: alan yöneticileri) filtrele
      final depId = widget.departmentId ?? (!appState.canViewAllOrders ? appState.departmentId : null);
      
      final data = await SupabaseService.getOrders(
        status: _statusFilter?.isNotEmpty == true ? _statusFilter : null,
        departmentId: depId,
      );
      if (mounted) setState(() { _orders = data; _applyFilter(); _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _applyFilter() {
    if (_search.isEmpty) {
      _filtered = _orders;
    } else {
      final q = _search.toLowerCase();
      _filtered = _orders.where((o) =>
        (o['title'] ?? '').toLowerCase().contains(q) ||
        (o['order_number'] ?? '').toLowerCase().contains(q) ||
        (o['customer']?['name'] ?? '').toLowerCase().contains(q)
      ).toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    final canCreate = context.watch<AppState>().canManageOrders;

    return Scaffold(
      appBar: Navigator.canPop(context)
          ? AppBar(
              title: Text(_getTitle(), style: const TextStyle(fontFamily: 'Inter', fontSize: 18)),
              leading: const BackButton(),
              elevation: 0,
              backgroundColor: Colors.white,
              foregroundColor: AppTheme.textMain,
            )
          : null,
      floatingActionButton: canCreate
          ? FloatingActionButton.extended(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => OrderFormScreen(initialDepartmentId: widget.departmentId))).then((_) => _load()),
              icon: const Icon(Icons.add),
              label: Text(tr('Yeni İş'), style: const TextStyle(fontFamily: 'Inter')),
            )
          : null,
      body: WebContentWrapper(
        padding: EdgeInsets.zero,
        child: Column(
        children: [
          // ── Arama & Filtre ───────────────────────────────
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Column(
              children: [
                TextField(
                  onChanged: (v) => setState(() { _search = v; _applyFilter(); }),
                    decoration: InputDecoration(
                      hintText: tr('İş adı, numara, müşteri ara...'),
                    prefixIcon: Icon(Icons.search),
                    contentPadding: EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 36,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _statuses.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (_, i) {
                      final selected = _statusFilter == _statuses[i] || (_statusFilter == null && i == 0);
                      return ChoiceChip(
                        label: Text(_statusLabels[i], style: TextStyle(fontFamily: 'Inter', fontSize: 12,
                          color: selected ? Colors.white : AppTheme.textSub)),
                        selected: selected,
                        selectedColor: AppTheme.primary,
                        backgroundColor: AppTheme.bg,
                        onSelected: (_) {
                          setState(() {
                            _statusFilter = _statuses[i].isEmpty ? null : _statuses[i];
                            _loading = true;
                          });
                          _load();
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),

          // ── Liste ────────────────────────────────────────
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.work_off_outlined, size: 56, color: AppTheme.textSub),
                            const SizedBox(height: 12),
                            const Text('İş bulunamadı', style: TextStyle(color: AppTheme.textSub, fontSize: 15, fontFamily: 'Inter')),
                            if (canCreate) ...[
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const OrderFormScreen())).then((_) => _load()),
                                icon: const Icon(Icons.add),
                                label: const Text('Yeni İş Ekle'),
                              ),
                            ],
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: _filtered.length,
                          itemBuilder: (_, i) {
                            final order = _filtered[i];
                            return Dismissible(
                              key: Key(order['id']),
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
                                    title: const Text('İşi Sil?'),
                                    content: const Text('Bu işi ve bağlı olan tüm plan/raporları silmek istediğinize emin misiniz?'),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Vazgeç')),
                                      TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Evet, Sil', style: TextStyle(color: AppTheme.error))),
                                    ],
                                  ),
                                );
                              },
                              onDismissed: (dir) async {
                                final orderId = order['id'];
                                try {
                                  await SupabaseService.deleteOrder(orderId);
                                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('İş başarıyla silindi'))));
                                } catch (e) {
                                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${tr('Hata')}: $e')));
                                }
                                _load();
                              },
                              child: _OrderListTile(
                                order: order,
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => OrderDetailScreen(orderId: order['id'])),
                                ).then((_) => _load()),
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

  String _getTitle() {
    if (widget.departmentId == 'dddddddd-1111-1111-1111-111111111111') return tr('Temizlik İşleri');
    if (widget.departmentId == 'dddddddd-2222-2222-2222-222222222222') return tr('Ray Servis İşleri');
    if (widget.departmentId == 'dddddddd-3333-3333-3333-333333333333') return tr('Otel Servis İşleri');
    if (widget.departmentId == 'dddddddd-4444-4444-4444-444444444444') return tr('Personel İşleri');
    if (widget.departmentId == 'dddddddd-5555-5555-5555-555555555555') return tr('Yönetim / Diğer');
    return tr('Tüm İşler');
  }
}

class _OrderListTile extends StatelessWidget {
  final Map<String, dynamic> order;
  final VoidCallback onTap;
  const _OrderListTile({required this.order, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final status = order['status'] ?? '';
    final priority = order['priority'] ?? 'normal';
    final serviceArea = order['service_area'];
    final customer = order['customer'];
    final responsible = order['responsible_user'];
    final startDate = order['planned_start_date'];

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      order['title'] ?? '',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15, fontFamily: 'Inter'),
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (priority == 'urgent')
                    const Icon(Icons.priority_high, color: AppTheme.error, size: 18),
                  const SizedBox(width: 4),
                  _StatusBadge(status: status),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.business, size: 14, color: AppTheme.textSub),
                  const SizedBox(width: 4),
                  Expanded(child: Text(customer?['name'] ?? '', style: const TextStyle(fontSize: 12, color: AppTheme.textSub, fontFamily: 'Inter'), maxLines: 1, overflow: TextOverflow.ellipsis)),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(order['order_number'] ?? '', style: const TextStyle(fontSize: 11, color: AppTheme.textSub, fontFamily: 'Inter')),
                  const Spacer(),
                  if (serviceArea != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(serviceArea['name'] ?? '', style: const TextStyle(fontSize: 11, fontFamily: 'Inter', color: AppTheme.primary)),
                    ),
                  if (startDate != null) ...[
                    const SizedBox(width: 8),
                    const Icon(Icons.calendar_today, size: 12, color: AppTheme.textSub),
                    const SizedBox(width: 2),
                    Text(startDate, style: const TextStyle(fontSize: 11, color: AppTheme.textSub, fontFamily: 'Inter')),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppTheme.statusColor(status).withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.statusColor(status).withOpacity(0.3)),
      ),
      child: Text(
        AppTheme.statusLabel(status),
        style: TextStyle(fontSize: 11, color: AppTheme.statusColor(status), fontWeight: FontWeight.w600, fontFamily: 'Inter'),
      ),
    );
  }
}

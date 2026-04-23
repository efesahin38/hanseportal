import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../theme/web_utils.dart';
import '../providers/app_state.dart';
import '../services/supabase_service.dart';
import '../services/localization_service.dart';
import 'order_detail_screen.dart';
import 'operation_plan_form_screen.dart';

class PlanningScreen extends StatefulWidget {
  const PlanningScreen({super.key});

  @override
  State<PlanningScreen> createState() => _PlanningScreenState();
}

class _PlanningScreenState extends State<PlanningScreen> {
  DateTime _selectedDate = DateTime.now();
  List<Map<String, dynamic>> _plans = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final appState = context.read<AppState>();
    setState(() => _loading = true);
    try {
      final departmentId = !appState.canViewAllOrders ? appState.departmentId : null;
      final data = await SupabaseService.getOperationPlans(
        date: _selectedDate,
        departmentId: departmentId,
      );
      if (mounted) setState(() { _plans = data; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _prevDay() { setState(() => _selectedDate = _selectedDate.subtract(const Duration(days: 1))); _load(); }
  void _nextDay() { setState(() => _selectedDate = _selectedDate.add(const Duration(days: 1))); _load(); }

  /// İş seçim dialog'u açarak yeni plan formu başlat
  Future<void> _showAddPlanDialog() async {
    // Aktif işleri getir
    List<Map<String, dynamic>> orders = [];
    try {
      final appState = context.read<AppState>();
      final departmentId = !appState.canViewAllOrders ? appState.departmentId : null;
      orders = await SupabaseService.getOrders(departmentId: departmentId);
      // Arşivlenmiş ve taslak olmayanları filtrele
      orders = orders.where((o) {
        final s = o['status'] ?? '';
        return s != 'archived' && s != 'invoiced';
      }).toList();
    } catch (_) {}

    if (!mounted) return;

    if (orders.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('Uygun aktif iş bulunamadı'))),
      );
      return;
    }

    final selected = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _OrderPickerSheet(orders: orders),
    );

    if (selected == null || !mounted) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OperationPlanFormScreen(
          orderId: selected['id'],
          initialDate: _selectedDate,
        ),
      ),
    );
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final canPlan = appState.canPlanOperations;

    final isToday = _selectedDate.year == DateTime.now().year &&
        _selectedDate.month == DateTime.now().month &&
        _selectedDate.day == DateTime.now().day;

    return Scaffold(
      floatingActionButton: canPlan
          ? FloatingActionButton.extended(
              onPressed: _showAddPlanDialog,
              icon: const Icon(Icons.add),
              label: Text(tr('Plan Ekle'), style: const TextStyle(fontFamily: 'Inter')),
            )
          : null,
      body: WebContentWrapper(
        child: Column(
          children: [
            // ── Tarih Seçici ─────────────────────────────────
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  IconButton(onPressed: _prevDay, icon: const Icon(Icons.chevron_left)),
                  Expanded(
                    child: GestureDetector(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _selectedDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2030),
                          locale: const Locale('de', 'DE'),
                        );
                        if (picked != null) { setState(() => _selectedDate = picked); _load(); }
                      },
                      child: Column(
                        children: [
                          Text(isToday ? tr('Heute') : '', style: const TextStyle(color: AppTheme.accent, fontFamily: 'Inter', fontSize: 12)),
                          Text(
                            '${_selectedDate.day}.${_selectedDate.month.toString().padLeft(2, '0')}.${_selectedDate.year}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Inter'),
                          ),
                          Text(tr('Tarih seçmek için tıklayın'), style: const TextStyle(color: AppTheme.textSub, fontSize: 11, fontFamily: 'Inter')),
                        ],
                      ),
                    ),
                  ),
                  IconButton(onPressed: _nextDay, icon: const Icon(Icons.chevron_right)),
                ],
              ),
            ),
  
            // ── Plan Listesi ─────────────────────────────────
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _plans.isEmpty
                      ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                          const Icon(Icons.event_busy, size: 56, color: AppTheme.textSub),
                          const SizedBox(height: 12),
                          Text(
                            isToday ? tr('Bugün için plan yok') : tr('Bu tarih için plan yok'),
                            style: const TextStyle(color: AppTheme.textSub, fontFamily: 'Inter'),
                          ),
                          if (canPlan) ...[
                            const SizedBox(height: 16),
                            OutlinedButton.icon(
                              onPressed: _showAddPlanDialog,
                              icon: const Icon(Icons.add),
                              label: Text(tr('Plan Oluştur'), style: const TextStyle(fontFamily: 'Inter')),
                            ),
                          ],
                        ]))
                      : RefreshIndicator(
                          onRefresh: _load,
                          child: ListView.builder(
                            padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
                            itemCount: _plans.length,
                            itemBuilder: (_, i) {
                              final plan = _plans[i];
                              return Dismissible(
                                key: Key(plan['id']),
                                direction: canPlan ? DismissDirection.horizontal : DismissDirection.none,
                                background: Container(
                                  alignment: Alignment.centerLeft,
                                  padding: const EdgeInsets.only(left: 20),
                                  decoration: BoxDecoration(color: AppTheme.primary, borderRadius: BorderRadius.circular(16)),
                                  child: const Icon(Icons.edit, color: Colors.white, size: 28),
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
                                      title: Text(tr('Planı Sil?')),
                                      content: Text(tr('Bu işletme planını ve atanan personelleri silmek istediğinize emin misiniz?')),
                                      actions: [
                                        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr('Vazgeç'))),
                                        TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(tr('Evet, Sil'), style: const TextStyle(color: AppTheme.error))),
                                      ],
                                    ),
                                  );
                                },
                                onDismissed: (dir) async {
                                  final planId = plan['id'];
                                  if (dir == DismissDirection.endToStart) {
                                    try {
                                      final appState = context.read<AppState>();
                                      // 1. Atanan personelleri bul
                                      final personnelIds = await SupabaseService.getPlanPersonnelIds(planId);
                                      
                                      // 2. Eski bildirimleri temizle (Atama ve Güncelleme mesajları gitsin)
                                      await SupabaseService.deleteNotificationsByPlanId(planId);
                                      
                                      // 3. İptal bildirimi gönder
                                      final orderTitle = plan['order']?['title'] ?? 'İş';
                                      for (var uid in personnelIds) {
                                        await SupabaseService.sendTaskNotification(
                                          recipientId: uid,
                                          title: tr('Plan İptal Edildi'),
                                          body: '$orderTitle ${tr('planı yönetici tarafından iptal edildi.')}',
                                          orderId: plan['order_id'],
                                          operationPlanId: planId,
                                          notificationType: 'task_cancelled',
                                          sentBy: appState.userId,
                                        );
                                      }
  
                                      // 4. Planı asıl veritabanından sil
                                      await SupabaseService.deleteOperationPlan(planId);
                                      
                                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('Plan silindi ve personel bilgilendirildi'))));
                                    } catch (e) {
                                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${tr('Fehler')}: $e')));
                                    }
                                  } else if (dir == DismissDirection.startToEnd) {
                                    final orderId = plan['order_id'];
                                    if (orderId != null) {
                                      await Navigator.push(context, MaterialPageRoute(
                                        builder: (_) => OperationPlanFormScreen(orderId: orderId, planId: planId),
                                      ));
                                    }
                                  }
                                  _load();
                                },
                                child: _PlanCard(
                                  plan: plan,
                                  onTap: () {
                                    final orderId = plan['order_id'];
                                    if (orderId != null) {
                                      Navigator.push(context, MaterialPageRoute(builder: (_) => OrderDetailScreen(orderId: orderId)));
                                    }
                                  },
                                  onEdit: () {
                                    final orderId = plan['order_id'];
                                    if (orderId != null) {
                                      Navigator.push(context, MaterialPageRoute(
                                        builder: (_) => OperationPlanFormScreen(orderId: orderId, planId: plan['id']),
                                      )).then((_) => _load());
                                    }
                                  },
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

// ─────────────────────────────────────────────────────
// İŞ SEÇİM SHEET
// ─────────────────────────────────────────────────────
class _OrderPickerSheet extends StatelessWidget {
  final List<Map<String, dynamic>> orders;
  const _OrderPickerSheet({required this.orders});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      builder: (_, ctrl) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40, height: 4,
                decoration: BoxDecoration(color: AppTheme.divider, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Text(tr('Hangi iş için plan oluşturulsun?'),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'Inter')),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                controller: ctrl,
                itemCount: orders.length,
                itemBuilder: (_, i) {
                  final o = orders[i];
                  final status = o['status'] ?? '';
                  final customer = o['customer'];
                  return ListTile(
                    leading: Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        color: AppTheme.statusColor(status).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.work_outline, color: AppTheme.statusColor(status), size: 20),
                    ),
                    title: Text(o['title'] ?? '', style: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Row(children: [
                      Text(o['order_number'] ?? '', style: const TextStyle(fontFamily: 'Inter', fontSize: 12, color: AppTheme.textSub)),
                      if (customer != null) ...[
                        const Text(' · ', style: TextStyle(color: AppTheme.textSub)),
                        Expanded(child: Text(customer['name'] ?? '', style: const TextStyle(fontFamily: 'Inter', fontSize: 12, color: AppTheme.textSub), maxLines: 1, overflow: TextOverflow.ellipsis)),
                      ],
                    ]),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(color: AppTheme.statusColor(status).withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                      child: Text(AppTheme.statusLabel(status), style: TextStyle(fontSize: 11, color: AppTheme.statusColor(status), fontFamily: 'Inter', fontWeight: FontWeight.w600)),
                    ),
                    onTap: () => Navigator.pop(context, o),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────
// PLAN KARTI
// ─────────────────────────────────────────────────────
class _PlanCard extends StatelessWidget {
  final Map<String, dynamic> plan;
  final VoidCallback onTap;
  final VoidCallback? onEdit;
  const _PlanCard({required this.plan, required this.onTap, this.onEdit});

  @override
  Widget build(BuildContext context) {
    final order = plan['order'];
    final customer = order?['customer'];
    final supervisor = plan['site_supervisor'];
    final personnelData = plan['operation_plan_personnel'];
    final personnel = personnelData is List ? personnelData : [];
    final startTime = plan['start_time'] ?? '';
    final endTime = plan['end_time'] ?? '';
    final orderStatus = order?['status'] ?? 'draft';

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
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppTheme.primary.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(children: [
                                  const Icon(Icons.access_time, size: 14, color: AppTheme.primary),
                                  const SizedBox(width: 4),
                                  Text('$startTime${endTime.isNotEmpty ? ' – $endTime' : ''}',
                                    style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w600, fontSize: 13, fontFamily: 'Inter')),
                                ]),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppTheme.statusColor(orderStatus).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(AppTheme.statusLabel(orderStatus),
                                  style: TextStyle(fontSize: 11, color: AppTheme.statusColor(orderStatus), fontFamily: 'Inter', fontWeight: FontWeight.w600)),
                              ),
                            ],
                          ),
              const SizedBox(height: 10),
              Text(order?['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15, fontFamily: 'Inter')),
              if (customer != null) ...[
                const SizedBox(height: 4),
                Row(children: [
                  const Icon(Icons.business, size: 14, color: AppTheme.textSub),
                  const SizedBox(width: 4),
                  Text(customer['name'] ?? '', style: const TextStyle(fontSize: 13, color: AppTheme.textSub, fontFamily: 'Inter')),
                ]),
              ],
              const Divider(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.people_outline, size: 15, color: AppTheme.textSub),
                  const SizedBox(width: 4),
                  Expanded(
                    child: personnel.isEmpty
                        ? Text(tr('Personel atanmamış'), style: const TextStyle(fontSize: 13, color: AppTheme.textSub, fontFamily: 'Inter'))
                        : Wrap(
                            spacing: 4,
                            runSpacing: 4,
                            children: personnel.map((p) {
                              final u = p['users'];
                              final name = u != null ? '${u['first_name']} ${u['last_name']}'.trim() : 'Bilinmiyor';
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppTheme.divider.withOpacity(0.5),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(name, style: const TextStyle(fontSize: 11, fontFamily: 'Inter')),
                              );
                            }).toList(),
                          ),
                  ),
                ],
              ),
              if (supervisor != null) ...[
                const SizedBox(height: 8),
                Row(children: [
                  const Icon(Icons.star_outline, size: 15, color: AppTheme.warning),
                  const SizedBox(width: 4),
                  Text('${tr('Saha Lideri')}: ${supervisor['first_name']} ${supervisor['last_name']}'.trim(),
                    style: const TextStyle(fontSize: 12, color: AppTheme.warning, fontFamily: 'Inter', fontWeight: FontWeight.w600)),
                ]),
              ],
              if (plan['site_instructions'] != null && (plan['site_instructions'] as String).isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.warning.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.warning.withOpacity(0.2)),
                  ),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Icon(Icons.info_outline, size: 14, color: AppTheme.warning),
                    const SizedBox(width: 6),
                    Expanded(child: Text(plan['site_instructions'], style: const TextStyle(fontSize: 12, fontFamily: 'Inter'), maxLines: 2, overflow: TextOverflow.ellipsis)),
                  ]),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (onEdit != null)
                    TextButton.icon(
                      onPressed: onEdit,
                      icon: const Icon(Icons.edit_calendar, size: 16),
                      label: Text(tr('Planı Düzenle'), style: const TextStyle(fontSize: 12, fontFamily: 'Inter')),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

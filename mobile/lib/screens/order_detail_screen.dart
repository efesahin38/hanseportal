import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../providers/app_state.dart';
import '../services/supabase_service.dart';
import 'operation_plan_form_screen.dart';
import 'extra_work_form_screen.dart';
import 'work_report_screen.dart';

class OrderDetailScreen extends StatefulWidget {
  final String orderId;
  const OrderDetailScreen({super.key, required this.orderId});

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> with SingleTickerProviderStateMixin {
  Map<String, dynamic>? _order;
  bool _loading = true;
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final data = await SupabaseService.getOrder(widget.orderId);
      if (mounted) setState(() { _order = data; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _showStatusDialog(String newStatus) async {
    final noteCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Durumu Değiştir', style: const TextStyle(fontFamily: 'Inter')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Yeni durum: ${AppTheme.statusLabel(newStatus)}', style: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            TextFormField(
              controller: noteCtrl,
              decoration: const InputDecoration(labelText: 'Not (opsiyonel)', hintText: 'Durum değişikliği sebebi...'),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('İptal')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Güncelle')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      // Find current user id
      final profile = await SupabaseService.getCurrentUserProfile();
      await SupabaseService.updateOrderStatus(widget.orderId, newStatus, noteCtrl.text.trim(), profile?['id'] ?? '');
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Durum güncellendi: ${AppTheme.statusLabel(newStatus)}')),
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_order == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('İş Detayı')),
        body: const Center(child: Text('İş bulunamadı', style: TextStyle(fontFamily: 'Inter'))),
      );
    }

    final o = _order!;
    final status = o['status'] ?? '';
    final customer = o['customer'];
    final serviceArea = o['service_area'];
    final responsible = o['responsible_user'];
    final plans = o['operation_plans'] as List? ?? [];
    final docs = o['documents'] as List? ?? [];
    final history = o['order_status_history'] as List? ?? [];

    final appState = context.watch<AppState>();

    return Scaffold(
      floatingActionButton: appState.canPlanOperations ? Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.small(
            heroTag: 'work_report',
            backgroundColor: AppTheme.success,
            tooltip: 'İş Sonu Raporu',
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => WorkReportScreen(orderId: widget.orderId))).then((_) => _load()),
            child: const Icon(Icons.summarize_outlined, color: Colors.white),
          ),
          const SizedBox(height: 8),
          FloatingActionButton.small(
            heroTag: 'extra_work',
            backgroundColor: AppTheme.warning,
            tooltip: 'Ek İş Ekle',
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ExtraWorkFormScreen(orderId: widget.orderId))).then((_) => _load()),
            child: const Icon(Icons.add_task, color: Colors.white),
          ),
          const SizedBox(height: 8),
          FloatingActionButton.extended(
            heroTag: 'add_plan',
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => OperationPlanFormScreen(orderId: widget.orderId))).then((_) => _load()),
            icon: const Icon(Icons.calendar_today),
            label: const Text('Plan Ekle'),
          ),
        ],
      ) : null,
      appBar: AppBar(
        title: Text(o['order_number'] ?? 'İş Detayı'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (newStatus) => _showStatusDialog(newStatus),
            itemBuilder: (_) => [
              'approved', 'planning', 'in_progress', 'completed', 'invoiced', 'archived'
            ].map((s) => PopupMenuItem(value: s, child: Row(children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(color: AppTheme.statusColor(s), shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Text(AppTheme.statusLabel(s), style: const TextStyle(fontFamily: 'Inter')),
            ]))).toList(),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Başlık Alanı ─────────────────────────────────
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(child: Text(o['title'] ?? '', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Inter'))),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.statusColor(status).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(AppTheme.statusLabel(status),
                      style: TextStyle(fontSize: 12, color: AppTheme.statusColor(status), fontWeight: FontWeight.w600, fontFamily: 'Inter')),
                  ),
                ]),
                const SizedBox(height: 6),
                if (customer != null)
                  Text(customer['name'] ?? '', style: const TextStyle(fontSize: 14, color: AppTheme.textSub, fontFamily: 'Inter')),
                if (serviceArea != null) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: AppTheme.primary.withOpacity(0.08), borderRadius: BorderRadius.circular(6)),
                    child: Text(serviceArea['name'] ?? '', style: const TextStyle(fontSize: 12, color: AppTheme.primary, fontFamily: 'Inter')),
                  ),
                ],
                const SizedBox(height: 12),
                TabBar(
                  controller: _tabs,
                  isScrollable: true,
                  labelStyle: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600, fontSize: 12),
                  unselectedLabelStyle: const TextStyle(fontFamily: 'Inter', fontSize: 12),
                  tabs: [
                    Tab(text: 'Bilgiler'),
                    Tab(text: 'Planlama (${plans.length})'),
                    Tab(text: 'Belgeler (${docs.length})'),
                    Tab(text: 'Geçmiş (${history.length})'),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                // Tab 1: Temel Bilgiler
                SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(children: [
                    _InfoCard('İş Bilgileri', [
                      _InfoRow('İş Numarası', o['order_number']),
                      _InfoRow('Öncelik', o['priority']),
                      _InfoRow('Başlangıç', o['planned_start_date']),
                      _InfoRow('Bitiş', o['planned_end_date']),
                      _InfoRow('Saha Adresi', o['site_address']),
                    ]),
                    const SizedBox(height: 12),
                    _InfoCard('Müşteri', [
                      _InfoRow('Müşteri', customer?['name']),
                      _InfoRow('Telefon', customer?['phone']),
                      _InfoRow('E-posta', customer?['email']),
                    ]),
                    const SizedBox(height: 12),
                    if (o['short_description'] != null || o['detailed_description'] != null)
                      _InfoCard('Açıklama', [
                        if (o['short_description'] != null)
                          Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(o['short_description'], style: const TextStyle(fontFamily: 'Inter', fontSize: 14))),
                        if (o['detailed_description'] != null)
                          Text(o['detailed_description'], style: const TextStyle(fontFamily: 'Inter', fontSize: 13, color: AppTheme.textSub)),
                      ]),
                  ]),
                ),
                // Tab 2: Planlama
                plans.isEmpty
                    ? const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(Icons.calendar_today_outlined, size: 48, color: AppTheme.textSub),
                        SizedBox(height: 12),
                        Text('Henüz plan yok', style: TextStyle(color: AppTheme.textSub, fontFamily: 'Inter')),
                      ]))
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: plans.length,
                        itemBuilder: (_, i) {
                          final p = plans[i];
                          return Card(
                            child: ListTile(
                              title: Text('${p['plan_date']} ${p['start_time'] ?? ''}', style: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600)),
                              subtitle: Text('Durum: ${AppTheme.statusLabel(p['status'] ?? '')}', style: const TextStyle(fontFamily: 'Inter')),
                            ),
                          );
                        },
                      ),
                // Tab 3: Belgeler
                docs.isEmpty
                    ? const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(Icons.folder_open_outlined, size: 48, color: AppTheme.textSub),
                        SizedBox(height: 12),
                        Text('Belge yok', style: TextStyle(color: AppTheme.textSub, fontFamily: 'Inter')),
                      ]))
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: docs.length,
                        itemBuilder: (_, i) {
                          final d = docs[i];
                          return Card(
                            child: ListTile(
                              leading: const Icon(Icons.insert_drive_file_outlined, color: AppTheme.primary),
                              title: Text(d['title'] ?? '', style: const TextStyle(fontFamily: 'Inter')),
                              subtitle: Text(d['document_type'] ?? '', style: const TextStyle(fontFamily: 'Inter', fontSize: 12, color: AppTheme.textSub)),
                            ),
                          );
                        },
                      ),
                // Tab 4: Durum Geçmişi
                history.isEmpty
                    ? const Center(child: Text('Geçmiş yok', style: TextStyle(color: AppTheme.textSub, fontFamily: 'Inter')))
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: history.length,
                        itemBuilder: (_, i) {
                          final h = history[i];
                          final createdAt = h['created_at'] != null
                              ? DateTime.parse(h['created_at']).toLocal()
                              : null;
                          return ListTile(
                            leading: Container(
                              width: 8, height: 8,
                              decoration: BoxDecoration(color: AppTheme.statusColor(h['new_status'] ?? ''), shape: BoxShape.circle),
                            ),
                            title: Text(
                              '${AppTheme.statusLabel(h['old_status'] ?? '?')} → ${AppTheme.statusLabel(h['new_status'] ?? '')}',
                              style: const TextStyle(fontFamily: 'Inter', fontSize: 13),
                            ),
                            subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              if (h['note'] != null) Text(h['note'], style: const TextStyle(fontFamily: 'Inter', fontSize: 12, color: AppTheme.textSub)),
                              if (createdAt != null)
                                Text('${createdAt.day}.${createdAt.month}.${createdAt.year}',
                                  style: const TextStyle(fontFamily: 'Inter', fontSize: 11, color: AppTheme.textSub)),
                            ]),
                          );
                        },
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _InfoCard(this.title, this.children);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, fontFamily: 'Inter')),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String? value;
  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    if (value == null || value!.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 100, child: Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.textSub, fontFamily: 'Inter'))),
          Expanded(child: Text(value!, style: const TextStyle(fontSize: 13, fontFamily: 'Inter'))),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../theme/web_utils.dart';
import '../providers/app_state.dart';
import '../services/supabase_service.dart';
import '../services/localization_service.dart';
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
  List<Map<String, dynamic>> _siteUpdates = [];
  bool _loading = true;
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 5, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final order = await SupabaseService.getOrder(widget.orderId);
      final updates = await SupabaseService.getSiteUpdates(widget.orderId);
      if (mounted) {
        setState(() {
          _order = order;
          _siteUpdates = updates;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  // _showStatusDialog removed to enforce automated workflow

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_order == null) {
      return Scaffold(
        appBar: AppBar(title: Text(tr('İş Detayı'))),
        body: Center(child: Text(tr('İş bulunamadı'), style: const TextStyle(fontFamily: 'Inter'))),
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
    final isAssignedForeman = plans.any((p) => p['site_supervisor_id'] == appState.userId);
    
    // İş sonu raporunu (yeşil buton) sadece yönetici, muhasebe ve sistem admin görebilir.
    final canSeeReport = appState.isBetriebsleiter || appState.isGeschaeftsfuehrer || appState.isBuchhaltung || appState.isSystemAdmin;
    // Ek işi saha lideri ve yetkili personeller ekleyebilir.
    final canAddExtraWork = isAssignedForeman || appState.isBetriebsleiter || appState.isGeschaeftsfuehrer || appState.isSystemAdmin;

    return Scaffold(
      floatingActionButton: (canSeeReport || canAddExtraWork || appState.canPlanOperations) ? Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (canSeeReport)
            FloatingActionButton.small(
              heroTag: 'work_report',
              backgroundColor: AppTheme.success,
              tooltip: tr('İş Sonu Raporu'),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => WorkReportScreen(orderId: widget.orderId))).then((_) => _load()),
              child: const Icon(Icons.summarize_outlined, color: Colors.white),
            ),
          if (canSeeReport) const SizedBox(height: 8),
          if (canAddExtraWork)
            FloatingActionButton.small(
              heroTag: 'extra_work',
              backgroundColor: AppTheme.warning,
              tooltip: tr('Ek İş Ekle'),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ExtraWorkFormScreen(orderId: widget.orderId))).then((_) => _load()),
              child: const Icon(Icons.add_task, color: Colors.white),
            ),
          if (canAddExtraWork) const SizedBox(height: 8),
          if (appState.canPlanOperations)
            FloatingActionButton.extended(
              heroTag: 'add_plan',
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => OperationPlanFormScreen(orderId: widget.orderId))).then((_) => _load()),
              icon: const Icon(Icons.calendar_today),
              label: Text(tr('Plan Ekle')),
            ),
        ],
      ) : null,
      appBar: AppBar(
        title: Text(o['order_number'] ?? tr('İş Detayı')),
      ),
      body: WebContentWrapper(
        padding: EdgeInsets.zero,
        child: Column(
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
                        Tab(text: tr('Bilgiler')),
                        Tab(text: '${tr('Planlama')} (${plans.length})'),
                        Tab(text: '${tr('Saha Günlüğü')} (${_siteUpdates.length})'),
                        Tab(text: '${tr('Belgeler')} (${docs.length})'),
                        Tab(text: '${tr('Geçmiş')} (${history.length})'),
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
                      _InfoCard(tr('İş Bilgileri'), [
                        _InfoRow(tr('İş Numarası'), o['order_number']),
                        _InfoRow(tr('Öncelik'), o['priority']),
                        _InfoRow(tr('Başlangıç'), o['planned_start_date']),
                        _InfoRow(tr('Bitiş'), o['planned_end_date']),
                        _InfoRow(tr('Saha Adresi'), o['site_address']),
                        _InfoRow(tr('Min. Faturalanacak Saat'), o['minimum_billable_hours']?.toString()),
                        _InfoRow(tr('Malzeme/Ekipman'), o['material_notes']),
                      ]),
                      const SizedBox(height: 12),
                      _InfoCard(tr('Müşteri'), [
                        _InfoRow(tr('Müşteri'), customer?['name']),
                        _InfoRow(tr('Telefon'), customer?['phone'], isMasked: !appState.canSeeFullCustomerDetails),
                        _InfoRow(tr('E-posta'), customer?['email'], isMasked: !appState.canSeeFullCustomerDetails),
                      ]),
                      const SizedBox(height: 12),
                      if (o['short_description'] != null || o['detailed_description'] != null)
                        _InfoCard(tr('Açıklama'), [
                          if (o['short_description'] != null)
                            Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(o['short_description'], style: const TextStyle(fontFamily: 'Inter', fontSize: 14))),
                          if (o['detailed_description'] != null)
                            Text(o['detailed_description'], style: const TextStyle(fontFamily: 'Inter', fontSize: 13, color: AppTheme.textSub)),
                        ]),
                    ]),
                  ),
                  // Tab 2: Planlama
                  plans.isEmpty
                        ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                          const Icon(Icons.calendar_today_outlined, size: 48, color: AppTheme.textSub),
                          const SizedBox(height: 12),
                          Text(tr('Henüz plan yok'), style: const TextStyle(color: AppTheme.textSub, fontFamily: 'Inter')),
                        ]))
                      : ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: plans.length,
                          itemBuilder: (_, i) {
                            final p = plans[i];
                            final personnel = p['operation_plan_personnel'] as List? ?? [];
                            final startTime = p['start_time'] ?? '';
                            final endTime = p['end_time'] ?? '';
                            final supervisor = p['site_supervisor'] as Map<String, dynamic>?;

                            return Card(
                              margin: const EdgeInsets.only(bottom: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => OperationPlanFormScreen(orderId: widget.orderId, planId: p['id'])),
                                ).then((_) => _load()),
                                child: Padding(
                                  padding: const EdgeInsets.all(14),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Üst satır: Tarih + Durum
                                      Row(
                                        children: [
                                          const Icon(Icons.calendar_today, size: 14, color: AppTheme.primary),
                                          const SizedBox(width: 6),
                                          Text(
                                            p['plan_date'] ?? '',
                                            style: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold, fontSize: 14),
                                          ),
                                          const Spacer(),
                                          Builder(
                                            builder: (context) {
                                              String dispStatus = p['status'] ?? 'draft';
                                              final oStatus = _order?['status'] ?? '';
                                              if (oStatus == 'completed' || oStatus == 'invoiced' || oStatus == 'archived' || oStatus == 'in_progress') {
                                                dispStatus = oStatus;
                                              } else if (personnel.isNotEmpty && dispStatus == 'draft') {
                                                dispStatus = 'approved'; // Atanmış plan
                                              }
                                              
                                              return Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                decoration: BoxDecoration(
                                                  color: AppTheme.statusColor(dispStatus).withOpacity(0.12),
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                                child: Text(
                                                  AppTheme.statusLabel(dispStatus),
                                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, fontFamily: 'Inter', color: AppTheme.statusColor(dispStatus)),
                                                ),
                                              );
                                            }
                                          ),
                                        ],
                                      ),
                                      // Saat bilgisi
                                      if (startTime.isNotEmpty) ...[
                                        const SizedBox(height: 6),
                                        Row(children: [
                                          const Icon(Icons.access_time, size: 13, color: AppTheme.textSub),
                                          const SizedBox(width: 4),
                                          Text(
                                            endTime.isNotEmpty ? '$startTime – $endTime' : startTime,
                                            style: const TextStyle(fontSize: 12, fontFamily: 'Inter', color: AppTheme.textSub),
                                          ),
                                        ]),
                                      ],
                                      // Saha sorumlusu
                                      if (supervisor != null) ...[
                                        const SizedBox(height: 6),
                                        Row(children: [
                                          const Icon(Icons.star_outline, size: 13, color: AppTheme.warning),
                                          const SizedBox(width: 4),
                                          Text(
                                            '${tr('Saha Sorumlusu')}: ${supervisor['first_name']} ${supervisor['last_name']}',
                                            style: const TextStyle(fontSize: 12, fontFamily: 'Inter', color: AppTheme.warning, fontWeight: FontWeight.w600),
                                          ),
                                        ]),
                                      ],
                                      // Personel listesi
                                      if (personnel.isNotEmpty) ...[
                                        const SizedBox(height: 10),
                                        const Divider(height: 1),
                                        const SizedBox(height: 8),
                                        Row(children: [
                                          const Icon(Icons.people_outline, size: 13, color: AppTheme.textSub),
                                          const SizedBox(width: 4),
                                          Text('${tr('Atanan Personel')} (${personnel.length} ${tr('kişi')})', style: const TextStyle(fontSize: 12, fontFamily: 'Inter', color: AppTheme.textSub, fontWeight: FontWeight.w600)),
                                        ]),
                                        const SizedBox(height: 6),
                                        ...personnel.map((pp) {
                                          final u = pp['user'] as Map<String, dynamic>? ?? {};
                                          final name = '${u['first_name'] ?? ''} ${u['last_name'] ?? ''}'.trim();
                                          final isSup = pp['is_supervisor'] == true;
                                          return Padding(
                                            padding: const EdgeInsets.only(bottom: 4),
                                            child: Row(children: [
                                              Icon(
                                                isSup ? Icons.star : Icons.person_outline,
                                                size: 13,
                                                color: isSup ? AppTheme.warning : AppTheme.textSub,
                                              ),
                                              const SizedBox(width: 6),
                                              Text(
                                                name,
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  fontFamily: 'Inter',
                                                  fontWeight: isSup ? FontWeight.w600 : FontWeight.normal,
                                                ),
                                              ),
                                            ]),
                                          );
                                        }),
                                      ] else ...[
                                        const SizedBox(height: 6),
                                        Text(tr('Henüz personel atanmadı'), style: const TextStyle(fontSize: 12, fontFamily: 'Inter', color: AppTheme.textSub, fontStyle: FontStyle.italic)),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),

                  // Tab 3: Saha Günlüğü
                  _siteUpdates.isEmpty
                      ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                          const Icon(Icons.auto_stories_outlined, size: 48, color: AppTheme.textSub),
                          const SizedBox(height: 12),
                          Text(tr('Henüz saha bildirimi yok'), style: const TextStyle(color: AppTheme.textSub, fontFamily: 'Inter')),
                        ]))
                      : ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: _siteUpdates.length,
                          itemBuilder: (_, i) {
                            final u = _siteUpdates[i];
                            final user = u['user'] as Map<String, dynamic>? ?? {};
                            final userName = '${user['first_name'] ?? ''} ${user['last_name'] ?? ''}'.trim();
                            final date = u['created_at'] != null ? DateTime.parse(u['created_at']).toLocal() : null;
                            
                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(children: [
                                      CircleAvatar(
                                        radius: 12,
                                        backgroundColor: AppTheme.primary.withOpacity(0.1),
                                        child: Text(userName.isNotEmpty ? userName[0].toUpperCase() : '?', 
                                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.primary)),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(child: Text(userName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, fontFamily: 'Inter'))),
                                      if (date != null)
                                        Text('${date.day}/${date.month} ${date.hour}:${date.minute.toString().padLeft(2, '0')}', 
                                          style: const TextStyle(color: AppTheme.textSub, fontSize: 11, fontFamily: 'Inter')),
                                    ]),
                                    const SizedBox(height: 8),
                                    if ((u['description'] ?? '').isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(bottom: 8),
                                        child: Text(u['description'], style: const TextStyle(fontSize: 13, fontFamily: 'Inter')),
                                      ),
                                    if (u['photo_url'] != null)
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Image.network(
                                          u['photo_url'],
                                          fit: BoxFit.cover,
                                          width: double.infinity,
                                          loadingBuilder: (context, child, loadingProgress) {
                                            if (loadingProgress == null) return child;
                                            return Container(
                                              height: 150,
                                              color: AppTheme.bg,
                                              child: const Center(child: CircularProgressIndicator()),
                                            );
                                          },
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                  // Tab 4: Belgeler
                  docs.isEmpty
                      ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                          const Icon(Icons.folder_open_outlined, size: 48, color: AppTheme.textSub),
                          const SizedBox(height: 12),
                          Text(tr('Belge yok'), style: const TextStyle(color: AppTheme.textSub, fontFamily: 'Inter')),
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
                  // Tab 5: Durum Geçmişi
                  history.isEmpty
                      ? Center(child: Text(tr('Geçmiş yok'), style: const TextStyle(color: AppTheme.textSub, fontFamily: 'Inter')))
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
  final bool isMasked;
  const _InfoRow(this.label, this.value, {this.isMasked = false});

  @override
  Widget build(BuildContext context) {
    if (value == null || value!.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 100, child: Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.textSub, fontFamily: 'Inter'))),
          Expanded(
            child: Text(
              isMasked ? '• • • • • •' : value!,
              style: TextStyle(
                fontSize: 13,
                fontFamily: 'Inter',
                color: isMasked ? AppTheme.textSub : AppTheme.textMain,
                fontStyle: isMasked ? FontStyle.italic : FontStyle.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

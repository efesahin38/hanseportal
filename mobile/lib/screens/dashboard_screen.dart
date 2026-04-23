import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../theme/web_utils.dart';
import '../providers/app_state.dart';
import '../services/supabase_service.dart';
import 'orders_screen.dart';
import 'reports_screen.dart';
import 'invoice_draft_detail_screen.dart';
import '../services/localization_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Map<String, int> _stats = {};
  List<Map<String, dynamic>> _recentOrders = [];
  List<Map<String, dynamic>> _pendingDrafts = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await context.read<AppState>().refreshProfile();
      _load();
    });
  }

  Future<void> _load() async {
    final appState = context.read<AppState>();
    try {
      final departmentId = !appState.canViewAllOrders ? appState.departmentId : null;

      final stats = await SupabaseService.getDashboardStats(
        appState.companyId,
        departmentId: departmentId,
      );

      final orders = await SupabaseService.getOrders(
        departmentId: departmentId,
      );

      List<Map<String, dynamic>> drafts = [];
      if (appState.isBuchhaltung || appState.isGeschaeftsfuehrer || appState.isBereichsleiter) {
        drafts = await SupabaseService.getInvoiceDrafts(
          serviceAreaIds: !appState.canViewAllOrders ? appState.serviceAreaIds : null,
          departmentId: departmentId,
        );
      }

      if (mounted) {
        setState(() {
          _stats = stats;
          _recentOrders = orders.take(5).toList();
          _pendingDrafts = drafts.take(3).toList();
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();

    return Scaffold(
      body: WebContentWrapper(
        padding: EdgeInsets.zero,
        child: RefreshIndicator(
          onRefresh: _load,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              // ── Premium Header ─────────────────────────────
              SliverToBoxAdapter(
                child: Container(
                  padding: EdgeInsets.fromLTRB(20, kIsWeb ? 24 : 60, 20, 30),
                  decoration: AppTheme.gradientBox().copyWith(
                    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${tr('Willkommen')}, ${appState.fullName.split(' ').first} 👋',
                                style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold, fontFamily: 'Poppins'),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Hanse Kollektiv Digital Management',
                                style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13),
                              ),
                            ],
                          ),
                          CircleAvatar(
                            backgroundColor: Colors.white.withOpacity(0.2),
                            child: const Icon(Icons.person, color: Colors.white),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      // Quick Stats Row
                      Row(
                        children: [
                          _QuickStat(label: tr('Aktive Aufträge'), value: '${_stats['activeOrders'] ?? 0}'),
                          const SizedBox(width: 12),
                          _QuickStat(label: tr('Heute'), value: '${_stats['todayPlans'] ?? 0}'),
                          const SizedBox(width: 12),
                          _QuickStat(label: tr('Bekleyen'), value: '${_stats['pendingDrafts'] ?? 0}'),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // ── Departman Klasörleri (Folders) ──────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(tr('Abteilungsordner'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textMain)),
                      const SizedBox(height: 16),
                      GridView.count(
                        crossAxisCount: WebUtils.gridColumns(context, mobile: 2, tablet: 3, desktop: 5),
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: 1.1,
                        children: [
                          if (appState.canViewAllOrders || appState.departmentId == 'dddddddd-1111-1111-1111-111111111111')
                            _FolderCard(
                              title: tr('Temizlik'),
                              subtitle: 'Gebäudereinigung',
                              icon: Icons.cleaning_services_outlined,
                              color: const Color(0xFF3B82F6),
                              manager: 'Sandra',
                              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => OrdersScreen(departmentId: 'dddddddd-1111-1111-1111-111111111111', initialStatus: (appState.isBuchhaltung || appState.isGeschaeftsfuehrer) ? 'completed' : null))).then((_) => _load()),
                            ),
                          if (appState.canViewAllOrders || appState.departmentId == 'dddddddd-2222-2222-2222-222222222222')
                            _FolderCard(
                              title: tr('Ray Servis'),
                              subtitle: 'Gleisbausicherung',
                              icon: Icons.railway_alert_outlined,
                              color: const Color(0xFFEF4444),
                              manager: 'Peter',
                              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => OrdersScreen(departmentId: 'dddddddd-2222-2222-2222-222222222222', initialStatus: (appState.isBuchhaltung || appState.isGeschaeftsfuehrer) ? 'completed' : null))).then((_) => _load()),
                            ),
                          if (appState.canViewAllOrders || appState.departmentId == 'dddddddd-3333-3333-3333-333333333333')
                            _FolderCard(
                              title: tr('Otel Servis'),
                              subtitle: 'Hotelservice',
                              icon: Icons.hotel_outlined,
                              color: const Color(0xFFF59E0B),
                              manager: 'Fatma',
                              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => OrdersScreen(departmentId: 'dddddddd-3333-3333-3333-333333333333', initialStatus: (appState.isBuchhaltung || appState.isGeschaeftsfuehrer) ? 'completed' : null))).then((_) => _load()),
                            ),
                          if (appState.canViewAllOrders || appState.departmentId == 'dddddddd-4444-4444-4444-444444444444')
                            _FolderCard(
                              title: tr('Personal'),
                              subtitle: 'Überlassung',
                              icon: Icons.people_outline,
                              color: const Color(0xFF10B981),
                              manager: 'Klaus',
                              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => OrdersScreen(departmentId: 'dddddddd-4444-4444-4444-444444444444', initialStatus: (appState.isBuchhaltung || appState.isGeschaeftsfuehrer) ? 'completed' : null))).then((_) => _load()),
                            ),
                          if (appState.canViewAllOrders || appState.departmentId == 'dddddddd-5555-5555-5555-555555555555')
                            _FolderCard(
                              title: tr('Verwaltung'),
                              subtitle: 'Verwaltung',
                              icon: Icons.admin_panel_settings_outlined,
                              color: const Color(0xFF6366F1),
                              manager: 'Martina',
                              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => OrdersScreen(departmentId: 'dddddddd-5555-5555-5555-555555555555', initialStatus: (appState.isBuchhaltung || appState.isGeschaeftsfuehrer) ? 'completed' : null))).then((_) => _load()),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // ── Bekleyen Taslak Faturalar ───────────────────
              if ((appState.isBuchhaltung || appState.isGeschaeftsfuehrer) && _pendingDrafts.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(tr('Bekleyen Taslak Faturalar'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textMain)),
                            TextButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ReportsScreen())), child: Text(tr('Alle'))),
                          ],
                        ),
                        ..._pendingDrafts.map((d) {
                          final order = d['order'];
                          final workReportsData = order != null ? order['work_reports'] : null;
                          final workReport = (workReportsData is List && workReportsData.isNotEmpty)
                              ? workReportsData[0]
                              : (workReportsData is Map<String, dynamic> ? workReportsData : null);
                          
                          double revenue = double.tryParse(d['total_amount']?.toString() ?? '0') ?? 0;
                          if (revenue == 0 && workReport != null) {
                            revenue = double.tryParse(workReport['total_revenue']?.toString() ?? '0') ?? 0;
                          }

                          double laborCost = 0;
                          double materialCost = 0;
                          if (workReport != null) {
                            laborCost = double.tryParse(workReport['estimated_labor_cost']?.toString() ?? '0') ?? 0;
                            materialCost = double.tryParse(workReport['estimated_material_cost']?.toString() ?? '0') ?? 0;
                          }

                          final profit = revenue - (laborCost + materialCost);

                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              dense: true,
                              leading: const Icon(Icons.receipt_long, color: AppTheme.warning, size: 20),
                              title: Text(d['draft_number'] ?? tr('Taslak'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, fontFamily: 'Inter')),
                              subtitle: Text(d['customer']?['name'] ?? '', style: const TextStyle(fontSize: 11)),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text('€ ${revenue.toStringAsFixed(2)}', style: const TextStyle(fontSize: 10, color: AppTheme.textSub)),
                                  Text('€ ${profit.toStringAsFixed(2)}', 
                                    style: TextStyle(fontWeight: FontWeight.bold, color: profit >= 0 ? AppTheme.success : AppTheme.error, fontSize: 13)),
                                ],
                              ),
                              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => InvoiceDraftDetailScreen(draftId: d['id']))),
                            ),
                          );
                        }),
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
                ),

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(tr('Son Hareketler'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textMain)),
                      TextButton(onPressed: () {}, child: Text(tr('Alle'))),
                    ],
                  ),
                ),
              ),

              if (_loading)
                const SliverToBoxAdapter(child: Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator())))
              else if (_recentOrders.isEmpty)
                SliverToBoxAdapter(child: Center(child: Padding(padding: const EdgeInsets.all(40), child: Text(tr('Noch keine Aktivitäten vorhanden')))))
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (ctx, i) => _ActivityItem(order: _recentOrders[i]),
                    childCount: _recentOrders.length,
                  ),
                ),

              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickStat extends StatelessWidget {
  final String label;
  final String value;
  const _QuickStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: AppTheme.glassBox(),
        child: Column(
          children: [
            Text(value, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            Text(label, style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

class _FolderCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String manager;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _FolderCard({required this.title, required this.subtitle, required this.manager, required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppTheme.divider),
          boxShadow: [BoxShadow(color: color.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: color, size: 28),
            ),
            const Spacer(),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.textMain)),
            Text(subtitle, style: const TextStyle(fontSize: 10, color: AppTheme.textSub)),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.person_pin, size: 12, color: AppTheme.textSub),
                const SizedBox(width: 4),
                Text(manager, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.textSub)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ActivityItem extends StatelessWidget {
  final Map<String, dynamic> order;
  const _ActivityItem({required this.order});

  @override
  Widget build(BuildContext context) {
    final status = order['status'] ?? '';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: [
          Container(
            width: 12, height: 12,
            decoration: BoxDecoration(color: AppTheme.statusColor(status), shape: BoxShape.circle),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(order['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                Text(order['customer']?['name'] ?? '', style: const TextStyle(fontSize: 12, color: AppTheme.textSub)),
              ],
            ),
          ),
          if (status == 'completed' && (context.read<AppState>().isBuchhaltung || context.read<AppState>().isGeschaeftsfuehrer))
            TextButton(
              onPressed: () async {
                try {
                  await SupabaseService.markOrderAsInvoiced(order['id'], context.read<AppState>().userId);
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('Fakturiert und zur Historie hinzugefügt.'))));
                  Navigator.push(context, MaterialPageRoute(builder: (_) => ReportsScreen()));
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${tr('Fehler')}: $e')));
                }
              },
              style: TextButton.styleFrom(backgroundColor: Colors.green.withOpacity(0.1), minimumSize: Size.zero, padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6)),
              child: Text(tr('Fakturieren'), style: const TextStyle(color: Colors.green, fontSize: 11, fontWeight: FontWeight.bold)),
            )
          else
            Text(AppTheme.statusLabel(status), style: TextStyle(fontSize: 11, color: AppTheme.statusColor(status), fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const _StatCard({required this.label, required this.value, required this.icon, required this.color, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.divider),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const Spacer(),
            Text(value, style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: color, fontFamily: 'Inter')),
            Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.textSub, fontFamily: 'Inter')),
          ],
        ),
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final Map<String, dynamic> order;
  const _OrderCard({required this.order});

  @override
  Widget build(BuildContext context) {
    final status = order['status'] ?? '';
    final customer = order['customer'];
    return Card(
      child: ListTile(
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: AppTheme.statusColor(status).withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(Icons.work_outline, color: AppTheme.statusColor(status), size: 20),
        ),
        title: Text(order['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, fontFamily: 'Inter'),
            maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(customer?['name'] ?? '', style: const TextStyle(fontSize: 12, color: AppTheme.textSub, fontFamily: 'Inter')),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: AppTheme.statusColor(status).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            AppTheme.statusLabel(status),
            style: TextStyle(fontSize: 11, color: AppTheme.statusColor(status), fontWeight: FontWeight.w600, fontFamily: 'Inter'),
          ),
        ),
      ),
    );
  }
}

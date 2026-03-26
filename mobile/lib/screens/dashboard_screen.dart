import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../providers/app_state.dart';
import '../services/supabase_service.dart';
import 'orders_screen.dart';
import 'planning_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Map<String, int> _stats = {};
  List<Map<String, dynamic>> _recentOrders = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final appState = context.read<AppState>();
    try {
      final stats = await SupabaseService.getDashboardStats(appState.companyId);
      final orders = await SupabaseService.getOrders();
      if (mounted) {
        setState(() {
          _stats = stats;
          _recentOrders = orders.take(5).toList();
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

    return RefreshIndicator(
      onRefresh: _load,
      child: CustomScrollView(
        slivers: [
          // ── Karşılama Başlığı ────────────────────────────
          SliverToBoxAdapter(
            child: Container(
              decoration: AppTheme.gradientBox(),
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Merhaba, ${appState.fullName.split(' ').first} 👋',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Inter',
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    AppTheme.roleLabel(appState.role),
                    style: const TextStyle(color: Colors.white70, fontSize: 14, fontFamily: 'Inter'),
                  ),
                ],
              ),
            ),
          ),

          // ── İstatistik Kartları ──────────────────────────
          SliverToBoxAdapter(
            child: Transform.translate(
              offset: const Offset(0, -16),
              child: _loading
                  ? const Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 1.4,
                        children: [
                          _StatCard(
                            label: 'Aktif İşler',
                            value: '${_stats['activeOrders'] ?? 0}',
                            icon: Icons.work,
                            color: AppTheme.primary,
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const OrdersScreen())),
                          ),
                          _StatCard(
                            label: 'Bugünkü Planlar',
                            value: '${_stats['todayPlans'] ?? 0}',
                            icon: Icons.calendar_today,
                            color: AppTheme.accent,
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PlanningScreen())),
                          ),
                          _StatCard(
                            label: 'Aktif Personel',
                            value: '${_stats['activePersonnel'] ?? 0}',
                            icon: Icons.people,
                            color: AppTheme.success,
                          ),
                          _StatCard(
                            label: 'Bekleyen Taslak',
                            value: '${_stats['pendingDrafts'] ?? 0}',
                            icon: Icons.receipt_long,
                            color: AppTheme.warning,
                          ),
                        ],
                      ),
                    ),
            ),
          ),

          // ── Son İşler ────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Son İşler', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'Inter')),
                  TextButton(
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const OrdersScreen())),
                    child: const Text('Tümü', style: TextStyle(fontFamily: 'Inter')),
                  ),
                ],
              ),
            ),
          ),

          if (_recentOrders.isEmpty && !_loading)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.work_off_outlined, size: 48, color: AppTheme.textSub),
                      SizedBox(height: 12),
                      Text('Henüz iş kaydı bulunmuyor', style: TextStyle(color: AppTheme.textSub, fontFamily: 'Inter')),
                    ],
                  ),
                ),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (ctx, i) => _OrderCard(order: _recentOrders[i]),
                childCount: _recentOrders.length,
              ),
            ),

          const SliverToBoxAdapter(child: SizedBox(height: 24)),
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

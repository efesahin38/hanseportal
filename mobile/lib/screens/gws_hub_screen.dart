import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../theme/web_utils.dart';
import '../providers/app_state.dart';
import '../services/supabase_service.dart';
import '../services/localization_service.dart';
import 'gws_tagesplan_screen.dart';
import 'gws_shop_screen.dart';
import 'gws_control_center_screen.dart';
import 'gws_operative_view_screen.dart';
import 'orders_screen.dart';

/// Gastwirtschaftsservice Ana Hub Ekranı – Mor temali
/// Fatma'nın (Bereichsleiter-GWS) ana çalışma alanı.
class GwsHubScreen extends StatefulWidget {
  final String? departmentId;
  const GwsHubScreen({super.key, this.departmentId});
  @override
  State<GwsHubScreen> createState() => _GwsHubScreenState();
}

class _GwsHubScreenState extends State<GwsHubScreen> {
  static const Color _color = AppTheme.gwsColor;

  List<Map<String, dynamic>> _todayPlans = [];
  List<Map<String, dynamic>> _objects = [];
  bool _loading = true;
  int _openShopOrders = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final today = DateTime.now();
      final plans = await SupabaseService.getGwsDailyPlans(date: today);
      final objects = await SupabaseService.getCustomers(departmentId: widget.departmentId);
      final shopOrders = await SupabaseService.getGwsShopOrders(status: 'bestellt');
      if (mounted) setState(() {
        _todayPlans = plans;
        _objects = objects.take(10).toList();
        _openShopOrders = shopOrders.length;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: AppBar(
        backgroundColor: _color,
        title: const Text('🏨 Gastwirtschaftsservice', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold)),
        leading: const BackButton(),
        actions: [
          IconButton(icon: const Icon(Icons.home_outlined), tooltip: 'Zur Startseite', onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst)),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _color,
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => GwsTagesplanScreen(departmentId: widget.departmentId, objects: _objects))),
        icon: const Icon(Icons.add),
        label: const Text('Neuer Tagesplan', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold)),
      ),
      body: WebContentWrapper(
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildHeader(),
              const SizedBox(height: 20),
              _buildKPIRow(),
              const SizedBox(height: 20),
              _buildQuickActions(context),
              const SizedBox(height: 20),
              _buildTodayPlans(context),
              const SizedBox(height: 20),
              _buildObjectsList(context),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_color, const Color(0xFF5B21B6)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: _color.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 8))],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(16)),
            child: const Icon(Icons.hotel, color: Colors.white, size: 32),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Gastwirtschaftsservice', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold, fontFamily: 'Inter')),
                const SizedBox(height: 4),
                Text('${DateTime.now().day}.${DateTime.now().month}.${DateTime.now().year}', style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13, fontFamily: 'Inter')),
                const SizedBox(height: 2),
                const Text('Bereichsleitung: Fatma', style: TextStyle(color: Colors.white70, fontSize: 12, fontFamily: 'Inter')),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKPIRow() {
    return Row(
      children: [
        _KpiCard(label: 'Heutige\nTagespläne', value: '${_todayPlans.length}', icon: Icons.today, color: _color),
        const SizedBox(width: 12),
        _KpiCard(label: 'Aktive\nObjekte', value: '${_objects.length}', icon: Icons.hotel_outlined, color: const Color(0xFF5B21B6)),
        const SizedBox(width: 12),
        _KpiCard(label: 'Shop\nBestellungen', value: '$_openShopOrders', icon: Icons.shopping_cart_outlined, color: _openShopOrders > 0 ? Colors.orange : AppTheme.textSub),
      ],
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Schnellzugriff', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textMain, fontFamily: 'Inter')),
        const SizedBox(height: 12),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 2.2,
          children: [
            _QuickAction(
              icon: Icons.calendar_today,
              label: 'Tagesplanung',
              color: _color,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => GwsTagesplanScreen(departmentId: widget.departmentId, objects: _objects))),
            ),
            _QuickAction(
              icon: Icons.shopping_cart_outlined,
              label: 'Shop / Bestellungen',
              color: Colors.orange,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => GwsShopScreen(objects: _objects))),
            ),
            _QuickAction(
              icon: Icons.work_outline,
              label: 'Aufträge',
              color: AppTheme.primary,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => OrdersScreen(departmentId: widget.departmentId, customTitle: '🏨 Gastwirtschaftsservice'))),
            ),
            _QuickAction(
              icon: Icons.check_circle_outline,
              label: 'Freigaben',
              color: AppTheme.success,
              onTap: () {
                final title = 'Freigaben';
                if (title == 'Freigabe-Center') {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const GwsControlCenterScreen()));
                } else if (title == 'Zimmerliste') {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const GwsOperativeViewScreen()));
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$title – folgt in Kürze')));
                }
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTodayPlans(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Heutige Tagespläne', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textMain, fontFamily: 'Inter')),
            TextButton.icon(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => GwsTagesplanScreen(departmentId: widget.departmentId, objects: _objects))),
              icon: Icon(Icons.add_circle_outline, color: _color, size: 18),
              label: Text('Neu', style: TextStyle(color: _color, fontFamily: 'Inter')),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_todayPlans.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.divider),
            ),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.event_note_outlined, size: 40, color: _color.withOpacity(0.3)),
                  const SizedBox(height: 8),
                  const Text('Kein Tagesplan für heute', style: TextStyle(color: AppTheme.textSub, fontFamily: 'Inter')),
                ],
              ),
            ),
          )
        else
          ...(_todayPlans.map((plan) => InkWell(
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => GwsTagesplanScreen(
                planId: plan['id'],
                objects: const [], // Will be loaded by the screen
              ))).then((_) => _load());
            },
            borderRadius: BorderRadius.circular(14),
            child: _PlanCard(plan: plan, color: _color),
          ))),
      ],
    );
  }

  Widget _buildObjectsList(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Aktive Objekte (Kunden)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textMain, fontFamily: 'Inter')),
        const SizedBox(height: 8),
        if (_objects.isEmpty)
          const Text('Keine Objekte zugewiesen', style: TextStyle(color: AppTheme.textSub, fontFamily: 'Inter'))
        else
          ...(_objects.map((obj) => InkWell(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => GwsTagesplanScreen(
              departmentId: widget.departmentId, 
              objects: _objects,
            ))).then((_) => _load()),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.divider),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: _color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                    child: Icon(Icons.hotel_outlined, color: _color, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(obj['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontFamily: 'Inter', fontSize: 14)),
                        if (obj['address'] != null) Text(obj['address'], style: const TextStyle(color: AppTheme.textSub, fontSize: 12, fontFamily: 'Inter'), maxLines: 1, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: _color.withOpacity(0.5)),
                ],
              ),
            ),
          ))),
      ],
    );
  }
}

class _KpiCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _KpiCard({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.divider),
          boxShadow: [BoxShadow(color: color.withOpacity(0.08), blurRadius: 8, offset: const Offset(0, 3))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 8),
            Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color, fontFamily: 'Inter')),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.textSub, fontFamily: 'Inter'), maxLines: 2),
          ],
        ),
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _QuickAction({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.3)),
          boxShadow: [BoxShadow(color: color.withOpacity(0.08), blurRadius: 8, offset: const Offset(0, 3))],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(label, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: color, fontFamily: 'Inter'), maxLines: 2)),
          ],
        ),
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  final Map<String, dynamic> plan;
  final Color color;
  const _PlanCard({required this.plan, required this.color});

  String _statusLabel(String? s) {
    switch (s) {
      case 'draft': return 'Entwurf';
      case 'released': return 'Freigegeben';
      case 'in_progress': return 'In Durchführung';
      case 'completed': return 'Abgeschlossen';
      default: return s ?? 'Entwurf';
    }
  }

  @override
  Widget build(BuildContext context) {
    final obj = plan['object'] as Map<String, dynamic>?;
    final rooms = (plan['rooms'] as List?)?.length ?? 0;
    final areas = (plan['areas'] as List?)?.length ?? 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.3)),
        boxShadow: [BoxShadow(color: color.withOpacity(0.08), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
            child: Icon(Icons.today, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(obj?['name'] ?? 'Objekt', style: const TextStyle(fontWeight: FontWeight.w600, fontFamily: 'Inter', fontSize: 14)),
                Text('$rooms Zimmer · $areas Bereiche', style: const TextStyle(color: AppTheme.textSub, fontSize: 12, fontFamily: 'Inter')),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
            child: Text(_statusLabel(plan['status']), style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600, fontFamily: 'Inter')),
          ),
        ],
      ),
    );
  }
}

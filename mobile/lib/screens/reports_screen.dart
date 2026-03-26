import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../providers/app_state.dart';
import '../services/supabase_service.dart';
import 'invoice_draft_detail_screen.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabs;
  List<Map<String, dynamic>> _invoiceDrafts = [];
  Map<String, dynamic> _accountingSummary = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this)
      ..addListener(() { if (mounted) setState(() {}); });
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final drafts = await SupabaseService.getInvoiceDrafts();
      final summary = await SupabaseService.getAccountingSummary();
      if (mounted) setState(() { _invoiceDrafts = drafts; _accountingSummary = summary; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabs,
              labelStyle: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600, fontSize: 13),
              unselectedLabelStyle: const TextStyle(fontFamily: 'Inter', fontSize: 13),
              tabs: const [
                Tab(text: 'Ön Fatura Taslakları'),
                Tab(text: 'Muhasebe Özeti'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                _InvoiceDraftTab(drafts: _invoiceDrafts, loading: _loading, onRefresh: _load),
                _AccountingSummaryTab(summary: _accountingSummary, loading: _loading),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Ön Fatura Taslakları ─────────────────────────────────────
class _InvoiceDraftTab extends StatelessWidget {
  final List<Map<String, dynamic>> drafts;
  final bool loading;
  final Future<void> Function() onRefresh;

  const _InvoiceDraftTab({required this.drafts, required this.loading, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    if (drafts.isEmpty) {
      return const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.receipt_long_outlined, size: 56, color: AppTheme.textSub),
        SizedBox(height: 12),
        Text('Ön fatura taslağı yok', style: TextStyle(color: AppTheme.textSub, fontFamily: 'Inter')),
      ]));
    }
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: drafts.length,
        itemBuilder: (_, i) {
          final d = drafts[i];
          final status = d['status'] ?? 'auto_generated';
          final customer = d['customer'];
          final total = d['total_amount'];
          final issuer = d['issuing_company'];

          return Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(d['draft_number'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, fontFamily: 'Inter')),
                      ),
                      _DraftStatusChip(status: status),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(customer?['name'] ?? '', style: const TextStyle(fontSize: 14, fontFamily: 'Inter')),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(issuer?['short_name'] ?? '', style: const TextStyle(fontSize: 12, color: AppTheme.textSub, fontFamily: 'Inter')),
                      if (total != null)
                        Text(
                          '${double.tryParse(total.toString())?.toStringAsFixed(2) ?? total} €',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.primary, fontFamily: 'Inter'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => InvoiceDraftDetailScreen(draftId: d['id'])),
                        ).then((_) => onRefresh()),
                        icon: const Icon(Icons.visibility_outlined, size: 16),
                        label: const Text('İncele', style: TextStyle(fontFamily: 'Inter', fontSize: 12)),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          minimumSize: Size.zero,
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (status == 'auto_generated' || status == 'under_review')
                        OutlinedButton.icon(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => InvoiceDraftDetailScreen(draftId: d['id'])),
                          ).then((_) => onRefresh()),
                          icon: const Icon(Icons.check_circle_outline, size: 16),
                          label: const Text('Onayla', style: TextStyle(fontFamily: 'Inter', fontSize: 12)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.success,
                            side: const BorderSide(color: AppTheme.success),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            minimumSize: Size.zero,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _DraftStatusChip extends StatelessWidget {
  final String status;
  const _DraftStatusChip({required this.status});

  String get label {
    switch (status) {
      case 'auto_generated':    return 'Oluşturuldu';
      case 'under_review':      return 'İncelemede';
      case 'correction_needed': return 'Düzeltme';
      case 'approved':          return 'Onaylandı';
      case 'invoiced':          return 'Faturalandı';
      case 'cancelled':         return 'İptal';
      default:                  return status;
    }
  }

  Color get color {
    switch (status) {
      case 'auto_generated':    return AppTheme.info;
      case 'under_review':      return AppTheme.warning;
      case 'correction_needed': return AppTheme.error;
      case 'approved':          return AppTheme.success;
      case 'invoiced':          return Colors.teal;
      default:                  return AppTheme.textSub;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
      child: Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600, fontFamily: 'Inter')),
    );
  }
}

// ── Muhasebe Özeti ────────────────────────────────────────────
class _AccountingSummaryTab extends StatelessWidget {
  final Map<String, dynamic> summary;
  final bool loading;
  const _AccountingSummaryTab({required this.summary, required this.loading});

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    final invoicedTotal = (summary['invoiced_total'] as num?)?.toDouble() ?? 0.0;
    final pendingTotal  = (summary['pending_total'] as num?)?.toDouble() ?? 0.0;
    final completedOrders = summary['completed_orders'] as int? ?? 0;
    final pendingDrafts   = summary['pending_drafts'] as int? ?? 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Bu Ay', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'Inter')),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _SummaryCard(label: 'Faturalanan', value: '${invoicedTotal.toStringAsFixed(2)} €', color: AppTheme.success, icon: Icons.trending_up)),
              const SizedBox(width: 12),
              Expanded(child: _SummaryCard(label: 'Bekleyen', value: '${pendingTotal.toStringAsFixed(2)} €', color: AppTheme.warning, icon: Icons.hourglass_empty)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _SummaryCard(label: 'Tamamlanan İş', value: '$completedOrders', color: AppTheme.primary, icon: Icons.work_outline)),
              const SizedBox(width: 12),
              Expanded(child: _SummaryCard(label: 'Taslak Bekliyor', value: '$pendingDrafts', color: AppTheme.info, icon: Icons.receipt_outlined)),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;
  const _SummaryCard({required this.label, required this.value, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(height: 8),
        Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color, fontFamily: 'Inter')),
        Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.textSub, fontFamily: 'Inter')),
      ]),
    );
  }
}

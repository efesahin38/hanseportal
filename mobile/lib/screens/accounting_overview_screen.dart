import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../theme/web_utils.dart';
import '../providers/app_state.dart';
import '../services/supabase_service.dart';
import 'package:intl/intl.dart';
import '../services/pdf_service.dart';
import 'invoice_draft_detail_screen.dart';
import 'work_report_screen.dart';
import 'reports_screen.dart';
import '../services/localization_service.dart';

class AccountingOverviewScreen extends StatefulWidget {
  const AccountingOverviewScreen({super.key});

  @override
  State<AccountingOverviewScreen> createState() => _AccountingOverviewScreenState();
}

class _AccountingOverviewScreenState extends State<AccountingOverviewScreen> {
  Map<String, List<Map<String, dynamic>>> _groupedSessions = {};
  Map<String, Map<String, dynamic>> _workReports = {}; // orderId -> work_report
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final appState = context.read<AppState>();

    // Bereichsleiter darf Buchhaltung NIEMALS sehen
    if (appState.isBereichsleiter) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    try {
      // 1. Fetch approved sessions (can be many per project)
      final approvedSessions = await SupabaseService.getApprovedWorkSessionsForAccounting(
        serviceAreaIds: null,
        departmentId: null,
      );
      
      // 2. Fetch projects that are in financial phases (completed, invoiced)
      // This catches projects even if sessions aren't currently "active" in the filter.
      final pastOrdersQuery = await SupabaseService.client.from('orders').select('''
        *,
        customer:customers!orders_customer_id_fkey(id, name),
        invoice_drafts(total_amount, subtotal),
        extra_works(estimated_material_cost, estimated_labor_cost, recorded_material_cost, recorded_labor_cost),
        work_reports(total_revenue, estimated_labor_cost, estimated_material_cost, actual_labor_cost, actual_material_cost),
        work_sessions(id, actual_start, approved_billable_hours, approved_at, approval_status, user:users(id, first_name, last_name))
      ''').inFilter('status', ['completed', 'invoiced']).order('created_at', ascending: false);

      final List<dynamic> pastOrders = pastOrdersQuery;
      Map<String, List<Map<String, dynamic>>> groups = {};
      
      // Add projects from approved sessions
      for (var s in approvedSessions) {
        final orderId = s['order_id']?.toString();
        if (orderId == null) continue;
        groups.putIfAbsent(orderId, () => []).add(s);
      }

      // Add projects from past orders (if not already there)
      for (var o in pastOrders) {
        final orderId = o['id'].toString();
        if (!groups.containsKey(orderId)) {
          // Use sessions from the project if available
          final sessions = List<Map<String, dynamic>>.from(o['work_sessions'] ?? []);
          // Normalize sessions to match expected structure if needed
          final normalized = sessions.map((s) => {
             ...s,
             'order_id': orderId,
             'order': o,
          }).toList();
          groups[orderId] = normalized;
        }
      }

      if (mounted) {
        setState(() {
          _groupedSessions = groups;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Accounting load error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();

    // Bereichsleiter – kein Zugang zur Buchhaltung
    if (appState.isBereichsleiter) {
      return Scaffold(
        appBar: AppBar(title: Text(tr('Buchhaltung'))),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_outline, size: 64, color: Color(0xFFCBD5E1)),
              const SizedBox(height: 16),
              Text(
                tr('Kein Zugriff'),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 8),
              Text(
                tr('Sie haben keine Berechtigung, diese Seite zu sehen.'),
                style: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(tr('Mali Proje Analizi'), style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Inter')),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: WebContentWrapper(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _buildDailySummary(),
                    const SizedBox(height: 24),
                    Text(tr('Proje Bazlı Analiz'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'Inter')),
                    const SizedBox(height: 12),
                    if (_groupedSessions.isEmpty)
                      _buildEmptyState()
                    else
                      ..._groupedSessions.keys.map((key) {
                        final projectSessions = _groupedSessions[key]!;
                        final workReport = _workReports[key];
                        return _ProjectFinancialCard(
                          sessions: projectSessions,
                          workReport: workReport,
                        );
                      }),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildDailySummary() {
    double todayIncome = 0;
    double todayLaborCost = 0;
    double todayMaterialCost = 0;
    int todayDrafts = 0;

    // Proje bazlı bilgileri topla (bugüne ait)
    List<Map<String, dynamic>> todayProjects = [];

    final now = DateTime.now();
    final todayStr = DateFormat('yyyy-MM-dd').format(now);

    for (var entry in _groupedSessions.entries) {
      final group = entry.value;
      final orderId = entry.key;
      final first = group.first;
      final order = first['order'];
      final drafts = order['invoice_drafts'] as List?;
      final extraWorks = order['extra_works'] as List?;
      final workReport = _workReports[orderId];
      
      // Bugün onaylanmış oturumları bul
      bool hasToday = false;
      double projectLaborToday = 0;
      
      for (var s in group) {
        if (s['approved_at'] != null && s['approved_at'].toString().startsWith(todayStr)) {
          hasToday = true;
          final hrs = (s['approved_billable_hours'] as num?)?.toDouble() ?? 0;
          projectLaborToday += (hrs * 25.0);
        }
      }

      if (hasToday) {
        // Gelir
        double projectIncome = 0;
        if (drafts != null && drafts.isNotEmpty) {
          todayDrafts++;
        }

        if (workReport != null && workReport['total_revenue'] != null && (workReport['total_revenue'] as num) > 0) {
          projectIncome = (workReport['total_revenue'] as num).toDouble();
        } else if (drafts != null && drafts.isNotEmpty) {
          projectIncome = (drafts.first['total_amount'] as num?)?.toDouble() ?? 0;
        }

        // Gider: Work report varsa onu kullan, yoksa fallback
        double projectLabor = 0;
        double projectMaterial = 0;

        if (workReport != null) {
          projectLabor = (workReport['estimated_labor_cost'] as num?)?.toDouble() ?? 0;
          projectMaterial = (workReport['estimated_material_cost'] as num?)?.toDouble() ?? 0;
        } else {
          projectLabor = 0; // Fallback labor removed
          if (extraWorks != null) {
            for (var ew in extraWorks) {
              projectMaterial += (ew['estimated_material_cost'] as num?)?.toDouble() ?? 0;
            }
          }
        }

        todayIncome += projectIncome;
        todayLaborCost += projectLabor;
        todayMaterialCost += projectMaterial;

        todayProjects.add({
          'title': order['title'] ?? tr('Unbekannt'),
          'income': projectIncome,
          'labor': projectLabor,
          'material': projectMaterial,
        });
      }
    }

    final todayExpense = todayLaborCost + todayMaterialCost;
    final todayProfit = todayIncome - todayExpense;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF1E293B), Color(0xFF334155)]),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(tr('Bugünkü Finansal Özet'), style: const TextStyle(color: Colors.white70, fontSize: 13, fontFamily: 'Inter')),
          const SizedBox(height: 4),
          Text(DateFormat('dd MMMM yyyy', 'de_DE').format(now), style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Inter')),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _summaryItem(tr('Tahmini Gelir'), '€ ${todayIncome.toStringAsFixed(0)}', Colors.greenAccent),
              _summaryItem(tr('Tahmini Gider'), '€ ${todayExpense.toStringAsFixed(0)}', Colors.orangeAccent),
              _summaryItem(tr('Nettogewinn'), '€ ${todayProfit.toStringAsFixed(0)}', todayProfit >= 0 ? Colors.blueAccent : Colors.redAccent),
            ],
          ),

          // Bugünkü projelerin detaylı dökümü
          if (todayProjects.isNotEmpty) ...[
            const Divider(color: Colors.white10, height: 24),
            Text(tr('Bugünkü Proje Detayları'), style: const TextStyle(color: Colors.white54, fontSize: 11, fontFamily: 'Inter', fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ...todayProjects.map((p) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Expanded(child: Text(p['title'], style: const TextStyle(color: Colors.white60, fontSize: 11, fontFamily: 'Inter'), maxLines: 1, overflow: TextOverflow.ellipsis)),
                  Text('${tr('G')}:€${(p['income'] as double).toStringAsFixed(0)}', style: const TextStyle(color: Colors.greenAccent, fontSize: 10, fontFamily: 'Inter')),
                  const SizedBox(width: 8),
                  Text('${tr('Gd')}:€${((p['labor'] as double) + (p['material'] as double)).toStringAsFixed(0)}', style: const TextStyle(color: Colors.orangeAccent, fontSize: 10, fontFamily: 'Inter')),
                  const SizedBox(width: 8),
                  Text('${tr('K')}:€${((p['income'] as double) - (p['labor'] as double) - (p['material'] as double)).toStringAsFixed(0)}', style: TextStyle(color: ((p['income'] as double) - (p['labor'] as double) - (p['material'] as double)) >= 0 ? Colors.blueAccent : Colors.redAccent, fontSize: 10, fontFamily: 'Inter', fontWeight: FontWeight.bold)),
                ],
              ),
            )),
          ],

          const Divider(color: Colors.white10, height: 24),
          Row(
            children: [
              const Icon(Icons.receipt_long, color: Colors.white54, size: 16),
              const SizedBox(width: 8),
              Text(tr('Bugün {count} yeni fatura taslağı oluşturuldu.', args: {'count': todayDrafts.toString()}), style: const TextStyle(color: Colors.white54, fontSize: 12, fontFamily: 'Inter')),
            ],
          ),
          if (todayLaborCost > 0 || todayMaterialCost > 0) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.monetization_on_outlined, color: Colors.white38, size: 14),
                const SizedBox(width: 8),
                Text(
                  '${tr('Lohnkosten')}: €${todayLaborCost.toStringAsFixed(0)} • ${tr('Materialkosten')}: €${todayMaterialCost.toStringAsFixed(0)}',
                  style: const TextStyle(color: Colors.white38, fontSize: 11, fontFamily: 'Inter'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _summaryItem(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11, fontFamily: 'Inter')),
        Text(value, style: TextStyle(color: color, fontSize: 19, fontWeight: FontWeight.bold, fontFamily: 'Inter')),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 80),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.blueGrey.withOpacity(0.05),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.account_balance_wallet_outlined, size: 64, color: AppTheme.textSub.withOpacity(0.3)),
            ),
            const SizedBox(height: 24),
            Text(
              tr('Henüz Analiz Edilecek Veri Yok'),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textMain, fontFamily: 'Inter'),
            ),
            const SizedBox(height: 8),
            Text(
              tr('Onaylanmış veya tamamlanmış işler burada listelenecektir.'),
              style: const TextStyle(color: AppTheme.textSub, fontFamily: 'Inter'),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ProjectFinancialCard extends StatelessWidget {
  final List<Map<String, dynamic>> sessions;
  final Map<String, dynamic>? workReport;
  const _ProjectFinancialCard({required this.sessions, this.workReport});

  @override
  Widget build(BuildContext context) {
    if (sessions.isEmpty) return const SizedBox.shrink();

    final first = sessions.first;
    final order = first['order'];
    final customer = order['customer'];
    final drafts = order['invoice_drafts'] as List?;
    final extraWorks = order['extra_works'] as List?;
    
    // GELİR (Income) - İş Sonu Raporundaki gerçek gelir veya Fatura taslağındaki tutar
    double totalIncome = 0;
    if (workReport != null && workReport!['total_revenue'] != null && (workReport!['total_revenue'] as num) > 0) {
      totalIncome = (workReport!['total_revenue'] as num).toDouble();
    } else if (drafts != null && drafts.isNotEmpty) {
      totalIncome = (drafts.first['total_amount'] as num?)?.toDouble() ?? 0;
    }

    // GİDER - Work report varsa gerçek verileri kullan, yoksa fallback
    double laborCost = 0;
    double materialCost = 0;

    if (workReport != null) {
      // Work report'taki gerçek girilen değerleri kullan
      laborCost = (workReport!['estimated_labor_cost'] as num?)?.toDouble() ?? 0;
      materialCost = (workReport!['estimated_material_cost'] as num?)?.toDouble() ?? 0;
    } else {
      // Sesiion fallback labor removed (now 0)
      if (extraWorks != null) {
        for (var ew in extraWorks) {
          materialCost += (ew['estimated_material_cost'] as num?)?.toDouble() ?? 0;
        }
      }
    }

    double totalExpense = laborCost + materialCost;
    double profit = totalIncome - totalExpense;
    double marginPercent = totalIncome > 0 ? (profit / totalIncome) * 100 : 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10)],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(order['title'] ?? tr('Unbenanntes Projekt'), 
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppTheme.primary)),
                    ),
                    StatefulBuilder(
                      builder: (context, setStateCard) {
                        final isAlreadyInvoiced = order['status'] == 'invoiced';
                        final canInvoice = (order['status'] == 'completed' || workReport != null) && !isAlreadyInvoiced;

                        return Row(
                          children: [
                            if (canInvoice)
                              GestureDetector(
                                onTap: () async {
                                  try {
                                    final orderId = order['id'];
                                    final userId = context.read<AppState>().userId;
                                    await SupabaseService.markOrderAsInvoiced(orderId, userId);
                                    if (!context.mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Faturalandırıldı ve geçmişe eklendi.')));
                                    
                                    setStateCard(() {
                                      order['status'] = 'invoiced';
                                    });
                                    
                                    Future.delayed(const Duration(milliseconds: 500), () {
                                      if (context.mounted) Navigator.push(context, MaterialPageRoute(builder: (_) => const ReportsScreen(initialIndex: 4)));
                                    });
                                  } catch(e) {
                                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
                                  }
                                },
                                child: Container(
                                  margin: const EdgeInsets.only(right: 8),
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(color: Colors.green.withOpacity(0.08), borderRadius: BorderRadius.circular(10)),
                                  child: Text(tr('Fakturieren'), style: const TextStyle(color: Colors.green, fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'Inter')),
                                ),
                              ),
                            if (isAlreadyInvoiced)
                              Container(
                                margin: const EdgeInsets.only(right: 8),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(color: Colors.grey.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
                                child: Text(tr('Faturalandırıldı'), style: const TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'Inter')),
                              ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(color: AppTheme.primary.withOpacity(0.08), borderRadius: BorderRadius.circular(10)),
                              child: Text(DateFormat('dd.MM.yyyy').format(DateTime.parse(sessions.first['actual_start'] ?? DateTime.now().toIso8601String()).toLocal()),
                                style: const TextStyle(color: AppTheme.primary, fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'Inter')),
                            ),
                          ],
                        );
                      }
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(customer?['name'] ?? '', style: const TextStyle(color: AppTheme.textSub, fontSize: 14)),
                const Divider(height: 24),
                
                // Finansal Özet Satırı
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _finItem(tr('Tahmini Gelir'), '€ ${totalIncome.toStringAsFixed(0)}', Colors.green),
                    _finItem(tr('Tahmini Gider'), '€ ${totalExpense.toStringAsFixed(0)}', Colors.redAccent),
                    _finItem(tr('Nettogewinn'), '€ ${profit.toStringAsFixed(0)}', profit >= 0 ? AppTheme.primary : AppTheme.error),
                  ],
                ),
                const SizedBox(height: 12),

                // Gider Detay Bilgisi
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8F9FA),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.divider),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(tr('Gider Dökümü'), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textSub, fontFamily: 'Inter')),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('${tr('Lohnkosten')}:', style: TextStyle(fontSize: 12, color: Colors.grey[700], fontFamily: 'Inter')),
                          Text('€ ${laborCost.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.deepOrange, fontFamily: 'Inter')),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('${tr('Malzeme Gideri')}:', style: TextStyle(fontSize: 12, color: Colors.grey[700], fontFamily: 'Inter')),
                          Text('€ ${materialCost.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.orange, fontFamily: 'Inter')),
                        ],
                      ),
                      if (workReport != null) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.verified_outlined, size: 12, color: AppTheme.success.withOpacity(0.7)),
                            const SizedBox(width: 4),
                            Text(tr('Aus dem Abschlussprotokoll entnommen'), style: TextStyle(fontSize: 9, color: AppTheme.success.withOpacity(0.7), fontFamily: 'Inter', fontStyle: FontStyle.italic)),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Kar Marjı
                if (totalIncome > 0) ...[
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: (marginPercent / 100).clamp(0, 1).toDouble(),
                            backgroundColor: AppTheme.divider,
                            color: marginPercent >= 30 ? AppTheme.success : marginPercent >= 10 ? AppTheme.warning : AppTheme.error,
                            minHeight: 6,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text('${marginPercent.toStringAsFixed(1)}%', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: marginPercent >= 30 ? AppTheme.success : marginPercent >= 10 ? AppTheme.warning : AppTheme.error)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(tr('Gewinnmarge'), style: TextStyle(fontSize: 10, color: AppTheme.textSub)),
                  const SizedBox(height: 12),
                ],
                
                Text(tr('Mitarbeiterdetail & Stunden'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textSub)),
                const SizedBox(height: 8),
                ...sessions.map((s) {
                  final user = s['user'];
                  final hrs = (s['approved_billable_hours'] as num?)?.toDouble() ?? 0;
                  final approvedAt = s['approved_at'] != null ? DateFormat('dd.MM HH:mm').format(DateTime.parse(s['approved_at']).toLocal()) : '--';
                  
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('${user['first_name']} ${user['last_name']}', style: const TextStyle(fontSize: 13)),
                        Text('${hrs.toStringAsFixed(1)} ${tr('sa')} • $approvedAt', 
                          style: const TextStyle(fontSize: 12, color: AppTheme.textSub, fontStyle: FontStyle.italic)),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
          
          // Action Footer
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFFF1F5F9),
              borderRadius: BorderRadius.only(bottomLeft: Radius.circular(16), bottomRight: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => WorkReportScreen(orderId: first['order_id']))),
                    icon: const Icon(Icons.analytics_outlined, size: 18),
                    label: Text(tr('Raporu Görüntüle'), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey, padding: const EdgeInsets.symmetric(vertical: 12)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final orderComplete = await SupabaseService.getOrder(first['order_id']);
                      final report = await SupabaseService.getWorkReport(first['order_id']);
                      final extraWorks = await SupabaseService.getExtraWorks(first['order_id']);
                      
                      if (orderComplete != null) {
                        final bytes = await PdfService.buildWorkReportPdf(
                          order: orderComplete,
                          report: report,
                          sessions: sessions,
                          extraWorks: extraWorks,
                        );
                        await PdfService.sharePdf(bytes, 'is_sonu_raporu_${orderComplete['order_number']}.pdf');
                      }
                    },
                    icon: const Icon(Icons.picture_as_pdf, size: 18),
                    label: Text(tr('PDF İndir'), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, padding: const EdgeInsets.symmetric(vertical: 12)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _finItem(String label, String value, Color color) => Expanded(
    child: Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.textSub)),
        Text(value, style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: color)),
      ],
    ),
  );
}

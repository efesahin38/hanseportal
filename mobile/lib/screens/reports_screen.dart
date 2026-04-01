import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../theme/web_utils.dart'; // WebUtils ekle
import '../providers/app_state.dart';
import '../services/supabase_service.dart';
import '../services/pdf_service.dart';
import 'package:intl/intl.dart';
import 'invoice_draft_detail_screen.dart';

class ReportsScreen extends StatefulWidget {
  final int initialIndex;
  const ReportsScreen({super.key, this.initialIndex = 0});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabs;
  List<Map<String, dynamic>> _invoiceDrafts = [];
  Map<String, dynamic> _accountingSummary = {};
  List<Map<String, dynamic>> _deptPerformance = [];
  bool _loading = true;
  String? _downloadingOrderId;

  @override
  void initState() {
    super.initState();
    _initTabs();
    _load();
  }

  void _initTabs() {
    final appState = context.read<AppState>();
    final canSeePersonnel = appState.isGeschaeftsfuehrer || appState.isBetriebsleiter || appState.isBuchhaltung || appState.isSystemAdmin;
    final count = canSeePersonnel ? 5 : 2;
    _tabs = TabController(length: count, vsync: this, initialIndex: widget.initialIndex < count ? widget.initialIndex : 0)
      ..addListener(() { if (mounted) setState(() {}); });
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final drafts = await SupabaseService.getInvoiceDrafts();
      final summary = await SupabaseService.getAccountingSummary();
      final performance = await SupabaseService.getDepartmentalPerformance();
      if (mounted) {
        setState(() {
          _invoiceDrafts = drafts;
          _accountingSummary = summary;
          _deptPerformance = performance;
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
    final canSeePersonnel = appState.isGeschaeftsfuehrer || appState.isBetriebsleiter || appState.isBuchhaltung || appState.isSystemAdmin;

    final tabs = <Tab>[
      const Tab(text: 'Muhasebe Özeti'),
      const Tab(text: 'Aylık Rapor'),
      if (canSeePersonnel) const Tab(text: 'Ön Fatura Taslakları'),
      if (canSeePersonnel) const Tab(text: 'Personel Saatleri'),
      if (canSeePersonnel) const Tab(text: 'Fatura Geçmişi'),
    ];

    final tabViews = <Widget>[
      _DailyAccountingSummaryTab(loading: _loading),
      _MonthlyReportTab(),
      if (canSeePersonnel) _InvoiceDraftTab(drafts: _invoiceDrafts, loading: _loading, onRefresh: _load),
      if (canSeePersonnel) _PersonnelHoursTab(),
      if (canSeePersonnel) _InvoiceHistoryTab(),
    ];

    // Ensure tab count matches exactly
    if (_tabs.length != tabs.length) {
      _tabs.dispose();
      _tabs = TabController(length: tabs.length, vsync: this)
        ..addListener(() { if (mounted) setState(() {}); });
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Raporlar ve Analizler'),
        centerTitle: false,
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.primary,
        elevation: 0,
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          labelColor: AppTheme.primary,
          unselectedLabelColor: AppTheme.textSub,
          indicatorColor: AppTheme.primary,
          tabs: tabs,
        ),
      ),
      body: WebContentWrapper(
        padding: EdgeInsets.zero,
        child: TabBarView(
          controller: _tabs,
          children: tabViews,
        ),
      ),
    );
  }
}

// ── 1) Ön Fatura Taslakları ─────────────────────────────────────
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

// ── 2) Muhasebe Özeti (Günlük) ────────────────────────────────────
class _DailyAccountingSummaryTab extends StatefulWidget {
  final bool loading;
  const _DailyAccountingSummaryTab({required this.loading});

  @override
  State<_DailyAccountingSummaryTab> createState() => _DailyAccountingSummaryTabState();
}

class _DailyAccountingSummaryTabState extends State<_DailyAccountingSummaryTab> {
  List<Map<String, dynamic>> _dailyData = [];
  bool _loadingData = true;

  @override
  void initState() {
    super.initState();
    _loadDailyData();
  }

  Future<void> _loadDailyData() async {
    setState(() => _loadingData = true);
    try {
      // Son 30 günlük veriyi çek
      final now = DateTime.now();
      final from = now.subtract(const Duration(days: 30));
      final dateFrom = DateFormat('yyyy-MM-dd').format(from);
      final dateTo = DateFormat('yyyy-MM-dd').format(now);

      final sessions = await SupabaseService.getApprovedSessionsByDateRange(
        dateFrom: dateFrom,
        dateTo: dateTo,
      );

      // Günlük gruplama
      Map<String, Map<String, dynamic>> dailyMap = {};

      for (var s in sessions) {
        final approvedAt = s['approved_at']?.toString() ?? '';
        if (approvedAt.isEmpty) continue;
        final dateKey = approvedAt.substring(0, 10); // yyyy-MM-dd

        if (!dailyMap.containsKey(dateKey)) {
          dailyMap[dateKey] = {
            'date': dateKey,
            'income': 0.0,
            'laborCost': 0.0,
            'materialCost': 0.0,
            'sessionCount': 0,
            'orderIds': <String>{},
          };
        }

        final day = dailyMap[dateKey]!;
        day['sessionCount'] = (day['sessionCount'] as int) + 1;

        // Fallback labor removed
        final fallbackLabor = 0.0;

        final order = s['order'];
        if (order != null) {
          final orderId = order['id'] ?? '';
          final orderIds = day['orderIds'] as Set<String>;
          if (!orderIds.contains(orderId) && orderId.isNotEmpty) {
            orderIds.add(orderId);
            // Gelir ve Gideri sadece bir kere say
            final reportsRaw = order['work_reports'];
            Map<String, dynamic>? wReport;
            if (reportsRaw is List && reportsRaw.isNotEmpty) wReport = reportsRaw.first;
            else if (reportsRaw is Map) wReport = Map<String, dynamic>.from(reportsRaw);

            // GELİR
            double rev = 0;
            if (wReport != null && (wReport['total_revenue'] as num? ?? 0) > 0) {
              rev = (wReport['total_revenue'] as num).toDouble();
            } else {
              final drafts = order['invoice_drafts'] as List?;
              if (drafts != null && drafts.isNotEmpty) {
                rev = (drafts.first['total_amount'] as num?)?.toDouble() ?? 0;
              }
            }
            day['income'] = (day['income'] as double) + rev;

            // GİDER (İşçilik)
            double labor = 0;
            if (wReport != null && (wReport['estimated_labor_cost'] as num? ?? 0) > 0) {
              labor = (wReport['estimated_labor_cost'] as num).toDouble();
            } else {
              labor = fallbackLabor;
            }
            day['laborCost'] = (day['laborCost'] as double) + labor;

            // GİDER (Malzeme)
            double material = 0;
            if (wReport != null && (wReport['estimated_material_cost'] as num? ?? 0) > 0) {
              material = (wReport['estimated_material_cost'] as num).toDouble();
            } else {
              final extras = order['extra_works'] as List?;
              if (extras != null) {
                for (var ew in extras) {
                  material += (ew['estimated_material_cost'] as num?)?.toDouble() ?? 0;
                }
              }
            }
            day['materialCost'] = (day['materialCost'] as double) + material;
          }
        }
      }

      // Listeye çevir ve tarihe göre sırala (yeniden eskiye)
      final dailyList = dailyMap.values.toList()
        ..sort((a, b) => (b['date'] as String).compareTo(a['date'] as String));

      setState(() {
        _dailyData = dailyList;
        _loadingData = false;
      });
    } catch (e) {
      if (mounted) setState(() => _loadingData = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingData) return const Center(child: CircularProgressIndicator());
    if (_dailyData.isEmpty) {
      return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.calendar_today_outlined, size: 56, color: AppTheme.textSub.withOpacity(0.5)),
          const SizedBox(height: 16),
          const Text('Günlük finansal veri bulunamadı', style: TextStyle(color: AppTheme.textSub, fontFamily: 'Inter')),
          const SizedBox(height: 8),
          const Text('Son 30 gün içinde onaylı çalışma seansı yok', style: TextStyle(color: AppTheme.textSub, fontSize: 12, fontFamily: 'Inter')),
        ]),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadDailyData,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _dailyData.length + 1,
        itemBuilder: (ctx, i) {
          if (i == 0) {
            // Toplam özet header
            double totalIncome = 0, totalExpense = 0;
            for (var d in _dailyData) {
              totalIncome += (d['income'] as double);
              totalExpense += (d['laborCost'] as double) + (d['materialCost'] as double);
            }
            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF1E293B), Color(0xFF334155)]),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Son 30 Gün Özeti', style: TextStyle(color: Colors.white70, fontSize: 12, fontFamily: 'Inter')),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text('Gelir', style: TextStyle(color: Colors.white54, fontSize: 11)),
                        Text('€ ${totalIncome.toStringAsFixed(0)}', style: const TextStyle(color: Colors.greenAccent, fontSize: 18, fontWeight: FontWeight.bold)),
                      ]),
                      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text('Gider', style: TextStyle(color: Colors.white54, fontSize: 11)),
                        Text('€ ${totalExpense.toStringAsFixed(0)}', style: const TextStyle(color: Colors.orangeAccent, fontSize: 18, fontWeight: FontWeight.bold)),
                      ]),
                      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text('Net Kar', style: TextStyle(color: Colors.white54, fontSize: 11)),
                        Text('€ ${(totalIncome - totalExpense).toStringAsFixed(0)}', style: TextStyle(color: (totalIncome - totalExpense) >= 0 ? Colors.blueAccent : Colors.redAccent, fontSize: 18, fontWeight: FontWeight.bold)),
                      ]),
                    ],
                  ),
                ],
              ),
            );
          }

          final d = _dailyData[i - 1];
          final income = d['income'] as double;
          final labor = d['laborCost'] as double;
          final material = d['materialCost'] as double;
          final expense = labor + material;
          final profit = income - expense;
          final dateStr = d['date'] as String;
          final sessions = d['sessionCount'] as int;

          DateTime? parsedDate;
          try { parsedDate = DateTime.parse(dateStr); } catch (_) {}
          final displayDate = parsedDate != null ? DateFormat('dd MMMM yyyy', 'tr_TR').format(parsedDate) : dateStr;

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.divider),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 6)],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(displayDate, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, fontFamily: 'Inter')),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: AppTheme.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                      child: Text('$sessions seans', style: const TextStyle(fontSize: 10, color: AppTheme.primary, fontFamily: 'Inter')),
                    ),
                  ],
                ),
                const Divider(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _miniStat('Gelir', '€ ${income.toStringAsFixed(0)}', Colors.green),
                    _miniStat('İşçilik', '€ ${labor.toStringAsFixed(0)}', Colors.deepOrange),
                    _miniStat('Malzeme', '€ ${material.toStringAsFixed(0)}', Colors.orange),
                    _miniStat('Net Kar', '€ ${profit.toStringAsFixed(0)}', profit >= 0 ? AppTheme.primary : AppTheme.error),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _miniStat(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: AppTheme.textSub, fontFamily: 'Inter')),
        Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color, fontFamily: 'Inter')),
      ],
    );
  }
}

// ── 3) Aylık Rapor ────────────────────────────────────────────────
class _MonthlyReportTab extends StatefulWidget {
  @override
  State<_MonthlyReportTab> createState() => _MonthlyReportTabState();
}

class _MonthlyReportTabState extends State<_MonthlyReportTab> {
  int _selectedYear = DateTime.now().year;
  int _selectedMonth = DateTime.now().month;
  bool _loading = true;
  bool _exporting = false;
  
  double _totalIncome = 0;
  double _totalLaborCost = 0;
  double _totalMaterialCost = 0;
  List<Map<String, dynamic>> _dailyBreakdown = [];

  @override
  void initState() {
    super.initState();
    _loadMonthData();
  }

  Future<void> _loadMonthData() async {
    setState(() => _loading = true);
    try {
      final daysInMonth = DateTime(_selectedYear, _selectedMonth + 1, 0).day;
      final dateFrom = '$_selectedYear-${_selectedMonth.toString().padLeft(2, '0')}-01';
      final dateTo = '$_selectedYear-${_selectedMonth.toString().padLeft(2, '0')}-${daysInMonth.toString().padLeft(2, '0')}';

      final sessions = await SupabaseService.getApprovedSessionsByDateRange(
        dateFrom: dateFrom,
        dateTo: dateTo,
      );

      // Günlük gruplama
      Map<String, Map<String, dynamic>> dailyMap = {};
      double totalIncome = 0, totalLabor = 0, totalMaterial = 0;
      Set<String> countedOrders = {};

      for (var s in sessions) {
        final approvedAt = s['approved_at']?.toString() ?? '';
        if (approvedAt.isEmpty) continue;
        final dateKey = approvedAt.substring(0, 10);

        if (!dailyMap.containsKey(dateKey)) {
          dailyMap[dateKey] = {'date': dateKey, 'income': 0.0, 'expense': 0.0, 'profit': 0.0};
        }

        final hrs = (s['approved_billable_hours'] as num?)?.toDouble() ?? 0;
        final fallbackLabor = 0.0; // Fallback labor removed

        final order = s['order'];
        if (order != null) {
          final orderId = order['id'] ?? '';
          if (!countedOrders.contains(orderId) && orderId.isNotEmpty) {
            countedOrders.add(orderId);
            final reportsRaw = order['work_reports'];
            Map<String, dynamic>? wReport;
            if (reportsRaw is List && reportsRaw.isNotEmpty) wReport = reportsRaw.first;
            else if (reportsRaw is Map) wReport = Map<String, dynamic>.from(reportsRaw);

            // GELİR
            double rev = 0;
            if (wReport != null && (wReport['total_revenue'] as num? ?? 0) > 0) {
              rev = (wReport['total_revenue'] as num).toDouble();
            } else {
              final drafts = order['invoice_drafts'] as List?;
              if (drafts != null && drafts.isNotEmpty) {
                rev = (drafts.first['total_amount'] as num?)?.toDouble() ?? 0;
              }
            }
            totalIncome += rev;
            dailyMap[dateKey]!['income'] = (dailyMap[dateKey]!['income'] as double) + rev;

            // İŞÇİLİK GİDERİ
            double labor = 0;
            if (wReport != null && (wReport['estimated_labor_cost'] as num? ?? 0) > 0) {
              labor = (wReport['estimated_labor_cost'] as num).toDouble();
            } else {
              labor = fallbackLabor;
            }
            totalLabor += labor;
            dailyMap[dateKey]!['expense'] = (dailyMap[dateKey]!['expense'] as double) + labor;

            // MALZEME GİDERİ
            double material = 0;
            if (wReport != null && (wReport['estimated_material_cost'] as num? ?? 0) > 0) {
              material = (wReport['estimated_material_cost'] as num).toDouble();
            } else {
              final extras = order['extra_works'] as List?;
              if (extras != null) {
                for (var ew in extras) {
                  material += (ew['estimated_material_cost'] as num?)?.toDouble() ?? 0;
                }
              }
            }
            totalMaterial += material;
            dailyMap[dateKey]!['expense'] = (dailyMap[dateKey]!['expense'] as double) + material;
          }
        }
      }

      // Profit hesapla
      for (var d in dailyMap.values) {
        d['profit'] = (d['income'] as double) - (d['expense'] as double);
      }

      final dailyList = dailyMap.values.toList()
        ..sort((a, b) => (a['date'] as String).compareTo(b['date'] as String));

      setState(() {
        _totalIncome = totalIncome;
        _totalLaborCost = totalLabor;
        _totalMaterialCost = totalMaterial;
        _dailyBreakdown = dailyList;
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _exportPdf() async {
    setState(() => _exporting = true);
    try {
      final bytes = await PdfService.buildMonthlyReportPdf(
        year: _selectedYear,
        month: _selectedMonth,
        totalIncome: _totalIncome,
        totalLaborCost: _totalLaborCost,
        totalMaterialCost: _totalMaterialCost,
        totalProfit: _totalIncome - _totalLaborCost - _totalMaterialCost,
        dailyData: _dailyBreakdown,
      );
      await PdfService.sharePdf(bytes, 'aylik_rapor_${_selectedYear}_${_selectedMonth.toString().padLeft(2, '0')}.pdf');
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('PDF Hatası: $e')));
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final monthNames = ['', 'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran', 'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık'];
    final totalExpense = _totalLaborCost + _totalMaterialCost;
    final totalProfit = _totalIncome - totalExpense;
    final daysInMonth = DateTime(_selectedYear, _selectedMonth + 1, 0).day;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Ay seçici
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: () {
                  setState(() {
                    if (_selectedMonth == 1) { _selectedMonth = 12; _selectedYear--; }
                    else { _selectedMonth--; }
                  });
                  _loadMonthData();
                },
              ),
              Expanded(
                child: Center(
                  child: Text('${monthNames[_selectedMonth]} $_selectedYear ($daysInMonth gün)',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Inter')),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: () {
                  final now = DateTime.now();
                  if (_selectedYear < now.year || (_selectedYear == now.year && _selectedMonth < now.month)) {
                    setState(() {
                      if (_selectedMonth == 12) { _selectedMonth = 1; _selectedYear++; }
                      else { _selectedMonth++; }
                    });
                    _loadMonthData();
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (_loading) 
            const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()))
          else ...[
            // Aylık toplam kartı
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF0F172A), Color(0xFF1E3A5F)]),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${monthNames[_selectedMonth]} $_selectedYear Özeti', style: const TextStyle(color: Colors.white70, fontSize: 13, fontFamily: 'Inter')),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _monthStat('Toplam Gelir', '€ ${_totalIncome.toStringAsFixed(0)}', Colors.greenAccent),
                      _monthStat('Toplam Gider', '€ ${totalExpense.toStringAsFixed(0)}', Colors.orangeAccent),
                      _monthStat('Net Kar', '€ ${totalProfit.toStringAsFixed(0)}', totalProfit >= 0 ? Colors.cyanAccent : Colors.redAccent),
                    ],
                  ),
                  const Divider(color: Colors.white10, height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('İşçilik: € ${_totalLaborCost.toStringAsFixed(0)}', style: const TextStyle(color: Colors.white38, fontSize: 11, fontFamily: 'Inter')),
                      Text('Malzeme: € ${_totalMaterialCost.toStringAsFixed(0)}', style: const TextStyle(color: Colors.white38, fontSize: 11, fontFamily: 'Inter')),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // PDF İndir butonu
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _exporting ? null : _exportPdf,
                icon: _exporting 
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.picture_as_pdf),
                label: Text(_exporting ? 'Oluşturuluyor...' : 'Aylık Rapor PDF İndir'),
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
              ),
            ),
            const SizedBox(height: 20),

            // Günlük döküm listesi
            if (_dailyBreakdown.isNotEmpty) ...[
              const Text('Günlük Döküm', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, fontFamily: 'Inter')),
              const SizedBox(height: 8),
              ..._dailyBreakdown.map((d) {
                final dateStr = d['date'] as String;
                final inc = d['income'] as double;
                final exp = d['expense'] as double;
                final prof = d['profit'] as double;

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.divider),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(dateStr.substring(8, 10), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.primary)),
                      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text('Gelir', style: TextStyle(fontSize: 9, color: AppTheme.textSub)),
                        Text('€${inc.toStringAsFixed(0)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.green)),
                      ]),
                      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text('Gider', style: TextStyle(fontSize: 9, color: AppTheme.textSub)),
                        Text('€${exp.toStringAsFixed(0)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.orange)),
                      ]),
                      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text('Net Kar', style: TextStyle(fontSize: 9, color: AppTheme.textSub)),
                        Text('€${prof.toStringAsFixed(0)}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: prof >= 0 ? AppTheme.primary : AppTheme.error)),
                      ]),
                    ],
                  ),
                );
              }),
            ],
          ],
        ],
      ),
    );
  }

  Widget _monthStat(String label, String value, Color color) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11, fontFamily: 'Inter')),
      Text(value, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Inter')),
    ]);
  }
}

// ── 4) Personel Saatleri ──────────────────────────────────────────
class _PersonnelHoursTab extends StatefulWidget {
  @override
  State<_PersonnelHoursTab> createState() => _PersonnelHoursTabState();
}

class _PersonnelHoursTabState extends State<_PersonnelHoursTab> {
  int _selectedYear = DateTime.now().year;
  int _selectedMonth = DateTime.now().month;
  bool _loading = true;
  bool _exporting = false;
  List<Map<String, dynamic>> _personnelData = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final sessions = await SupabaseService.getPersonnelHoursForMonth(_selectedYear, _selectedMonth);

      // Kullanıcı bazlı gruplama
      Map<String, Map<String, dynamic>> userMap = {};
      for (var s in sessions) {
        final user = s['user'];
        if (user == null) continue;
        final userId = user['id'] ?? '';
        if (userId.isEmpty) continue;

        if (!userMap.containsKey(userId)) {
          userMap[userId] = {
            'id': userId,
            'name': '${user['first_name'] ?? ''} ${user['last_name'] ?? ''}'.trim(),
            'role': _roleLabel(user['role'] ?? ''),
            'hours': 0.0,
            'sessionCount': 0,
          };
        }
        final hrs = (s['approved_billable_hours'] as num?)?.toDouble() 
            ?? (s['billable_hours'] as num?)?.toDouble() ?? 0;
        userMap[userId]!['hours'] = (userMap[userId]!['hours'] as double) + hrs;
        userMap[userId]!['sessionCount'] = (userMap[userId]!['sessionCount'] as int) + 1;
      }

      final list = userMap.values.toList()
        ..sort((a, b) => (b['hours'] as double).compareTo(a['hours'] as double));

      setState(() {
        _personnelData = list;
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _roleLabel(String role) {
    switch (role) {
      case 'geschaeftsfuehrer':  return 'Geschäftsführer';
      case 'betriebsleiter':     return 'Betriebsleiter';
      case 'bereichsleiter':     return 'Bereichsleiter';
      case 'vorarbeiter':        return 'Vorarbeiter';
      case 'mitarbeiter':        return 'Mitarbeiter';
      case 'buchhaltung':        return 'Buchhaltung';
      case 'backoffice':         return 'Backoffice';
      default:                   return role;
    }
  }

  Future<void> _exportPdf() async {
    setState(() => _exporting = true);
    try {
      final bytes = await PdfService.buildPersonnelHoursPdf(
        year: _selectedYear,
        month: _selectedMonth,
        personnelData: _personnelData,
      );
      await PdfService.sharePdf(bytes, 'personel_saatleri_${_selectedYear}_${_selectedMonth.toString().padLeft(2, '0')}.pdf');
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('PDF Hatası: $e')));
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final monthNames = ['', 'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran', 'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık'];
    final totalHours = _personnelData.fold<double>(0, (sum, p) => sum + ((p['hours'] as num?)?.toDouble() ?? 0));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Ay seçici
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: () {
                  setState(() {
                    if (_selectedMonth == 1) { _selectedMonth = 12; _selectedYear--; }
                    else { _selectedMonth--; }
                  });
                  _loadData();
                },
              ),
              Expanded(
                child: Center(
                  child: Text('${monthNames[_selectedMonth]} $_selectedYear',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Inter')),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: () {
                  final now = DateTime.now();
                  if (_selectedYear < now.year || (_selectedYear == now.year && _selectedMonth < now.month)) {
                    setState(() {
                      if (_selectedMonth == 12) { _selectedMonth = 1; _selectedYear++; }
                      else { _selectedMonth++; }
                    });
                    _loadData();
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Toplam saat
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF1E3A5F), Color(0xFF2D5A8C)]),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
              Text('Toplam Çalışma Saati', style: const TextStyle(color: Colors.white70, fontSize: 12, fontFamily: 'Inter')),
              Text('${totalHours.toStringAsFixed(1)} saat', style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold, fontFamily: 'Inter')),
              Text('${_personnelData.length} çalışan', style: const TextStyle(color: Colors.white54, fontSize: 12, fontFamily: 'Inter')),
            ]),
          ),
          const SizedBox(height: 12),

          // PDF İndir
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _exporting ? null : _exportPdf,
              icon: _exporting 
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.picture_as_pdf),
              label: Text(_exporting ? 'Oluşturuluyor...' : 'Personel Saatleri PDF İndir'),
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
            ),
          ),
          const SizedBox(height: 16),

          if (_loading)
            const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()))
          else if (_personnelData.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: Column(children: [
                  Icon(Icons.people_outline, size: 48, color: AppTheme.textSub.withOpacity(0.4)),
                  const SizedBox(height: 12),
                  const Text('Bu ay çalışma verisi yok', style: TextStyle(color: AppTheme.textSub)),
                ]),
              ),
            )
          else
            ..._personnelData.asMap().entries.map((entry) {
              final i = entry.key;
              final p = entry.value;
              final hours = (p['hours'] as double);
              final maxHours = _personnelData.first['hours'] as double;

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.divider),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: AppTheme.primary.withOpacity(0.1),
                            child: Text('${i + 1}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primary)),
                          ),
                          const SizedBox(width: 10),
                          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(p['name'] ?? '', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, fontFamily: 'Inter')),
                            Text(p['role'] ?? '', style: const TextStyle(fontSize: 11, color: AppTheme.textSub, fontFamily: 'Inter')),
                          ]),
                        ]),
                        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                          Text('${hours.toStringAsFixed(1)} sa', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.primary, fontFamily: 'Inter')),
                          Text('${p['sessionCount']} seans', style: const TextStyle(fontSize: 10, color: AppTheme.textSub)),
                        ]),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: maxHours > 0 ? (hours / maxHours).clamp(0, 1) : 0,
                        backgroundColor: AppTheme.divider,
                        color: AppTheme.primary,
                        minHeight: 4,
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}

// ── 5) Departman Performansı ─────────────────────────────────────
class _DepartmentPerformanceTab extends StatelessWidget {
  final List<Map<String, dynamic>> data;
  final bool loading;
  final VoidCallback onRefresh;
  const _DepartmentPerformanceTab({required this.data, required this.loading, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    if (data.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.folder_open_outlined, size: 56, color: AppTheme.textSub.withOpacity(0.5)),
            const SizedBox(height: 16),
            const Text('Henüz performans verisi bulunmuyor', style: TextStyle(color: AppTheme.textSub)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: data.length,
        itemBuilder: (ctx, i) {
          final d = data[i];
          final completed = d['completed_orders'] ?? 0;
          final hours = (d['total_hours'] as num?)?.toDouble() ?? 0.0;
          
          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.divider),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10)],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(d['name'] ?? 'Bilinmeyen', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.primary)),
                    const Icon(Icons.folder_shared_outlined, color: AppTheme.primary),
                  ],
                ),
                const Divider(height: 24),
                Row(
                  children: [
                    _Metric(label: 'Biten İş', value: '$completed', color: AppTheme.success),
                    const SizedBox(width: 24),
                    _Metric(label: 'Toplam Saat', value: '${hours.toStringAsFixed(1)} h', color: AppTheme.info),
                  ],
                ),
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (completed / 20).clamp(0, 1),
                    backgroundColor: AppTheme.divider,
                    color: AppTheme.primary,
                    minHeight: 8,
                  ),
                ),
                const SizedBox(height: 8),
                const Text('Aylık hedefe göre ilerleme (20 İş)', style: TextStyle(fontSize: 10, color: AppTheme.textSub)),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _Metric({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.textSub)),
      ],
    );
  }
}

// ── 6) Fatura Geçmişi ────────────────────────────────────────────
class _InvoiceHistoryTab extends StatefulWidget {
  @override
  State<_InvoiceHistoryTab> createState() => _InvoiceHistoryTabState();
}

class _InvoiceHistoryTabState extends State<_InvoiceHistoryTab> {
  int _selectedYear = DateTime.now().year;
  int _selectedMonth = DateTime.now().month;
  bool _loading = true;
  String? _error;
  String? _downloadingOrderId;
  List<Map<String, dynamic>> _invoices = [];
  Map<String, List<Map<String, dynamic>>> _groupedByDate = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final daysInMonth = DateTime(_selectedYear, _selectedMonth + 1, 0).day;
      final dateFrom = '${_selectedYear}-${_selectedMonth.toString().padLeft(2, '0')}-01';
      final dateTo = '${_selectedYear}-${_selectedMonth.toString().padLeft(2, '0')}-${daysInMonth.toString().padLeft(2, '0')}'; 

      final data = await SupabaseService.getInvoiceDraftsByDateRange(
        dateFrom: dateFrom,
        dateTo: dateTo,
      );

      // Tarihe göre grupla
      Map<String, List<Map<String, dynamic>>> grouped = {};
      for (var d in data) {
        final createdAt = d['created_at']?.toString() ?? '';
        if (createdAt.length < 10) continue;
        final dateKey = createdAt.substring(0, 10);
        if (!grouped.containsKey(dateKey)) grouped[dateKey] = [];
        grouped[dateKey]!.add(d);
      }

      setState(() {
        _invoices = data;
        _groupedByDate = grouped;
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() => { _loading = false, _error = e.toString() });
    }
  }

  Future<void> _downloadPdf(String orderId) async {
    setState(() => _downloadingOrderId = orderId);
    try {
      final order = await SupabaseService.getOrder(orderId);
      if (order != null) {
        final sessions = await SupabaseService.getWorkSessionsForOrder(orderId);
        final workReport = await SupabaseService.getWorkReportByOrderId(orderId);
        final extraWorks = await SupabaseService.getExtraWorks(orderId);
        final pdf = await PdfService.buildWorkReportPdf(order: order, report: workReport, sessions: sessions, extraWorks: extraWorks);
        await PdfService.sharePdf(pdf, 'is_raporu_$orderId.pdf');
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('İş bulunamadı.')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('PDF Hatası: $e')));
    } finally {
      if (mounted) setState(() => _downloadingOrderId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final monthNames = ['', 'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran', 'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık'];

    return Column(
      children: [
        // Ay seçici
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: () {
                  setState(() {
                    if (_selectedMonth == 1) { _selectedMonth = 12; _selectedYear--; }
                    else { _selectedMonth--; }
                  });
                  _loadData();
                },
              ),
              Expanded(
                child: Center(
                  child: Text('${monthNames[_selectedMonth]} $_selectedYear',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Inter')),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: () {
                  final now = DateTime.now();
                  if (_selectedYear < now.year || (_selectedYear == now.year && _selectedMonth < now.month)) {
                    setState(() {
                      if (_selectedMonth == 12) { _selectedMonth = 1; _selectedYear++; }
                      else { _selectedMonth++; }
                    });
                    _loadData();
                  }
                },
              ),
            ],
          ),
        ),

        if (_loading)
          const Expanded(child: Center(child: CircularProgressIndicator()))
        else if (_error != null)
          Expanded(child: Center(child: Padding(
            padding: const EdgeInsets.all(16.0), 
            child: Text('Hata: $_error', style: const TextStyle(color: Colors.red, fontSize: 12, fontFamily: 'Inter')),
          )))
        else if (_groupedByDate.isEmpty)
          Expanded(
            child: Center(
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.receipt_long_outlined, size: 56, color: AppTheme.textSub.withOpacity(0.4)),
                const SizedBox(height: 12),
                const Text('Hiç fatura bulunamadı', style: TextStyle(color: AppTheme.textSub, fontFamily: 'Inter')),
                const SizedBox(height: 8),
                Text('Cihaz Saati: ${DateFormat('dd.MM.yyyy HH:mm').format(DateTime.now())}', style: const TextStyle(fontSize: 10, color: Colors.grey)),
              ]),
            ),
          )
        else
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text('${_invoices.length} fatura listeleniyor', style: const TextStyle(fontSize: 10, color: Colors.grey, fontStyle: FontStyle.italic)),
                ),
                ..._groupedByDate.entries.map((entry) {
                  final dateStr = entry.key;
                  final invoices = entry.value;

                  DateTime? parsedDate;
                  try { parsedDate = DateTime.parse(dateStr); } catch (_) {}
                  final displayDate = parsedDate != null ? DateFormat('dd MMMM yyyy', 'tr_TR').format(parsedDate) : dateStr;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(children: [
                          const Icon(Icons.calendar_today, size: 14, color: AppTheme.primary),
                          const SizedBox(width: 8),
                          Text(displayDate, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.primary, fontFamily: 'Inter')),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: AppTheme.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                            child: Text('${invoices.length} fatura', style: const TextStyle(fontSize: 10, color: AppTheme.primary)),
                          ),
                        ]),
                      ),
                      ...invoices.map((inv) {
                        // Relationship handling (Safety against List vs Map)
                        Map customer = {};
                        if (inv['customer'] is Map) {
                          customer = inv['customer'];
                        } else if (inv['customer'] is List && (inv['customer'] as List).isNotEmpty) {
                          customer = (inv['customer'] as List).first;
                        }

                        Map order = {};
                        if (inv['order'] is Map) {
                          order = inv['order'];
                        } else if (inv['order'] is List && (inv['order'] as List).isNotEmpty) {
                          order = (inv['order'] as List).first;
                        }

                        // NET KAR HESAPLAMA (Safe version)
                        double income = 0;
                        try { income = (inv['total_amount'] as num?)?.toDouble() ?? 0; } catch(_) {}
                        
                        double labor = 0;
                        double material = 0;

                        final wReportsRaw = order['work_reports'];
                        final List wReports = wReportsRaw is List ? wReportsRaw : (wReportsRaw != null ? [wReportsRaw] : []);

                        if (wReports.isNotEmpty) {
                          try {
                            final Map wr = wReports.first is Map ? wReports.first : {};
                            if (wr.isNotEmpty) {
                              if ((wr['total_revenue'] as num? ?? 0) > 0) income = (wr['total_revenue'] as num).toDouble();
                              labor = (wr['estimated_labor_cost'] as num? ?? 0).toDouble();
                              material = (wr['estimated_material_cost'] as num? ?? 0).toDouble();
                            }
                          } catch(_) {}
                        }

                        if (labor <= 0) {
                          labor = 0; // Fallback labor removed
                        }
                        if (material <= 0) {
                          final eWorksRaw = order['extra_works'];
                          final List eWorks = eWorksRaw is List ? eWorksRaw : [];
                          for (var ew in eWorks) {
                            try { material += (((ew as Map)['estimated_material_cost'] as num? ?? 0).toDouble()); } catch(_) {}
                          }
                        }
                        final netProfit = income - (labor + material);

                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppTheme.divider),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text(inv['draft_number'] ?? 'Taslak', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, fontFamily: 'Inter')),
                                  Text(customer['name'] ?? 'İsimsiz Müşteri', style: const TextStyle(fontSize: 12, color: AppTheme.textSub)),
                                ]),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text('€ ${netProfit.toStringAsFixed(2)}', 
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: netProfit >= 0 ? Colors.green[700] : Colors.red[700])),
                                  const Text('Net Kar', style: TextStyle(fontSize: 8, color: Colors.grey)),
                                ],
                              ),
                              const SizedBox(width: 8),
                              if (_downloadingOrderId == inv['order_id'])
                                const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                              else
                                IconButton(
                                  icon: const Icon(Icons.picture_as_pdf_outlined, size: 18, color: AppTheme.primary),
                                  onPressed: () => _downloadPdf(inv['order_id'] ?? ''),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                ),
                              IconButton(
                                icon: const Icon(Icons.visibility_outlined, size: 18),
                                onPressed: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => InvoiceDraftDetailScreen(draftId: inv['id'] ?? '')),
                                ),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                      const Divider(height: 16),
                    ],
                  );
                }).toList(),
              ],
            ),
          ),
      ],
    );
  }
}

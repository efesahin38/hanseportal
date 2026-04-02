import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../theme/web_utils.dart';
import '../providers/app_state.dart';
import '../services/supabase_service.dart';
import '../services/pdf_service.dart';
import '../services/localization_service.dart';

/// İş Sonu Raporlama ekranı (Bölüm 12)
class WorkReportScreen extends StatefulWidget {
  final String orderId;
  const WorkReportScreen({super.key, required this.orderId});

  @override
  State<WorkReportScreen> createState() => _WorkReportScreenState();
}

class _WorkReportScreenState extends State<WorkReportScreen> {
  Map<String, dynamic>? _order;
  Map<String, dynamic>? _report;
  List<Map<String, dynamic>> _extraWorks = [];
  bool _loading = true;
  bool _saving = false;

  final _summaryNote = TextEditingController();
  final _qualityNote = TextEditingController();
  final _customerFeedback = TextEditingController();
  final _totalRevenue = TextEditingController();
  final _laborCost = TextEditingController();
  final _materialCost = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final order = await SupabaseService.getOrder(widget.orderId);
      final report = await SupabaseService.getWorkReport(widget.orderId);
      final extras = await SupabaseService.getExtraWorks(widget.orderId);
      if (mounted) {
        setState(() {
          _order = order;
          _extraWorks = extras;
          if (report != null) {
            _report = report;
            _summaryNote.text = report['summary_note'] ?? '';
            _qualityNote.text = report['quality_note'] ?? '';
            _customerFeedback.text = report['customer_feedback'] ?? '';
            _totalRevenue.text = report['total_revenue']?.toString() ?? '';
            _laborCost.text = report['estimated_labor_cost']?.toString() ?? '';
            _materialCost.text = report['estimated_material_cost']?.toString() ?? '';
          }
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save({bool finalize = false}) async {
    final appState = context.read<AppState>();
    setState(() => _saving = true);
    try {
      // Sum actual hours from work_sessions
      final sessions = await SupabaseService.client
          .from('work_sessions')
          .select('actual_duration_h, billable_hours, extra_hours')
          .eq('order_id', widget.orderId);

      double totalActual = 0, totalBillable = 0, totalExtra = 0;
      for (final s in sessions as List) {
        totalActual += (s['actual_duration_h'] as num?)?.toDouble() ?? 0;
        totalBillable += (s['billable_hours'] as num?)?.toDouble() ?? 0;
        totalExtra += (s['extra_hours'] as num?)?.toDouble() ?? 0;
      }

      // Bölüm 10.4: Minimum fatura süresi kuralı
      final minHours = (_order?['minimum_billable_hours'] as num?)?.toDouble() ?? 4.0;
      if (totalBillable < minHours && totalBillable > 0) {
        // Eğer fiili/billable yetersizse, minimuma tamamla (Esas Süre ayrımı)
        totalBillable = minHours; 
      }

      final data = {
        'order_id': widget.orderId,
        if (_report != null) 'id': _report!['id'],
        'total_actual_hours': totalActual,
        'total_billable_hours': totalBillable,
        'total_extra_hours': totalExtra,
        'total_extra_works': _extraWorks.length,
        'summary_note': _summaryNote.text.trim(),
        'quality_note': _qualityNote.text.trim(),
        'customer_feedback': _customerFeedback.text.trim(),
        if (_totalRevenue.text.isNotEmpty) 'total_revenue': double.tryParse(_totalRevenue.text),
        if (_laborCost.text.isNotEmpty) 'estimated_labor_cost': double.tryParse(_laborCost.text),
        if (_materialCost.text.isNotEmpty) 'estimated_material_cost': double.tryParse(_materialCost.text),
        'is_finalized': finalize,
        if (finalize) ...{
          'finalized_by': appState.userId,
          'finalized_at': DateTime.now().toIso8601String(),
        },
        'created_by': appState.userId,
      };

      await SupabaseService.upsertWorkReport(data);
      await _load();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(finalize ? tr('Rapor finalize edildi') : tr('Rapor kaydedildi'))),
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${tr('Hata')}: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _exportPdf(Map<String, dynamic>? order, bool isFinalized) async {
    if (order == null) return;
    setState(() => _saving = true);
    try {
      final sessions = await SupabaseService.getWorkSessionsForOrder(widget.orderId);
      final bytes = await PdfService.buildWorkReportPdf(
        order: order,
        report: _report,
        sessions: sessions,
        extraWorks: _extraWorks,
      );
      final orderNum = order['order_number'] ?? 'rapor';
      await PdfService.sharePdf(bytes, 'is_sonu_raporu_$orderNum.pdf');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('${tr('PDF hatası')}: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _summaryNote.dispose();
    _qualityNote.dispose();
    _customerFeedback.dispose();
    _totalRevenue.dispose();
    _laborCost.dispose();
    _materialCost.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final o = _order;
    final isFinalized = _report?['is_finalized'] == true;

    return Scaffold(
      appBar: AppBar(
        title: Text(tr('İş Sonu Raporu')),
        actions: [
          // PDF Export
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_outlined),
            tooltip: tr('PDF Oluştur & Paylaş'),
            onPressed: _saving ? null : () => _exportPdf(o, isFinalized),
          ),
          if (!isFinalized)
            TextButton.icon(
              onPressed: _saving ? null : () => _save(finalize: true),
              icon: const Icon(Icons.check_circle_outline, color: Colors.white),
              label: Text(tr('Finalizeye'), style: const TextStyle(color: Colors.white, fontFamily: 'Inter')),
            ),
        ],
      ),
      body: WebContentWrapper(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Finalized banner
            if (isFinalized)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.success.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.success.withOpacity(0.3)),
                ),
                child: Row(children: [
                  const Icon(Icons.verified, color: AppTheme.success),
                  const SizedBox(width: 8),
                  Text(tr('Bu rapor finalize edilmiştir'), style: const TextStyle(color: AppTheme.success, fontWeight: FontWeight.w600, fontFamily: 'Inter')),
                ]),
              ),
  
            // İş Özeti
            if (o != null) _infoCard(tr('İş Özeti'), [
              _stat(tr('İş Numarası'), o['order_number'] ?? ''),
              _stat(tr('Müşteri'), o['customer']?['name'] ?? ''),
              _stat(tr('Durum'), AppTheme.statusLabel(o['status'] ?? '')),
              _stat(tr('Saha Adresi'), o['site_address'] ?? ''),
            ]),
            const SizedBox(height: 12),
  
            // Çalışma Süre Özeti (Sadece Muhasebe ve Yönetim görebilir)
            if (context.read<AppState>().isBuchhaltung || context.read<AppState>().isGeschaeftsfuehrer || context.read<AppState>().isSystemAdmin)
              FutureBuilder(
                future: SupabaseService.client
                    .from('work_sessions')
                    .select('''
                      *,
                      user:users!work_sessions_user_id_fkey(first_name, last_name)
                    ''')
                    .eq('order_id', widget.orderId),
                builder: (ctx, snap) {
                  if (!snap.hasData) return const SizedBox();
                  final sessions = snap.data as List;
                  double totalActual = 0, totalBillable = 0, totalExtra = 0;
                  
                  for (final s in sessions) {
                    totalActual += (s['actual_duration_h'] as num?)?.toDouble() ?? 0;
                    // Onaylanmış saat varsa onu kullan, yoksa ham saat (billable_hours)
                    final sBillable = (s['approved_billable_hours'] as num?)?.toDouble() ?? (s['billable_hours'] as num?)?.toDouble() ?? 0;
                    totalBillable += sBillable;
                    totalExtra += (s['extra_hours'] as num?)?.toDouble() ?? 0;
                  }
                  
                  final minH = (_order?['minimum_billable_hours'] as num?)?.toDouble() ?? 4.0;
                  final displayBillable = totalBillable < minH && totalBillable > 0 ? minH : totalBillable;
  
                  return Column(
                    children: [
                      _infoCard(tr('Çalışma Süre Özeti (Onaylı)'), [
                        _stat(tr('Fiili Çalışma Süresi'), '${totalActual.toStringAsFixed(1)} ${tr('saat')}'),
                        _stat(tr('Esas (Hizmet) Süresi'), '${displayBillable.toStringAsFixed(1)} ${tr('saat')}', isBold: true),
                        if (totalBillable < minH && totalBillable > 0)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text('⚠️ Not: ${tr('Minimum')} $minH ${tr('saat')} ${tr('kuralı uygulandı')}', style: const TextStyle(fontSize: 11, color: AppTheme.warning, fontFamily: 'Inter')),
                          ),
                        const Divider(),
                        _stat(tr('Fazla Mesai'), '${totalExtra.toStringAsFixed(1)} ${tr('saat')}'),
                        _stat(tr('Seans Sayısı'), '${sessions.length}'),
                      ]),
                      const SizedBox(height: 12),
                      _infoCard(tr('Personel Çalışma Detayı'), [
                        ...sessions.map((s) {
                          final u = s['user'];
                          final hrs = (s['approved_billable_hours'] as num?)?.toDouble() ?? (s['billable_hours'] as num?)?.toDouble() ?? 0;
                          final isApproved = s['approval_status'] == 'approved';
                          
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('${u['first_name']} ${u['last_name']}', style: const TextStyle(fontSize: 13, fontFamily: 'Inter')),
                                Row(
                                  children: [
                                    Text('${hrs.toStringAsFixed(1)} ${tr('saat')}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                                    const SizedBox(width: 6),
                                    Icon(
                                      isApproved ? Icons.check_circle : Icons.pending,
                                      size: 14,
                                      color: isApproved ? AppTheme.success : AppTheme.warning,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ]),
                      const SizedBox(height: 12),
                    ],
                  );
                },
              ),
  
            // Ek İşler
            _infoCard('${tr('Ek İşler')} (${_extraWorks.length})', [
              if (_extraWorks.isEmpty)
                Text(tr('Ek iş yok'), style: const TextStyle(color: AppTheme.textSub, fontFamily: 'Inter'))
              else
                ..._extraWorks.map((ew) => _extraWorkRow(ew)),
            ]),
            const SizedBox(height: 12),
  
            // Maliyet / Gelir - Sadece yetkili personeller görebilir
            if (context.read<AppState>().isBuchhaltung || context.read<AppState>().isGeschaeftsfuehrer || context.read<AppState>().isBetriebsleiter || context.read<AppState>().isSystemAdmin)
              _infoCard(tr('Tahmini Maliyet & Gelir (Yönetici Özeti)'), [
                TextFormField(
                  controller: _totalRevenue,
                  enabled: !isFinalized,
                  decoration: InputDecoration(labelText: tr('Tahmini Gelir (€)'), prefixText: '€ '),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: TextFormField(
                    controller: _laborCost,
                    enabled: !isFinalized,
                    decoration: InputDecoration(labelText: tr('İşçilik Maliyeti (€)')),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  )),
                  const SizedBox(width: 10),
                  Expanded(child: TextFormField(
                    controller: _materialCost,
                    enabled: !isFinalized,
                    decoration: InputDecoration(labelText: tr('Malzeme Maliyeti (€)')),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  )),
                ]),
              ]),
            if (context.read<AppState>().isBuchhaltung || context.read<AppState>().isGeschaeftsfuehrer || context.read<AppState>().isBetriebsleiter || context.read<AppState>().isSystemAdmin)
              const SizedBox(height: 12),
  
            // Notlar
            _infoCard(tr('Notlar & Değerlendirme'), [
              TextFormField(
                controller: _summaryNote,
                enabled: !isFinalized,
                maxLines: 3,
                decoration: InputDecoration(labelText: tr('Genel Özet Notu')),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _qualityNote,
                enabled: !isFinalized,
                maxLines: 2,
                decoration: InputDecoration(labelText: tr('Kalite Notu')),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _customerFeedback,
                enabled: !isFinalized,
                maxLines: 2,
                decoration: InputDecoration(labelText: tr('Müşteri Geri Bildirimi')),
              ),
            ]),
  
            const SizedBox(height: 24),
            if (!isFinalized) ...[
              ElevatedButton(
                onPressed: _saving ? null : () => _save(),
                child: _saving
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text(tr('Taslak Olarak Kaydet'), style: const TextStyle(fontFamily: 'Inter')),
              ),
              const SizedBox(height: 16),
            ],
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: isFinalized ? AppTheme.primary : Colors.white,
                foregroundColor: isFinalized ? Colors.white : AppTheme.primary,
                side: isFinalized ? null : const BorderSide(color: AppTheme.primary),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              onPressed: _saving ? null : () => _exportPdf(o, isFinalized),
              icon: Icon(Icons.picture_as_pdf, color: isFinalized ? Colors.white : AppTheme.primary),
              label: Text(tr('PDF 📄 ile Paylaş'), style: TextStyle(
                color: isFinalized ? Colors.white : AppTheme.primary,
                fontSize: 16,
                fontWeight: FontWeight.bold,
                fontFamily: 'Inter',
              )),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _infoCard(String title, List<Widget> children) => Container(
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

  Widget _stat(String label, String value, {bool isBold = false}) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(children: [
      SizedBox(width: 140, child: Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.textSub, fontFamily: 'Inter'))),
      Expanded(child: Text(value, style: TextStyle(fontSize: 13, fontFamily: 'Inter', fontWeight: isBold ? FontWeight.bold : FontWeight.w500))),
    ]),
  );

  Widget _extraWorkRow(Map<String, dynamic> ew) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(children: [
      Container(
        width: 8, height: 8,
        decoration: BoxDecoration(
          color: ew['is_billable'] == true ? AppTheme.success : ew['is_billable'] == false ? AppTheme.error : AppTheme.warning,
          shape: BoxShape.circle,
        ),
      ),
      const SizedBox(width: 8),
      Expanded(child: Text(ew['title'] ?? '', style: const TextStyle(fontSize: 13, fontFamily: 'Inter'))),
      if (ew['duration_h'] != null)
        Text('${ew['duration_h']}h', style: const TextStyle(fontSize: 12, color: AppTheme.textSub, fontFamily: 'Inter')),
    ]),
  );
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../providers/app_state.dart';
import '../services/supabase_service.dart';

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
          SnackBar(content: Text(finalize ? 'Rapor finalize edildi' : 'Rapor kaydedildi')),
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
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
        title: const Text('İş Sonu Raporu'),
        actions: [
          if (!isFinalized)
            TextButton.icon(
              onPressed: _saving ? null : () => _save(finalize: true),
              icon: const Icon(Icons.check_circle_outline, color: Colors.white),
              label: const Text('Finalizeye', style: TextStyle(color: Colors.white, fontFamily: 'Inter')),
            ),
        ],
      ),
      body: ListView(
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
                const Text('Bu rapor finalize edilmiştir', style: TextStyle(color: AppTheme.success, fontWeight: FontWeight.w600, fontFamily: 'Inter')),
              ]),
            ),

          // İş Özeti
          if (o != null) _infoCard('İş Özeti', [
            _stat('İş Numarası', o['order_number'] ?? ''),
            _stat('Müşteri', o['customer']?['name'] ?? ''),
            _stat('Durum', AppTheme.statusLabel(o['status'] ?? '')),
            _stat('Saha Adresi', o['site_address'] ?? ''),
          ]),
          const SizedBox(height: 12),

          // Çalışma Süre Özeti
          FutureBuilder(
            future: SupabaseService.client
                .from('work_sessions')
                .select('actual_duration_h, billable_hours, extra_hours, user_id, actual_start, actual_end')
                .eq('order_id', widget.orderId),
            builder: (ctx, snap) {
              if (!snap.hasData) return const SizedBox();
              final sessions = snap.data as List;
              double totalActual = 0, totalBillable = 0, totalExtra = 0;
              for (final s in sessions) {
                totalActual += (s['actual_duration_h'] as num?)?.toDouble() ?? 0;
                totalBillable += (s['billable_hours'] as num?)?.toDouble() ?? 0;
                totalExtra += (s['extra_hours'] as num?)?.toDouble() ?? 0;
              }
              return _infoCard('Çalışma Süre Özeti', [
                _stat('Toplam Fiili Süre', '${totalActual.toStringAsFixed(1)} saat'),
                _stat('Faturalanabilir Süre', '${totalBillable.toStringAsFixed(1)} saat'),
                _stat('Fazla Mesai', '${totalExtra.toStringAsFixed(1)} saat'),
                _stat('Seans Sayısı', '${sessions.length}'),
              ]);
            },
          ),
          const SizedBox(height: 12),

          // Ek İşler
          _infoCard('Ek İşler (${_extraWorks.length})', [
            if (_extraWorks.isEmpty)
              const Text('Ek iş yok', style: TextStyle(color: AppTheme.textSub, fontFamily: 'Inter'))
            else
              ..._extraWorks.map((ew) => _extraWorkRow(ew)),
          ]),
          const SizedBox(height: 12),

          // Maliyet / Gelir
          _infoCard('Tahmini Maliyet & Gelir', [
            TextFormField(
              controller: _totalRevenue,
              enabled: !isFinalized,
              decoration: const InputDecoration(labelText: 'Tahmini Gelir (€)', prefixText: '€ '),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: TextFormField(
                controller: _laborCost,
                enabled: !isFinalized,
                decoration: const InputDecoration(labelText: 'İşçilik Maliyeti (€)'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              )),
              const SizedBox(width: 10),
              Expanded(child: TextFormField(
                controller: _materialCost,
                enabled: !isFinalized,
                decoration: const InputDecoration(labelText: 'Malzeme Maliyeti (€)'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              )),
            ]),
          ]),
          const SizedBox(height: 12),

          // Notlar
          _infoCard('Notlar & Değerlendirme', [
            TextFormField(
              controller: _summaryNote,
              enabled: !isFinalized,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Genel Özet Notu'),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _qualityNote,
              enabled: !isFinalized,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Kalite Notu'),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _customerFeedback,
              enabled: !isFinalized,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Müşteri Geri Bildirimi'),
            ),
          ]),

          const SizedBox(height: 24),
          if (!isFinalized)
            ElevatedButton(
              onPressed: _saving ? null : () => _save(),
              child: _saving
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Taslak Olarak Kaydet'),
            ),
          const SizedBox(height: 24),
        ],
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

  Widget _stat(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(children: [
      SizedBox(width: 120, child: Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.textSub, fontFamily: 'Inter'))),
      Expanded(child: Text(value, style: const TextStyle(fontSize: 13, fontFamily: 'Inter', fontWeight: FontWeight.w500))),
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

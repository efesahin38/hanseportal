import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../theme/web_utils.dart';
import '../providers/app_state.dart';
import '../services/supabase_service.dart';
import '../services/localization_service.dart';
import '../services/pdf_service.dart';

/// Ön Fatura Taslağı Detay Ekranı (Bölüm 13)
class InvoiceDraftDetailScreen extends StatefulWidget {
  final String draftId;
  const InvoiceDraftDetailScreen({super.key, required this.draftId});

  @override
  State<InvoiceDraftDetailScreen> createState() => _InvoiceDraftDetailScreenState();
}

class _InvoiceDraftDetailScreenState extends State<InvoiceDraftDetailScreen> {
  Map<String, dynamic>? _draft;
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  bool _saving = false;

  final _accountingNote = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final draft = await SupabaseService.client
          .from('invoice_drafts')
          .select('''
            *,
            customer:customers!orders_customer_id_fkey(id, name, phone, email),
            issuing_company:companies!invoice_drafts_issuing_company_id_fkey(id, name, short_name, iban, bic, tax_number)
          ''')
          .eq('id', widget.draftId)
          .maybeSingle();

      final items = await SupabaseService.client
          .from('invoice_draft_items')
          .select()
          .eq('invoice_draft_id', widget.draftId)
          .order('sort_order');

      if (mounted) {
        setState(() {
          _draft = draft;
          _items = List<Map<String, dynamic>>.from(items);
          _accountingNote.text = draft?['accounting_note'] ?? '';
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _updateStatus(String newStatus) async {
    setState(() => _saving = true);
    try {
      await SupabaseService.upsertInvoiceDraft({
        'id': widget.draftId,
        'status': newStatus,
        'accounting_note': _accountingNote.text.trim(),
      });
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${tr('Durum güncellendi')}: ${_draftStatusLabel(newStatus)}')),
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${tr('Hata')}: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _exportPdf() async {
    if (_draft == null) return;
    setState(() => _saving = true);
    try {
      final bytes = await PdfService.buildInvoiceDraftPdf(
        draft: _draft!,
        items: _items,
      );
      final draftNum = _draft!['draft_number'] ?? 'taslak';
      await PdfService.sharePdf(bytes, 'on_fatura_$draftNum.pdf');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('${tr('PDF hatası')}: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _draftStatusLabel(String s) {
    switch (s) {
      case 'auto_generated':   return tr('Otomatik Oluşturuldu');
      case 'under_review':     return tr('İncelemede');
      case 'correction_needed': return tr('Düzeltme Gerekli');
      case 'approved':         return tr('Onaylandı');
      case 'invoiced':         return tr('Faturalandı');
      case 'cancelled':        return tr('İptal Edildi');
      default:                 return s;
    }
  }

  Color _draftStatusColor(String s) {
    switch (s) {
      case 'auto_generated':   return AppTheme.info;
      case 'under_review':     return AppTheme.warning;
      case 'correction_needed': return AppTheme.error;
      case 'approved':         return AppTheme.success;
      case 'invoiced':         return Colors.purple;
      case 'cancelled':        return AppTheme.textSub;
      default:                 return AppTheme.textSub;
    }
  }

  @override
  void dispose() {
    _accountingNote.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_draft == null) return Scaffold(appBar: AppBar(title: Text(tr('Ön Fatura'))), body: Center(child: Text(tr('Veri bulunamadı'))));

    final d = _draft!;
    final status = d['status'] ?? '';
    final customer = d['customer'];
    final company = d['issuing_company'];
    
    // Fallback: If total_amount is 0, check if we can get it from work_reports via FutureBuilder or a pre-loaded value.
    // For now, let's keep the existing variables but allow the FutureBuilder below to override display or just use a helper.
    double total = (d['total_amount'] as num?)?.toDouble() ?? 0;
    
    final canEdit = context.watch<AppState>().canManageInvoices;

    return Scaffold(
      appBar: AppBar(
        title: Text(d['draft_number'] ?? tr('Ön Fatura')),
        actions: [
          // PDF Export
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_outlined),
            tooltip: tr('PDF Oluştur & Paylaş'),
            onPressed: _saving ? null : _exportPdf,
          ),
          if (canEdit)
            PopupMenuButton<String>(
              onSelected: _updateStatus,
              itemBuilder: (_) => [
                'under_review', 'correction_needed', 'approved', 'invoiced', 'cancelled'
              ].map((s) => PopupMenuItem(
                value: s,
                child: Row(children: [
                  Container(width: 8, height: 8, decoration: BoxDecoration(color: _draftStatusColor(s), shape: BoxShape.circle)),
                  const SizedBox(width: 8),
                  Text(_draftStatusLabel(s), style: const TextStyle(fontFamily: 'Inter')),
                ]),
              )).toList(),
            ),
        ],
      ),
      body: WebContentWrapper(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Durum badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: _draftStatusColor(status).withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(children: [
                Icon(Icons.receipt_long, color: _draftStatusColor(status), size: 18),
                const SizedBox(width: 8),
                Text(_draftStatusLabel(status),
                  style: TextStyle(color: _draftStatusColor(status), fontWeight: FontWeight.w600, fontFamily: 'Inter')),
              ]),
            ),
            const SizedBox(height: 16),
  
            // Şirket & Müşteri
            _card(tr('Fatura Bilgileri'), [
              if (company != null) ...[
                Text(tr('Faturayı Kesen:'), style: const TextStyle(fontSize: 12, color: AppTheme.textSub, fontFamily: 'Inter')),
                Text(company['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontFamily: 'Inter')),
                if (company['iban'] != null) Text('IBAN: ${company['iban']}', style: const TextStyle(fontSize: 12, fontFamily: 'Inter')),
                const SizedBox(height: 10),
              ],
              if (customer != null) ...[
                Text(tr('Müşteri:'), style: const TextStyle(fontSize: 12, color: AppTheme.textSub, fontFamily: 'Inter')),
                Text(customer['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontFamily: 'Inter')),
                if (d['billing_address'] != null) Text(d['billing_address'], style: const TextStyle(fontSize: 12, fontFamily: 'Inter')),
                if (d['billing_tax_number'] != null) Text('${tr('Vergi No:')} ${d['billing_tax_number']}', style: const TextStyle(fontSize: 12, fontFamily: 'Inter')),
              ],
              if (d['service_date_from'] != null || d['service_date_to'] != null) ...[
                const SizedBox(height: 8),
                Text(
                  '${tr('Hizmet Tarihi:')} ${d['service_date_from'] ?? ''} – ${d['service_date_to'] ?? ''}',
                  style: const TextStyle(fontSize: 12, fontFamily: 'Inter', color: AppTheme.textSub),
                ),
              ],
            ]),
            const SizedBox(height: 12),
  
            // Müşteri Banka & Vergi Bilgileri (Bölüm 1)
            if (customer != null && context.read<AppState>().canSeeFinancialDetails) ...[
              _card(tr('Müşteri Banka & Vergi Bilgileri (Hassas)'), [
                if (customer['bank_name'] != null) _row(tr('Banka'), customer['bank_name']),
                if (customer['iban'] != null) _row('IBAN', customer['iban']),
                if (customer['bic'] != null) _row('BIC', customer['bic']),
                if (customer['vat_number'] != null) _row('USt-IdNr.', customer['vat_number']),
                if (customer['secondary_contact_name'] != null) ...[
                  const Divider(),
                  _row(tr('İkinci Muhatap'), customer['secondary_contact_name']),
                  if (customer['secondary_contact_phone'] != null) _row(tr('İkinci Tel'), customer['secondary_contact_phone']),
                ],
              ]),
              const SizedBox(height: 12),
            ],
  
            // Kalemler
            _card(tr('Fatura Kalemleri'), [
              // Ana Kalemler
              Text(tr('Ana Hizmet Kalemleri'), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, fontFamily: 'Inter')),
              const SizedBox(height: 8),
              ..._items.where((i) => i['item_type'] == 'main').map((item) => _itemRow(item)),
              const SizedBox(height: 12),
              // Ek Kalemler
              if (_items.any((i) => i['item_type'] == 'extra')) ...[
                Text(tr('Ek Hizmet Kalemleri'), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, fontFamily: 'Inter')),
                const SizedBox(height: 8),
                ..._items.where((i) => i['item_type'] == 'extra').map((item) => _itemRow(item)),
              ],
            ]),
            const SizedBox(height: 12),
  
            // Proje Mali Analizi (Yönetici Özel) - Gerçek verilerle
            if (canEdit) FutureBuilder(
              future: _draft?['order_id'] != null 
                ? SupabaseService.getWorkReportByOrderId(_draft!['order_id'])
                : Future.value(null),
              builder: (ctx, snapshot) {
                double effectiveRevenue = total;
                double realLaborCost = 0;
                double realMaterialCost = 0;
                String source = tr('Henüz iş sonu raporu girilmemiş');
                
                if (snapshot.hasData && snapshot.data != null) {
                  final wr = snapshot.data as Map<String, dynamic>;
                  realLaborCost = (wr['estimated_labor_cost'] as num?)?.toDouble() ?? 0;
                  realMaterialCost = (wr['estimated_material_cost'] as num?)?.toDouble() ?? 0;
                  if (wr['actual_labor_cost'] != null || wr['actual_material_cost'] != null) {
                    source = tr('Tahmini Gelir ve Gider iş sonu raporundan alınmıştır');
                  } else if (wr['actual_labor_cost'] != null) {
                    source = tr('İş sonu raporundan gider verileri çekilmiştir');
                  }
                }
  
                final realExpense = realLaborCost + realMaterialCost;
                final realProfit = effectiveRevenue - realExpense;
  
                return _card(tr('Proje Finansal Analizi (Özet)'), [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _financialSummaryItem(tr('Tahmini Gelir'), '€ ${effectiveRevenue.toStringAsFixed(2)}', Colors.green),
                      _financialSummaryItem(tr('Tahmini Gider'), '€ ${realExpense.toStringAsFixed(2)}', Colors.orange),
                      _financialSummaryItem(tr('Net Kar'), '€ ${realProfit.toStringAsFixed(2)}', realProfit >= 0 ? AppTheme.primary : AppTheme.error),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _financialSummaryItem(tr('İşçilik Gideri'), '€ ${realLaborCost.toStringAsFixed(2)}', Colors.deepOrange),
                      _financialSummaryItem(tr('Malzeme Gideri'), '€ ${realMaterialCost.toStringAsFixed(2)}', Colors.amber),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text('* $source', style: const TextStyle(fontSize: 10, color: AppTheme.textSub, fontStyle: FontStyle.italic)),
                ]);
              },
            ),
            if (canEdit) const SizedBox(height: 12),
  
            // Muhasebe Notu
            if (canEdit) _card(tr('Muhasebe Notu'), [
              TextFormField(
                controller: _accountingNote,
                maxLines: 3,
                decoration: InputDecoration(labelText: tr('Muhasebe İçin Not'), hintText: tr('Muhasebe iç notu...')),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _saving ? null : () => _updateStatus(status),
                child: _saving
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text(tr('Notu Kaydet')),
              ),
            ]),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _card(String title, List<Widget> children) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppTheme.divider),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, fontFamily: 'Inter')),
      const SizedBox(height: 12),
      ...children,
    ]),
  );

  Widget _itemRow(Map<String, dynamic> item) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(children: [
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(item['description'] ?? '', style: const TextStyle(fontSize: 13, fontFamily: 'Inter')),
        Text('${item['quantity']} ${item['unit'] ?? ''}', style: const TextStyle(fontSize: 11, color: AppTheme.textSub, fontFamily: 'Inter')),
      ])),
      if (item['total_price'] != null)
        Text('€ ${(item['total_price'] as num).toStringAsFixed(2)}',
          style: const TextStyle(fontSize: 13, fontFamily: 'Inter', fontWeight: FontWeight.w500)),
    ]),
  );

  Widget _totalRow(String label, String value, {required bool bold}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(children: [
      Expanded(child: Text(label, style: TextStyle(fontFamily: 'Inter', fontWeight: bold ? FontWeight.bold : FontWeight.normal))),
      Text(value, style: TextStyle(fontFamily: 'Inter', fontWeight: bold ? FontWeight.bold : FontWeight.normal, fontSize: bold ? 16 : 14)),
    ]),
  );

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 100, child: Text('$label:', style: const TextStyle(fontSize: 12, color: AppTheme.textSub, fontFamily: 'Inter'))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, fontFamily: 'Inter'))),
        ],
      ),
    );
  }

  Widget _financialSummaryItem(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: AppTheme.textSub, fontFamily: 'Inter')),
        Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color, fontFamily: 'Inter')),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../providers/app_state.dart';
import '../services/supabase_service.dart';

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
            customer:customers(id, name, phone, email),
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
          SnackBar(content: Text('Durum güncellendi: ${_draftStatusLabel(newStatus)}')),
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _draftStatusLabel(String s) {
    switch (s) {
      case 'auto_generated':   return 'Otomatik Oluşturuldu';
      case 'under_review':     return 'İncelemede';
      case 'correction_needed': return 'Düzeltme Gerekli';
      case 'approved':         return 'Onaylandı';
      case 'invoiced':         return 'Faturalandı';
      case 'cancelled':        return 'İptal Edildi';
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
    if (_draft == null) return Scaffold(appBar: AppBar(title: const Text('Ön Fatura')), body: const Center(child: Text('Bulunamadı')));

    final d = _draft!;
    final status = d['status'] ?? '';
    final customer = d['customer'];
    final company = d['issuing_company'];
    final subtotal = (d['subtotal'] as num?)?.toDouble() ?? 0;
    final taxAmount = (d['tax_amount'] as num?)?.toDouble() ?? 0;
    final total = (d['total_amount'] as num?)?.toDouble() ?? 0;
    final taxRate = (d['tax_rate'] as num?)?.toDouble() ?? 19;

    final canEdit = context.watch<AppState>().canManageInvoices;

    return Scaffold(
      appBar: AppBar(
        title: Text(d['draft_number'] ?? 'Ön Fatura'),
        actions: [
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
      body: ListView(
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
          _card('Fatura Bilgileri', [
            if (company != null) ...[
              Text('Faturayı Kesen:', style: const TextStyle(fontSize: 12, color: AppTheme.textSub, fontFamily: 'Inter')),
              Text(company['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontFamily: 'Inter')),
              if (company['iban'] != null) Text('IBAN: ${company['iban']}', style: const TextStyle(fontSize: 12, fontFamily: 'Inter')),
              const SizedBox(height: 10),
            ],
            if (customer != null) ...[
              Text('Müşteri:', style: const TextStyle(fontSize: 12, color: AppTheme.textSub, fontFamily: 'Inter')),
              Text(customer['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontFamily: 'Inter')),
              if (d['billing_address'] != null) Text(d['billing_address'], style: const TextStyle(fontSize: 12, fontFamily: 'Inter')),
              if (d['billing_tax_number'] != null) Text('Vergi No: ${d['billing_tax_number']}', style: const TextStyle(fontSize: 12, fontFamily: 'Inter')),
            ],
            if (d['service_date_from'] != null || d['service_date_to'] != null) ...[
              const SizedBox(height: 8),
              Text(
                'Hizmet Tarihi: ${d['service_date_from'] ?? ''} – ${d['service_date_to'] ?? ''}',
                style: const TextStyle(fontSize: 12, fontFamily: 'Inter', color: AppTheme.textSub),
              ),
            ],
          ]),
          const SizedBox(height: 12),

          // Kalemler
          _card('Fatura Kalemleri', [
            // Ana Kalemler
            const Text('Ana Hizmet Kalemleri', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, fontFamily: 'Inter')),
            const SizedBox(height: 8),
            ..._items.where((i) => i['item_type'] == 'main').map((item) => _itemRow(item)),
            const SizedBox(height: 12),
            // Ek Kalemler
            if (_items.any((i) => i['item_type'] == 'extra')) ...[
              const Text('Ek Hizmet Kalemleri', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, fontFamily: 'Inter')),
              const SizedBox(height: 8),
              ..._items.where((i) => i['item_type'] == 'extra').map((item) => _itemRow(item)),
            ],
          ]),
          const SizedBox(height: 12),

          // Toplamlar
          _card('Toplamlar', [
            _totalRow('Ara Toplam', '€ ${subtotal.toStringAsFixed(2)}', bold: false),
            _totalRow('KDV (%${taxRate.toStringAsFixed(0)})', '€ ${taxAmount.toStringAsFixed(2)}', bold: false),
            const Divider(),
            _totalRow('GENEL TOPLAM', '€ ${total.toStringAsFixed(2)}', bold: true),
            if (d['payment_terms'] != null) ...[
              const SizedBox(height: 8),
              Text('Ödeme Koşulu: ${d['payment_terms']}', style: const TextStyle(fontSize: 12, color: AppTheme.textSub, fontFamily: 'Inter')),
            ],
          ]),
          const SizedBox(height: 12),

          // Muhasebe Notu
          if (canEdit) _card('Muhasebe Notu', [
            TextFormField(
              controller: _accountingNote,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Muhasebe İçin Not', hintText: 'Muhasebe iç notu...'),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _saving ? null : () => _updateStatus(status),
              child: _saving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Notu Kaydet'),
            ),
          ]),
          const SizedBox(height: 24),
        ],
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
}

import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'localization_service.dart';
import '../theme/app_theme.dart';
import '../theme/string_utils.dart';


/// Hanse Kollektiv – PDF Üretim Servisi
/// İş Sonu Raporu ve Ön Fatura Taslağı için PDF çıktısı üretir.
class PdfService {
  static final _euro = NumberFormat.currency(locale: 'de_DE', symbol: '€');
  static final _date = DateFormat('dd.MM.yyyy');

  // ─────────────────────────────────────────────────────────
  // İŞ SONU RAPORU PDF
  // ─────────────────────────────────────────────────────────
  static Future<Uint8List> buildWorkReportPdf({
    required Map<String, dynamic> order,
    required Map<String, dynamic>? report,
    required List<Map<String, dynamic>> sessions,
    required List<Map<String, dynamic>> extraWorks,
  }) async {
    final pdf = pw.Document();

    final font = await PdfGoogleFonts.notoSansRegular();
    final fontBold = await PdfGoogleFonts.notoSansBold();
    final logoImage = await rootBundle.load('assets/logo.jpeg');
    final logo = pw.MemoryImage(logoImage.buffer.asUint8List());

    final customer = order['customer'] as Map<String, dynamic>? ?? {};
    final serviceArea = order['service_area'] as Map<String, dynamic>? ?? {};

    double totalActual = 0, totalBillable = 0, totalExtra = 0;
    for (final s in sessions) {
      totalActual += (s['actual_duration_h'] as num?)?.toDouble() ?? 0;
      // Onaylanmış saat varsa onu kullan, yoksa ham saat (billable_hours)
      final sBillable = (s['approved_billable_hours'] as num?)?.toDouble() ?? (s['billable_hours'] as num?)?.toDouble() ?? 0;
      totalBillable += sBillable;
      totalExtra += (s['extra_hours'] as num?)?.toDouble() ?? 0;
    }

    final billableExtras = extraWorks.where((e) => e['is_billable'] == true).toList();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        theme: pw.ThemeData.withFont(base: font, bold: fontBold),
        header: (context) => _buildHeader(context, font, fontBold, logo: logo),
        footer: (context) => _buildFooter(context, font, fontBold),
        build: (context) => [
          pw.SizedBox(height: 4),
          // ── İş Özeti ──
          _sectionTitle(tr('İş Bilgileri'), fontBold),
          _infoTable([
            [tr('İş Numarası'), order['order_number'] ?? '-'],
            [tr('İş Başlığı'), order['title'] ?? '-'],
            [tr('Müşteri'), customer['name'] ?? '-'],
            [tr('Hizmet Alanı'), serviceArea['name'] ?? '-'],
            [tr('Saha Adresi'), order['site_address'] ?? '-'],
            [
              tr('Tarih Aralığı'),
              '${_fmtDate(order['planned_start_date'])} – ${_fmtDate(order['planned_end_date'])}'
            ],
          ], font, fontBold),
          pw.SizedBox(height: 12),

          // ── Çalışma Süreleri ──
          _sectionTitle(tr('Çalışma Süre Özeti'), fontBold),
          _infoTable([
            [tr('Toplam Fiili Süre'), '${totalActual.toStringAsFixed(1)} ${tr('saat')}'],
            [tr('Faturalanabilir Süre'), '${totalBillable.toStringAsFixed(1)} ${tr('saat')}'],
            [tr('Fazla Mesai'), '${totalExtra.toStringAsFixed(1)} ${tr('saat')}'],
            [tr('Seans Sayısı'), '${sessions.length}'],
          ], font, fontBold),

          if (sessions.isNotEmpty) ...[
            pw.SizedBox(height: 10),
            pw.Text(tr('Çalışan Detayı'),
                style: pw.TextStyle(font: fontBold, fontSize: 11, color: PdfColors.grey700)),
            pw.SizedBox(height: 6),
            _sessionsTable(sessions, font, fontBold),
          ],
          pw.SizedBox(height: 8),

          // ── Ek İşler ──
          _sectionTitle('${tr('Ek İşler')} (${extraWorks.length})', fontBold),
          if (extraWorks.isEmpty)
            pw.Text(tr('Ek iş kaydı bulunmuyor.'),
                style: pw.TextStyle(font: font, fontSize: 10, color: PdfColors.grey500))
          else
            _extraWorksTable(extraWorks, font, fontBold),
          pw.SizedBox(height: 8),

          // ── Maliyet ve Gelir (Yönetici Özeti) ──
          () {
            double income = 0;
            double labor = 0;
            double material = 0;

            if (report != null) {
              income = (report['total_revenue'] as num?)?.toDouble() ?? 0;
              labor = (report['estimated_labor_cost'] as num?)?.toDouble() ?? 0;
              material = (report['estimated_material_cost'] as num?)?.toDouble() ?? 0;
            }

            // Eğer report yoksa veya değerler girilmemişse fallback (Mali Proje Analizi mantığı)
            if (income <= 0) {
              final drafts = order['invoice_drafts'] as List?;
              if (drafts != null && drafts.isNotEmpty) {
                income = (drafts.first['total_amount'] as num?)?.toDouble() ?? 0;
              }
            }
            if (labor <= 0) {
              for (final s in sessions) {
                final hrs = (s['approved_billable_hours'] as num?)?.toDouble() ?? 0;
                labor += (hrs * 25.0);
              }
            }
            if (material <= 0) {
              for (final ew in extraWorks) {
                material += (ew['estimated_material_cost'] as num?)?.toDouble() ?? 0;
              }
            }

            final totalExpense = labor + material;
            final profit = income - totalExpense;

            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _sectionTitle(tr('Tahmini Maliyet & Gelir (Yönetici Özeti)'), fontBold),
                pw.Container(
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.blueGrey50,
                    border: pw.Border.all(color: PdfColors.blueGrey100),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          _totalLine(tr('Tahmini Gelir'), _euro.format(income), font, fontBold, bold: false),
                          _totalLine(tr('İşçilik Gideri'), _euro.format(labor), font, fontBold, bold: false),
                          _totalLine(tr('Malzeme Gideri'), _euro.format(material), font, fontBold, bold: false),
                        ],
                      ),
                      pw.SizedBox(height: 4),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          _totalLine(tr('Toplam Gider'), _euro.format(totalExpense), font, fontBold, bold: false),
                          _totalLine(tr('Net Kar'), _euro.format(profit), font, fontBold, bold: true),
                        ],
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 16),
              ],
            );
          }(),

          // ── Müşteri Bilgileri & Finansal Detaylar ──
          _sectionTitle(tr('Kundeninformationen (Finanzinformationen)'), fontBold),
          _infoTable([
            if ((customer['secondary_contact_name']?.toString().trim() ?? '').isNotEmpty) 
              [tr('İkinci Muhatap'), customer['secondary_contact_name']],
            if ((customer['vat_number']?.toString().trim() ?? '').isNotEmpty) 
              [tr('USt-IdNr.'), customer['vat_number']],
            if ((customer['bank_name']?.toString().trim() ?? '').isNotEmpty) 
              [tr('Bankname'), customer['bank_name']],
            if ((customer['iban']?.toString().trim() ?? '').isNotEmpty) 
              ['IBAN', customer['iban']],
            if ((customer['bic']?.toString().trim() ?? '').isNotEmpty) 
              ['BIC / SWIFT', customer['bic']],
            if ([customer['secondary_contact_name'], customer['vat_number'], customer['bank_name'], customer['iban'], customer['bic']]
                  .every((e) => e == null || e.toString().trim().isEmpty))
              [tr('Finansal Bilgiler'), tr('Kayıtlı finansal bilgi bulunmuyor.')],
          ], font, fontBold),
          pw.SizedBox(height: 16),

          // ── Notlar ──
          if (report != null) ...[
            _sectionTitle(tr('Notlar & Değerlendirme'), fontBold),
            if ((report['summary_note'] ?? '').isNotEmpty) ...[
              pw.Text(tr('Genel Özet'), style: pw.TextStyle(font: fontBold, fontSize: 10)),
              pw.Text(report['summary_note'] ?? '',
                  style: pw.TextStyle(font: font, fontSize: 10)),
              pw.SizedBox(height: 8),
            ],
            if ((report['quality_note'] ?? '').isNotEmpty) ...[
              pw.Text(tr('Kalite Notu'), style: pw.TextStyle(font: fontBold, fontSize: 10)),
              pw.Text(report['quality_note'] ?? '',
                  style: pw.TextStyle(font: font, fontSize: 10)),
              pw.SizedBox(height: 8),
            ],
            if ((report['customer_feedback'] ?? '').isNotEmpty) ...[
              pw.Text(tr('Müşteri Geri Bildirimi'), style: pw.TextStyle(font: fontBold, fontSize: 10)),
              pw.Text(report['customer_feedback'] ?? '',
                  style: pw.TextStyle(font: font, fontSize: 10)),
            ],
          ],

          // ── Faturalanabilir Ek İşler Özeti ──
          if (billableExtras.isNotEmpty) ...[
            pw.SizedBox(height: 16),
            _sectionTitle(tr('Faturalanabilir Ek İşler'), fontBold),
            _extraWorksTable(billableExtras, font, fontBold),
          ],
        ],
      ),
    );

    return pdf.save();
  }

  // ─────────────────────────────────────────────────────────
  // GASTWIRTSCHAFTSSERVICE (GWS) RAPORU
  // ─────────────────────────────────────────────────────────
  static Future<Uint8List> buildGwsReportPdf({
    required Map<String, dynamic> plan,
    required List<Map<String, dynamic>> rooms,
    required List<Map<String, dynamic>> areas,
  }) async {
    final pdf = pw.Document();

    final font = await PdfGoogleFonts.notoSansRegular();
    final fontBold = await PdfGoogleFonts.notoSansBold();
    final logoImage = await rootBundle.load('assets/logo.jpeg');
    final logo = pw.MemoryImage(logoImage.buffer.asUint8List());

    final order = plan['order'] as Map<String, dynamic>? ?? {};
    final object = plan['object'] as Map<String, dynamic>? ?? {};
    final leader = plan['leader'] as Map<String, dynamic>? ?? {};

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        theme: pw.ThemeData.withFont(base: font, bold: fontBold),
        header: (context) => _buildHeader(context, font, fontBold, logo: logo),
        footer: (context) => _buildFooter(context, font, fontBold),
        build: (context) => [
          pw.Header(
            level: 0,
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('OPERATİONEL GWS RAPORU', style: pw.TextStyle(font: fontBold, fontSize: 18, color: PdfColors.blueGrey800)),
                pw.Text('v1.19.8', style: pw.TextStyle(font: font, fontSize: 10, color: PdfColors.grey)),
              ],
            ),
          ),
          pw.SizedBox(height: 10),
          
          _sectionTitle('Genel Bilgiler', fontBold),
          _infoTable([
            ['Müşteri / Otel', object['name'] ?? '-'],
            ['Sipariş (Auftrag)', order['title'] ?? '-'],
            ['Plan Tarihi', _fmtDate(plan['plan_date'])],
            ['Saha Sorumlusu', '${leader['first_name'] ?? ''} ${leader['last_name'] ?? ''}'],
            ['Rapor Durumu', plan['status'] ?? 'Draft'],
          ], font, fontBold),
          pw.SizedBox(height: 20),

          if (rooms.isNotEmpty) ...[
            _sectionTitle('Zimmerliste / Oda Detayları', fontBold),
            _gwsItemsTable(rooms, true, font, fontBold),
            pw.SizedBox(height: 20),
          ],

          if (areas.isNotEmpty) ...[
            _sectionTitle('Bereiche / Ortak Alanlar', fontBold),
            _gwsItemsTable(areas, false, font, fontBold),
            pw.SizedBox(height: 20),
          ],

          _sectionTitle('Müşteri Onayı (External Manager)', fontBold),
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey300),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Müşteri Notu:', style: pw.TextStyle(font: fontBold, fontSize: 10)),
                pw.Text(plan['customer_comment'] ?? '-', style: pw.TextStyle(font: font, fontSize: 10)),
                pw.SizedBox(height: 15),
                if (plan['customer_signature'] != null) ...[
                  pw.Text('Elektronik İmza:', style: pw.TextStyle(font: fontBold, fontSize: 10)),
                  pw.SizedBox(height: 5),
                  pw.Container(
                    height: 60,
                    width: 150,
                    child: pw.Image(pw.MemoryImage(base64Decode(plan['customer_signature'])), fit: pw.BoxFit.contain),
                  ),
                  pw.SizedBox(height: 5),
                  pw.Text('İmza Tarihi: ${_fmtTimestamp(plan['signed_at'])}', style: pw.TextStyle(font: font, fontSize: 8, color: PdfColors.grey600)),
                ] else
                  pw.Text('Dijital imza henüz atılmamıştır.', style: pw.TextStyle(font: font, fontSize: 10, color: PdfColors.red)),
              ],
            ),
          ),
        ],
      ),
    );

    return pdf.save();
  }

  static pw.Widget _gwsItemsTable(List<Map<String, dynamic>> items, bool isRoom, pw.Font font, pw.Font fontBold) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey200),
      columnWidths: {
        0: const pw.FixedColumnWidth(80),
        1: const pw.FlexColumnWidth(2),
        2: const pw.FlexColumnWidth(1),
        3: const pw.FixedColumnWidth(60),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.blueGrey700),
          children: [
            pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(isRoom ? 'Oda No' : 'Alan Adı', style: pw.TextStyle(color: PdfColors.white, font: fontBold, fontSize: 9))),
            pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('Checklist / Notlar', style: pw.TextStyle(color: PdfColors.white, font: fontBold, fontSize: 9))),
            pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('Çalışan', style: pw.TextStyle(color: PdfColors.white, font: fontBold, fontSize: 9))),
            pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('Durum', style: pw.TextStyle(color: PdfColors.white, font: fontBold, fontSize: 9))),
          ],
        ),
        ...items.map((itm) {
          final checklist = itm['checklist_data'] as Map? ?? {};
          final checklistStr = checklist.entries.where((e) => e.value == true).map((e) => 'v ${e.key}').join(', ');
          
          return pw.TableRow(children: [
            pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(isRoom ? '${itm['room_number']}' : '${itm['area_name']}', style: pw.TextStyle(font: fontBold, fontSize: 9))),
            pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(checklistStr.isEmpty ? 'Kayıt bulunmuyor' : checklistStr, style: pw.TextStyle(font: font, fontSize: 8)),
                if (itm['worker_notes'] != null)
                  pw.Text('Not: ${itm['worker_notes']}', style: pw.TextStyle(font: font, fontSize: 7, color: PdfColors.grey600, fontStyle: pw.FontStyle.italic)),
              ],
            )),
            pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('-', style: pw.TextStyle(font: font, fontSize: 8))),
            pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(
              itm['checker_status']?.toUpperCase() ?? 'PENDING',
              style: pw.TextStyle(font: fontBold, fontSize: 8, color: itm['checker_status'] == 'ok' ? PdfColors.green700 : PdfColors.red700),
            )),
          ]);
        }),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────
  // ÖN FATURA TASLAĞI PDF
  // ─────────────────────────────────────────────────────────
  static Future<Uint8List> buildInvoiceDraftPdf({
    required Map<String, dynamic> draft,
    required List<Map<String, dynamic>> items,
    double? laborCost,
    double? materialCost,
  }) async {
    final pdf = pw.Document();

    final font = await PdfGoogleFonts.notoSansRegular();
    final fontBold = await PdfGoogleFonts.notoSansBold();
    final logoImage = await rootBundle.load('assets/logo.jpeg');
    final logo = pw.MemoryImage(logoImage.buffer.asUint8List());

    final customer = draft['customer'] as Map<String, dynamic>? ?? {};
    final company = draft['issuing_company'] as Map<String, dynamic>? ?? {};
    final subtotal = (draft['subtotal'] as num?)?.toDouble() ?? 0;
    final taxAmount = (draft['tax_amount'] as num?)?.toDouble() ?? 0;
    final total = (draft['total_amount'] as num?)?.toDouble() ?? 0;
    final taxRate = (draft['tax_rate'] as num?)?.toDouble() ?? 19;

    final mainItems = items.where((i) => i['item_type'] == 'main').toList();
    final extraItems = items.where((i) => i['item_type'] == 'extra').toList();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        theme: pw.ThemeData.withFont(base: font, bold: fontBold),
        header: (context) => _buildHeader(context, font, fontBold, logo: logo),
        footer: (context) => _buildFooter(context, font, fontBold),
        build: (context) => [
          pw.SizedBox(height: 2),
          // ── Başlık ──
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(vertical: 12),
            decoration: const pw.BoxDecoration(
              border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(tr('ÖN FATURA TASLAĞI'),
                        style: pw.TextStyle(
                            font: fontBold, fontSize: 18, color: PdfColors.blueGrey800)),
                    pw.Text(draft['draft_number'] ?? '',
                        style: pw.TextStyle(font: font, fontSize: 12, color: PdfColors.grey600)),
                  ],
                ),
                pw.Text(
                  '${tr('Tarih')}: ${_date.format(DateTime.now())}',
                  style: pw.TextStyle(font: font, fontSize: 10, color: PdfColors.grey600),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 20),

          // ── Taraflar ──
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(tr('FATURALAYIN'), style: pw.TextStyle(font: fontBold, fontSize: 9, color: PdfColors.grey500)),
                    pw.SizedBox(height: 4),
                    pw.Text(formatCompanyName(company['name'] ?? ''), style: pw.TextStyle(font: fontBold, fontSize: 11)),
                    if (company['address'] != null)
                      pw.Text(company['address'], style: pw.TextStyle(font: font, fontSize: 8, color: PdfColors.grey700)),
                    if (company['iban'] != null)
                      pw.Text('IBAN: ${company['iban']}', style: pw.TextStyle(font: font, fontSize: 9, color: PdfColors.grey700)),
                    if (company['bic'] != null)
                      pw.Text('BIC: ${company['bic']}', style: pw.TextStyle(font: font, fontSize: 9, color: PdfColors.grey700)),
                    if (company['tax_number'] != null)
                      pw.Text('St.Nr: ${company['tax_number']}', style: pw.TextStyle(font: font, fontSize: 9, color: PdfColors.grey700)),
                  ],
                ),
              ),
              pw.SizedBox(width: 20),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(tr('MÜŞTERİ'), style: pw.TextStyle(font: fontBold, fontSize: 9, color: PdfColors.grey500)),
                    pw.SizedBox(height: 4),
                    pw.Text(customer['name'] ?? '', style: pw.TextStyle(font: fontBold, fontSize: 11)),
                    if ((draft['billing_address'] ?? '').isNotEmpty)
                      pw.Text(draft['billing_address'] ?? '', style: pw.TextStyle(font: font, fontSize: 9, color: PdfColors.grey700)),
                    if ((customer['vat_number'] ?? '').isNotEmpty)
                      pw.Text('USt-IdNr: ${customer['vat_number']}', style: pw.TextStyle(font: font, fontSize: 9, color: PdfColors.grey700)),
                    if ((customer['tax_number'] ?? '').isNotEmpty)
                      pw.Text('St.Nr: ${customer['tax_number']}', style: pw.TextStyle(font: font, fontSize: 9, color: PdfColors.grey700)),
                    if ((customer['iban'] ?? '').isNotEmpty)
                      pw.Text('IBAN: ${customer['iban']}', style: pw.TextStyle(font: font, fontSize: 9, color: PdfColors.grey700)),
                  ],
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 16),

          // ── Hizmet Tarihi & Muhatap ──
          if (draft['service_date_from'] != null || draft['service_date_to'] != null)
            _infoTable([
              [
                tr('Hizmet Tarihi'),
                '${_fmtDate(draft['service_date_from'])} – ${_fmtDate(draft['service_date_to'])}'
              ],
              if ((draft['site_address'] ?? '').isNotEmpty) [tr('Hizmet Adresi'), draft['site_address']],
              if ((draft['contact_name'] ?? '').isNotEmpty) [tr('Muhatap'), draft['contact_name']],
              if ((draft['payment_terms'] ?? '').isNotEmpty) [tr('Ödeme Koşulu'), draft['payment_terms']],
            ], font, fontBold),
          pw.SizedBox(height: 20),

          // ── Ana Kalemler ──
          if (mainItems.isNotEmpty) ...[
            _sectionTitle(tr('Ana Hizmet Kalemleri'), fontBold),
            _itemsTable(mainItems, font, fontBold),
            pw.SizedBox(height: 12),
          ],

          // ── Ek Kalemler ──
          if (extraItems.isNotEmpty) ...[
            _sectionTitle(tr('Ek Hizmet Kalemleri (Detaylı)'), fontBold),
            _itemsTable(extraItems, font, fontBold, isExtra: true),
            pw.SizedBox(height: 12),
          ],

          // ── Toplamlar ──
          pw.Container(
            alignment: pw.Alignment.centerRight,
            child: pw.Container(
              width: 220,
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey300),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
              ),
              padding: const pw.EdgeInsets.all(12),
              child: pw.Column(
                children: [
                  _totalLine(tr('Ara Toplam'), _euro.format(subtotal), font, fontBold, bold: false),
                  _totalLine(
                      '${tr('KDV')} (${taxRate.toStringAsFixed(0)}%)',
                      _euro.format(taxAmount),
                      font,
                      fontBold,
                      bold: false),
                  pw.Divider(color: PdfColors.grey300),
                  _totalLine(tr('GENEL TOPLAM'), _euro.format(total), font, fontBold, bold: true),
                ],
              ),
            ),
          ),

          // ── Intern Analyse (Yönetici Özeti) ──
          pw.SizedBox(height: 20),
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              color: PdfColors.blueGrey50,
              border: pw.Border.all(color: PdfColors.blueGrey100),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(tr('İNTERNAL ANALİZ (Sadece Yönetici Görür)'), style: pw.TextStyle(font: fontBold, fontSize: 8, color: PdfColors.blueGrey700)),
                pw.SizedBox(height: 6),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    _totalLine(tr('Toplam Gelir'), _euro.format(total), font, fontBold, bold: false),
                    _totalLine(tr('İşçilik Gideri'), _euro.format(laborCost ?? 0), font, fontBold, bold: false),
                    _totalLine(tr('Malzeme Gideri'), _euro.format(materialCost ?? 0), font, fontBold, bold: false),
                  ],
                ),
                pw.SizedBox(height: 4),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    _totalLine(tr('Toplam Gider'), _euro.format((laborCost ?? 0) + (materialCost ?? 0)), font, fontBold, bold: false),
                    _totalLine(tr('Net Kar'), _euro.format(total - (laborCost ?? 0) - (materialCost ?? 0)), font, fontBold, bold: true),
                  ],
                ),
              ],
            ),
          ),

          // ── Notlar ──
          if ((draft['notes'] ?? '').isNotEmpty || (draft['accounting_note'] ?? '').isNotEmpty) ...[
            pw.SizedBox(height: 20),
            _sectionTitle(tr('Notlar'), fontBold),
            if ((draft['notes'] ?? '').isNotEmpty)
              pw.Text(draft['notes'] ?? '', style: pw.TextStyle(font: font, fontSize: 10)),
            if ((draft['accounting_note'] ?? '').isNotEmpty) ...[
              pw.SizedBox(height: 4),
              pw.Text('${tr('Muhasebe Notu')}: ${draft['accounting_note']}', style: pw.TextStyle(font: font, fontSize: 9, color: PdfColors.grey700, fontStyle: pw.FontStyle.italic)),
            ],
          ],

          // ── Durum ──
          pw.SizedBox(height: 20),
          pw.Container(
            padding: const pw.EdgeInsets.all(8),
            decoration: pw.BoxDecoration(
              color: PdfColors.amber50,
              border: pw.Border.all(color: PdfColors.amber),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
            ),
            child: pw.Text(
              tr('Bu belge ön fatura taslağıdır. Resmi fatura değildir.'),
              style: pw.TextStyle(font: fontBold, fontSize: 9, color: PdfColors.orange800),
            ),
          ),
        ],
      ),
    );

    return pdf.save();
  }

  // ─────────────────────────────────────────────────────────
  // YARDIMCI WIDGET'LAR
  // ─────────────────────────────────────────────────────────

  static pw.Widget _buildHeader(pw.Context context, pw.Font font, pw.Font fontBold, {pw.MemoryImage? logo}) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 6),
      margin: const pw.EdgeInsets.only(bottom: 6),
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: PdfColors.black, width: 0.5)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('Hanse Kollektiv GmbH', style: pw.TextStyle(font: fontBold, fontSize: 13)),
              pw.Text('Bau- und Gebäudeservice', style: pw.TextStyle(fontSize: 8.5, color: PdfColors.grey700)),
              pw.SizedBox(height: 2),
              pw.Text('Eiffestr. 598, 20537 Hamburg', style: pw.TextStyle(fontSize: 8.5, color: PdfColors.grey700)),
              pw.Text('Tel: 040 303 978 87 / Fax: 040 303 978 88', style: pw.TextStyle(fontSize: 8.5, color: PdfColors.grey700)),
              pw.Text('E-Mail: info@hansekollektiv.de, www.hansekollektiv.de', style: pw.TextStyle(fontSize: 8.5, color: PdfColors.grey700)),
            ],
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              if (logo != null)
                pw.Container(
                  height: 40,
                  child: pw.Image(logo, fit: pw.BoxFit.contain),
                ),
              pw.SizedBox(height: 6),
              _buildMetaInfo(font, fontBold),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildMetaInfo(pw.Font font, pw.Font fontBold) {
    return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: [
          _metaLine('Steuer-Nr:', '46/728/03670', font, fontBold),
          _metaLine('UST-ID:', 'DE293806070', font, fontBold),
          _metaLine('Tel:', '040 303 978 87', font, fontBold),
          _metaLine('Datum:', _date.format(DateTime.now()), font, fontBold),
        ],
    );
  }

  static pw.Widget _metaLine(String label, String value, pw.Font font, pw.Font fontBold) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 2),
      child: pw.Row(
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          pw.SizedBox(width: 80, child: pw.Text(label, style: pw.TextStyle(font: font, fontSize: 9, color: PdfColors.grey700))),
          pw.Text(value, style: pw.TextStyle(font: font, fontSize: 10)),
        ],
      ),
    );
  }

  static pw.Widget _buildFooter(pw.Context context, pw.Font font, pw.Font fontBold) {
    return pw.Container(
      decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: PdfColors.black, width: 0.5)),
      ),
      padding: const pw.EdgeInsets.only(top: 10),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('Bankverbindung: Hamburger Sparkasse', style: pw.TextStyle(font: font, fontSize: 9)),
              pw.Text('IBAN: DE44 2005 0550 1015 2289 82', style: pw.TextStyle(font: font, fontSize: 9)),
              pw.Text('BIC: HASPDEHHXXX', style: pw.TextStyle(font: font, fontSize: 9)),
            ],
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text('Geschäftsführer: Ekrem Demir', style: pw.TextStyle(font: font, fontSize: 9)),
              pw.Text('HRB: 130529', style: pw.TextStyle(font: font, fontSize: 9)),
              pw.SizedBox(height: 4),
              pw.Text('Sayfa ${context.pageNumber} / ${context.pagesCount}', style: pw.TextStyle(font: font, fontSize: 8, color: PdfColors.grey500)),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _sectionTitle(String title, pw.Font fontBold) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 2),
      margin: const pw.EdgeInsets.only(bottom: 4, top: 2),
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: PdfColors.blueGrey100, width: 0.5)),
      ),
      child: pw.Text(
        title,
        style: pw.TextStyle(font: fontBold, fontSize: 11, color: PdfColors.blueGrey700),
      ),
    );
  }

  static pw.Widget _infoTable(
      List<List<String>> rows, pw.Font font, pw.Font fontBold) {
    return pw.Table(
      columnWidths: {
        0: const pw.FixedColumnWidth(130),
        1: const pw.FlexColumnWidth(),
      },
      children: rows.map((row) {
        return pw.TableRow(children: [
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 2, horizontal: 4),
            child: pw.Text(row[0],
                style: pw.TextStyle(font: fontBold, fontSize: 9, color: PdfColors.grey600)),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 2, horizontal: 4),
            child: pw.Text(row.length > 1 ? row[1] : '-',
                style: pw.TextStyle(font: font, fontSize: 10)),
          ),
        ]);
      }).toList(),
    );
  }

  static pw.Widget _sessionsTable(
      List<Map<String, dynamic>> sessions, pw.Font font, pw.Font fontBold) {
    final headerStyle = pw.TextStyle(font: fontBold, fontSize: 9, color: PdfColors.white);
    final cellStyle = pw.TextStyle(font: font, fontSize: 9);

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey200),
      columnWidths: {
        0: const pw.FlexColumnWidth(2),
        1: const pw.FlexColumnWidth(1.5),
        2: const pw.FlexColumnWidth(1.5),
        3: const pw.FixedColumnWidth(60),
        4: const pw.FixedColumnWidth(60),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.blueGrey700),
          children: [tr('Çalışan'), tr('Başlangıç'), tr('Bitiş'), tr('Fiili'), tr('Faturalanan')]
              .map((h) => pw.Padding(
                    padding: const pw.EdgeInsets.all(4),
                    child: pw.Text(h, style: headerStyle),
                  ))
              .toList(),
        ),
        ...sessions.map((s) {
          final user = s['user'] as Map<String, dynamic>? ?? {};
          final name = '${user['first_name'] ?? ''} ${user['last_name'] ?? ''}'.trim();
          return pw.TableRow(children: [
            pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(name.isEmpty ? '-' : name, style: cellStyle)),
            pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(_fmtTimestamp(s['actual_start']), style: cellStyle)),
            pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(_fmtTimestamp(s['actual_end']), style: cellStyle)),
            pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('${((s['actual_duration_h'] as num?)?.toDouble() ?? 0).toStringAsFixed(1)}h', style: cellStyle)),
            pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('${((s['approved_billable_hours'] as num?)?.toDouble() ?? (s['billable_hours'] as num?)?.toDouble() ?? 0).toStringAsFixed(1)}h', style: cellStyle)),
          ]);
        }),
      ],
    );
  }

  static pw.Widget _extraWorksTable(
      List<Map<String, dynamic>> works, pw.Font font, pw.Font fontBold) {
    final headerStyle = pw.TextStyle(font: fontBold, fontSize: 9, color: PdfColors.white);
    final cellStyle = pw.TextStyle(font: font, fontSize: 9);

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey200),
      columnWidths: {
        0: const pw.FlexColumnWidth(3),
        1: const pw.FixedColumnWidth(60),
        2: const pw.FixedColumnWidth(70),
        3: const pw.FixedColumnWidth(80),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.blueGrey700),
          children: [tr('Ek İş Başlığı'), tr('Tarih'), tr('Süre'), tr('Durum')]
              .map((h) => pw.Padding(
                    padding: const pw.EdgeInsets.all(4),
                    child: pw.Text(h, style: headerStyle),
                  ))
              .toList(),
        ),
        ...works.map((ew) => pw.TableRow(children: [
          pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(ew['title'] ?? '-', style: cellStyle)),
          pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(_fmtDate(ew['work_date']), style: cellStyle)),
          pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(ew['duration_h'] != null ? '${ew['duration_h']}h' : '-', style: cellStyle)),
          pw.Padding(
            padding: const pw.EdgeInsets.all(4),
            child: pw.Text(
              ew['is_billable'] == true ? tr('Fatural.') : ew['is_billable'] == false ? tr('Fatural. değil') : tr('Bek.'),
              style: pw.TextStyle(
                font: fontBold,
                fontSize: 8,
                color: ew['is_billable'] == true ? PdfColors.green700 : ew['is_billable'] == false ? PdfColors.red700 : PdfColors.orange700,
              ),
            ),
          ),
        ])),
      ],
    );
  }

  static pw.Widget _itemsTable(
      List<Map<String, dynamic>> items, pw.Font font, pw.Font fontBold, {bool isExtra = false}) {
    final headerStyle = pw.TextStyle(font: fontBold, fontSize: 9, color: PdfColors.white);
    final cellStyle = pw.TextStyle(font: font, fontSize: 10);

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey200),
      columnWidths: {
        0: const pw.FlexColumnWidth(4),
        if (isExtra) 1: const pw.FlexColumnWidth(2), // Sorumlu/Yapan
        if (isExtra) 2: const pw.FixedColumnWidth(60), // Süre
        if (!isExtra) 1: const pw.FixedColumnWidth(50), 
        if (!isExtra) 2: const pw.FixedColumnWidth(50),
        3: const pw.FixedColumnWidth(80),
        4: const pw.FixedColumnWidth(80),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.blueGrey700),
          children: [
            tr('Açıklama'), 
            if (isExtra) tr('Yapan / Kaydeden') else tr('Miktar'),
            if (isExtra) tr('Süre (h)') else tr('Birim'), 
            tr('Birim Fiyat'), 
            tr('Toplam')
          ].map((h) => pw.Padding(
                    padding: const pw.EdgeInsets.all(4),
                    child: pw.Text(h, style: headerStyle),
                  ))
              .toList(),
        ),
        ...items.map((item) {
          // Eğer ek iş ise açıklamadan yapan kişiyi çıkarmaya çalışalım veya ham veriyi kullanalım
          // Not: invoice_draft_items tablosunda bu bilgi yoksa description içinde olabilir.
          return pw.TableRow(children: [
            pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(item['description'] ?? '-', style: cellStyle)),
            if (isExtra)
              pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(item['recorded_by_name'] ?? 'Saha Ekibi', style: cellStyle))
            else
              pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('${item['quantity'] ?? 1}', style: cellStyle)),
            
            if (isExtra)
              pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('${item['quantity'] ?? 0}h', style: cellStyle))
            else
              pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(item['unit'] ?? '-', style: cellStyle)),

            pw.Padding(
              padding: const pw.EdgeInsets.all(5),
              child: pw.Text(
                item['unit_price'] != null ? _euro.format(item['unit_price']) : '-',
                style: cellStyle,
              ),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(5),
              child: pw.Text(
                item['total_price'] != null ? _euro.format(item['total_price']) : '-',
                style: pw.TextStyle(font: fontBold, fontSize: 10),
                textAlign: pw.TextAlign.right,
              ),
            ),
          ]);
        }),
      ],
    );
  }

  static pw.Widget _totalLine(
      String label, String value, pw.Font font, pw.Font fontBold,
      {required bool bold}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label,
              style: pw.TextStyle(
                  font: bold ? fontBold : font,
                  fontSize: bold ? 12 : 10,
                  color: bold ? PdfColors.black : PdfColors.grey700)),
          pw.Text(value,
              style: pw.TextStyle(
                  font: bold ? fontBold : font,
                  fontSize: bold ? 13 : 10,
                  color: bold ? PdfColors.black : PdfColors.grey700)),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  // PDF'İ PAYLAŞ / YAZDIR
  // ─────────────────────────────────────────────────────────
  static Future<void> previewPdf(Uint8List bytes, String title) async {
    await Printing.layoutPdf(
      onLayout: (_) async => bytes,
      name: title,
    );
  }

  static Future<void> sharePdf(Uint8List bytes, String filename) async {
    await Printing.sharePdf(bytes: bytes, filename: filename);
  }

  // ─────────────────────────────────────────────────────────
  // YARDIMCI FONKSİYONLAR
  // ─────────────────────────────────────────────────────────
  static String _fmtDate(dynamic val) {
    if (val == null) return '-';
    try {
      final dt = DateTime.parse(val.toString());
      return _date.format(dt);
    } catch (_) {
      return val.toString();
    }
  }

  static String _fmtTimestamp(dynamic val) {
    if (val == null) return '-';
    try {
      final dt = DateTime.parse(val.toString()).toLocal();
      return DateFormat('dd.MM HH:mm').format(dt);
    } catch (_) {
      return '-';
    }
  }

  static String _fmtEuro(dynamic val) {
    if (val == null) return '-';
    final d = double.tryParse(val.toString()) ?? 0;
    return _euro.format(d);
  }

  static double? _calcMargin(Map<String, dynamic> report) {
    final rev = (report['total_revenue'] as num?)?.toDouble();
    final labor = (report['estimated_labor_cost'] as num?)?.toDouble() ?? 0;
    final material = (report['estimated_material_cost'] as num?)?.toDouble() ?? 0;
    if (rev == null) return null;
    return rev - labor - material;
  }

  // ─────────────────────────────────────────────────────────
  // AYLIK RAPOR PDF
  // ─────────────────────────────────────────────────────────
  static Future<Uint8List> buildMonthlyReportPdf({
    required int year,
    required int month,
    required double totalIncome,
    required double totalLaborCost,
    required double totalMaterialCost,
    required double totalProfit,
    required List<Map<String, dynamic>> dailyData,
  }) async {
    final pdf = pw.Document();
    final font = await PdfGoogleFonts.notoSansRegular();
    final fontBold = await PdfGoogleFonts.notoSansBold();
    final logoImage = await rootBundle.load('assets/logo.jpeg');
    final logo = pw.MemoryImage(logoImage.buffer.asUint8List());

    final monthNames = ['', tr('Ocak'), tr('Şubat'), tr('Mart'), tr('Nisan'), tr('Mayıs'), tr('Haziran'), tr('Temmuz'), tr('Ağustos'), tr('Eylül'), tr('Ekim'), tr('Kasım'), tr('Aralık')];
    final monthName = monthNames[month];

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        theme: pw.ThemeData.withFont(base: font, bold: fontBold),
        header: (context) => _buildHeader(context, font, fontBold, logo: logo),
        footer: (context) => _buildFooter(context, font, fontBold),
        build: (context) => [
          pw.SizedBox(height: 2),
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(vertical: 12),
            decoration: const pw.BoxDecoration(
              border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300)),
            ),
            child: pw.Text('${tr('AYLIK MALI RAPOR')} - $monthName $year',
                style: pw.TextStyle(font: fontBold, fontSize: 18, color: PdfColors.blueGrey800)),
          ),
          pw.SizedBox(height: 16),

          _sectionTitle(tr('Genel Özet'), fontBold),
          _infoTable([
            [tr('Toplam Gelir'), _euro.format(totalIncome)],
            [tr('Toplam İşçilik Gideri'), _euro.format(totalLaborCost)],
            [tr('Toplam Malzeme Gideri'), _euro.format(totalMaterialCost)],
            [tr('Toplam Gider'), _euro.format(totalLaborCost + totalMaterialCost)],
            [tr('Net Kar'), _euro.format(totalProfit)],
          ], font, fontBold),
          pw.SizedBox(height: 20),

          _sectionTitle(tr('Günlük Döküm'), fontBold),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey200),
            columnWidths: {
              0: const pw.FlexColumnWidth(2),
              1: const pw.FlexColumnWidth(1.5),
              2: const pw.FlexColumnWidth(1.5),
              3: const pw.FlexColumnWidth(1.5),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.blueGrey700),
                children: [tr('Tarih'), tr('Gelir'), tr('Gider'), tr('Net Kar')]
                    .map((h) => pw.Padding(
                          padding: const pw.EdgeInsets.all(4),
                          child: pw.Text(h, style: pw.TextStyle(font: fontBold, fontSize: 9, color: PdfColors.white)),
                        ))
                    .toList(),
              ),
              ...dailyData.map((d) => pw.TableRow(children: [
                pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(d['date'] ?? '', style: pw.TextStyle(font: font, fontSize: 9))),
                pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(_euro.format(d['income'] ?? 0), style: pw.TextStyle(font: font, fontSize: 9))),
                pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(_euro.format(d['expense'] ?? 0), style: pw.TextStyle(font: font, fontSize: 9))),
                pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(_euro.format(d['profit'] ?? 0), style: pw.TextStyle(font: fontBold, fontSize: 9))),
              ])),
            ],
          ),
        ],
      ),
    );
    return pdf.save();
  }

  // ─────────────────────────────────────────────────────────
  // PERSONEL SAATLERİ PDF
  // ─────────────────────────────────────────────────────────
  static Future<Uint8List> buildPersonnelHoursPdf({
    required int year,
    required int month,
    required List<Map<String, dynamic>> personnelData,
  }) async {
    final pdf = pw.Document();
    final font = await PdfGoogleFonts.notoSansRegular();
    final fontBold = await PdfGoogleFonts.notoSansBold();

    final monthNames = ['', tr('Ocak'), tr('Şubat'), tr('Mart'), tr('Nisan'), tr('Mayıs'), tr('Haziran'), tr('Temmuz'), tr('Ağustos'), tr('Eylül'), tr('Ekim'), tr('Kasım'), tr('Aralık')];
    final monthName = monthNames[month];

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        theme: pw.ThemeData.withFont(base: font, bold: fontBold),
        header: (context) => _buildHeader(context, font, fontBold),
        footer: (context) => _buildFooter(context, font, fontBold),
        build: (context) => [
          pw.SizedBox(height: 2),
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(vertical: 12),
            decoration: const pw.BoxDecoration(
              border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300)),
            ),
            child: pw.Text('${tr('PERSONEL CALISMA SAATLERI')} - $monthName $year',
                style: pw.TextStyle(font: fontBold, fontSize: 18, color: PdfColors.blueGrey800)),
          ),
          pw.SizedBox(height: 16),

          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey200),
            columnWidths: {
              0: const pw.FixedColumnWidth(30),
              1: const pw.FlexColumnWidth(3),
              2: const pw.FlexColumnWidth(2),
              3: const pw.FlexColumnWidth(1.5),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.blueGrey700),
                children: ['#', tr('Çalışan'), tr('Pozisyon'), tr('Toplam Saat')]
                    .map((h) => pw.Padding(
                          padding: const pw.EdgeInsets.all(5),
                          child: pw.Text(h, style: pw.TextStyle(font: fontBold, fontSize: 10, color: PdfColors.white)),
                        ))
                    .toList(),
              ),
              ...personnelData.asMap().entries.map((entry) {
                final i = entry.key;
                final p = entry.value;
                return pw.TableRow(children: [
                  pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('${i + 1}', style: pw.TextStyle(font: font, fontSize: 10))),
                  pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(p['name'] ?? '', style: pw.TextStyle(font: font, fontSize: 10))),
                  pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(AppTheme.roleLabel(p['role'] ?? ''), style: pw.TextStyle(font: font, fontSize: 10))),
                  pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('${(p['hours'] as num?)?.toStringAsFixed(1) ?? '0.0'} h', style: pw.TextStyle(font: fontBold, fontSize: 10))),
                ]);
              }),
            ],
          ),
          pw.SizedBox(height: 16),
          pw.Text(
            '${tr('Toplam')}: ${personnelData.fold<double>(0, (sum, p) => sum + ((p['hours'] as num?)?.toDouble() ?? 0)).toStringAsFixed(1)} ${tr('saat')}',
            style: pw.TextStyle(font: fontBold, fontSize: 12, color: PdfColors.blueGrey800),
          ),
        ],
      ),
    );
    return pdf.save();
  }
}


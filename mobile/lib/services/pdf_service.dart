import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';

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
        margin: const pw.EdgeInsets.all(36),
        theme: pw.ThemeData.withFont(base: font, bold: fontBold),
        header: (context) => _buildHeader(fontBold),
        footer: (context) => _buildFooter(context, font),
        build: (context) => [
          // ── Başlık ──
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(vertical: 12),
            decoration: const pw.BoxDecoration(
              border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('İŞ SONU RAPORU',
                    style: pw.TextStyle(font: fontBold, fontSize: 18, color: PdfColors.blueGrey800)),
                pw.Text(
                  'Oluşturma: ${_date.format(DateTime.now())}',
                  style: pw.TextStyle(font: font, fontSize: 10, color: PdfColors.grey600),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 16),

          // ── İş Özeti ──
          _sectionTitle('İş Bilgileri', fontBold),
          _infoTable([
            ['İş Numarası', order['order_number'] ?? '-'],
            ['İş Başlığı', order['title'] ?? '-'],
            ['Müşteri', customer['name'] ?? '-'],
            ['Hizmet Alanı', serviceArea['name'] ?? '-'],
            ['Saha Adresi', order['site_address'] ?? '-'],
            [
              'Tarih Aralığı',
              '${_fmtDate(order['planned_start_date'])} – ${_fmtDate(order['planned_end_date'])}'
            ],
          ], font, fontBold),
          pw.SizedBox(height: 16),

          // ── Çalışma Süreleri ──
          _sectionTitle('Çalışma Süre Özeti', fontBold),
          _infoTable([
            ['Toplam Fiili Süre', '${totalActual.toStringAsFixed(1)} saat'],
            ['Faturalanabilir Süre', '${totalBillable.toStringAsFixed(1)} saat'],
            ['Fazla Mesai', '${totalExtra.toStringAsFixed(1)} saat'],
            ['Seans Sayısı', '${sessions.length}'],
          ], font, fontBold),

          if (sessions.isNotEmpty) ...[
            pw.SizedBox(height: 10),
            pw.Text('Çalışan Detayı',
                style: pw.TextStyle(font: fontBold, fontSize: 11, color: PdfColors.grey700)),
            pw.SizedBox(height: 6),
            _sessionsTable(sessions, font, fontBold),
          ],
          pw.SizedBox(height: 16),

          // ── Ek İşler ──
          _sectionTitle('Ek İşler (${extraWorks.length})', fontBold),
          if (extraWorks.isEmpty)
            pw.Text('Ek iş kaydı bulunmuyor.',
                style: pw.TextStyle(font: font, fontSize: 10, color: PdfColors.grey500))
          else
            _extraWorksTable(extraWorks, font, fontBold),
          pw.SizedBox(height: 16),

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
                _sectionTitle('Tahmini Maliyet & Gelir (Yönetici Özeti)', fontBold),
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
                          _totalLine('Tahmini Gelir', _euro.format(income), font, fontBold, bold: false),
                          _totalLine('İşçilik Gideri', _euro.format(labor), font, fontBold, bold: false),
                          _totalLine('Malzeme Gideri', _euro.format(material), font, fontBold, bold: false),
                        ],
                      ),
                      pw.SizedBox(height: 4),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          _totalLine('Toplam Gider', _euro.format(totalExpense), font, fontBold, bold: false),
                          _totalLine('Net Kar', _euro.format(profit), font, fontBold, bold: true),
                        ],
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 16),
              ],
            );
          }(),

          // ── Müşteri Bilgileri (Bölüm 1) ──
          _sectionTitle('Müşteri Bilgileri', fontBold),
          _infoTable([
            ['Banka', customer['bank_name'] ?? '-'],
            ['IBAN', customer['iban'] ?? '-'],
            ['BIC', customer['bic'] ?? '-'],
            ['USt-IdNr.', customer['vat_number'] ?? '-'],
            if (customer['secondary_contact_name'] != null) ['İkinci Muhatap', customer['secondary_contact_name']],
          ], font, fontBold),
          pw.SizedBox(height: 16),

          // ── Notlar ──
          if (report != null) ...[
            _sectionTitle('Notlar & Değerlendirme', fontBold),
            if ((report['summary_note'] ?? '').isNotEmpty) ...[
              pw.Text('Genel Özet', style: pw.TextStyle(font: fontBold, fontSize: 10)),
              pw.Text(report['summary_note'] ?? '',
                  style: pw.TextStyle(font: font, fontSize: 10)),
              pw.SizedBox(height: 8),
            ],
            if ((report['quality_note'] ?? '').isNotEmpty) ...[
              pw.Text('Kalite Notu', style: pw.TextStyle(font: fontBold, fontSize: 10)),
              pw.Text(report['quality_note'] ?? '',
                  style: pw.TextStyle(font: font, fontSize: 10)),
              pw.SizedBox(height: 8),
            ],
            if ((report['customer_feedback'] ?? '').isNotEmpty) ...[
              pw.Text('Müşteri Geri Bildirimi', style: pw.TextStyle(font: fontBold, fontSize: 10)),
              pw.Text(report['customer_feedback'] ?? '',
                  style: pw.TextStyle(font: font, fontSize: 10)),
            ],
          ],

          // ── Faturalanabilir Ek İşler Özeti ──
          if (billableExtras.isNotEmpty) ...[
            pw.SizedBox(height: 16),
            _sectionTitle('Faturalanabilir Ek İşler', fontBold),
            _extraWorksTable(billableExtras, font, fontBold),
          ],
        ],
      ),
    );

    return pdf.save();
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
        margin: const pw.EdgeInsets.all(36),
        theme: pw.ThemeData.withFont(base: font, bold: fontBold),
        header: (context) => _buildHeader(fontBold),
        footer: (context) => _buildFooter(context, font),
        build: (context) => [
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
                    pw.Text('ÖN FATURA TASLAĞI',
                        style: pw.TextStyle(
                            font: fontBold, fontSize: 18, color: PdfColors.blueGrey800)),
                    pw.Text(draft['draft_number'] ?? '',
                        style: pw.TextStyle(font: font, fontSize: 12, color: PdfColors.grey600)),
                  ],
                ),
                pw.Text(
                  'Tarih: ${_date.format(DateTime.now())}',
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
                    pw.Text('FATURALAYIN', style: pw.TextStyle(font: fontBold, fontSize: 9, color: PdfColors.grey500)),
                    pw.SizedBox(height: 4),
                    pw.Text(company['name'] ?? '', style: pw.TextStyle(font: fontBold, fontSize: 11)),
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
                    pw.Text('MÜŞTERİ', style: pw.TextStyle(font: fontBold, fontSize: 9, color: PdfColors.grey500)),
                    pw.SizedBox(height: 4),
                    pw.Text(customer['name'] ?? '', style: pw.TextStyle(font: fontBold, fontSize: 11)),
                    if ((draft['billing_address'] ?? '').isNotEmpty)
                      pw.Text(draft['billing_address'] ?? '', style: pw.TextStyle(font: font, fontSize: 9, color: PdfColors.grey700)),
                    if ((draft['billing_tax_number'] ?? '').isNotEmpty)
                      pw.Text('USt-IdNr: ${draft['billing_tax_number']}', style: pw.TextStyle(font: font, fontSize: 9, color: PdfColors.grey700)),
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
                'Hizmet Tarihi',
                '${_fmtDate(draft['service_date_from'])} – ${_fmtDate(draft['service_date_to'])}'
              ],
              if ((draft['site_address'] ?? '').isNotEmpty) ['Hizmet Adresi', draft['site_address']],
              if ((draft['contact_name'] ?? '').isNotEmpty) ['Muhatap', draft['contact_name']],
              if ((draft['payment_terms'] ?? '').isNotEmpty) ['Ödeme Koşulu', draft['payment_terms']],
            ], font, fontBold),
          pw.SizedBox(height: 20),

          // ── Ana Kalemler ──
          if (mainItems.isNotEmpty) ...[
            _sectionTitle('Ana Hizmet Kalemleri', fontBold),
            _itemsTable(mainItems, font, fontBold),
            pw.SizedBox(height: 12),
          ],

          // ── Ek Kalemler ──
          if (extraItems.isNotEmpty) ...[
            _sectionTitle('Ek Hizmet Kalemleri (Detaylı)', fontBold),
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
                  _totalLine('Ara Toplam', _euro.format(subtotal), font, fontBold, bold: false),
                  _totalLine(
                      'KDV (${taxRate.toStringAsFixed(0)}%)',
                      _euro.format(taxAmount),
                      font,
                      fontBold,
                      bold: false),
                  pw.Divider(color: PdfColors.grey300),
                  _totalLine('GENEL TOPLAM', _euro.format(total), font, fontBold, bold: true),
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
                pw.Text('İNTERNAL ANALİZ (Sadece Yönetici Görür)', style: pw.TextStyle(font: fontBold, fontSize: 8, color: PdfColors.blueGrey700)),
                pw.SizedBox(height: 6),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    _totalLine('Toplam Gelir', _euro.format(total), font, fontBold, bold: false),
                    _totalLine('İşçilik Gideri', _euro.format(laborCost ?? 0), font, fontBold, bold: false),
                    _totalLine('Malzeme Gideri', _euro.format(materialCost ?? 0), font, fontBold, bold: false),
                  ],
                ),
                pw.SizedBox(height: 4),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    _totalLine('Toplam Gider', _euro.format((laborCost ?? 0) + (materialCost ?? 0)), font, fontBold, bold: false),
                    _totalLine('Net Kar', _euro.format(total - (laborCost ?? 0) - (materialCost ?? 0)), font, fontBold, bold: true),
                  ],
                ),
              ],
            ),
          ),

          // ── Notlar ──
          if ((draft['notes'] ?? '').isNotEmpty || (draft['accounting_note'] ?? '').isNotEmpty) ...[
            pw.SizedBox(height: 20),
            _sectionTitle('Notlar', fontBold),
            if ((draft['notes'] ?? '').isNotEmpty)
              pw.Text(draft['notes'] ?? '', style: pw.TextStyle(font: font, fontSize: 10)),
            if ((draft['accounting_note'] ?? '').isNotEmpty) ...[
              pw.SizedBox(height: 4),
              pw.Text('Muhasebe Notu: ${draft['accounting_note']}', style: pw.TextStyle(font: font, fontSize: 9, color: PdfColors.grey700, fontStyle: pw.FontStyle.italic)),
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
              'Bu belge ön fatura taslağıdır. Resmi fatura değildir.',
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

  static pw.Widget _buildHeader(pw.Font fontBold) {
    return pw.Container(
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: PdfColors.blueGrey200, width: 0.5)),
      ),
      padding: const pw.EdgeInsets.only(bottom: 8),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text('Hanse Kollektiv GmbH',
              style: pw.TextStyle(font: fontBold, fontSize: 14, color: PdfColors.blueGrey700)),
          pw.Text('Dijital Yönetim Sistemi',
              style: pw.TextStyle(fontSize: 9, color: PdfColors.grey500)),
        ],
      ),
    );
  }

  static pw.Widget _buildFooter(pw.Context context, pw.Font font) {
    return pw.Container(
      decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: PdfColors.grey300, width: 0.5)),
      ),
      padding: const pw.EdgeInsets.only(top: 8),
      child: pw.Column(
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Hanse Kollektiv GmbH • Hamburg • www.hanse-kollektiv.de',
                style: pw.TextStyle(font: font, fontSize: 7, color: PdfColors.grey600),
              ),
              pw.Text(
                'Sayfa ${context.pageNumber} / ${context.pagesCount}',
                style: pw.TextStyle(font: font, fontSize: 8, color: PdfColors.grey500),
              ),
            ],
          ),
          pw.SizedBox(height: 4),
          pw.Text('Bu belge dijital olarak oluşturulmuştur ve imza gerektirmez.', 
              style: pw.TextStyle(font: font, fontSize: 6, color: PdfColors.grey400)),
        ],
      ),
    );
  }

  static pw.Widget _sectionTitle(String title, pw.Font fontBold) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 6),
      margin: const pw.EdgeInsets.only(bottom: 8),
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: PdfColors.blueGrey100, width: 1)),
      ),
      child: pw.Text(
        title,
        style: pw.TextStyle(font: fontBold, fontSize: 12, color: PdfColors.blueGrey700),
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
            padding: const pw.EdgeInsets.symmetric(vertical: 3, horizontal: 4),
            child: pw.Text(row[0],
                style: pw.TextStyle(font: fontBold, fontSize: 9, color: PdfColors.grey600)),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 3, horizontal: 4),
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
          children: ['Çalışan', 'Başlangıç', 'Bitiş', 'Fiili', 'Faturalanan']
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
          children: ['Ek İş Başlığı', 'Tarih', 'Süre', 'Durum']
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
              ew['is_billable'] == true ? 'Fatural.' : ew['is_billable'] == false ? 'Fatural. değil' : 'Bek.',
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
            'Açıklama', 
            if (isExtra) 'Yapan / Kaydeden' else 'Miktar',
            if (isExtra) 'Süre (h)' else 'Birim', 
            'Birim Fiyat', 
            'Toplam'
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

    final monthNames = ['', 'Ocak', 'Subat', 'Mart', 'Nisan', 'Mayis', 'Haziran', 'Temmuz', 'Agustos', 'Eylul', 'Ekim', 'Kasim', 'Aralik'];
    final monthName = monthNames[month];

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        theme: pw.ThemeData.withFont(base: font, bold: fontBold),
        header: (context) => _buildHeader(fontBold),
        footer: (context) => _buildFooter(context, font),
        build: (context) => [
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(vertical: 12),
            decoration: const pw.BoxDecoration(
              border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300)),
            ),
            child: pw.Text('AYLIK MALI RAPOR - $monthName $year',
                style: pw.TextStyle(font: fontBold, fontSize: 18, color: PdfColors.blueGrey800)),
          ),
          pw.SizedBox(height: 16),

          _sectionTitle('Genel Ozet', fontBold),
          _infoTable([
            ['Toplam Gelir', _euro.format(totalIncome)],
            ['Toplam Iscilik Gideri', _euro.format(totalLaborCost)],
            ['Toplam Malzeme Gideri', _euro.format(totalMaterialCost)],
            ['Toplam Gider', _euro.format(totalLaborCost + totalMaterialCost)],
            ['Net Kar', _euro.format(totalProfit)],
          ], font, fontBold),
          pw.SizedBox(height: 20),

          _sectionTitle('Gunluk Dokum', fontBold),
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
                children: ['Tarih', 'Gelir', 'Gider', 'Net Kar']
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

    final monthNames = ['', 'Ocak', 'Subat', 'Mart', 'Nisan', 'Mayis', 'Haziran', 'Temmuz', 'Agustos', 'Eylul', 'Ekim', 'Kasim', 'Aralik'];
    final monthName = monthNames[month];

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        theme: pw.ThemeData.withFont(base: font, bold: fontBold),
        header: (context) => _buildHeader(fontBold),
        footer: (context) => _buildFooter(context, font),
        build: (context) => [
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(vertical: 12),
            decoration: const pw.BoxDecoration(
              border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300)),
            ),
            child: pw.Text('PERSONEL CALISMA SAATLERI - $monthName $year',
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
                children: ['#', 'Calisan', 'Pozisyon', 'Toplam Saat']
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
                  pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(p['role'] ?? '', style: pw.TextStyle(font: font, fontSize: 10))),
                  pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('${(p['hours'] as num?)?.toStringAsFixed(1) ?? '0.0'} h', style: pw.TextStyle(font: fontBold, fontSize: 10))),
                ]);
              }),
            ],
          ),
          pw.SizedBox(height: 16),
          pw.Text(
            'Toplam: ${personnelData.fold<double>(0, (sum, p) => sum + ((p['hours'] as num?)?.toDouble() ?? 0)).toStringAsFixed(1)} saat',
            style: pw.TextStyle(font: fontBold, fontSize: 12, color: PdfColors.blueGrey800),
          ),
        ],
      ),
    );
    return pdf.save();
  }
}


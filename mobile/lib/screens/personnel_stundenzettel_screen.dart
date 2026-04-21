import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../theme/web_utils.dart';
import '../services/supabase_service.dart';
import '../services/pdf_service.dart';
import '../services/localization_service.dart';
import '../providers/app_state.dart';
import '../widgets/signature_pad_widget.dart';

/// Üst yetkililer için: Belirli bir çalışanın aylık Stundenzettel'ini gösterir.
/// Ay seçimi, 31 günlük tablo, onaylanan saatler ve PDF indirme.
class PersonnelStundenzettelScreen extends StatefulWidget {
  final Map<String, dynamic> employee;
  const PersonnelStundenzettelScreen({super.key, required this.employee});

  @override
  State<PersonnelStundenzettelScreen> createState() => _PersonnelStundenzettelScreenState();
}

class _PersonnelStundenzettelScreenState extends State<PersonnelStundenzettelScreen> {
  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  List<Map<String, dynamic>> _sessions = [];
  Map<String, dynamic>? _approvalData;
  bool _loading = false;
  bool _pdfLoading = false;
  String? _newSignature;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final monthStr = '${_selectedMonth.year}-${_selectedMonth.month.toString().padLeft(2, '0')}';
      final appState = context.read<AppState>();
      final isHighLevel = appState.isGeschaeftsfuehrer || appState.isSystemAdmin || appState.isBetriebsleiter || appState.isBuchhaltung || appState.isBackoffice;
      final saIds = isHighLevel ? null : (appState.serviceAreaIds.isEmpty ? null : appState.serviceAreaIds);

      final sessions = await SupabaseService.getApprovedSessionsDetailByMonth(
        widget.employee['id'],
        _selectedMonth.year,
        _selectedMonth.month,
        serviceAreaIds: saIds,
      );
      final approval = await SupabaseService.getMonthlyApproval(widget.employee['id'], monthStr);
      
      if (mounted) {
        setState(() { 
          _sessions = sessions; 
          _approvalData = approval;
          _loading = false; 
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${tr('Hata')}: $e'), backgroundColor: AppTheme.error),
        );
      }
    }
  }

  Future<void> _sendToManager() async {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('Lütfen onay için imza atınız.'))));
    setState(() => _isSaving = true);
    try {
      final monthStr = '${_selectedMonth.year}-${_selectedMonth.month.toString().padLeft(2, '0')}';
      await SupabaseService.upsertMonthlyApproval({
        'employee_id': widget.employee['id'],
        'month': monthStr,
        'employee_signature': _newSignature,
        'employee_signed_at': DateTime.now().toIso8601String(),
        'status': 'pending',
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('Onay gönderildi ✓')), backgroundColor: AppTheme.success));
        _load();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${tr('Hata')}: $e'), backgroundColor: AppTheme.error));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _approve() async {
    setState(() => _isSaving = true);
    try {
      final appState = context.read<AppState>();
      final monthStr = '${_selectedMonth.year}-${_selectedMonth.month.toString().padLeft(2, '0')}';
      await SupabaseService.upsertMonthlyApproval({
        'employee_id': widget.employee['id'],
        'month': monthStr,
        'manager_id': appState.userId,
        'manager_approved_at': DateTime.now().toIso8601String(),
        'status': 'approved',
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bericht erfolgreich genehmigt!'), backgroundColor: AppTheme.success));
        _load();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${tr('Hata')}: $e'), backgroundColor: AppTheme.error));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  /// Gün → toplam onaylı saat
  Map<int, double> get _hoursByDay {
    final Map<int, double> result = {};
    for (final s in _sessions) {
      final start = s['actual_start'] != null
          ? DateTime.tryParse(s['actual_start'])?.toLocal()
          : null;
      if (start == null) continue;
      final day = start.day;
      final hrs = (s['approved_billable_hours'] as num?)?.toDouble() ?? 0.0;
      result[day] = (result[day] ?? 0.0) + hrs;
    }
    return result;
  }

  /// Gün → sipariş adı
  Map<int, String> get _orderByDay {
    final Map<int, String> result = {};
    for (final s in _sessions) {
      final start = s['actual_start'] != null
          ? DateTime.tryParse(s['actual_start'])?.toLocal()
          : null;
      if (start == null) continue;
      final day = start.day;
      final title = s['order']?['title']?.toString() ?? '';
      if (title.isNotEmpty) {
        if (result[day] == null) {
          result[day] = title;
        } else if (!result[day]!.contains(title)) {
          result[day] = '${result[day]}, $title';
        }
      }
    }
    return result;
  }

  double get _totalHours => _hoursByDay.values.fold(0.0, (a, b) => a + b);
  int get _workDays => _hoursByDay.keys.length;
  int get _daysInMonth => DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0).day;

  Future<void> _downloadPdf() async {
    setState(() => _pdfLoading = true);
    try {
      final approvalDate = _approvalData?['manager_approved_at'] != null 
          ? DateFormat('dd.MM.yyyy').format(DateTime.parse(_approvalData!['manager_approved_at'])) 
          : null;

      final bytes = await PdfService.buildStundenzettelPdf(
        employee: widget.employee,
        year: _selectedMonth.year,
        month: _selectedMonth.month,
        sessions: _sessions,
        employeeSignature: _approvalData?['employee_signature'],
        approvalDate: approvalDate,
      );
      final name = '${widget.employee['first_name']}_${widget.employee['last_name']}'
          '_${_selectedMonth.year}_${_selectedMonth.month.toString().padLeft(2, '0')}.pdf';
      await PdfService.sharePdf(bytes, 'stundenzettel_$name');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PDF Fehler: $e'), backgroundColor: AppTheme.error),
        );
      }
    } finally {
      if (mounted) setState(() => _pdfLoading = false);
    }
  }

  Future<void> _pickMonth() async {
    // Basit ay seçici: 12 ay geri 3 ay ileri
    final now = DateTime.now();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) {
        return SizedBox(
          height: 320,
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40, height: 4,
                decoration: BoxDecoration(color: AppTheme.border, borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: 12),
              const Text('Monat auswählen', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, fontFamily: 'Inter')),
              const Divider(height: 20),
              Expanded(
                child: ListView.builder(
                  itemCount: 15,
                  itemBuilder: (ctx, i) {
                    final m = DateTime(now.year, now.month - 12 + i);
                    final label = DateFormat('MMMM yyyy', 'de_DE').format(m);
                    final isSelected = m.year == _selectedMonth.year && m.month == _selectedMonth.month;
                    return ListTile(
                      title: Text(label, style: TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected ? AppTheme.primary : AppTheme.textMain,
                      )),
                      trailing: isSelected ? Icon(Icons.check_circle, color: AppTheme.primary) : null,
                      onTap: () {
                        Navigator.pop(ctx);
                        setState(() => _selectedMonth = m);
                        _load();
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final fullName = '${widget.employee['first_name'] ?? ''} ${widget.employee['last_name'] ?? ''}'.trim();
    final monthLabel = DateFormat('MMMM yyyy', 'de_DE').format(_selectedMonth);
    final hoursByDay = _hoursByDay;
    final orderByDay = _orderByDay;
    final status = _approvalData?['status'] ?? 'none';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Arbeitszeiterfassung', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'Inter')),
            Text(fullName, style: const TextStyle(fontSize: 12, color: Colors.white70, fontFamily: 'Inter')),
          ],
        ),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: WebContentWrapper(
        child: Column(
          children: [
            // ── Header: Çalışan + Ay Seçici + PDF Butonu ──
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Çalışan avatar + isim
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: AppTheme.primary.withOpacity(0.12),
                        child: Text(
                          '${(widget.employee['first_name'] ?? '').toString().isNotEmpty ? widget.employee['first_name'][0] : ''}${(widget.employee['last_name'] ?? '').toString().isNotEmpty ? widget.employee['last_name'][0] : ''}',
                          style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold, fontSize: 18),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(
                            children: [
                              Expanded(child: Text(fullName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, fontFamily: 'Inter'))),
                              if (status == 'approved')
                                const Icon(Icons.check_circle, color: AppTheme.success, size: 20)
                              else if (status == 'pending')
                                const Icon(Icons.access_time_filled, color: Colors.orange, size: 20),
                            ],
                          ),
                          Text(AppTheme.roleLabel(widget.employee['role'] ?? ''), style: const TextStyle(fontSize: 12, color: AppTheme.textSub, fontFamily: 'Inter')),
                        ]),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Ay seçici
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: _pickMonth,
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                            decoration: BoxDecoration(
                              border: Border.all(color: AppTheme.divider),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.calendar_month, size: 18, color: AppTheme.primary),
                                const SizedBox(width: 8),
                                Text(monthLabel, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, fontFamily: 'Inter')),
                                const Spacer(),
                                const Icon(Icons.expand_more, size: 20, color: AppTheme.textSub),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton.icon(
                        onPressed: (_sessions.isEmpty || _pdfLoading) ? null : _downloadPdf,
                        icon: _pdfLoading
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Icon(Icons.picture_as_pdf, size: 18),
                        label: const Text('PDF', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFF59E0B),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Özet istatistikler
                  if (!_loading)
                    Row(
                      children: [
                        _statChip(Icons.timer, '${_totalHours.toStringAsFixed(1)} Std.', 'Gesamt', AppTheme.primary),
                        const SizedBox(width: 8),
                        _statChip(Icons.calendar_today, '$_workDays Tage', 'Arbeitstage', const Color(0xFF10B981)),
                        const SizedBox(width: 8),
                        _statChip(Icons.work_outline, '${_sessions.length}', 'Einsätze', const Color(0xFF8B5CF6)),
                      ],
                    ),
                ],
              ),
            ),

            // ── Tablo ──
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _buildTable(hoursByDay, orderByDay),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statChip(IconData icon, String value, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.18)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Text(label, style: TextStyle(fontSize: 9, color: color, fontFamily: 'Inter', fontWeight: FontWeight.w500)),
            ]),
            Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color, fontFamily: 'Inter')),
          ],
        ),
      ),
    );
  }

  Widget _buildTable(Map<int, double> hoursByDay, Map<int, String> orderByDay) {
    if (_sessions.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.access_time_filled, size: 64, color: AppTheme.textSub.withOpacity(0.25)),
            const SizedBox(height: 16),
            Text(
              tr('Keine genehmigten Stunden für diesen Monat.'),
              style: const TextStyle(fontSize: 15, color: AppTheme.textSub, fontFamily: 'Inter'),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Tablo başlık
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: AppTheme.primary,
            borderRadius: const BorderRadius.only(topLeft: Radius.circular(12), topRight: Radius.circular(12)),
          ),
          child: Row(
            children: [
              _colHeader('Tag', flex: 1),
              _colHeader('Datum', flex: 2),
              _colHeader('Zeit (Std.)', flex: 2),
              _colHeader('Auftrag', flex: 4),
            ],
          ),
        ),

        // Her gün
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(12), bottomRight: Radius.circular(12)),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)],
          ),
          child: Column(
            children: List.generate(_daysInMonth, (i) {
              final day = i + 1;
              final date = DateTime(_selectedMonth.year, _selectedMonth.month, day);
              final isWeekend = date.weekday == DateTime.saturday || date.weekday == DateTime.sunday;
              final hours = hoursByDay[day];
              final hasWork = hours != null && hours > 0;
              final order = orderByDay[day] ?? '';

              Color bg = Colors.white;
              if (isWeekend) bg = const Color(0xFFF8FAFC);
              if (hasWork) bg = const Color(0xFFF0FDF4);

              return Container(
                decoration: BoxDecoration(
                  color: bg,
                  border: Border(bottom: BorderSide(color: AppTheme.divider.withOpacity(0.5))),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                child: Row(
                  children: [
                    // Gün no
                    Expanded(
                      flex: 1,
                      child: Text(
                        '$day',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: hasWork ? const Color(0xFF16A34A) : (isWeekend ? AppTheme.textSub : AppTheme.textMain),
                          fontFamily: 'Inter',
                        ),
                      ),
                    ),
                    // Tarih (hafta günü)
                    Expanded(
                      flex: 2,
                      child: Text(
                        DateFormat('EEE dd.MM', 'de_DE').format(date),
                        style: TextStyle(
                          fontSize: 12,
                          color: isWeekend ? AppTheme.textSub : AppTheme.textMain,
                          fontFamily: 'Inter',
                          fontStyle: isWeekend ? FontStyle.italic : FontStyle.normal,
                        ),
                      ),
                    ),
                    // Saat
                    Expanded(
                      flex: 2,
                      child: hasWork
                          ? Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFF16A34A).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${hours.toStringAsFixed(2)} h',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF16A34A),
                                  fontFamily: 'Inter',
                                ),
                              ),
                            )
                          : Text(
                              isWeekend ? 'Wochenende' : '—',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppTheme.textSub.withOpacity(0.5),
                                fontFamily: 'Inter',
                              ),
                            ),
                    ),
                    // Sipariş
                    Expanded(
                      flex: 4,
                      child: Text(
                        order,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppTheme.textSub,
                          fontFamily: 'Inter',
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
        ),

        const SizedBox(height: 8),

        // Toplam satırı
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [AppTheme.primary, AppTheme.accent]),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Icon(Icons.summarize, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              const Text('Gesamt', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14, fontFamily: 'Inter')),
              const Spacer(),
              Text(
                '${_totalHours.toStringAsFixed(2)} Stunden',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16, fontFamily: 'Inter'),
              ),
              const SizedBox(width: 12),
              Text(
                '($_workDays Tage)',
                style: const TextStyle(color: Colors.white70, fontSize: 12, fontFamily: 'Inter'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // ── İmza ve Onay Bölümü ──
        _buildApprovalSection(),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildApprovalSection() {
    final appState = context.watch<AppState>();
    final isOwnProfile = widget.employee['id'] == appState.userId;
    final status = _approvalData?['status'] ?? 'none';
    final isApproved = status == 'approved';
    final isSigned = status == 'pending' || isApproved;

    // Yetki kontrolü (Onaylayabilir mi?)
    // Üst yetkililer herkesi onaylayabilir
    bool canApprove = appState.isGeschaeftsfuehrer || 
                      appState.isBetriebsleiter || 
                      appState.isSystemAdmin || 
                      appState.isBuchhaltung ||
                      appState.isBackoffice;
    
    // Bereichsleiter ise SADECE ortak servis alanı varsa onaylayabilir (Görse bile onaylayamaz)
    if (!canApprove && appState.isBereichsleiter) {
      final myAreas = appState.serviceAreaIds;
      final empUsa = widget.employee['user_service_areas'];
      List<String> empAreas = [];
      if (empUsa is List) {
        empAreas = empUsa.map((a) => (a['service_area_id'] ?? '').toString()).where((id) => id.isNotEmpty).toList();
      }
      canApprove = myAreas.any((id) => empAreas.contains(id));
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isApproved ? const Color(0xFFF0FDF4) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isApproved ? const Color(0xFFBBF7D0) : AppTheme.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                isApproved ? Icons.verified : (isSigned ? Icons.history : Icons.edit_note),
                color: isApproved ? AppTheme.success : (isSigned ? Colors.orange : AppTheme.textSub),
              ),
              const SizedBox(width: 10),
              Text(
                isApproved ? 'Monatlicher Bericht Genehmigt' : (isSigned ? 'Warten auf Genehmigung' : 'Bericht Unterschreiben'),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: isApproved ? AppTheme.success : AppTheme.textMain,
                  fontFamily: 'Inter',
                ),
              ),
              if (isApproved) ...[
                const Spacer(),
                const Icon(Icons.check_circle, color: AppTheme.success, size: 24),
              ],
            ],
          ),
          const SizedBox(height: 16),

          if (isApproved) ...[
            _infoRow('Mitarbeiter Signatur', 'Bereit im PDF'),
            _infoRow('Genehmigt von', '${_approvalData?['manager']?['first_name'] ?? ''} ${_approvalData?['manager']?['last_name'] ?? ''}'),
            _infoRow('Datum', _approvalData?['manager_approved_at'] != null ? DateFormat('dd.MM.yyyy HH:mm').format(DateTime.parse(_approvalData!['manager_approved_at'])) : '-'),
          ] else if (isSigned) ...[
            // İmzalı ama onay bekliyor
            if (_approvalData?['employee_signature'] != null)
              Center(
                child: Container(
                  height: 80,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(border: Border.all(color: AppTheme.divider), borderRadius: BorderRadius.circular(8)),
                  child: Image.memory(base64Decode(_approvalData!['employee_signature'])),
                ),
              ),
            const SizedBox(height: 12),
            Text('Gesendet am: ${DateFormat('dd.MM.yyyy HH:mm').format(DateTime.parse(_approvalData!['employee_signed_at']))}', 
              textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: AppTheme.textSub)),
            const SizedBox(height: 16),
            if (canApprove)
              ElevatedButton.icon(
                onPressed: _isSaving ? null : _approve,
                icon: _isSaving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.check_circle),
                label: const Text('BERICHT GENEHMIGEN', style: TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.success, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14)),
              ),
          ] else if (isOwnProfile) ...[
            // Henüz imzalanmamış ve kendi profili
            const Text('Bitte unterschreiben Sie den Bericht für diesen Monat, um ihn an Ihren Bereichsleiter zu senden:', style: TextStyle(fontSize: 13, color: AppTheme.textSub)),
            const SizedBox(height: 12),
            SignaturePadWidget(
              onSigned: (b64) => _newSignature = b64,
              color: AppTheme.primary,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _isSaving ? null : _sendToManager,
              icon: _isSaving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.send),
              label: const Text('UNTERSCHREIBEN & SENDEN', style: TextStyle(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14)),
            ),
          ] else ...[
            const Center(child: Text('Der Mitarbeiter hat diesen Bericht noch nicht unterschrieben.', style: TextStyle(fontStyle: FontStyle.italic, color: AppTheme.textSub))),
          ],
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.textSub)),
          Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _colHeader(String text, {int flex = 1}) {
    return Expanded(
      flex: flex,
      child: Text(
        text,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12, fontFamily: 'Inter'),
      ),
    );
  }
}

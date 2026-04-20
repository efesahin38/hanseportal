import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../theme/web_utils.dart';
import '../providers/app_state.dart';
import '../services/supabase_service.dart';
import '../services/pdf_service.dart';
import '../services/localization_service.dart';
import '../widgets/signature_pad_widget.dart';
import 'package:image_picker/image_picker.dart';

/// GWS İş Formu – Tam Workflow
/// Roller: Mitarbeiter (form doldur) → Teamleiter (kontrol) → Bereichsleiter (paylaş)
///         → External Manager (görüntüle + yorum + imza → geri yolla)
class GwsItemFormScreen extends StatefulWidget {
  final Map<String, dynamic> item;
  final String type;     // 'room' | 'area'
  final String planId;
  final bool isExternalManager;

  const GwsItemFormScreen({
    super.key,
    required this.item,
    required this.type,
    required this.planId,
    this.isExternalManager = false,
  });

  @override
  State<GwsItemFormScreen> createState() => _GwsItemFormScreenState();
}

class _GwsItemFormScreenState extends State<GwsItemFormScreen> {
  static const Color _color = AppTheme.gwsColor;

  // --- Form controllers ---
  final _workerNotes    = TextEditingController();
  final _checkerNotes   = TextEditingController();
  final _extComment     = TextEditingController();

  // --- Checklist ---
  late Map<String, bool> _checklist;

  // --- Checker status ---
  String _checkerStatus = 'pending'; // 'pending' | 'ok' | 'fehler'

  // --- Photos ---
  List<String> _photos = [];         // stored paths/URLs

  // --- PDF URLs ---
  List<String> _pdfUrls = [];

  // --- Signature (External Manager) ---
  String? _extSignatureBase64;

  // --- Sharing state ---
  bool _isSharedWithExternal = false;
  bool _extHasReturned = false;

  // --- Save/Loading ---
  bool _saving = false;
  bool _loading = false;

  // --- Role helpers ---
  late bool _canFullEdit;    // GF, Betriebsleiter, Backoffice, Muhasebe, SystemAdmin
  late bool _isTeamLeader;   // Vorarbeiter / Bereichsleiter
  late bool _isMitarbeiter;
  late bool _canShare;       // Bereichsleiter + canFullEdit

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    final itm = widget.item;
    // Checklist
    final rawData = itm['checklist_data'] as Map? ?? {};
    final defaultItems = widget.type == 'room'
        ? ['Bett gemacht', 'Bad sauber', 'Müll geleert', 'Boden gesaugt', 'Fenster geputzt', 'Handtücher gewechselt']
        : ['Boden gewischt', 'Flächen desinfiziert', 'Glas gereinigt', 'Müll geleert'];
    _checklist = {for (var k in defaultItems) k: rawData[k] == true};

    // Notes
    _workerNotes.text  = itm['worker_notes'] ?? '';
    _checkerNotes.text = itm['checker_notes'] ?? '';
    _extComment.text   = itm['external_comment'] ?? '';
    _checkerStatus     = itm['checker_status'] ?? 'pending';

    // Photos
    _photos   = List<String>.from(itm['photos'] ?? []);
    _pdfUrls  = List<String>.from(itm['pdf_urls'] ?? []);

    // Sharing state
    _isSharedWithExternal = itm['is_shared_with_external'] == true;
    _extHasReturned       = itm['external_returned_at'] != null;
    _extSignatureBase64   = itm['external_signature'];

    // Roles
    final appState = context.read<AppState>();
    _canFullEdit = appState.canPlanOperations || appState.canSeeFinancialDetails;
    // Team Leader fallback
    _isTeamLeader = appState.isVorarbeiter || appState.isBereichsleiter;
    _isMitarbeiter = (appState.role == 'mitarbeiter' || appState.isMitarbeiter) && !widget.isExternalManager;
    _canShare = appState.isBereichsleiter || _canFullEdit;
  }

  @override
  void dispose() {
    _workerNotes.dispose();
    _checkerNotes.dispose();
    _extComment.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await SupabaseService.updateGwsItemDetails(
        type: widget.type,
        id: widget.item['id'],
        checklistData: _checklist,
        workerNotes: _workerNotes.text.trim(),
        photos: _photos,
        checkerStatus: _checkerStatus,
        checkerNotes: _checkerNotes.text.trim(),
        status: _checkerStatus == 'ok' ? 'checked' : (_isMitarbeiter ? 'done' : null),
      );
      if (_pdfUrls.isNotEmpty) {
        await SupabaseService.updateGwsItemPdfs(
          type: widget.type,
          id: widget.item['id'],
          pdfUrls: _pdfUrls,
        );
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('✓ Gespeichert'),
          backgroundColor: AppTheme.success,
          duration: Duration(seconds: 2),
        ));
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fehler: $e'), backgroundColor: AppTheme.error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _toggleShareWithExternal(bool share) async {
    setState(() => _loading = true);
    try {
      await SupabaseService.shareGwsItemWithExternal(
        type: widget.type,
        id: widget.item['id'],
        shared: share,
      );
      setState(() => _isSharedWithExternal = share);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(share ? '📤 An Externen Manager gesendet' : '🔒 Freigabe zurückgezogen'),
        backgroundColor: share ? _color : AppTheme.textSub,
      ));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fehler: $e'), backgroundColor: AppTheme.error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submitExternalFeedback() async {
    if (_extSignatureBase64 == null || _extSignatureBase64!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Bitte erst unterschreiben!'),
        backgroundColor: AppTheme.error,
      ));
      return;
    }
    setState(() => _saving = true);
    try {
      await SupabaseService.saveGwsExternalFeedback(
        type: widget.type,
        id: widget.item['id'],
        comment: _extComment.text.trim(),
        signatureBase64: _extSignatureBase64!,
      );
      setState(() => _extHasReturned = true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('✓ Rückmeldung gesendet. Vielen Dank!'),
          backgroundColor: AppTheme.success,
        ));
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fehler: $e'), backgroundColor: AppTheme.error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _downloadPdf() async {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('PDF wird generiert...')));
    try {
      final bytes = await PdfService.generateGenericFormPdf(
        title: widget.type == 'room' ? 'Zimmer ${widget.item['room_number']}' : (widget.item['area_name'] ?? 'Bereich'),
        subtitle: 'GWS Bericht',
        orderId: widget.planId, // Bu GWS plan ID'si ama PDF title'da gözükecek
        data: {
          'Checkliste': _checklist,
          'Mitarbeiter-Notizen': _workerNotes.text,
          'Kontrolle (Notizen)': _checkerNotes.text,
          'Status': _checkerStatus,
          'external_comment': _extComment.text,
          'external_signature': _extSignatureBase64,
          'photos': _photos,
        },
      );
      await PdfService.downloadPdf(bytes, 'GWS_Bericht_${widget.item['id']}.pdf');
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('PDF Fehler: $e')));
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 60);
    if (image != null) {
      setState(() => _saving = true);
      try {
        final bytes = await image.readAsBytes();
        final fileName = 'gws_${widget.type}_${widget.item['id']}_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final url = await SupabaseService.uploadDocument(fileName, bytes); // 'document' bucket'ına atıyor default
        setState(() => _photos.add(url));
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload Fehler: $e')));
      } finally {
        if (mounted) setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.type == 'room'
        ? 'Zimmer ${widget.item['room_number'] ?? ''}'
        : (widget.item['area_name'] ?? 'Bereich');

    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        backgroundColor: _color,
        foregroundColor: Colors.white,
        title: Text(title, style: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold)),
        actions: [
          if (widget.item['id'] != null)
            IconButton(
              icon: const Icon(Icons.picture_as_pdf, color: Colors.white),
              onPressed: _downloadPdf,
              tooltip: 'PDF herunterladen',
            ),
          if (!widget.isExternalManager && !_saving)
            TextButton.icon(
              onPressed: _isMitarbeiter || _isTeamLeader || _canFullEdit ? _save : null,
              icon: const Icon(Icons.save, color: Colors.white, size: 20),
              label: const Text('Speichern', style: TextStyle(color: Colors.white, fontFamily: 'Inter', fontWeight: FontWeight.bold)),
            ),
          if (_saving)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))),
            ),
        ],
      ),
      body: WebContentWrapper(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ─── STATUS BANNER ─────────────────────────────────────────
            _buildStatusBanner(),

            // ─── CHECKLISTE ─────────────────────────────────────────────
            _buildSection(
              icon: Icons.checklist,
              title: 'Checkliste',
              child: Column(
                children: _checklist.keys.map((key) => CheckboxListTile(
                  title: Text(key, style: const TextStyle(fontFamily: 'Inter', fontSize: 14)),
                  value: _checklist[key],
                  // Mitarbeiter, Teamleiter OR Full Edit roles can edit checklist
                  onChanged: ((_isMitarbeiter || _isTeamLeader || _canFullEdit) && !widget.isExternalManager)
                      ? (v) => setState(() => _checklist[key] = v!)
                      : null,
                  activeColor: _color,
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                )).toList(),
              ),
            ),

            // ─── MITARBEITER NOTIZEN ────────────────────────────────────
            _buildSection(
              icon: Icons.edit_note,
              title: 'Mitarbeiter-Notizen',
              child: TextField(
                controller: _workerNotes,
                maxLines: 3,
                readOnly: !(_isMitarbeiter || _isTeamLeader || _canFullEdit) || widget.isExternalManager,
                decoration: InputDecoration(
                  hintText: (_isMitarbeiter || _isTeamLeader || _canFullEdit) ? 'Hinweise zur Durchführung...' : '—',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  filled: true,
                  fillColor: (_isMitarbeiter || _isTeamLeader || _canFullEdit) ? Colors.white : AppTheme.bg,
                ),
              ),
            ),

            // ─── FOTOS ──────────────────────────────────────────────────
            _buildSection(
              icon: Icons.photo_library_outlined,
              title: 'Fotos',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ..._photos.map((p) => ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          width: 80, height: 80,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            border: Border.all(color: _color.withOpacity(0.3)),
                          ),
                          child: (p.startsWith('http')) 
                            ? Image.network(p, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, color: Colors.red))
                            : Image.network(
                                SupabaseService.getPublicUrl(p),
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, color: Colors.red),
                                loadingBuilder: (context, child, loadingProgress) {
                                  if (loadingProgress == null) return child;
                                  return const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)));
                                },
                              ),
                        ),
                      )),
                      if ((_isMitarbeiter || _isTeamLeader || _canFullEdit) && !widget.isExternalManager)
                        InkWell(
                          onTap: _pickImage,
                          child: Container(
                            width: 80, height: 80,
                            decoration: BoxDecoration(
                              border: Border.all(color: _color.withOpacity(0.4), style: BorderStyle.solid),
                              borderRadius: BorderRadius.circular(10),
                              color: _color.withOpacity(0.05),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add_a_photo, color: _color, size: 24),
                                const SizedBox(height: 4),
                                Text('Foto', style: TextStyle(color: _color, fontSize: 10, fontFamily: 'Inter')),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                  if (_photos.isEmpty && !_isMitarbeiter)
                    const Padding(
                      padding: EdgeInsets.only(top: 4),
                      child: Text('Keine Fotos', style: TextStyle(color: AppTheme.textSub, fontFamily: 'Inter', fontSize: 13)),
                    ),
                ],
              ),
            ),

            // ─── KONTROLLE (TEAMLEITER) ──────────────────────────────────
            if (_isTeamLeader || widget.isExternalManager)
              _buildSection(
                icon: Icons.task_alt,
                title: 'Kontrolle (Teamleiter)',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _statusChip('ok', '✅ Alles OK', Colors.green, _checkerStatus == 'ok',
                            widget.isExternalManager ? null : (sel) { if (sel) setState(() => _checkerStatus = 'ok'); }),
                        const SizedBox(width: 8),
                        _statusChip('fehler', '❌ Fehler', Colors.red, _checkerStatus == 'fehler',
                            widget.isExternalManager ? null : (sel) { if (sel) setState(() => _checkerStatus = 'fehler'); }),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _checkerNotes,
                      maxLines: 2,
                      readOnly: widget.isExternalManager,
                      decoration: InputDecoration(
                        hintText: 'Kontrollnotizen...',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        filled: true,
                        fillColor: widget.isExternalManager ? AppTheme.bg : Colors.white,
                      ),
                    ),
                  ],
                ),
              ),

            // ─── EXTERNAL SHARING (BEREICHSLEITER+) ─────────────────────
            if (_canShare && !widget.isExternalManager)
              _buildSection(
                icon: Icons.share_outlined,
                title: 'Externen Manager einbeziehen',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_extHasReturned) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.success.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppTheme.success.withOpacity(0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(children: [
                              Icon(Icons.check_circle, color: AppTheme.success, size: 16),
                              SizedBox(width: 6),
                              Text('Externer Manager hat geantwortet', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Inter', fontSize: 13, color: AppTheme.success)),
                            ]),
                            if ((widget.item['external_comment'] as String? ?? '').isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text('Kommentar: ${widget.item['external_comment']}', style: const TextStyle(fontFamily: 'Inter', fontSize: 13)),
                            ],
                            if (widget.item['external_signature'] != null) ...[
                              const SizedBox(height: 12),
                              const Text('Unterschrift Ext. Manager:', style: TextStyle(fontFamily: 'Inter', fontSize: 11, color: AppTheme.textSub)),
                              const SizedBox(height: 4),
                              Container(
                                height: 100,
                                decoration: BoxDecoration(color: Colors.white, border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
                                child: widget.item['external_signature'] != null && widget.item['external_signature'].toString().length > 50
                                   ? Image.memory(base64Decode(widget.item['external_signature']), fit: BoxFit.contain)
                                   : const Center(child: Text('Keine Signatur')),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _isSharedWithExternal
                                ? '📤 Bereits an Externen Manager gesendet'
                                : '📋 Noch nicht geteilt',
                            style: TextStyle(fontFamily: 'Inter', fontSize: 13, color: _isSharedWithExternal ? _color : AppTheme.textSub),
                          ),
                        ),
                        if (_loading)
                          const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        else
                          Switch(
                            value: _isSharedWithExternal,
                            activeColor: _color,
                            onChanged: _toggleShareWithExternal,
                          ),
                      ],
                    ),
                    if (!_isSharedWithExternal)
                      const Padding(
                        padding: EdgeInsets.only(top: 4),
                        child: Text('Aktivieren → Externer Manager kann dieses Formular sehen, kommentieren und unterschreiben.', style: TextStyle(fontSize: 11, color: AppTheme.textSub, fontFamily: 'Inter')),
                      ),
                  ],
                ),
              ),

            // ─── EXTERNAL MANAGER BEREICH ────────────────────────────────
            if (widget.isExternalManager && _isSharedWithExternal && !_extHasReturned) ...[
              const Divider(height: 32, thickness: 2),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _color.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _color.withOpacity(0.25)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Icon(Icons.person_outline, color: _color),
                      const SizedBox(width: 8),
                      Text('Ihr Feedback', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _color, fontFamily: 'Inter')),
                    ]),
                    const SizedBox(height: 16),
                    const Text('Ihr Kommentar (optional):', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600, fontSize: 13)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _extComment,
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: 'Ihre Anmerkungen, z.B. "Alles in Ordnung" oder "Zimmer 12 war nicht sauber"...',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text('Bitte hier unterschreiben: *', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600, fontSize: 13)),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: _color.withOpacity(0.4)),
                        borderRadius: BorderRadius.circular(12),
                        color: Colors.white,
                      ),
                      child: SignaturePadWidget(
                        color: _color,
                        onSigned: (b64) => setState(() => _extSignatureBase64 = b64),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text('* Pflichtfeld zum Absenden', style: TextStyle(fontSize: 11, color: AppTheme.textSub, fontFamily: 'Inter')),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _color,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: _saving ? null : _submitExternalFeedback,
                        icon: _saving
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Icon(Icons.send, color: Colors.white),
                        label: const Text(
                          'An uns zurücksenden',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, fontFamily: 'Inter'),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // ─── NOT SHARED INFO (External Manager) ─────────────────────
            if (widget.isExternalManager && !_isSharedWithExternal)
              _buildSection(
                icon: Icons.lock_outline,
                title: 'Zugang',
                child: const Text(
                  'Dieses Formular wurde noch nicht für Sie freigegeben. Bitte warten Sie, bis der zuständige Bereichsleiter es mit Ihnen teilt.',
                  style: TextStyle(fontFamily: 'Inter', color: AppTheme.textSub, fontSize: 13),
                ),
              ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBanner() {
    final statusMap = {
      'draft':   ('⬜ Entwurf', Colors.grey),
      'done':    ('✅ Erledigt', Colors.blue),
      'checked': ('🔍 Geprüft', Colors.orange),
      'shared':  ('📤 Geteilt', AppTheme.gwsColor),
      'approved':('✅ Freigegeben', AppTheme.success),
      'pending': ('⏳ Ausstehend', Colors.grey),
    };
    final status = widget.item['status'] as String? ?? 'draft';
    final (label, color) = statusMap[status] ?? ('—', Colors.grey);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Text(label, style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold, color: color, fontSize: 14)),
          const Spacer(),
          if (_isSharedWithExternal)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: _color.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
              child: Text('📤 Extern geteilt', style: TextStyle(color: _color, fontSize: 11, fontFamily: 'Inter', fontWeight: FontWeight.w600)),
            ),
          if (_extHasReturned) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: AppTheme.success.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
              child: const Text('↩ Rückmeldung', style: TextStyle(color: AppTheme.success, fontSize: 11, fontFamily: 'Inter', fontWeight: FontWeight.w600)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSection({required IconData icon, required String title, required Widget child}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: Row(children: [
              Icon(icon, size: 18, color: _color),
              const SizedBox(width: 8),
              Text(title.toUpperCase(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textSub, letterSpacing: 0.5, fontFamily: 'Inter')),
            ]),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(14),
            child: child,
          ),
        ],
      ),
    );
  }

  Widget _statusChip(String value, String label, Color color, bool selected, Function(bool)? onSelected) {
    return FilterChip(
      label: Text(label, style: const TextStyle(fontFamily: 'Inter', fontSize: 13)),
      selected: selected,
      onSelected: onSelected,
      selectedColor: color.withOpacity(0.15),
      checkmarkColor: color,
      side: BorderSide(color: selected ? color : Colors.grey.shade300),
      labelStyle: TextStyle(color: selected ? color : AppTheme.textSub, fontWeight: selected ? FontWeight.bold : FontWeight.normal),
    );
  }
}

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../providers/app_state.dart';
import '../services/supabase_service.dart';
import '../services/localization_service.dart';
import '../services/pdf_service.dart';
import 'package:printing/printing.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import '../widgets/signature_pad_widget.dart';

// ─────────────────────────────────────────────────────────────────────────────
// CONSTANTS
// ─────────────────────────────────────────────────────────────────────────────

const String kGebaeudeCompanyId = 'aaaaaaaa-0000-0000-0000-000000000002';

const List<Map<String, dynamic>> _kForms = [
  {
    'key': 'bereichsfreigabe',
    'label': 'Bereichsfreigabe',
    'subtitle': 'vor Reinigungsstart',
    'color': 0xFF10B981,
  },
  {
    'key': 'qualitaetskontrolle',
    'label': 'Qualitätskontrolle',
    'subtitle': 'Abnahme nach Reinigung',
    'color': 0xFF6366F1,
  },
  {
    'key': 'stundenlohn',
    'label': 'Stundenlohn- & Leistungsnachweis',
    'subtitle': 'Tages- / Wochenrapport',
    'color': 0xFF64748B,
  },
  {
    'key': 'maengelliste',
    'label': 'Mängel- & Restpunkteliste',
    'subtitle': 'Offene Punkte & Nacharbeit',
    'color': 0xFFEF4444,
  },
  {
    'key': 'tagesrapport',
    'label': 'Tagesrapport',
    'subtitle': 'Bauleitung & Interne Projektsteuerung',
    'color': 0xFF3B82F6,
  },
];

// ─────────────────────────────────────────────────────────────────────────────
// TAB OVERVIEW
// ─────────────────────────────────────────────────────────────────────────────

class OrderFormulareTab extends StatefulWidget {
  final String orderId;
  final String? orderCompanyId;
  final String? orderDepartmentId;
  final List<String> supervisorIds;
  final bool isForeman;

  const OrderFormulareTab({
    super.key,
    required this.orderId,
    required this.orderCompanyId,
    this.orderDepartmentId,
    required this.supervisorIds,
    this.isForeman = false,
  });

  @override
  State<OrderFormulareTab> createState() => _OrderFormulareTabState();
}

class _OrderFormulareTabState extends State<OrderFormulareTab> {
  Map<String, Map<String, dynamic>> _formData = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final rows = await SupabaseService.getOrderForms(widget.orderId);
      final map = <String, Map<String, dynamic>>{};
      for (final r in rows) {
        map[r['form_type'] as String] = r;
      }
      if (mounted) setState(() { _formData = map; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool _isGebaeudeOrder() {
    final cid = widget.orderCompanyId ?? '';
    return cid == kGebaeudeCompanyId;
  }

  bool _canEdit(AppState a) {
    if (a.isGeschaeftsfuehrer || a.isBetriebsleiter || a.isBackoffice || a.isBuchhaltung || a.isSystemAdmin) return true;
    // Sadece bu işe atanmış takım lideri (is_supervisor yıldızlı kişi) formu düzenleyebilir
    if (widget.isForeman || widget.supervisorIds.contains(a.userId)) return true;
    if (a.isBereichsleiter && a.departmentId == widget.orderDepartmentId) return true;
    return false;
  }

  bool _canApprove(AppState a) {
    // Takım lideri ONAYLAYAMAZ – sadece GF, BL, BRL ve üst roller onaylar
    if (a.isGeschaeftsfuehrer || a.isBetriebsleiter || a.isBackoffice || a.isBuchhaltung || a.isSystemAdmin) return true;
    if (a.isBereichsleiter && widget.orderDepartmentId != null && a.departmentId == widget.orderDepartmentId) return true;
    return false;
  }

  bool _canDelete(AppState a) {
    // Takım lideri silme yapamaz
    if (a.isGeschaeftsfuehrer || a.isBetriebsleiter || a.isSystemAdmin) return true;
    if (a.isBereichsleiter && a.departmentId == widget.orderDepartmentId) return true;
    return false;
  }

  bool _canView(AppState a) => a.userId.isNotEmpty;

  bool _canSendToExtManager(AppState a) {
    return a.isGeschaeftsfuehrer || a.isBetriebsleiter || a.isSystemAdmin ||
        (a.isBereichsleiter && a.departmentId == widget.orderDepartmentId);
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.read<AppState>();

    if (_loading) return const Center(child: CircularProgressIndicator());

    if (!_canView(appState)) {
      return _InfoMessage(icon: Icons.block, message: 'Keine Zugriffsberechtigung');
    }

    final editable = _canEdit(appState);
    final canApprove = _canApprove(appState);
    final canDelete = _canDelete(appState);
    final canSendToExt = _canSendToExtManager(appState);

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Info banner ──
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.06),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.primary.withOpacity(0.2)),
            ),
            child: const Row(children: [
              Icon(Icons.info_outline, color: AppTheme.primary, size: 16),
              SizedBox(width: 8),
              Expanded(child: Text(
                'Alle Formulare können digital ausgefüllt, unterschrieben und über den Browser gedruckt oder als PDF gespeichert werden.',
                style: TextStyle(fontSize: 11, fontFamily: 'Inter', color: AppTheme.primary),
              )),
            ]),
          ),
          // Cards
          ..._kForms.map((meta) {
            final key = meta['key'] as String;
            final row = _formData[key];
            return _FormCard(
              meta: meta,
              row: row,
              editable: editable,
              canApprove: canApprove,
              canDelete: canDelete,
              canSendToExt: canSendToExt,
              isReadOnly: !appState.canPlanOperations,
              onOpen: () => _openForm(context, key, row, editable, canApprove, canDelete, canSendToExt, appState),
            );
          }),
        ],
      ),
    );
  }

  void _openForm(
    BuildContext context,
    String key,
    Map<String, dynamic>? row,
    bool editable,
    bool canApprove,
    bool canDelete,
    bool canSendToExt,
    AppState appState,
  ) {
    final args = _FormArgs(
      orderId: widget.orderId,
      row: row,
      editable: editable,
      canApprove: canApprove,
      canDelete: canDelete,
      canSendToExt: canSendToExt,
      appState: appState,
      onRefresh: _load,
    );

    Widget screen;
    switch (key) {
      case 'bereichsfreigabe':    screen = _BereichsfreigabeScreen(args: args); break;
      case 'qualitaetskontrolle': screen = _QualitaetskontrolleScreen(args: args); break;
      case 'stundenlohn':         screen = _StundenlohnScreen(args: args); break;
      case 'maengelliste':        screen = _MaengellisteScreen(args: args); break;
      case 'tagesrapport':        screen = _TagesrapportScreen(args: args); break;
      default: return;
    }
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen)).then((_) => _load());
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DATA CONTAINER
// ─────────────────────────────────────────────────────────────────────────────

class _FormArgs {
  final String orderId;
  final Map<String, dynamic>? row;
  final bool editable;
  final bool canApprove;
  final bool canDelete;
  final bool canSendToExt;
  final AppState appState;
  final VoidCallback onRefresh;

  const _FormArgs({
    required this.orderId, required this.row, required this.editable,
    required this.canApprove, required this.canDelete,
    this.canSendToExt = false,
    required this.appState, required this.onRefresh,
  });

  Map<String, dynamic> get data => Map<String, dynamic>.from(row?['data'] as Map? ?? {});
  String get status => row?['status'] as String? ?? 'nicht_begonnen';
  String? get formId => row?['id'] as String?;
  bool get isApproved => row?['is_approved'] == true;
  
  /// Workflow aşaması: team_editing | pending_ext_review | pending_bl_approval | completed
  String get workflowStage => (row?['data'] as Map?)?['_workflow_stage'] as String? ?? 'team_editing';
}

// ─────────────────────────────────────────────────────────────────────────────
// OVERVIEW CARD
// ─────────────────────────────────────────────────────────────────────────────

class _FormCard extends StatelessWidget {
  final Map<String, dynamic> meta;
  final Map<String, dynamic>? row;
  final bool editable;
  final bool canApprove;
  final bool canDelete;
  final bool canSendToExt;
  final bool isReadOnly;
  final VoidCallback onOpen;

  const _FormCard({
    required this.meta, required this.row, required this.editable,
    required this.canApprove, required this.canDelete,
    this.canSendToExt = false,
    required this.isReadOnly,
    required this.onOpen,
  });

  Color get _color => Color(meta['color'] as int);

  String get _statusLabel {
    final s = row?['status'] as String? ?? 'nicht_begonnen';
    switch (s) {
      case 'fertig':         return 'Fertig';
      case 'in_bearbeitung': return 'In Bearbeitung';
      default:               return 'Nicht begonnen';
    }
  }

  Color get _statusColor {
    final s = row?['status'] as String? ?? 'nicht_begonnen';
    switch (s) {
      case 'fertig':         return const Color(0xFF10B981);
      case 'in_bearbeitung': return const Color(0xFFF59E0B);
      default:               return const Color(0xFF94A3B8);
    }
  }

  bool get _isApproved => row?['is_approved'] == true;

  /// Workflow stage from data JSON
  String get _workflowStage => (row?['data'] as Map?)?['_workflow_stage'] as String? ?? 'team_editing';

  String get _workflowStageLabel {
    switch (_workflowStage) {
      case 'pending_ext_review': return '⏳ Wartet auf Ext. Manager';
      case 'pending_bl_approval': return '🔁 Zurück beim BL';
      case 'completed':           return '✅ Abgeschlossen';
      default:                    return 'In Bearbeitung';
    }
  }

  Color get _workflowStageColor {
    switch (_workflowStage) {
      case 'pending_ext_review': return Colors.orange;
      case 'pending_bl_approval': return const Color(0xFF6366F1);
      case 'completed':           return const Color(0xFF10B981);
      default:                    return AppTheme.primary;
    }
  }

  IconData get _workflowStageIcon {
    switch (_workflowStage) {
      case 'pending_ext_review': return Icons.send_outlined;
      case 'pending_bl_approval': return Icons.reply;
      case 'completed':           return Icons.check_circle_outline;
      default:                    return Icons.edit_outlined;
    }
  }

  String _updaterName() {
    final u = row?['updated_by_user'] as Map?;
    if (u == null) return '—';
    return '${u['first_name'] ?? ''} ${u['last_name'] ?? ''}'.trim();
  }

  String _updatedAt() {
    final ts = row?['updated_at'] as String?;
    if (ts == null) return '';
    final dt = DateTime.tryParse(ts)?.toLocal();
    if (dt == null) return '';
    return '${dt.day}.${dt.month}.${dt.year} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _isApproved ? const Color(0xFF10B981) : AppTheme.divider, width: _isApproved ? 1.5 : 1),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: _color.withOpacity(0.08),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
          ),
          child: Row(children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(color: _color, borderRadius: BorderRadius.circular(10)),
              child: Center(child: Text(
                (meta['label'] as String)[0].toUpperCase(),
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16, fontFamily: 'Inter'),
              )),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(meta['label'] as String, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, fontFamily: 'Inter', color: AppTheme.textMain)),
              Text(meta['subtitle'] as String, style: const TextStyle(fontSize: 11, fontFamily: 'Inter', color: AppTheme.textSub)),
            ])),
            if (_isApproved)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: const Color(0xFF10B981).withOpacity(0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFF10B981).withOpacity(0.4))),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.verified_outlined, size: 12, color: Color(0xFF10B981)),
                  SizedBox(width: 4),
                  Text('Genehmigt', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF10B981), fontFamily: 'Inter')),
                ]),
              ),
          ]),
        ),
        // Body
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: _statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                      child: Text(_statusLabel, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _statusColor, fontFamily: 'Inter')),
                    ),
                    // Workflow aşaması göstergesi
                    if (_workflowStage != 'team_editing') ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: _workflowStageColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: _workflowStageColor.withOpacity(0.4)),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(_workflowStageIcon, size: 11, color: _workflowStageColor),
                          const SizedBox(width: 4),
                          Text(_workflowStageLabel, style: TextStyle(fontSize: 10, color: _workflowStageColor, fontWeight: FontWeight.w600, fontFamily: 'Inter')),
                        ]),
                      ),
                    ],
                  ]),
                  if (_updaterName() != '—') ...[
                    const SizedBox(height: 6),
                    Text('Bearbeitet: ${_updaterName()}', style: const TextStyle(fontSize: 11, color: AppTheme.textSub, fontFamily: 'Inter')),
                    if (_updatedAt().isNotEmpty)
                      Text(_updatedAt(), style: const TextStyle(fontSize: 10, color: AppTheme.textSub, fontFamily: 'Inter')),
                  ],
                ])),
                const SizedBox(width: 12),
                if (row == null && isReadOnly)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(color: Colors.grey.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                    child: const Text('Kein Formular', style: TextStyle(color: AppTheme.textSub, fontSize: 11, fontFamily: 'Inter')),
                  )
                else
                  ElevatedButton(
                    onPressed: onOpen,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _color,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Text(_workflowStage == 'pending_ext_review' ? 'Öffnen' : 'Öffnen', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, fontFamily: 'Inter')),
                      const SizedBox(width: 4),
                      const Icon(Icons.arrow_forward, size: 14),
                    ]),
                  ),
              ]),
            ],
          ),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SHARED FORM SCAFFOLD
// ─────────────────────────────────────────────────────────────────────────────

class _FormScaffold extends StatefulWidget {
  final String title;
  final String subtitle;
  final Color color;
  final _FormArgs args;
  final String formType;
  final String status;
  final ValueChanged<String> onStatusChanged;
  final Widget fields;
  final Map<String, dynamic> Function() buildData;

  const _FormScaffold({
    required this.title,
    required this.subtitle,
    required this.color,
    required this.args,
    required this.formType,
    required this.status,
    required this.onStatusChanged,
    required this.fields,
    required this.buildData,
  });

  @override
  State<_FormScaffold> createState() => _FormScaffoldState();
}

class _FormScaffoldState extends State<_FormScaffold> {
  List<String> _photos = [];
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    final data = widget.args.data;
    if (data['photos'] is List) {
      _photos = List<String>.from(data['photos']);
    }
  }

  Future<void> _save(BuildContext ctx) async {
    try {
      // Latest data'yı çek ki External Manager'ın girdiği _ext_manager_ signature vs. kaybolmasın
      Map<String, dynamic> submitData = {};
      if (widget.args.formId != null) {
        final existing = await SupabaseService.getOrderForm(widget.args.formId!);
        if (existing != null && existing['data'] != null) {
          submitData = Map<String, dynamic>.from(existing['data']);
        }
      } else {
        submitData = Map<String, dynamic>.from(widget.args.data);
      }
      
      final newData = widget.buildData();
      submitData.addAll(newData);
      submitData['photos'] = _photos;

      await SupabaseService.upsertOrderForm(
        id: widget.args.formId,
        orderId: widget.args.orderId,
        formType: widget.formType,
        status: widget.status,
        data: submitData,
        userId: widget.args.appState.userId,
      );
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
          content: Row(children: [
            Icon(Icons.check_circle_outline, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Text('Gespeichert ✓', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600)),
          ]),
          backgroundColor: Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
        ));
        Navigator.pop(ctx);
      }
    } catch (e) {
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
          content: Text('Fehler beim Speichern: $e', style: const TextStyle(fontFamily: 'Inter')),
          backgroundColor: AppTheme.error,
        ));
      }
    }
  }

  Future<void> _sendToExtManager(BuildContext ctx) async {
    try {
      final submitData = widget.args.data;
      final newData = widget.buildData();
      submitData.addAll(newData);
      submitData['photos'] = _photos;
      submitData['_workflow_stage'] = 'pending_ext_review';
      submitData['_sent_to_ext_at'] = DateTime.now().toIso8601String();
      await SupabaseService.upsertOrderForm(
        id: widget.args.formId,
        orderId: widget.args.orderId,
        formType: widget.formType,
        status: widget.status,
        data: submitData,
        userId: widget.args.appState.userId,
      );
      if (ctx.mounted) {
        if (widget.args.row != null) {
          widget.args.row!['data'] = submitData;
        }
        // Just reload layout to reflect the new state, the panel will appear immediately below.
        setState(() {});
      }
    } catch (e) {
      if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Fehler: $e'), backgroundColor: AppTheme.error));
    }
  }

  Future<void> _sendBackToBl(BuildContext ctx, String extComment, String extSignature) async {
    try {
      Map<String, dynamic> submitData = {};
      if (widget.args.formId != null) {
        final existing = await SupabaseService.getOrderForm(widget.args.formId!);
        if (existing != null && existing['data'] != null) {
          submitData = Map<String, dynamic>.from(existing['data']);
        }
      } else {
        submitData = Map<String, dynamic>.from(widget.args.data);
      }
      
      submitData['_workflow_stage'] = 'pending_bl_approval';
      submitData['_ext_manager_comment'] = extComment;
      submitData['_ext_manager_signature'] = extSignature;
      submitData['_ext_returned_at'] = DateTime.now().toIso8601String();
      await SupabaseService.upsertOrderForm(
        id: widget.args.formId,
        orderId: widget.args.orderId,
        formType: widget.formType,
        status: widget.status,
        data: submitData,
        userId: widget.args.appState.userId,
      );
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
          content: Text('✅ Rückmeldung an Bereichsleiter gesendet!', style: TextStyle(fontFamily: 'Inter')),
          backgroundColor: Color(0xFF6366F1),
        ));
        Navigator.pop(ctx);
      }
    } catch (e) {
      if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Fehler: $e'), backgroundColor: AppTheme.error));
    }
  }

  Future<void> _completeWorkflow(BuildContext ctx) async {
    final confirm = await showDialog<bool>(context: ctx, builder: (c) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Row(children: [
        Icon(Icons.check_circle, color: Color(0xFF10B981)),
        SizedBox(width: 8),
        Text('Workflow abschließen?', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold, fontSize: 16)),
      ]),
      content: const Text(
        'Das Formular wird final abgeschlossen und kann nicht mehr bearbeitet werden. PDF wird erstellt.',
        style: TextStyle(fontFamily: 'Inter'),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Zurück')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
          onPressed: () => Navigator.pop(c, true),
          child: const Text('Abschließen & PDF', style: TextStyle(color: Colors.white)),
        ),
      ],
    ));
    if (confirm != true) return;
    try {
      // Latest data'yı çek ki External Manager'ın girdiği _ext_manager_ signature vs. kaybolmasın
      Map<String, dynamic> submitData = {};
      if (widget.args.formId != null) {
        final existing = await SupabaseService.getOrderForm(widget.args.formId!);
        if (existing != null && existing['data'] != null) {
          submitData = Map<String, dynamic>.from(existing['data']);
        }
      } else {
        submitData = Map<String, dynamic>.from(widget.args.data);
      }
      
      final newData = widget.buildData();
      submitData.addAll(newData);
      submitData['photos'] = _photos;
      submitData['_workflow_stage'] = 'completed';
      submitData['_completed_at'] = DateTime.now().toIso8601String();
      await SupabaseService.upsertOrderForm(
        id: widget.args.formId,
        orderId: widget.args.orderId,
        formType: widget.formType,
        status: 'fertig',
        data: submitData,
        userId: widget.args.appState.userId,
      );
      if (widget.args.formId != null) {
        await SupabaseService.approveOrderForm(widget.args.formId!, widget.args.appState.userId);
      }
      if (ctx.mounted) {
        _downloadPdf();
        ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
          content: Text('✅ Workflow abgeschlossen! PDF wird erzeugt.', style: TextStyle(fontFamily: 'Inter')),
          backgroundColor: Color(0xFF10B981),
        ));
        Navigator.pop(ctx);
      }
    } catch (e) {
      if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Fehler: $e'), backgroundColor: AppTheme.error));
    }
  }

  Future<void> _approve(BuildContext ctx) async {
    final confirm = await showDialog<bool>(context: ctx, builder: (c) => AlertDialog(
      title: const Text('Formular genehmigen', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold)),
      content: const Text('Möchten Sie dieses Formular genehmigen? Diese Aktion kann nicht rückgängig gemacht werden.', style: TextStyle(fontFamily: 'Inter')),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Abbrechen')),
        ElevatedButton(
          onPressed: () => Navigator.pop(c, true),
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
          child: const Text('Genehmigen', style: TextStyle(color: Colors.white)),
        ),
      ],
    ));
    if (confirm != true) return;
    try {
      // Önce formu kaydet (photos, signatures dahil)
      // Latest data'yı çek ki External Manager'ın girdiği _ext_manager_ signature vs. kaybolmasın
      Map<String, dynamic> submitData = {};
      if (widget.args.formId != null) {
        final existing = await SupabaseService.getOrderForm(widget.args.formId!);
        if (existing != null && existing['data'] != null) {
          submitData = Map<String, dynamic>.from(existing['data']);
        }
      }
      
      final newData = widget.buildData();
      submitData.addAll(newData);
      submitData['photos'] = _photos;
      
      await SupabaseService.upsertOrderForm(
        id: widget.args.formId,
        orderId: widget.args.orderId,
        formType: widget.formType,
        status: widget.status,
        data: submitData,
        userId: widget.args.appState.userId,
      );
      // Sonra onayla
      if (widget.args.formId != null) {
        await SupabaseService.approveOrderForm(widget.args.formId!, widget.args.appState.userId);
      }
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
          content: Text('Formular genehmigt ✓', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600)),
          backgroundColor: Color(0xFF10B981),
        ));
        Navigator.pop(ctx);
      }
    } catch (e) {
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Fehler: $e'), backgroundColor: AppTheme.error));
      }
    }
  }

  Future<void> _delete(BuildContext ctx) async {
    if (widget.args.isApproved) {
      ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
        content: Text('Genehmigte Formulare können nicht gelöscht werden.', style: TextStyle(fontFamily: 'Inter')),
        backgroundColor: AppTheme.error,
      ));
      return;
    }
    final confirm = await showDialog<bool>(context: ctx, builder: (c) => AlertDialog(
      title: const Text('Formular löschen', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold)),
      content: const Text('Möchten Sie dieses Formular wirklich löschen? Alle Daten gehen verloren.', style: TextStyle(fontFamily: 'Inter')),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Abbrechen')),
        ElevatedButton(
          onPressed: () => Navigator.pop(c, true),
          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
          child: const Text('Löschen', style: TextStyle(color: Colors.white)),
        ),
      ],
    ));
    if (confirm != true) return;
    try {
      if (widget.args.formId != null) await SupabaseService.deleteOrderForm(widget.args.formId!);
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Gelöscht'), backgroundColor: AppTheme.error));
        Navigator.pop(ctx);
      }
    } catch (e) {
      if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Fehler: $e'), backgroundColor: AppTheme.error));
    }
  }

  Future<void> _pickAndUploadPhoto() async {
    showModalBottomSheet(context: context, builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.camera_alt),
            title: const Text('Foto (Kamera / Galerie)'),
            subtitle: const Text('Wird komprimiert, um Speicherplatz zu sparen.'),
            onTap: () {
              Navigator.pop(ctx);
              _handleImagePick();
            },
          ),
          ListTile(
            leading: const Icon(Icons.insert_drive_file),
            title: const Text('Dokument (PDF, Doc)'),
            onTap: () {
              Navigator.pop(ctx);
              _handleFilePick();
            },
          ),
        ],
      ),
    ));
  }

  Future<void> _handleImagePick() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 50, maxWidth: 1024);
      if (picked == null) return;

      setState(() => _uploading = true);
      final bytes = await picked.readAsBytes();
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${picked.name}';
      
      final url = await SupabaseService.uploadDocument(fileName, bytes);
      if (mounted) setState(() { _photos.add(url); _uploading = false; });
    } catch (e) {
      if (mounted) { setState(() => _uploading = false); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload Fehler: $e'))); }
    }
  }

  Future<void> _handleFilePick() async {
    try {
      // Import needed inline or ensure file_picker is imported at top
      // We will ensure file_picker is imported below.
      final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['pdf', 'doc', 'docx', 'txt']);
      if (result == null || result.files.single.bytes == null) return;

      setState(() => _uploading = true);
      final bytes = result.files.single.bytes!;
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${result.files.single.name}';
      
      final url = await SupabaseService.uploadDocument(fileName, bytes);
      if (mounted) setState(() { _photos.add(url); _uploading = false; });
    } catch (e) {
      if (mounted) { setState(() => _uploading = false); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload Fehler: $e'))); }
    }
  }

  Future<void> _downloadPdf() async {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('PDF wird generiert...')));
    try {
      Map<String, dynamic> combinedData = {};
      if (widget.args.formId != null) {
        final existing = await SupabaseService.getOrderForm(widget.args.formId!);
        if (existing != null && existing['data'] != null) {
          combinedData = Map<String, dynamic>.from(existing['data']);
        }
      } else {
        combinedData = Map<String, dynamic>.from(widget.args.data);
      }
      
      final newData = widget.buildData();
      combinedData.addAll(newData);
      combinedData['photos'] = _photos;

      final bytes = await PdfService.generateGenericFormPdf(
        title: widget.title,
        subtitle: widget.subtitle,
        orderId: widget.args.orderId,
        data: combinedData,
      );
      await PdfService.downloadPdf(bytes, 'Formular_${widget.formType}.pdf');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('PDF Fehler: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final args = widget.args;
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        backgroundColor: widget.color,
        foregroundColor: Colors.white,
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(widget.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, fontFamily: 'Inter')),
          Text(widget.subtitle, style: const TextStyle(fontSize: 11, fontFamily: 'Inter', color: Colors.white70)),
        ]),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            tooltip: 'Als PDF herunterladen',
            onPressed: () => _downloadPdf(),
          ),
          if (args.canDelete && args.formId != null && !args.isApproved)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Formular löschen',
              onPressed: () => _delete(context),
            ),
          if (args.canApprove && args.formId != null && !args.isApproved)
            TextButton.icon(
              onPressed: () => _approve(context),
              icon: const Icon(Icons.verified_outlined, color: Colors.white, size: 18),
              label: const Text('Genehmigen', style: TextStyle(color: Colors.white, fontFamily: 'Inter', fontWeight: FontWeight.w600, fontSize: 12)),
            ),
          // Ext. Manager sadece yorum + geri gönder yapabilir, formu kaydedemez
          if (args.editable && !args.isApproved && !args.appState.isExternalManager)
            TextButton.icon(
              onPressed: () => _save(context),
              icon: const Icon(Icons.save_outlined, color: Colors.white, size: 18),
              label: const Text('Speichern', style: TextStyle(color: Colors.white, fontFamily: 'Inter', fontWeight: FontWeight.w600, fontSize: 12)),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Approval banner
          if (args.isApproved) ...[
            Builder(builder: (ctx) {
              final u = args.row?['approved_by_user'] as Map?;
              final name = u != null ? '${u['first_name'] ?? ''} ${u['last_name'] ?? ''}'.trim() : '';
              final ts = args.row?['approved_at'] as String?;
              final dt = ts != null ? DateTime.tryParse(ts)?.toLocal() : null;
              return Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(color: const Color(0xFF10B981).withOpacity(0.08), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3))),
                child: Row(children: [
                  const Icon(Icons.verified_outlined, color: Color(0xFF10B981), size: 18),
                  const SizedBox(width: 8),
                  Expanded(child: Text(
                    'Genehmigt von $name${dt != null ? ' am ${dt.day}.${dt.month}.${dt.year}' : ''}',
                    style: const TextStyle(fontSize: 12, fontFamily: 'Inter', color: Color(0xFF10B981), fontWeight: FontWeight.w600),
                  )),
                ]),
              );
            }),
          ],

          // Status chooser
          if (!args.isApproved) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.divider)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Status', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textSub, fontFamily: 'Inter', letterSpacing: 0.5)),
                const SizedBox(height: 10),
                Wrap(spacing: 8, children: [
                  _statusChip('nicht_begonnen', 'Nicht begonnen', const Color(0xFF94A3B8), widget.status, args.editable && !args.appState.isExternalManager, widget.onStatusChanged),
                  _statusChip('in_bearbeitung', 'In Bearbeitung', const Color(0xFFF59E0B), widget.status, args.editable && !args.appState.isExternalManager, widget.onStatusChanged),
                  _statusChip('fertig', 'Fertig', const Color(0xFF10B981), widget.status, args.editable && !args.appState.isExternalManager, widget.onStatusChanged),
                ]),
              ]),
            ),
            const SizedBox(height: 16),
          ],

          // ── Form Fields ──
          // Form fields
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.divider)),
            child: widget.fields,
          ),
          
          const SizedBox(height: 16),
          
          // --- PHOTOS / DOCS SECTION ---
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.divider)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Fotos & Dokumente', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, fontFamily: 'Inter')),
                    if (args.editable && !args.isApproved)
                      TextButton.icon(
                        onPressed: _uploading ? null : _pickAndUploadPhoto,
                        icon: _uploading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.add_a_photo_outlined),
                        label: const Text('Hinzufügen'),
                      ),
                  ],
                ),
                if (_photos.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text('Keine Dateien angehängt.', style: TextStyle(fontSize: 13, color: AppTheme.textSub, fontFamily: 'Inter')),
                  )
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _photos.map((url) => Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(url, width: 80, height: 80, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(width: 80, height: 80, color: Colors.grey[200], child: const Icon(Icons.insert_drive_file))),
                        ),
                        if (args.editable && !args.isApproved)
                          Positioned(
                            right: 0, top: 0,
                            child: InkWell(
                              onTap: () => setState(() => _photos.remove(url)),
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                                child: const Icon(Icons.close, color: Colors.white, size: 14),
                              ),
                            ),
                          )
                      ],
                    )).toList(),
                  )
              ],
            ),
          ),

          // ── Workflow Stage Banner / Aktionen AT BOTTOM ──
          const SizedBox(height: 24),
          const Divider(thickness: 2),
          const SizedBox(height: 16),
          Builder(builder: (ctx) {
            final stage = args.workflowStage;
            final appState = args.appState;
            final isExtMgr = appState.isExternalManager;
            final extComment = (args.data['_ext_manager_comment'] as String?) ?? '';
            final extSignature = (args.data['_ext_manager_signature'] as String?) ?? '';
            final sentAt = (args.data['_sent_to_ext_at'] as String?);
            final returnedAt = (args.data['_ext_returned_at'] as String?);

            // Zaten tamamlanmış
            if (stage == 'completed') {
              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3)),
                ),
                child: const Row(children: [
                  Icon(Icons.check_circle, color: Color(0xFF10B981), size: 18),
                  SizedBox(width: 8),
                  Expanded(child: Text('Workflow abgeschlossen. Formular archiviert.', style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: Color(0xFF10B981)))),
                ]),
              );
            }

            // Ext. Manager bekleniyor VEYA Açılmış
            if (stage == 'pending_ext_review') {
              return Column(children: [
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.orange.withOpacity(0.3)),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      const Icon(Icons.schedule_send, color: Colors.orange, size: 18),
                      const SizedBox(width: 8),
                      Expanded(child: Text(
                        isExtMgr ? 'Bitte hier als Externer Manager Feedback geben & unterschreiben:' : 'Wartet auf Externen Manager', 
                        style: const TextStyle(fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.bold, color: Colors.orange)
                      )),
                    ]),
                    if (sentAt != null && !isExtMgr) ...[
                      const SizedBox(height: 4),
                      Text('Gesendet: ${_formatDate(sentAt)}', style: const TextStyle(fontSize: 11, color: AppTheme.textSub, fontFamily: 'Inter')),
                    ],
                  ]),
                ),
                // SADECE EXTERNAL MANAGER İÇİN YORUM + GERİ GÖNDER BUTONU
                if (isExtMgr) ...[
                  _ExtManagerCommentPanel(
                    onSend: (comment, sign) => _sendBackToBl(context, comment, sign),
                  ),
                  const SizedBox(height: 12),
                ],
              ]);
            }

            // BL onayı bekleniyor VEYA tamamlanmış formda imza var
            if (stage == 'pending_bl_approval' || (['team_editing', 'completed', 'approved'].contains(stage) && extSignature.isNotEmpty)) {
              return Column(children: [
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.success.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.success.withOpacity(0.3)),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Row(children: [
                      Icon(Icons.check_circle, color: AppTheme.success, size: 18),
                      SizedBox(width: 8),
                      Expanded(child: Text('Externer Manager hat geantwortet', style: TextStyle(fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.success))),
                    ]),
                    if (extComment.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppTheme.success.withOpacity(0.2)),
                        ),
                        child: Text(extComment, style: const TextStyle(fontFamily: 'Inter', fontSize: 13, color: Colors.black87)),
                      ),
                    ],
                    if (extSignature.isNotEmpty && extSignature.length > 50) ...[
                      const SizedBox(height: 12),
                      const Text('Unterschrift Ext. Manager:', style: TextStyle(fontSize: 11, fontFamily: 'Inter', color: AppTheme.textSub)),
                      const SizedBox(height: 4),
                      Container(
                        width: 200,
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade300)),
                        child: Image.memory(base64Decode(extSignature), fit: BoxFit.contain, errorBuilder: (_, __, ___) => const Text('Ungültige Signatur')),
                      ),
                    ],
                    if (returnedAt != null) ...[
                      const SizedBox(height: 8),
                      Text('Rückmeldung am: ${_formatDate(returnedAt)}', style: const TextStyle(fontSize: 11, color: AppTheme.textSub, fontFamily: 'Inter')),
                    ],
                  ]),
                ),
                // BL ise "Abschließen" butonu
                if (args.canSendToExt && stage == 'pending_bl_approval') ...[
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () => _completeWorkflow(context),
                      icon: const Icon(Icons.check_circle_outline),
                      label: const Text('Workflow abschließen & PDF', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ]);
            }

            // Normal team_editing aşaması: BL-gonderme butonu göster (TOGGLE GIBI)
            if (stage == 'team_editing' && args.canSendToExt) {
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
                    const Padding(
                      padding: EdgeInsets.fromLTRB(14, 12, 14, 8),
                      child: Row(children: [
                        Icon(Icons.share_outlined, size: 18, color: Color(0xFF6366F1)),
                        SizedBox(width: 8),
                        Text('EXTERNEN MANAGER EINBEZIEHEN', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textSub, letterSpacing: 0.5, fontFamily: 'Inter')),
                      ]),
                    ),
                    const Divider(height: 1),
                    Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(
                            children: [
                              const Expanded(
                                child: Text('📋 Noch nicht geteilt', style: TextStyle(fontFamily: 'Inter', fontSize: 13, color: AppTheme.textSub)),
                              ),
                              Switch(
                                value: false,
                                activeColor: const Color(0xFF6366F1),
                                onChanged: (val) {
                                  if (val) {
                                      // Set it as pending_ext_review and save, so the UI updates to show the signature panel
                                      _sendToExtManager(context);
                                  }
                                },
                              ),
                            ],
                          ),
                          const Padding(
                            padding: EdgeInsets.only(top: 4),
                            child: Text('Aktivieren → Externer Manager kann dieses Formular sehen, kommentieren und unterschreiben.', style: TextStyle(fontSize: 11, color: AppTheme.textSub, fontFamily: 'Inter')),
                          ),
                        ])
                    )
                  ],
                ),
              );
            }

            // NOT SHARED INFO FOR EXT MANAGER
            if (isExtMgr && (stage == 'team_editing' || stage == 'draft')) {
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
                    const Padding(
                      padding: EdgeInsets.fromLTRB(14, 12, 14, 8),
                      child: Row(children: [
                        Icon(Icons.lock_outline, size: 18, color: Colors.grey),
                        SizedBox(width: 8),
                        Text('ZUGANG', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textSub, letterSpacing: 0.5, fontFamily: 'Inter')),
                      ]),
                    ),
                    const Divider(height: 1),
                    const Padding(
                      padding: EdgeInsets.all(14),
                      child: Text(
                        'Dieses Formular wurde noch nicht für Sie freigegeben. Bitte warten Sie, bis der zuständige Bereichsleiter es mit Ihnen teilt.',
                        style: TextStyle(fontFamily: 'Inter', color: AppTheme.textSub, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              );
            }

            return const SizedBox();
          }),

          // Read-only notice
          if (!args.editable && !args.canApprove)
            Container(
              margin: const EdgeInsets.only(top: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppTheme.warning.withOpacity(0.08), borderRadius: BorderRadius.circular(10), border: Border.all(color: AppTheme.warning.withOpacity(0.3))),
              child: const Row(children: [
                Icon(Icons.lock_outline, color: AppTheme.warning, size: 16),
                SizedBox(width: 8),
                Expanded(child: Text('Nur Lesen – Sie sind nicht berechtigt, dieses Formular zu bearbeiten.', style: TextStyle(fontSize: 12, fontFamily: 'Inter', color: AppTheme.warning))),
              ]),
            ),
          const SizedBox(height: 40),
        ]),
      ),
    );
  }

  Widget _statusChip(String key, String label, Color color, String current, bool enabled, ValueChanged<String> onChange) {
    final selected = current == key;
    return ChoiceChip(
      label: Text(label, style: TextStyle(fontSize: 12, fontFamily: 'Inter', color: selected ? Colors.white : color, fontWeight: FontWeight.w600)),
      selected: selected,
      onSelected: enabled ? (_) => onChange(key) : null,
      selectedColor: color,
      backgroundColor: color.withOpacity(0.08),
      side: BorderSide(color: selected ? color : color.withOpacity(0.3)),
    );
  }

  String _formatDate(String isoString) {
    final dt = DateTime.tryParse(isoString)?.toLocal();
    if (dt == null) return isoString;
    return '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

// ── Ext. Manager Yorum Paneli ─────────────────────────────────────────────────

class _ExtManagerCommentPanel extends StatefulWidget {
  final Future<void> Function(String comment, String signature) onSend;
  const _ExtManagerCommentPanel({required this.onSend});

  @override
  State<_ExtManagerCommentPanel> createState() => _ExtManagerCommentPanelState();
}

class _ExtManagerCommentPanelState extends State<_ExtManagerCommentPanel> {
  final _ctrl = TextEditingController();
  String? _sig;
  bool _sending = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF6366F1).withOpacity(0.4)),
        boxShadow: [BoxShadow(color: const Color(0xFF6366F1).withOpacity(0.07), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Icon(Icons.comment_outlined, color: Color(0xFF6366F1), size: 18),
          SizedBox(width: 8),
          Text('Meine Stellungnahme \u0026 Unterschrift', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF6366F1))),
        ]),
        const SizedBox(height: 10),
        TextField(
          controller: _ctrl,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: 'Kommentar, Anmerkungen oder Anweisungen eingeben...',
            hintStyle: const TextStyle(color: AppTheme.textSub, fontFamily: 'Inter', fontSize: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF6366F1))),
          ),
          style: const TextStyle(fontFamily: 'Inter', fontSize: 13),
        ),
        const SizedBox(height: 12),
        const Text('Digitale Unterschrift', style: TextStyle(fontSize: 12, color: AppTheme.textSub, fontFamily: 'Inter', fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        SignaturePadWidget(onSigned: (b64) => _sig = b64),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            onPressed: _sending ? null : () async {
              if (_ctrl.text.trim().isEmpty && (_sig == null || _sig!.isEmpty)) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bitte Kommentar oder Unterschrift angeben.'), backgroundColor: AppTheme.error));
                return;
              }
              setState(() => _sending = true);
              await widget.onSend(_ctrl.text.trim(), _sig ?? '');
              if (mounted) setState(() => _sending = false);
            },
            icon: _sending ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.reply_all),
            label: const Text('Stellungnahme senden \u0026 zurückleiten', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold)),
          ),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SHARED FIELD HELPERS
// ─────────────────────────────────────────────────────────────────────────────


Widget _section(String label) => Padding(
  padding: const EdgeInsets.only(top: 16, bottom: 8),
  child: Text(label.toUpperCase(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.textSub, fontFamily: 'Inter', letterSpacing: 1.2)),
);

Widget _field(String label, TextEditingController c, {bool ro = false, bool multi = false, TextInputType? kb}) =>
  Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: TextField(
      controller: c, readOnly: ro, maxLines: multi ? 4 : 1,
      keyboardType: kb ?? (multi ? TextInputType.multiline : TextInputType.text),
      decoration: InputDecoration(
        labelText: label, isDense: true, alignLabelWithHint: multi,
        filled: ro, fillColor: ro ? const Color(0xFFF8FAFC) : null,
      ),
      style: const TextStyle(fontFamily: 'Inter', fontSize: 13),
    ),
  );

Widget _drop(String label, String? value, List<String> opts, bool enabled, ValueChanged<String?> cb) =>
  Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: DropdownButtonFormField<String>(
      value: opts.contains(value) ? value : null,
      decoration: InputDecoration(labelText: label, isDense: true),
      items: opts.map((o) => DropdownMenuItem(value: o, child: Text(o, style: const TextStyle(fontFamily: 'Inter', fontSize: 13)))).toList(),
      onChanged: enabled ? cb : null,
    ),
  );

Widget _signatureBox(String label, TextEditingController c, bool ro) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.textSub, fontFamily: 'Inter', fontWeight: FontWeight.bold)),
      const SizedBox(height: 6),
      if (ro || (c.text.isNotEmpty && c.text.length > 50)) // Fall back logic or already filled
        Container(
          height: 100, width: double.infinity,
          decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(8), border: Border.all(color: AppTheme.border)),
          alignment: Alignment.center,
          child: c.text.isEmpty
              ? const Text('Keine Unterschrift', style: TextStyle(color: AppTheme.textSub, fontStyle: FontStyle.italic, fontSize: 13))
              : (c.text.length > 50 ? Image.memory(base64Decode(c.text), fit: BoxFit.contain, errorBuilder: (_, __, ___) => const Text('Keine Unterschrift', style: TextStyle(color: AppTheme.warning, fontStyle: FontStyle.italic))) : Text(c.text, style: const TextStyle(fontStyle: FontStyle.italic))),
        )
      else
        Container(
          decoration: BoxDecoration(border: Border.all(color: AppTheme.border), borderRadius: BorderRadius.circular(8), color: Colors.white),
          child: SignaturePadWidget(onSigned: (b64) => c.text = b64),
        ),
    ]),
  );
}

Widget _netto(double hours) =>
  Container(
    padding: const EdgeInsets.all(12),
    margin: const EdgeInsets.only(bottom: 10),
    decoration: BoxDecoration(color: AppTheme.primary.withOpacity(0.06), borderRadius: BorderRadius.circular(8), border: Border.all(color: AppTheme.primary.withOpacity(0.2))),
    child: Row(children: [
      const Icon(Icons.timer_outlined, color: AppTheme.primary, size: 16),
      const SizedBox(width: 8),
      const Text('Arbeitsstunden (Netto): ', style: TextStyle(fontSize: 12, color: AppTheme.textSub, fontFamily: 'Inter')),
      Text('${hours.toStringAsFixed(2)} h', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.primary, fontFamily: 'Inter')),
    ]),
  );

// ─────────────────────────────────────────────────────────────────────────────
// FORM 1: BEREICHSFREIGABE
// ─────────────────────────────────────────────────────────────────────────────

class _BereichsfreigabeScreen extends StatefulWidget {
  final _FormArgs args;
  const _BereichsfreigabeScreen({required this.args});
  @override State<_BereichsfreigabeScreen> createState() => _BereichsfreigabeState();
}

class _BereichsfreigabeState extends State<_BereichsfreigabeScreen> {
  late String _status;
  late final TextEditingController _proj, _bereich, _datum, _team, _bauleiter, _auftraggeber, _hinweise, _notizen, _freigabeVon, _signTeam, _signObj;
  String? _vorbereitungen, _zugaenglich, _schutzbedarf, _verschmutzung;

  bool get ro => !widget.args.editable || widget.args.isApproved;

  @override
  void initState() {
    super.initState();
    final d = widget.args.data;
    _status = widget.args.status;
    _proj         = TextEditingController(text: d['projektbezeichnung'] ?? '');
    _bereich      = TextEditingController(text: d['bereich'] ?? '');
    _datum        = TextEditingController(text: d['datum'] ?? '');
    _team         = TextEditingController(text: d['team'] ?? '');
    _bauleiter    = TextEditingController(text: d['bauleiter'] ?? '');
    _auftraggeber = TextEditingController(text: d['auftraggeber'] ?? '');
    _hinweise     = TextEditingController(text: d['hinweise'] ?? '');
    _notizen      = TextEditingController(text: d['notizen'] ?? '');
    _freigabeVon  = TextEditingController(text: d['freigabe_von'] ?? '');
    _signTeam     = TextEditingController(text: d['sign_teamleiter'] ?? '');
    _signObj      = TextEditingController(text: d['sign_objektleiter'] ?? '');
    _vorbereitungen = d['vorbereitungen'];
    _zugaenglich    = d['zugaenglich'];
    _schutzbedarf   = d['schutzbedarf'];
    _verschmutzung  = d['verschmutzung'];
  }

  @override
  Widget build(BuildContext ctx) => _FormScaffold(
    title: 'Bereichsfreigabe', subtitle: 'vor Reinigungsstart', color: const Color(0xFF10B981),
    args: widget.args, formType: 'bereichsfreigabe', status: _status,
    onStatusChanged: (s) => setState(() => _status = s),
    buildData: () => {
      'projektbezeichnung': _proj.text.trim(), 'bereich': _bereich.text.trim(),
      'datum': _datum.text.trim(), 'team': _team.text.trim(),
      'bauleiter': _bauleiter.text.trim(), 'auftraggeber': _auftraggeber.text.trim(),
      'vorbereitungen': _vorbereitungen, 'zugaenglich': _zugaenglich,
      'schutzbedarf': _schutzbedarf, 'verschmutzung': _verschmutzung,
      'hinweise': _hinweise.text.trim(), 'notizen': _notizen.text.trim(),
      'freigabe_von': _freigabeVon.text.trim(),
      'sign_teamleiter': _signTeam.text.trim(), 'sign_objektleiter': _signObj.text.trim(),
    },
    fields: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _section('Projektangaben'),
      _field('Projektbezeichnung', _proj, ro: ro),
      _field('Bereich / Abschnitt', _bereich, ro: ro),
      _field('Datum', _datum, ro: ro, kb: TextInputType.datetime),
      _field('Ausführendes Team', _team, ro: ro),
      _field('Bauleiter (Auftraggeber)', _bauleiter, ro: ro),
      _field('Auftraggeber (Firma / Name)', _auftraggeber, ro: ro),
      _section('Status'),
      _drop('Vorbereitungen anderer Abschnitte abgeschlossen', _vorbereitungen, ['Ja', 'Nein', 'Teilweise'], !ro, (v) => setState(() => _vorbereitungen = v)),
      _drop('Bereich zugänglich / freigegeben', _zugaenglich, ['Ja', 'Nein', 'Eingeschränkt'], !ro, (v) => setState(() => _zugaenglich = v)),
      _drop('Schutzbedarf vorhanden', _schutzbedarf, ['Ja', 'Nein'], !ro, (v) => setState(() => _schutzbedarf = v)),
      _drop('Verschmutzungsgrad', _verschmutzung, ['Gering', 'Mittel', 'Stark'], !ro, (v) => setState(() => _verschmutzung = v)),
      _section('Hinweise & Notizen'),
      _field('Besondere Materialoberflächen / Hinweise', _hinweise, ro: ro, multi: true),
      _field('Freie Notizen', _notizen, ro: ro, multi: true),
      _section('Freigabe & Unterschriften'),
      _field('Freigabe erteilt durch', _freigabeVon, ro: ro),
      _signatureBox('Unterschrift Teamleiter', _signTeam, ro),
      _signatureBox('Unterschrift Objektleiter', _signObj, ro),
    ]),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// FORM 2: QUALITÄTSKONTROLLE
// ─────────────────────────────────────────────────────────────────────────────

class _QualitaetskontrolleScreen extends StatefulWidget {
  final _FormArgs args;
  const _QualitaetskontrolleScreen({required this.args});
  @override State<_QualitaetskontrolleScreen> createState() => _QualitaetskontrolleState();
}

class _QualitaetskontrolleState extends State<_QualitaetskontrolleScreen> {
  late String _status;
  late final TextEditingController _proj, _auftraggeber, _bereich, _datumRein, _datumAbna, _teamleiter, _restmaengel, _hinweise, _notizen, _freigabeVon, _signBauleitung, _signObjekt;
  String? _boden, _waende, _tueren, _glas, _technik, _schutzbedarf, _verschmutzung, _fotoDoku, _statusFreigabe;

  static const _qOpts = ['Einwandfrei', 'Nacharbeit erforderlich', 'Nicht geprüft'];

  bool get ro => !widget.args.editable || widget.args.isApproved;

  @override
  void initState() {
    super.initState();
    final d = widget.args.data;
    _status = widget.args.status;
    final teamName = '${widget.args.appState.currentUser?['first_name'] ?? ''} ${widget.args.appState.currentUser?['last_name'] ?? ''}'.trim();
    _proj          = TextEditingController(text: d['projektbezeichnung'] ?? '');
    _auftraggeber  = TextEditingController(text: d['auftraggeber'] ?? '');
    _bereich       = TextEditingController(text: d['bereich'] ?? '');
    _datumRein     = TextEditingController(text: d['datum_reinigung'] ?? '');
    _datumAbna     = TextEditingController(text: d['datum_abnahme'] ?? '');
    _teamleiter    = TextEditingController(text: d['teamleiter'] ?? teamName);
    _restmaengel   = TextEditingController(text: d['restmaengel'] ?? '');
    _hinweise      = TextEditingController(text: d['hinweise'] ?? '');
    _notizen       = TextEditingController(text: d['notizen'] ?? '');
    _freigabeVon   = TextEditingController(text: d['freigabe_von'] ?? '');
    _signBauleitung = TextEditingController(text: d['sign_bauleitung'] ?? '');
    _signObjekt    = TextEditingController(text: d['sign_objektleiter'] ?? '');
    _boden = d['boden']; _waende = d['waende']; _tueren = d['tueren'];
    _glas = d['glas']; _technik = d['technik']; _schutzbedarf = d['schutzbedarf'];
    _verschmutzung = d['verschmutzung']; _fotoDoku = d['foto_doku']; _statusFreigabe = d['status_freigabe'];
  }

  @override
  Widget build(BuildContext ctx) => _FormScaffold(
    title: 'Qualitätskontrolle', subtitle: 'Abnahme nach Reinigung', color: const Color(0xFF6366F1),
    args: widget.args, formType: 'qualitaetskontrolle', status: _status,
    onStatusChanged: (s) => setState(() => _status = s),
    buildData: () => {
      'projektbezeichnung': _proj.text.trim(), 'auftraggeber': _auftraggeber.text.trim(),
      'bereich': _bereich.text.trim(), 'datum_reinigung': _datumRein.text.trim(),
      'datum_abnahme': _datumAbna.text.trim(), 'teamleiter': _teamleiter.text.trim(),
      'boden': _boden, 'waende': _waende, 'tueren': _tueren, 'glas': _glas, 'technik': _technik,
      'schutzbedarf': _schutzbedarf, 'verschmutzung': _verschmutzung,
      'restmaengel': _restmaengel.text.trim(), 'hinweise': _hinweise.text.trim(),
      'notizen': _notizen.text.trim(), 'foto_doku': _fotoDoku, 'status_freigabe': _statusFreigabe,
      'freigabe_von': _freigabeVon.text.trim(),
      'sign_bauleitung': _signBauleitung.text.trim(), 'sign_objektleiter': _signObjekt.text.trim(),
    },
    fields: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _section('Projektangaben'),
      _field('Projektbezeichnung', _proj, ro: ro),
      _field('Auftraggeber (Firma / Name)', _auftraggeber, ro: ro),
      _field('Bereich / Abschnitt', _bereich, ro: ro),
      _field('Datum der Reinigung', _datumRein, ro: ro, kb: TextInputType.datetime),
      _field('Datum der Abnahme', _datumAbna, ro: ro, kb: TextInputType.datetime),
      TextField(
        controller: _teamleiter, readOnly: true,
        decoration: InputDecoration(
          labelText: 'Teamleiter vor Ort',
          isDense: true, filled: true, fillColor: const Color(0xFFF8FAFC),
          suffixIcon: const Icon(Icons.lock_outline, size: 14, color: AppTheme.textSub),
        ),
        style: const TextStyle(fontFamily: 'Inter', fontSize: 13),
      ),
      const SizedBox(height: 10),
      _section('Prüfbereiche'),
      _drop('Bodenflächen', _boden, _qOpts, !ro, (v) => setState(() => _boden = v)),
      _drop('Wände / Wandanschlüsse', _waende, _qOpts, !ro, (v) => setState(() => _waende = v)),
      _drop('Türen / Beschläge', _tueren, _qOpts, !ro, (v) => setState(() => _tueren = v)),
      _drop('Glas / Festverglasung', _glas, _qOpts, !ro, (v) => setState(() => _glas = v)),
      _drop('Technikbereiche / Installationen', _technik, _qOpts, !ro, (v) => setState(() => _technik = v)),
      _section('Gesamtbewertung'),
      _drop('Schutzbedarf vorhanden', _schutzbedarf, ['Ja', 'Nein'], !ro, (v) => setState(() => _schutzbedarf = v)),
      _drop('Verschmutzungsgrad', _verschmutzung, ['Gering', 'Mittel', 'Stark'], !ro, (v) => setState(() => _verschmutzung = v)),
      _field('Restmängel / Offene Punkte', _restmaengel, ro: ro, multi: true),
      _field('Besondere Materialoberflächen / Hinweise', _hinweise, ro: ro, multi: true),
      _field('Freie Notizen', _notizen, ro: ro, multi: true),
      _section('Freigabe & Unterschriften'),
      _drop('Fotodokumentation erstellt', _fotoDoku, ['Ja', 'Nein', 'Nicht erforderlich'], !ro, (v) => setState(() => _fotoDoku = v)),
      _drop('Status Freigabe', _statusFreigabe, ['Freigegeben', 'Bedingt freigegeben', 'Nicht freigegeben'], !ro, (v) => setState(() => _statusFreigabe = v)),
      _field('Freigabe erteilt von', _freigabeVon, ro: ro),
      _signatureBox('Unterschrift Bauleitung', _signBauleitung, ro),
      _signatureBox('Unterschrift Objektleiter Reinigung', _signObjekt, ro),
    ]),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// FORM 3: STUNDENLOHN & LEISTUNGSNACHWEIS
// ─────────────────────────────────────────────────────────────────────────────

class _StundenlohnScreen extends StatefulWidget {
  final _FormArgs args;
  const _StundenlohnScreen({required this.args});
  @override State<_StundenlohnScreen> createState() => _StundenlohnState();
}

class _StundenlohnState extends State<_StundenlohnScreen> {
  late String _status;
  late final TextEditingController _proj, _auftraggeber, _bereich, _datum, _mitarbeiter, _beginn, _ende, _pausen, _taetigkeiten, _geraete, _besonderheiten, _notizen, _signMa, _signBl;
  String? _leistungsart, _leistungstyp;

  bool get ro => !widget.args.editable || widget.args.isApproved;

  double get _nettoH {
    final bParts = _beginn.text.split(':');
    final eParts = _ende.text.split(':');
    if (bParts.length < 2 || eParts.length < 2) return 0;
    final bH = int.tryParse(bParts[0]) ?? 0;
    final bM = int.tryParse(bParts[1]) ?? 0;
    final eH = int.tryParse(eParts[0]) ?? 0;
    final eM = int.tryParse(eParts[1]) ?? 0;
    final p = int.tryParse(_pausen.text) ?? 0;
    final diff = (eH * 60 + eM) - (bH * 60 + bM) - p;
    return diff > 0 ? diff / 60.0 : 0;
  }

  @override
  void initState() {
    super.initState();
    final d = widget.args.data;
    _status = widget.args.status;
    _proj         = TextEditingController(text: d['projektbezeichnung'] ?? '');
    _auftraggeber = TextEditingController(text: d['auftraggeber'] ?? '');
    _bereich      = TextEditingController(text: d['bereich'] ?? '');
    _datum        = TextEditingController(text: d['datum'] ?? '');
    _mitarbeiter  = TextEditingController(text: d['mitarbeiter'] ?? '');
    _beginn       = TextEditingController(text: d['beginn'] ?? '');
    _ende         = TextEditingController(text: d['ende'] ?? '');
    _pausen       = TextEditingController(text: d['pausen']?.toString() ?? '');
    _taetigkeiten = TextEditingController(text: d['taetigkeiten'] ?? '');
    _geraete      = TextEditingController(text: d['geraete'] ?? '');
    _besonderheiten = TextEditingController(text: d['besonderheiten'] ?? '');
    _notizen      = TextEditingController(text: d['notizen'] ?? '');
    _signMa       = TextEditingController(text: d['sign_mitarbeiter'] ?? '');
    _signBl       = TextEditingController(text: d['sign_bauleitung'] ?? '');
    _leistungsart = d['leistungsart'];
    _leistungstyp = d['leistungstyp'];
  }

  @override
  Widget build(BuildContext ctx) => _FormScaffold(
    title: 'Stundenlohn- & Leistungsnachweis', subtitle: 'Tages- / Wochenrapport', color: const Color(0xFF64748B),
    args: widget.args, formType: 'stundenlohn', status: _status,
    onStatusChanged: (s) => setState(() => _status = s),
    buildData: () => {
      'projektbezeichnung': _proj.text.trim(), 'auftraggeber': _auftraggeber.text.trim(),
      'bereich': _bereich.text.trim(), 'datum': _datum.text.trim(), 'mitarbeiter': _mitarbeiter.text.trim(),
      'beginn': _beginn.text.trim(), 'ende': _ende.text.trim(), 'pausen': _pausen.text.trim(),
      'netto_stunden': _nettoH, 'leistungsart': _leistungsart, 'leistungstyp': _leistungstyp,
      'taetigkeiten': _taetigkeiten.text.trim(), 'geraete': _geraete.text.trim(),
      'besonderheiten': _besonderheiten.text.trim(), 'notizen': _notizen.text.trim(),
      'sign_mitarbeiter': _signMa.text.trim(), 'sign_bauleitung': _signBl.text.trim(),
    },
    fields: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _section('Projektangaben'),
      _field('Projektbezeichnung', _proj, ro: ro),
      _field('Auftraggeber (Firma / Name)', _auftraggeber, ro: ro),
      _field('Bereich / Abschnitt', _bereich, ro: ro),
      _field('Datum', _datum, ro: ro, kb: TextInputType.datetime),
      _field('Mitarbeiter (Name)', _mitarbeiter, ro: ro),
      _section('Arbeitszeiten'),
      Row(children: [
        Expanded(child: _field('Beginn Arbeitszeit', _beginn, ro: ro, kb: TextInputType.datetime)),
        const SizedBox(width: 12),
        Expanded(child: _field('Ende Arbeitszeit', _ende, ro: ro, kb: TextInputType.datetime)),
      ]),
      _field('Pausen (Min.)', _pausen, ro: ro, kb: TextInputType.number),
      StatefulBuilder(builder: (_, __) => _netto(_nettoH)),
      _section('Leistung'),
      _drop('Art der Leistung', _leistungsart, ['Baugrundreinigung', 'Feinreinigung', 'Nachreinigung', 'Schutzmaßnahmen', 'Sonstige'], !ro, (v) => setState(() => _leistungsart = v)),
      _field('Ausgeführte Tätigkeiten', _taetigkeiten, ro: ro, multi: true),
      _field('Eingesetzte Geräte / Mittel', _geraete, ro: ro, multi: true),
      _drop('Leistung Hauptauftrag oder Zusatzauftrag', _leistungstyp, ['Hauptauftrag', 'Zusatzauftrag', 'Stundenlohn'], !ro, (v) => setState(() => _leistungstyp = v)),
      _section('Sonstiges'),
      _field('Besonderheiten / Behinderungen', _besonderheiten, ro: ro, multi: true),
      _field('Freie Notizen', _notizen, ro: ro, multi: true),
      _section('Unterschriften'),
      _signatureBox('Unterschrift Mitarbeiter', _signMa, ro),
      _signatureBox('Unterschrift Bauleitung (Gegenzeichnung)', _signBl, ro),
    ]),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// FORM 4: MÄNGELLISTE
// ─────────────────────────────────────────────────────────────────────────────

class _MaengellisteScreen extends StatefulWidget {
  final _FormArgs args;
  const _MaengellisteScreen({required this.args});
  @override State<_MaengellisteScreen> createState() => _MaengellisteState();
}

class _MaengellisteState extends State<_MaengellisteScreen> {
  late String _status;
  late final TextEditingController _proj, _auftraggeber, _bereich, _datumErf, _erfasstVon;
  final List<TextEditingController> _descCtrl = [];
  final List<String?> _prio = [];
  late final TextEditingController _weitereHinweise, _freiNotizen, _verantwortlich, _erledigungstermin, _signTeam;
  String? _gesamtStatus;

  bool get ro => !widget.args.editable || widget.args.isApproved;

  @override
  void initState() {
    super.initState();
    final d = widget.args.data;
    _status = widget.args.status;
    _proj           = TextEditingController(text: d['projektbezeichnung'] ?? '');
    _auftraggeber   = TextEditingController(text: d['auftraggeber'] ?? '');
    _bereich        = TextEditingController(text: d['bereich'] ?? '');
    _datumErf       = TextEditingController(text: d['datum_erfassung'] ?? '');
    _erfasstVon     = TextEditingController(text: d['erfasst_von'] ?? '');
    _weitereHinweise = TextEditingController(text: d['weitere_hinweise'] ?? '');
    _freiNotizen    = TextEditingController(text: d['notizen'] ?? '');
    _verantwortlich = TextEditingController(text: d['verantwortlich'] ?? '');
    _erledigungstermin = TextEditingController(text: d['erledigungstermin'] ?? '');
    _signTeam       = TextEditingController(text: d['sign_teamleiter'] ?? '');
    _gesamtStatus   = d['gesamt_status'];
    final maengel = d['maengel'] as List? ?? [];
    for (int i = 0; i < 3; i++) {
      final m = i < maengel.length ? maengel[i] as Map? ?? {} : {};
      _descCtrl.add(TextEditingController(text: m['beschreibung'] ?? ''));
      _prio.add(m['prioritaet'] as String?);
    }
  }

  @override
  Widget build(BuildContext ctx) => _FormScaffold(
    title: 'Mängel- & Restpunkteliste', subtitle: 'Offene Punkte & Nacharbeit', color: const Color(0xFFEF4444),
    args: widget.args, formType: 'maengelliste', status: _status,
    onStatusChanged: (s) => setState(() => _status = s),
    buildData: () => {
      'projektbezeichnung': _proj.text.trim(), 'auftraggeber': _auftraggeber.text.trim(),
      'bereich': _bereich.text.trim(), 'datum_erfassung': _datumErf.text.trim(),
      'erfasst_von': _erfasstVon.text.trim(),
      'maengel': List.generate(3, (i) => {
        'beschreibung': _descCtrl[i].text.trim(), 'prioritaet': _prio[i],
      }).where((m) => (m['beschreibung'] as String).isNotEmpty).toList(),
      'weitere_hinweise': _weitereHinweise.text.trim(), 'notizen': _freiNotizen.text.trim(),
      'verantwortlich': _verantwortlich.text.trim(), 'erledigungstermin': _erledigungstermin.text.trim(),
      'gesamt_status': _gesamtStatus, 'sign_teamleiter': _signTeam.text.trim(),
    },
    fields: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _section('Projektangaben'),
      _field('Projektbezeichnung', _proj, ro: ro),
      _field('Auftraggeber (Firma / Name)', _auftraggeber, ro: ro),
      _field('Bereich / Abschnitt', _bereich, ro: ro),
      _field('Datum der Erfassung', _datumErf, ro: ro, kb: TextInputType.datetime),
      _field('Erfasst von', _erfasstVon, ro: ro),
      ...List.generate(3, (i) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _section('Mangel Nr. ${i + 1}'),
        _field('Mangel Nr. ${i + 1} – Beschreibung', _descCtrl[i], ro: ro, multi: true),
        _drop('Mangel ${i + 1} – Priorität', _prio[i], ['Sofort', 'Innerhalb 24h', 'Nächster Arbeitstag'], !ro, (v) => setState(() => _prio[i] = v)),
      ])),
      _section('Abschluss'),
      _field('Weitere Mängel / Anmerkungen', _weitereHinweise, ro: ro, multi: true),
      _field('Freie Notizen', _freiNotizen, ro: ro, multi: true),
      _field('Verantwortlich für Nacharbeit', _verantwortlich, ro: ro),
      _field('Erledigungstermin', _erledigungstermin, ro: ro, kb: TextInputType.datetime),
      _drop('Status bei Abschluss', _gesamtStatus, ['Alle erledigt', 'Teilweise erledigt', 'Offen'], !ro, (v) => setState(() => _gesamtStatus = v)),
      _section('Unterschrift'),
      _signatureBox('Unterschrift Teamleiter', _signTeam, ro),
    ]),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// FORM 5: TAGESRAPPORT
// ─────────────────────────────────────────────────────────────────────────────

class _TagesrapportScreen extends StatefulWidget {
  final _FormArgs args;
  const _TagesrapportScreen({required this.args});
  @override State<_TagesrapportScreen> createState() => _TagesrapportState();
}

class _TagesrapportState extends State<_TagesrapportScreen> {
  late String _status;
  late final TextEditingController _proj, _auftraggeber, _datum, _bereich, _ereignisse, _statErledigt, _statBehindert, _statZusatz, _personal, _vorkommnisse, _naechsteSchritte, _notizen, _signObjekt;
  String? _abstimmung;

  bool get ro => !widget.args.editable || widget.args.isApproved;

  @override
  void initState() {
    super.initState();
    final d = widget.args.data;
    _status = widget.args.status;
    _proj          = TextEditingController(text: d['projektbezeichnung'] ?? '');
    _auftraggeber  = TextEditingController(text: d['auftraggeber'] ?? '');
    _datum         = TextEditingController(text: d['datum'] ?? '');
    _bereich       = TextEditingController(text: d['bereich'] ?? '');
    _ereignisse    = TextEditingController(text: d['ereignisse'] ?? '');
    _statErledigt  = TextEditingController(text: d['status_erledigt'] ?? '');
    _statBehindert = TextEditingController(text: d['status_behindert'] ?? '');
    _statZusatz    = TextEditingController(text: d['status_zusatz'] ?? '');
    _personal      = TextEditingController(text: d['personal_anzahl']?.toString() ?? '');
    _vorkommnisse  = TextEditingController(text: d['vorkommnisse'] ?? '');
    _naechsteSchritte = TextEditingController(text: d['naechste_schritte'] ?? '');
    _notizen       = TextEditingController(text: d['notizen'] ?? '');
    _signObjekt    = TextEditingController(text: d['sign_objektleiter'] ?? '');
    _abstimmung    = d['abstimmung'];
  }

  @override
  Widget build(BuildContext ctx) => _FormScaffold(
    title: 'Tagesrapport', subtitle: 'Bauleitung & Interne Projektsteuerung', color: const Color(0xFF3B82F6),
    args: widget.args, formType: 'tagesrapport', status: _status,
    onStatusChanged: (s) => setState(() => _status = s),
    buildData: () => {
      'projektbezeichnung': _proj.text.trim(), 'auftraggeber': _auftraggeber.text.trim(),
      'datum': _datum.text.trim(), 'bereich': _bereich.text.trim(),
      'ereignisse': _ereignisse.text.trim(), 'status_erledigt': _statErledigt.text.trim(),
      'status_behindert': _statBehindert.text.trim(), 'status_zusatz': _statZusatz.text.trim(),
      'personal_anzahl': _personal.text.trim(), 'vorkommnisse': _vorkommnisse.text.trim(),
      'abstimmung': _abstimmung, 'naechste_schritte': _naechsteSchritte.text.trim(),
      'notizen': _notizen.text.trim(), 'sign_objektleiter': _signObjekt.text.trim(),
    },
    fields: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _section('Projektangaben'),
      _field('Projektbezeichnung', _proj, ro: ro),
      _field('Auftraggeber (Firma / Name)', _auftraggeber, ro: ro),
      _field('Datum', _datum, ro: ro, kb: TextInputType.datetime),
      _field('Bereich / Abschnitt', _bereich, ro: ro),
      _section('Tagesmeldung'),
      _field('Besondere Ereignisse / Abweichungen', _ereignisse, ro: ro, multi: true),
      _section('Status'),
      _field('Status: Erledigt', _statErledigt, ro: ro, multi: true),
      _field('Status: Behindert / Nicht freigegeben', _statBehindert, ro: ro, multi: true),
      _field('Status: Zusatzaufwand / Klärungsbedarf', _statZusatz, ro: ro, multi: true),
      _field('Eingesetztes Personal (Anzahl)', _personal, ro: ro, kb: TextInputType.number),
      _section('Abschluss'),
      _field('Besondere Vorkommnisse', _vorkommnisse, ro: ro, multi: true),
      _drop('Abstimmung mit Bauleitung erfolgt', _abstimmung, ['Ja', 'Nein', 'Ausstehend'], !ro, (v) => setState(() => _abstimmung = v)),
      _field('Nächste Schritte / Morgen', _naechsteSchritte, ro: ro, multi: true),
      _field('Freie Notizen', _notizen, ro: ro, multi: true),
      _section('Unterschrift'),
      _signatureBox('Unterschrift Objektleiter Reinigung', _signObjekt, ro),
    ]),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// HELPERS
// ─────────────────────────────────────────────────────────────────────────────

class _InfoMessage extends StatelessWidget {
  final IconData icon;
  final String message;
  const _InfoMessage({required this.icon, required this.message});
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 52, color: AppTheme.textSub),
        const SizedBox(height: 12),
        Text(message, textAlign: TextAlign.center, style: const TextStyle(color: AppTheme.textSub, fontFamily: 'Inter')),
      ]),
    ),
  );
}

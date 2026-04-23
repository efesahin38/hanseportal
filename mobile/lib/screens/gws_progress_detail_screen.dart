import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../theme/web_utils.dart';
import '../services/supabase_service.dart';
import '../services/localization_service.dart';
import '../providers/app_state.dart';
import '../widgets/signature_pad_widget.dart';
import 'gws_item_form_screen.dart';
import '../services/pdf_service.dart';

class GwsProgressDetailScreen extends StatefulWidget {
  final String planId;
  final String objectName;
  final bool isExternalManager;
  const GwsProgressDetailScreen({
    super.key, 
    required this.planId, 
    required this.objectName,
    this.isExternalManager = false,
  });

  @override
  State<GwsProgressDetailScreen> createState() => _GwsProgressDetailScreenState();
}

class _GwsProgressDetailScreenState extends State<GwsProgressDetailScreen> {
  static const Color _color = AppTheme.gwsColor;
  bool _loading = true;
  List<Map<String, dynamic>> _rooms = [];
  List<Map<String, dynamic>> _areas = [];

  String? _signatureBase64;
  final _commentController = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final rooms = await SupabaseService.getGwsPlanRooms(widget.planId);
      final areas = await SupabaseService.getGwsPlanAreas(widget.planId);
      final plan = await SupabaseService.getGwsDailyPlan(widget.planId);
      
      if (mounted) {
        setState(() {
          _rooms = rooms;
          _areas = areas;
          _commentController.text = plan?['customer_comment'] ?? '';
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submitFeedback() async {
    if (_signatureBase64 == null && widget.isExternalManager) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('Bitte für die Genehmigung unterschreiben.'))));
      return;
    }
    setState(() => _saving = true);
    try {
      await SupabaseService.updateGwsPlanCustomerFeedback(
        planId: widget.planId,
        comment: _commentController.text.trim(),
        signatureBase64: _signatureBase64 ?? '',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('Genehmigung gesendet ✓')), backgroundColor: AppTheme.success));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e'), backgroundColor: AppTheme.error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  double get _progress {
    final total = _rooms.length + _areas.length;
    if (total == 0) return 0;
    final done = _rooms.where((r) => r['status'] == 'done' || r['status'] == 'checked').length +
                 _areas.where((a) => a['status'] == 'done' || a['status'] == 'checked').length;
    return done / total;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: _color,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Canlı İş Takibi / Fortschritt', style: TextStyle(fontSize: 16)),
            Text(widget.objectName, style: const TextStyle(fontSize: 12, color: Colors.white70)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            onPressed: () async {
              final plan = await SupabaseService.getGwsDailyPlan(widget.planId);
              if (plan != null) {
                final pdfBytes = await PdfService.buildGwsReportPdf(plan: plan, rooms: _rooms, areas: _areas);
                await PdfService.previewPdf(pdfBytes, 'GWS_Report_${widget.objectName}.pdf');
              }
            },
          ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: WebContentWrapper(
        child: _loading 
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildProgressBar(),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      if (_rooms.isNotEmpty) ...[
                        const Text('Zimmer', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, fontFamily: 'Inter')),
                        const SizedBox(height: 8),
                        ..._rooms.map((r) => _buildItemTile(r, true)),
                        const SizedBox(height: 24),
                      ],
                      if (_areas.isNotEmpty) ...[
                        const Text('Bereiche', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, fontFamily: 'Inter')),
                        const SizedBox(height: 8),
                        ..._areas.map((a) => _buildItemTile(a, false)),
                        const SizedBox(height: 24),
                      ],
                      if (widget.isExternalManager) _buildExternalManagerFeedbackForm(),
                      const SizedBox(height: 80),
                    ],
                  ),
                ),
              ],
            ),
      ),
    );
  }

  Widget _buildExternalManagerFeedbackForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Divider(height: 48),
        const Text('Kundenfeedback & Abnahme', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, fontFamily: 'Inter')),
        const SizedBox(height: 16),
        TextField(
          controller: _commentController,
          maxLines: 4,
          decoration: InputDecoration(
            label: Text(tr('Kommentar')),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            hintText: tr('Hier können Sie Ihr Feedback zum Auftrag schreiben...'),
          ),
        ),
        const SizedBox(height: 20),
        Text('${tr('Digitale Unterschrift')}:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, fontFamily: 'Inter')),
        const SizedBox(height: 8),
        SignaturePadWidget(
          color: _color,
          onSigned: (b64) => _signatureBase64 = b64,
        ),
        const SizedBox(height: 32),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: _color,
            padding: const EdgeInsets.symmetric(vertical: 18),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: _saving ? null : _submitFeedback,
          child: _saving 
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : Text(tr('ABGESCHLOSSEN & AN FIRMA ZURÜCK'), style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.1)),
        ),
      ],
    );
  }

  Widget _buildProgressBar() {
    final perc = (_progress * 100).toInt();
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: _color.withOpacity(0.05), border: Border(bottom: BorderSide(color: _color.withOpacity(0.1)))),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Gesamtfortschritt', style: TextStyle(fontWeight: FontWeight.bold, color: _color)),
              Text('$perc %', style: TextStyle(fontWeight: FontWeight.bold, color: _color, fontSize: 18)),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: _progress,
              minHeight: 12,
              backgroundColor: _color.withOpacity(0.1),
              valueColor: const AlwaysStoppedAnimation(AppTheme.success),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemTile(Map<String, dynamic> item, bool isRoom) {
    final status = item['status'] ?? 'todo';
    Color c = Colors.grey;
    IconData icon = Icons.pending_actions;
    String label = 'Wartet';

    if (status == 'doing') { c = Colors.orange; icon = Icons.play_circle_outline; label = 'Bearbeitung'; }
    if (status == 'done') { c = AppTheme.success; icon = Icons.check_circle_outline; label = 'Erledigt'; }
    if (status == 'checked') { c = Colors.blue; icon = Icons.verified_user_outlined; label = 'Geprüft'; }

    return InkWell(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => GwsItemFormScreen(
          item: item, 
          type: isRoom ? 'room' : 'area',
          planId: widget.planId,
          isExternalManager: widget.isExternalManager,
        ))).then((_) => _load());
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.divider)),
        child: Row(
          children: [
            Icon(isRoom ? Icons.bed : Icons.room_service, size: 20, color: AppTheme.textSub),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                isRoom ? 'Zimmer ${item['room_number']}' : '${item['area_name']}',
                style: const TextStyle(fontWeight: FontWeight.w600, fontFamily: 'Inter'),
              ),
            ),
            Row(
              children: [
                Icon(icon, size: 14, color: c),
                const SizedBox(width: 4),
                Text(label, style: TextStyle(color: c, fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'Inter')),
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right, size: 16, color: Colors.grey),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

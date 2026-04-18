import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../theme/web_utils.dart';
import '../providers/app_state.dart';
import '../services/supabase_service.dart';
import '../services/localization_service.dart';
import 'gws_progress_detail_screen.dart';
import 'order_detail_screen.dart';

/// Externer Manager'ın sahip olduğu Aufträge listesi.
/// Sadece muhattabı olduğu işleri görebilir.
/// Yapabilecekleri: Onaylama, Yorum/Açıklama, Talimat verme, Durum görüntüleme.
class ExternalManagerAuftraegeScreen extends StatefulWidget {
  const ExternalManagerAuftraegeScreen({super.key});
  @override
  State<ExternalManagerAuftraegeScreen> createState() => _ExternalManagerAuftraegeScreenState();
}

class _ExternalManagerAuftraegeScreenState extends State<ExternalManagerAuftraegeScreen> {
  List<Map<String, dynamic>> _orders = [];
  bool _loading = true;

  static const Color _color = AppTheme.gwsColor;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final appState = context.read<AppState>();
    setState(() => _loading = true);
    try {
      final orders = await SupabaseService.getOrdersForExternalManager(appState.userId);
      if (mounted) setState(() { _orders = orders; _loading = false; });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    if (_orders.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.assignment_outlined, size: 64, color: _color.withOpacity(0.3)),
            const SizedBox(height: 16),
            const Text('Keine zugewiesenen Aufträge', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textMain, fontFamily: 'Inter')),
            const SizedBox(height: 8),
            const Text('Sie wurden noch keinem Auftrag als Ansprechpartner zugewiesen.', style: TextStyle(color: AppTheme.textSub, fontFamily: 'Inter'), textAlign: TextAlign.center),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: _color),
              onPressed: _load,
              icon: const Icon(Icons.refresh),
              label: const Text('Aktualisieren'),
            ),
          ],
        ),
      );
    }

    return WebContentWrapper(
      child: RefreshIndicator(
        onRefresh: _load,
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: _orders.length + 1,
          itemBuilder: (context, index) {
            if (index == 0) return _buildHeader();
            final order = _orders[index - 1];
            return _OrderCard(order: order, color: _color, onRefresh: _load);
          },
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_color, _color.withOpacity(0.7)],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(14)),
            child: const Icon(Icons.assignment, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Meine Aufträge', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold, fontFamily: 'Inter')),
                Text('${_orders.length} Auftrag/-träge zugewiesen', style: const TextStyle(color: Colors.white70, fontSize: 13, fontFamily: 'Inter')),
              ],
            ),
          ),
          IconButton(icon: const Icon(Icons.refresh, color: Colors.white), onPressed: _load),
        ],
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final Map<String, dynamic> order;
  final Color color;
  final VoidCallback onRefresh;

  const _OrderCard({required this.order, required this.color, required this.onRefresh});

  String _statusLabel(String? s) {
    switch (s) {
      case 'draft': return 'Entwurf';
      case 'planning': return 'Planung';
      case 'in_progress': return 'In Bearbeitung';
      case 'completed': return 'Abgeschlossen';
      case 'invoiced': return 'Fakturiert';
      case 'archived': return 'Archiviert';
      default: return s ?? '';
    }
  }

  Color _statusColor(String? s) {
    switch (s) {
      case 'draft': return AppTheme.textSub;
      case 'planning': return Colors.blue;
      case 'in_progress': return AppTheme.primary;
      case 'completed': return AppTheme.success;
      case 'invoiced': return Colors.orange;
      default: return AppTheme.textSub;
    }
  }

  @override
  Widget build(BuildContext context) {
    final customer = order['customer'] as Map<String, dynamic>?;
    final responsible = order['responsible_user'] as Map<String, dynamic>?;
    final status = order['status'] as String?;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.divider),
        boxShadow: [BoxShadow(color: color.withOpacity(0.08), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withOpacity(0.04),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              border: Border(bottom: BorderSide(color: AppTheme.divider)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                  child: Icon(Icons.work_outline, color: color, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(order['title'] ?? 'Auftrag', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, fontFamily: 'Inter', color: AppTheme.textMain), maxLines: 1, overflow: TextOverflow.ellipsis),
                      if (order['order_number'] != null)
                        Text('Nr. ${order['order_number']}', style: const TextStyle(fontSize: 12, color: AppTheme.textSub, fontFamily: 'Inter')),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _statusColor(status).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(_statusLabel(status), style: TextStyle(color: _statusColor(status), fontSize: 11, fontWeight: FontWeight.w600, fontFamily: 'Inter')),
                ),
              ],
            ),
          ),
          // Info
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (customer != null)
                  _infoRow(Icons.business_outlined, customer['name'] ?? '', color),
                if (order['site_address'] != null && (order['site_address'] as String).isNotEmpty)
                  _infoRow(Icons.location_on_outlined, order['site_address'], color),
                if (responsible != null)
                  _infoRow(Icons.person_outline, 'Verantwortlich: ${responsible['first_name']} ${responsible['last_name']}', color),
                if (order['planned_start_date'] != null)
                  _infoRow(Icons.calendar_today_outlined, 'Start: ${_formatDate(order['planned_start_date'])}', color),
                if (order['description'] != null && (order['description'] as String).isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(order['description'], style: const TextStyle(fontSize: 13, color: AppTheme.textSub, fontFamily: 'Inter'), maxLines: 3, overflow: TextOverflow.ellipsis),
                ],
              ],
            ),
          ),
          // Actions
          Container(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                // ── Details / Formulare ──
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primary,
                    side: const BorderSide(color: AppTheme.primary),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => OrderDetailScreen(orderId: order['id'])),
                  ).then((_) => onRefresh()),
                  icon: const Icon(Icons.assignment_outlined, size: 16),
                  label: const Text('Details & Formulare', style: TextStyle(fontFamily: 'Inter', fontSize: 13)),
                ),
                // ── Kommentar ──
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: color,
                    side: BorderSide(color: color),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  onPressed: () => _showCommentDialog(context, order, isInstruction: false),
                  icon: const Icon(Icons.comment_outlined, size: 16),
                  label: const Text('Kommentar', style: TextStyle(fontFamily: 'Inter', fontSize: 13)),
                ),
                // ── Talimat ──
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.orange,
                    side: const BorderSide(color: Colors.orange),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  onPressed: () => _showCommentDialog(context, order, isInstruction: true),
                  icon: const Icon(Icons.assignment_turned_in_outlined, size: 16),
                  label: const Text('Talimat', style: TextStyle(fontFamily: 'Inter', fontSize: 13)),
                ),
                // ── Genehmigen ──
                if (status == 'in_progress' || status == 'completed')
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.success,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    onPressed: () => _showApprovalDialog(context, order),
                    icon: const Icon(Icons.check_circle_outline, size: 16),
                    label: const Text('Genehmigen', style: TextStyle(fontFamily: 'Inter', fontSize: 13)),
                  ),
                // ── GWS Fortschritt ──
                if (order['department'] != null && order['department']['name'].toString().toLowerCase().contains('gast'))
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: color,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    onPressed: () async {
                      final plans = await SupabaseService.getGwsDailyPlans(objectId: order['customer_id']);
                      if (plans.isNotEmpty && context.mounted) {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => GwsProgressDetailScreen(planId: plans.first['id'], objectName: order['customer']['name'])));
                      } else if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Aktuell kein aktiver Tagesplan für dieses Objekt found.')));
                      }
                    },
                    icon: const Icon(Icons.timeline, size: 16),
                    label: const Text('Fortschritt', style: TextStyle(fontFamily: 'Inter', fontSize: 13)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String text, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color.withOpacity(0.7)),
          const SizedBox(width: 6),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13, color: AppTheme.textMain, fontFamily: 'Inter'), maxLines: 1, overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }

  String _formatDate(String? date) {
    if (date == null) return '';
    try {
      final d = DateTime.parse(date);
      return '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
    } catch (_) { return date; }
  }

  void _showCommentDialog(BuildContext context, Map<String, dynamic> order, {required bool isInstruction}) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(isInstruction ? Icons.assignment_turned_in : Icons.comment, color: isInstruction ? Colors.orange : color),
            const SizedBox(width: 8),
            Text(isInstruction ? 'Talimat / Anweisung' : 'Kommentar / Rückmeldung', style: const TextStyle(fontFamily: 'Inter', fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Auftrag: ${order['title'] ?? ''}', style: const TextStyle(color: AppTheme.textSub, fontSize: 13, fontFamily: 'Inter')),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: isInstruction
                    ? 'z. B. "Morgen bitte Extra-Reinigung im 3. OG"'
                    : 'z. B. "Zimmer 204 war nicht sauber"',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Abbrechen')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: isInstruction ? Colors.orange : color),
            onPressed: () async {
              if (ctrl.text.trim().isEmpty) return;
              try {
                await SupabaseService.addOrderComment(
                  orderId: order['id'],
                  comment: ctrl.text.trim(),
                  commentType: isInstruction ? 'instruction' : 'feedback',
                  createdBy: null,
                );
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(isInstruction ? 'Talimat gesendet ✓' : 'Kommentar gespeichert ✓'), backgroundColor: AppTheme.success),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fehler: $e'), backgroundColor: AppTheme.error));
              }
            },
            child: Text(isInstruction ? 'Talimat senden' : 'Speichern'),
          ),
        ],
      ),
    );
  }

  void _showApprovalDialog(BuildContext context, Map<String, dynamic> order) {
    final signCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: AppTheme.success),
            SizedBox(width: 8),
            Text('Auftrag genehmigen', style: TextStyle(fontFamily: 'Inter', fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppTheme.success.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: AppTheme.success, size: 18),
                  const SizedBox(width: 8),
                  Expanded(child: Text('Auftrag: ${order['title'] ?? ''}', style: const TextStyle(fontFamily: 'Inter', fontSize: 13))),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text('Bestätigung / Unterschrift:', style: TextStyle(fontWeight: FontWeight.w600, fontFamily: 'Inter', fontSize: 13)),
            const SizedBox(height: 8),
            TextField(
              controller: signCtrl,
              decoration: InputDecoration(
                hintText: 'Ihr Name als digitale Unterschrift',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Icon(Icons.draw_outlined),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Abbrechen')),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.success),
            onPressed: () async {
              if (signCtrl.text.trim().isEmpty) return;
              try {
                await SupabaseService.addOrderComment(
                  orderId: order['id'],
                  comment: 'Genehmigt von: ${signCtrl.text.trim()} (Externer Manager)',
                  commentType: 'approval',
                  createdBy: null,
                );
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Auftrag genehmigt ✓'), backgroundColor: AppTheme.success),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fehler: $e'), backgroundColor: AppTheme.error));
              }
            },
            icon: const Icon(Icons.check),
            label: const Text('Genehmigen & Unterschreiben'),
          ),
        ],
      ),
    );
  }
}

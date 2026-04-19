import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../theme/web_utils.dart';
import '../providers/app_state.dart';
import '../services/supabase_service.dart';
import '../services/localization_service.dart';
import 'gws_personnel_planning_screen.dart';
import 'gws_item_form_screen.dart';

/// GWS Tagesplanungsmaske
/// Operative Herzstück: Zimmer, Bereiche, Zusatzleistungen, kaufmännische Vorschau
class GwsTagesplanScreen extends StatefulWidget {
  final String? departmentId;
  final String? planId; // Mevcut planı yüklemek için
  final String? initialOrderId; // Yeni planda işi doğrudan eşlemek için
  final List<Map<String, dynamic>> objects;
  const GwsTagesplanScreen({super.key, this.departmentId, this.planId, this.initialOrderId, required this.objects});
  @override
  State<GwsTagesplanScreen> createState() => _GwsTagesplanScreenState();
}

class _GwsTagesplanScreenState extends State<GwsTagesplanScreen> {
  static const Color _color = AppTheme.gwsColor;

  // Block A – Tageskopf
  DateTime _planDate = DateTime.now();
  String? _selectedObjectId;
  String? _selectedOrderId;
  String _status = 'draft';
  bool _isShared = false;
  List<Map<String, dynamic>> _gwsOrders = [];

  // Block B – Zimmer
  final List<Map<String, dynamic>> _rooms = [];

  // Block C – Bereiche
  final List<Map<String, dynamic>> _areas = [];

  // Block D – Zusatzleistungen
  final List<Map<String, dynamic>> _extras = [];

  bool _saving = false;
  bool _isTeamLeader = false;

  // Preise
  static const Map<String, double> _roomPrices = {
    'Einzelzimmer': 18.0,
    'Doppelzimmer': 22.0,
    'Suite': 45.0,
    'Familienzimmer': 30.0,
  };

  static const Map<String, double> _areaPrices = {
    'Lobby': 35.0,
    'Flur': 25.0,
    'Gäste-WC': 15.0,
    'Restaurant': 60.0,
    'Frühstücksraum': 40.0,
    'Treppenhaus': 20.0,
    'Empfang': 25.0,
    'Außenbereich': 50.0,
  };

  static const Map<String, double> _extraPrices = {
    'Glasreinigung': 80.0,
    'Hausmeistereinsatz': 45.0,
    'Sonderreinigung': 60.0,
    'Serviceunterstützung': 35.0,
    'Wäscheservice': 25.0,
  };

  double get _roomTotal => _rooms.fold(0, (s, r) => s + ((r['price'] as num?)?.toDouble() ?? 0));
  double get _areaTotal => _areas.fold(0, (s, a) => s + ((a['price'] as num?)?.toDouble() ?? 0));
  double get _extraTotal => _extras.fold(0, (s, e) => s + ((e['price'] as num?)?.toDouble() ?? 0));
  double get _grandTotal => _roomTotal + _areaTotal + _extraTotal;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    final appState = context.read<AppState>();
    setState(() => _loading = true);
    try {
      // Load active orders for GWS
      final orders = await SupabaseService.getGwsOrders(departmentId: widget.departmentId);
      
      if (widget.planId != null) {
        // Mevcut planı yükle
        final plan = await SupabaseService.getGwsDailyPlan(widget.planId!);
        if (plan != null) {
          _planDate = DateTime.tryParse(plan['plan_date']) ?? DateTime.now();
          _selectedObjectId = plan['object_id']?.toString();
          _selectedOrderId = plan['order_id']?.toString();
          _status = plan['status'] ?? 'draft';
          _isShared = plan['is_shared_with_customer'] == true;
          
          final rooms = await SupabaseService.getGwsPlanRooms(widget.planId!);
          final areas = await SupabaseService.getGwsPlanAreas(widget.planId!);
          final isLeader = await SupabaseService.isUserGwsTeamLeader(widget.planId!, appState.userId);
          
          _rooms.clear(); _rooms.addAll(rooms);
          _areas.clear(); _areas.addAll(areas);
          _isTeamLeader = isLeader;
        }
      } else if (widget.initialOrderId != null) {
        _selectedOrderId = widget.initialOrderId;
        final o = orders.where((x) => x['id'].toString() == widget.initialOrderId).firstOrNull;
        if (o != null) {
          _selectedObjectId = o['customer_id']?.toString();
        }
      }
      
      if (mounted) {
        setState(() {
          _gwsOrders = orders;
          
          if (_selectedOrderId != null) {
            final valid = _gwsOrders.any((o) => o['id'].toString() == _selectedOrderId);
            if (!valid) _selectedOrderId = null; // Dropdown'un crash etmesini engellemek için
          }

          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: _color,
        title: const Text('Tagesplanung', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold)),
        actions: [
          if (_saving)
            const Center(child: Padding(padding: EdgeInsets.only(right: 16), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))))
          else if (!appState.isExternalManager)
            TextButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save, color: Colors.white),
              label: const Text('Speichern', style: TextStyle(color: Colors.white, fontFamily: 'Inter', fontWeight: FontWeight.bold)),
            ),
        ],
      ),
      body: _loading 
        ? const Center(child: CircularProgressIndicator())
        : WebContentWrapper(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // DIAGNOSTIC BANNER
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(8)),
                  child: const Center(child: Text('DIAGNOSTIC MODE: v19.2.9 (If you see this, code is updated)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))),
                ),
                const SizedBox(height: 12),
                _buildBlockA(appState),
                const SizedBox(height: 16),
                if (!appState.isExternalManager) ...[
                  _buildPersonnelAssignment(),
                  const SizedBox(height: 16),
                ],
                _buildBlockB(appState),
                const SizedBox(height: 16),
                _buildBlockC(appState),
                const SizedBox(height: 16),
                _buildBlockD(appState),
                const SizedBox(height: 16),
                if (appState.canSeeFinancialDetails) ...[
                  _buildBlockE(),
                  const SizedBox(height: 16),
                ],
                // Gönderim Butonları
                if (widget.planId != null) ...[
                  const Divider(),
                  if (appState.isExternalManager)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: AppTheme.success, padding: const EdgeInsets.symmetric(vertical: 16)),
                        onPressed: () => _updateWorkflowStatus('in_bearbeitung', 'Bereichsleiter\'a Gönderildi'),
                        icon: const Icon(Icons.send_rounded),
                        label: const Text('An Bereichsleiter Senden', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    )
                  else if (appState.isBereichsleiter || appState.canSeeFinancialDetails)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: AppTheme.info, padding: const EdgeInsets.symmetric(vertical: 16)),
                        onPressed: () => _updateWorkflowStatus('vom_kunden_gemeldet', 'External Manager\'a Gönderildi'),
                        icon: const Icon(Icons.send_outlined),
                        label: const Text('An External Manager Senden', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                ],
                const SizedBox(height: 80),
              ],
            ),
          ),
    );
  }

  // ── Block A: Tageskopf ─────────────────────────────────────
  Widget _buildBlockA(AppState appState) {
    return _buildSection(
      title: 'Block A – Tageskopf',
      icon: Icons.calendar_today,
      child: Column(
        children: [
          // Datum
          InkWell(
            onTap: () async {
              final d = await showDatePicker(context: context, initialDate: _planDate, firstDate: DateTime.now().subtract(const Duration(days: 30)), lastDate: DateTime.now().add(const Duration(days: 90)));
              if (d != null) setState(() => _planDate = d);
            },
            child: InputDecorator(
              decoration: const InputDecoration(labelText: 'Datum', prefixIcon: Icon(Icons.calendar_today)),
              child: Text('${_planDate.day.toString().padLeft(2, '0')}.${_planDate.month.toString().padLeft(2, '0')}.${_planDate.year}', style: const TextStyle(fontSize: 15, fontFamily: 'Inter')),
            ),
          ),
          const SizedBox(height: 12),
          // Auftrag / Sipariş
          DropdownButtonFormField<String>(
            value: _selectedOrderId,
            decoration: const InputDecoration(labelText: 'Sipariş (Auftrag) *', prefixIcon: Icon(Icons.assignment)),
            items: _gwsOrders.isEmpty 
              ? [const DropdownMenuItem<String>(value: null, child: Text('⚠️ Aktif iş bulunamadı', style: TextStyle(color: Colors.red)))]
              : _gwsOrders.map((ord) => DropdownMenuItem<String>(
                  value: ord['id'].toString(),
                  child: Text('${ord['customer']?['name'] ?? 'Müşteri Yok'}: ${ord['title']}', style: const TextStyle(fontFamily: 'Inter', fontSize: 13), overflow: TextOverflow.ellipsis),
                )).toList(),
            onChanged: (v) {
              final ord = _gwsOrders.firstWhere((element) => element['id'] == v);
              setState(() {
                _selectedOrderId = v;
                _selectedObjectId = ord['customer_id'];
              });
            },
          ),
          const SizedBox(height: 12),
          // Status
          appState.isExternalManager 
            ? InputDecorator(
                decoration: const InputDecoration(labelText: 'Status'),
                child: Text(_statusText(_status), style: const TextStyle(fontSize: 15, fontFamily: 'Inter')),
              )
            : DropdownButtonFormField<String>(
                value: _status,
                decoration: const InputDecoration(labelText: 'Status'),
                items: const [
                  DropdownMenuItem(value: 'draft', child: Text('📝 Entwurf')),
                  DropdownMenuItem(value: 'vom_kunden_gemeldet', child: Text('📩 Vom Kunden gemeldet')),
                  DropdownMenuItem(value: 'in_bearbeitung', child: Text('🔄 Intern in Bearbeitung')),
                  DropdownMenuItem(value: 'released', child: Text('✅ Freigegeben')),
                ],
                onChanged: (v) => setState(() => _status = v!),
              ),
          if (widget.planId != null && appState.canSeeFinancialDetails) ...[
            const SizedBox(height: 16),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Müşteriyle Paylaş', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Inter')),
                Switch(
                  value: _isShared,
                  activeColor: AppTheme.gwsColor,
                  onChanged: (v) async {
                    setState(() => _isShared = v);
                    await SupabaseService.shareGwsPlanWithCustomer(widget.planId!, v);
                  },
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _statusText(String s) {
    if (s == 'draft') return '📝 Entwurf';
    if (s == 'vom_kunden_gemeldet') return '📩 Vom Kunden gemeldet';
    if (s == 'in_bearbeitung') return '🔄 Intern in Bearbeitung';
    if (s == 'released') return '✅ Freigegeben';
    return s;
  }

  Future<void> _updateWorkflowStatus(String newStatus, String msg) async {
    setState(() => _saving = true);
    try {
      await SupabaseService.updateGwsDailyPlan(widget.planId!, {'status': newStatus});
      setState(() { _status = newStatus; _saving = false; });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: AppTheme.success));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fehler: $e'), backgroundColor: AppTheme.error));
        setState(() => _saving = false);
      }
    }
  }

  // ── Block B: Zimmerliste ───────────────────────────────────
  Widget _buildBlockB(AppState appState) {
    return _buildSection(
      title: 'Block B – Zimmerliste',
      icon: Icons.bed,
      action: appState.isExternalManager ? null : IconButton(
        icon: Icon(Icons.add_circle, color: _color),
        onPressed: _addRoomDialog,
      ),
      child: Column(
        children: [
          if (_rooms.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Column(
                  children: [
                    Icon(Icons.bed_outlined, size: 40, color: _color.withOpacity(0.3)),
                    const SizedBox(height: 8),
                    const Text('Noch keine Zimmer hinzugefügt', style: TextStyle(color: AppTheme.textSub, fontFamily: 'Inter')),
                    const SizedBox(height: 8),
                    if (!appState.isExternalManager)
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(foregroundColor: _color, side: BorderSide(color: _color)),
                        onPressed: _addRoomDialog,
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('Zimmer hinzufügen', style: TextStyle(fontFamily: 'Inter')),
                      ),
                  ],
                ),
              ),
            )
          else
            ...(_rooms.asMap().entries.map((entry) {
              final i = entry.key;
              final r = entry.value;
              final card = Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: _color.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _color.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    Container(width: 32, height: 32, decoration: BoxDecoration(color: _color, borderRadius: BorderRadius.circular(8)),
                      child: Center(child: Text('${r['room_number']}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12, fontFamily: 'Inter')))),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(r['category'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontFamily: 'Inter', fontSize: 13)),
                          Text(r['service_type'] ?? 'Housekeeping', style: const TextStyle(color: AppTheme.textSub, fontSize: 11, fontFamily: 'Inter')),
                        ],
                      ),
                    ),
                    _statusMiniBadge(r['status']),
                    const SizedBox(width: 8),
                    if (appState.canSeeFinancialDetails)
                      Text('€ ${(r['price'] as num?)?.toStringAsFixed(2) ?? '0.00'}', style: TextStyle(fontWeight: FontWeight.bold, color: _color, fontFamily: 'Inter', fontSize: 13)),
                    const SizedBox(width: 8),
                    if (r['id'] != null)
                      Icon(Icons.chevron_right, color: _color.withOpacity(0.4), size: 18),
                    if (!appState.isExternalManager)
                      IconButton(icon: const Icon(Icons.delete_outline, color: AppTheme.error, size: 18), onPressed: () => setState(() => _rooms.removeAt(i))),
                  ],
                ),
              );
              if (r['id'] == null || widget.planId == null) return card;
              return InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => GwsItemFormScreen(
                  item: r, type: 'room', planId: widget.planId!,
                  isExternalManager: context.read<AppState>().role == 'external_manager',
                ))).then((ok) { if (ok == true) _checkPermissions(); }),
                child: card,
              );
            })),
          if (_rooms.isNotEmpty) ...[
            const Divider(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${_rooms.length} Zimmer', style: const TextStyle(color: AppTheme.textSub, fontFamily: 'Inter')),
                if (appState.canSeeFinancialDetails)
                  Text('€ ${_roomTotal.toStringAsFixed(2)}', style: TextStyle(fontWeight: FontWeight.bold, color: _color, fontFamily: 'Inter')),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPersonnelAssignment() {
    return _buildSection(
      title: 'Personal & Einsatzplanung',
      icon: Icons.people,
      action: _status == 'draft' ? null : IconButton(
        icon: const Icon(Icons.edit_calendar, color: _color),
        onPressed: () {
          // Bu kısımsa artık savedId lazım, implementasyonda genelde pop'tan gelen id ile veya listelenerek yapılır.
          // Şimdilik Snackbar
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Personalplanung erst nach erstem Speichern verfügbar.')));
        },
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: _color, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              onPressed: () {
                 if (_selectedObjectId != null) {
                   // Burada kaydettikten sonra ID gelmeli, şimdilik snackbar
                   ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Personalplanung erst nach erstem Speichern verfügbar.')));
                 } else {
                   ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bitte erst ein Objekt auswählen ve Speichern.')));
                 }
              },
              icon: const Icon(Icons.person_add),
              label: const Text('Personel Ata & Yıldız Belirle'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusMiniBadge(String? s) {
    Color c = Colors.grey;
    if (s == 'doing') c = Colors.orange;
    if (s == 'done') c = AppTheme.success;
    if (s == 'checked') c = Colors.blue;
    return Container(
      width: 8, height: 8,
      decoration: BoxDecoration(color: c, shape: BoxShape.circle),
    );
  }

  // ── Block C: Bereichsliste ─────────────────────────────────
  Widget _buildBlockC(AppState appState) {
    return _buildSection(
      title: 'Block C – Bereichsliste',
      icon: Icons.location_city,
      action: appState.isExternalManager ? null : IconButton(icon: Icon(Icons.add_circle, color: _color), onPressed: _addAreaDialog),
      child: Column(
        children: [
          if (_areas.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Column(
                  children: [
                    Icon(Icons.location_city_outlined, size: 40, color: _color.withOpacity(0.3)),
                    const SizedBox(height: 8),
                    const Text('Noch keine Bereiche hinzugefügt', style: TextStyle(color: AppTheme.textSub, fontFamily: 'Inter')),
                    const SizedBox(height: 8),
                    if (!appState.isExternalManager)
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(foregroundColor: _color, side: BorderSide(color: _color)),
                        onPressed: _addAreaDialog,
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('Bereich hinzufügen', style: TextStyle(fontFamily: 'Inter')),
                      ),
                  ],
                ),
              ),
            )
          else
            ...(_areas.asMap().entries.map((entry) {
              final i = entry.key;
              final a = entry.value;
              final areaCard = Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(color: _color.withOpacity(0.04), borderRadius: BorderRadius.circular(10), border: Border.all(color: _color.withOpacity(0.2))),
                child: Row(
                  children: [
                    Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: _color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                      child: Icon(Icons.room_outlined, color: _color, size: 16)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(a['area_name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontFamily: 'Inter', fontSize: 13)),
                          Text(a['service_type'] ?? 'Reinigung', style: const TextStyle(color: AppTheme.textSub, fontSize: 11, fontFamily: 'Inter')),
                        ],
                      ),
                    ),
                    if (appState.canSeeFinancialDetails)
                      Text('€ ${(a['price'] as num?)?.toStringAsFixed(2) ?? '0.00'}', style: TextStyle(fontWeight: FontWeight.bold, color: _color, fontFamily: 'Inter', fontSize: 13)),
                    const SizedBox(width: 8),
                    if (a['id'] != null)
                      Icon(Icons.chevron_right, color: _color.withOpacity(0.4), size: 18),
                    if (!appState.isExternalManager)
                      IconButton(icon: const Icon(Icons.delete_outline, color: AppTheme.error, size: 18), onPressed: () => setState(() => _areas.removeAt(i))),
                  ],
                ),
              );
              if (a['id'] == null || widget.planId == null) return areaCard;
              return InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => GwsItemFormScreen(
                  item: a, type: 'area', planId: widget.planId!,
                  isExternalManager: context.read<AppState>().role == 'external_manager',
                ))).then((ok) { if (ok == true) _checkPermissions(); }),
                child: areaCard,
              );
            })),
          if (_areas.isNotEmpty) ...[
            const Divider(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${_areas.length} Bereiche', style: const TextStyle(color: AppTheme.textSub, fontFamily: 'Inter')),
                if (appState.canSeeFinancialDetails)
                  Text('€ ${_areaTotal.toStringAsFixed(2)}', style: TextStyle(fontWeight: FontWeight.bold, color: _color, fontFamily: 'Inter')),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ── Block D: Zusatzleistungen ──────────────────────────────
  Widget _buildBlockD(AppState appState) {
    return _buildSection(
      title: 'Block D – Zusatzleistungen',
      icon: Icons.add_task,
      action: appState.isExternalManager ? null : IconButton(icon: Icon(Icons.add_circle, color: _color), onPressed: _addExtraDialog),
      child: Column(
        children: [
          if (_extras.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text('Keine Zusatzleistungen', style: TextStyle(color: AppTheme.textSub.withOpacity(0.7), fontFamily: 'Inter', fontStyle: FontStyle.italic)),
            )
          else
            ...(_extras.asMap().entries.map((entry) {
              final i = entry.key;
              final e = entry.value;
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.stars_outlined, color: Colors.orange, size: 18)),
                title: Text(e['product_name'] ?? '', style: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600, fontSize: 13)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (appState.canSeeFinancialDetails)
                      Text('€ ${(e['price'] as num?)?.toStringAsFixed(2) ?? '0.00'}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange, fontFamily: 'Inter')),
                    if (!appState.isExternalManager)
                      IconButton(icon: const Icon(Icons.delete_outline, color: AppTheme.error, size: 18), onPressed: () => setState(() => _extras.removeAt(i))),
                  ],
                ),
              );
            })),
        ],
      ),
    );
  }

  // ── Block E: Kaufmännische Vorschau ────────────────────────
  Widget _buildBlockE() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_color, const Color(0xFF5B21B6)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: _color.withOpacity(0.3), blurRadius: 16, offset: const Offset(0, 6))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.euro_outlined, color: Colors.white, size: 22),
              SizedBox(width: 8),
              Text('Block E – Kaufmännische Vorschau', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold, fontFamily: 'Inter')),
            ],
          ),
          const SizedBox(height: 16),
          _priceRow('Zimmerleistungen (${_rooms.length} Stk.)', _roomTotal),
          _priceRow('Bereichsleistungen (${_areas.length} Stk.)', _areaTotal),
          _priceRow('Zusatzleistungen (${_extras.length} Stk.)', _extraTotal),
          const Divider(color: Colors.white24, height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Gesamt (Tagesumsatz)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16, fontFamily: 'Inter')),
              Text('€ ${_grandTotal.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 22, fontFamily: 'Inter')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _priceRow(String label, double value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 13, fontFamily: 'Inter')),
          Text('€ ${value.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14, fontFamily: 'Inter')),
        ],
      ),
    );
  }

  Widget _buildSection({required String title, required IconData icon, required Widget child, Widget? action}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.divider),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: _color.withOpacity(0.05),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              border: Border(bottom: BorderSide(color: _color.withOpacity(0.15))),
            ),
            child: Row(
              children: [
                Icon(icon, color: _color, size: 18),
                const SizedBox(width: 8),
                Expanded(child: Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: _color, fontFamily: 'Inter', fontSize: 14))),
                if (action != null) action,
              ],
            ),
          ),
          Padding(padding: const EdgeInsets.all(16), child: child),
        ],
      ),
    );
  }

  // ── Dialogs ────────────────────────────────────────────────
  void _addRoomDialog() {
    final roomCtrl = TextEditingController();
    String selectedCat = 'Einzelzimmer';
    String serviceType = 'Housekeeping';
    double price = _roomPrices[selectedCat]!;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(children: [Icon(Icons.bed, color: _color), const SizedBox(width: 8), const Text('Zimmer hinzufügen', style: TextStyle(fontFamily: 'Inter', fontSize: 16))]),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: roomCtrl, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: 'Zimmernummer', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: selectedCat,
                decoration: InputDecoration(labelText: 'Kategorie', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                items: _roomPrices.keys.map((k) => DropdownMenuItem(value: k, child: Text(k, style: const TextStyle(fontFamily: 'Inter')))).toList(),
                onChanged: (v) => setLocal(() { selectedCat = v!; price = _roomPrices[v]!; }),
              ),
              const SizedBox(height: 8),
              Text('Preis: € ${price.toStringAsFixed(2)}', style: TextStyle(color: _color, fontWeight: FontWeight.bold, fontFamily: 'Inter')),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Abbrechen')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: _color),
              onPressed: () {
                if (roomCtrl.text.isEmpty) return;
                setState(() => _rooms.add({
                  'room_number': roomCtrl.text.trim(),
                  'category': selectedCat,
                  'service_type': serviceType,
                  'price': price,
                  'status': 'assigned',
                }));
                Navigator.pop(ctx);
              },
              child: const Text('Hinzufügen'),
            ),
          ],
        ),
      ),
    );
  }

  void _addAreaDialog() {
    String selectedArea = 'Lobby';
    String serviceType = 'Reinigung';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(children: [Icon(Icons.location_city, color: _color), const SizedBox(width: 8), const Text('Bereich hinzufügen', style: TextStyle(fontFamily: 'Inter', fontSize: 16))]),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: selectedArea,
                decoration: InputDecoration(labelText: 'Bereich', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                items: _areaPrices.keys.map((k) => DropdownMenuItem(value: k, child: Text(k, style: const TextStyle(fontFamily: 'Inter')))).toList(),
                onChanged: (v) => setLocal(() => selectedArea = v!),
              ),
              const SizedBox(height: 8),
              Text('Preis: € ${_areaPrices[selectedArea]?.toStringAsFixed(2) ?? '0.00'}', style: TextStyle(color: _color, fontWeight: FontWeight.bold, fontFamily: 'Inter')),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Abbrechen')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: _color),
              onPressed: () {
                setState(() => _areas.add({
                  'area_name': selectedArea,
                  'area_type': selectedArea,
                  'service_type': serviceType,
                  'price': _areaPrices[selectedArea] ?? 0.0,
                  'status': 'assigned',
                }));
                Navigator.pop(ctx);
              },
              child: const Text('Hinzufügen'),
            ),
          ],
        ),
      ),
    );
  }

  void _addExtraDialog() {
    String selected = 'Glasreinigung';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(children: [Icon(Icons.add_task, color: Colors.orange), SizedBox(width: 8), Text('Zusatzleistung', style: TextStyle(fontFamily: 'Inter', fontSize: 16))]),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: selected,
                decoration: InputDecoration(labelText: 'Leistung', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                items: _extraPrices.keys.map((k) => DropdownMenuItem(value: k, child: Text(k, style: const TextStyle(fontFamily: 'Inter')))).toList(),
                onChanged: (v) => setLocal(() => selected = v!),
              ),
              const SizedBox(height: 8),
              Text('Preis: € ${_extraPrices[selected]?.toStringAsFixed(2) ?? '0.00'}', style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontFamily: 'Inter')),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Abbrechen')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              onPressed: () {
                setState(() => _extras.add({'product_name': selected, 'price': _extraPrices[selected] ?? 0.0}));
                Navigator.pop(ctx);
              },
              child: const Text('Hinzufügen'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (_selectedObjectId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bitte ein Objekt auswählen!'), backgroundColor: AppTheme.error));
      return;
    }
    setState(() => _saving = true);
    try {
      final appState = context.read<AppState>();
      final Map<String, dynamic> insertData = {
        'plan_date': _planDate.toIso8601String().split('T')[0],
        'object_id': _selectedObjectId,
        'order_id': _selectedOrderId,
        'internal_leader': appState.userId,
        'status': _status,
        'created_by': appState.userId,
      };
      
      String planId;
      if (widget.planId != null) {
        await SupabaseService.updateGwsDailyPlan(widget.planId!, insertData);
        planId = widget.planId!;
      } else {
        planId = await SupabaseService.createGwsDailyPlan(insertData);
      }
      
      await SupabaseService.upsertGwsPlanRooms(planId, _rooms);
      await SupabaseService.upsertGwsPlanAreas(planId, _areas);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tagesplan gespeichert ✓'), backgroundColor: AppTheme.success));
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fehler: $e'), backgroundColor: AppTheme.error));
        setState(() => _saving = false);
      }
    }
  }
}

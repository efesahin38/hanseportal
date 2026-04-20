import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../providers/app_state.dart';
import '../services/supabase_service.dart';

// ─── Brand Colors ─────────────────────────────────────────────
const Color _kDbBlue  = Color(0xFF0D47A1);
const Color _kDbLight = Color(0xFF1565C0);
const Color _kDbRed   = Color(0xFFD32F2F);
const Color _kPurple  = Color(0xFF7B1FA2);
const Color _kGreen   = Color(0xFF00695C);

// Role label helper (global)
String gleisbauRoleLabel(String key) {
  const m = {
    'sakra':              'SAKRA – Sicherungsaufsicht',
    'sipo':               'SiPO – Sicherungsposten',
    'buep':               'BUeP – Bahnuebergangsposten',
    'sesi':               'SeSi – Selbstsicherer',
    'sas':                'SAS – Schaltantragsteller',
    'hib':                'HIB – Helfer im Bahnbetrieb',
    'bahnerder':          'Bahnerder',
    'sbahn_kurzschliess': 'S-Bahn-Kurzschließer',
    'bediener_monteur':   'Bediener / Monteur',
    'raeumer':            'Räumer',
    'planer_pruefer':     'Planer / Prüfer',
  };
  return m[key] ?? key;
}

// ══════════════════════════════════════════════════════════════
// SAKRA LEITSTAND — embedded (no Scaffold)
// ══════════════════════════════════════════════════════════════
class GleisbauSakraLeitstandScreen extends StatefulWidget {
  final Map<String, dynamic> order;
  const GleisbauSakraLeitstandScreen({super.key, required this.order});
  @override
  State<GleisbauSakraLeitstandScreen> createState() => _GleisbauSakraLeitstandState();
}

class _GleisbauSakraLeitstandState extends State<GleisbauSakraLeitstandScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  Map<String, dynamic>? _checkliste;
  List<Map<String, dynamic>> _team       = [];
  List<Map<String, dynamic>> _ereignisse = [];
  bool _loading = true;

  static const _statusLabels = <String, String>{
    'draft':                'Entwurf',
    'angelegt':             'Angelegt',
    'in_vorbereitung':      'In Vorbereitung',
    'dokumente_fehlen':     'Unterlagen unvollständig',
    'personal_geplant':     'Personal geplant',
    'einsatzbereit':        'Einsatzbereit',
    'unterweisung_laeuft':  'Unterweisung läuft',
    'unterwiesen':          'Unterwiesen',
    'einsatz_begonnen':     'Einsatz begonnen',
    'einsatz_unterbrochen': 'Einsatz unterbrochen',
    'problem_gemeldet':     'Problem gemeldet',
    'einsatz_beendet':      'Einsatz beendet',
    'abgeschlossen':        'Intern abgeschlossen',
    'an_abrechnung':        'An Abrechnung übergeben',
    'abgerechnet':          'Abgerechnet',
    'archiviert':           'Archiviert',
  };

  static const _checks = <Map<String, Object>>[
    {'field': 'sicherungsplan_geprueft',   'label': 'Sicherungsplan geprüft',           'icon': Icons.rule},
    {'field': 'dokumente_vollstaendig',    'label': 'Dokumente vollständig',             'icon': Icons.folder_open},
    {'field': 'team_vollstaendig',         'label': 'Team vollständig',                 'icon': Icons.group},
    {'field': 'qualifikationen_plausibel', 'label': 'Qualifikationen plausibel',        'icon': Icons.verified},
    {'field': 'maschinen_geprueft',        'label': 'Maschinen geprüft',                'icon': Icons.precision_manufacturing},
    {'field': 'geraete_geprueft',          'label': 'Geräte geprüft',                   'icon': Icons.handyman},
    {'field': 'warnmittel_geprueft',       'label': 'Warnmittel geprüft',               'icon': Icons.warning},
    {'field': 'psa_geprueft',              'label': 'PSA geprüft',                      'icon': Icons.security},
    {'field': 'kommunikation_geprueft',    'label': 'Kommunikationsmittel geprüft',     'icon': Icons.phone},
    {'field': 'zugang_klar',               'label': 'Zugang / Sammelpunkt geklärt',     'icon': Icons.place},
    {'field': 'sicherheitsraeume_bekannt', 'label': 'Sicherheitsräume bekannt',         'icon': Icons.emergency},
    {'field': 'unterweisung_durchgefuehrt','label': 'Unterweisung durchgeführt',        'icon': Icons.school},
    {'field': 'bestaetigung_vollstaendig', 'label': 'Mitarbeiterbestätigungen vollst.', 'icon': Icons.how_to_reg},
  ];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
    _load();
  }

  @override
  void dispose() { _tabs.dispose(); super.dispose(); }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);
    final orderId = widget.order['id'] as String;
    try {
      final results = await Future.wait([
        SupabaseService.getGleisbauCheckliste(orderId),
        SupabaseService.getGleisbauPersonal(orderId),
        SupabaseService.getGleisbauEreignisse(orderId),
      ]);
      if (!mounted) return;
      setState(() {
        _checkliste = results[0] as Map<String, dynamic>?;
        _team       = (results[1] as List<Map<String, dynamic>>?) ?? [];
        _ereignisse = (results[2] as List<Map<String, dynamic>>?) ?? [];
        _loading    = false;
      });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  int get _erledigte => _checks.where((c) => _checkliste?[c['field']] == true).length;
  bool get _vollstaendig => _erledigte == _checks.length;

  Future<void> _toggleCheck(String field, bool value) async {
    final orderId = widget.order['id'] as String;
    final appState = context.read<AppState>();
    try {
      await SupabaseService.upsertGleisbauCheckliste({
        'order_id': orderId,
        'sakra_user_id': appState.userId,
        field: value,
        'updated_at': DateTime.now().toIso8601String(),
      });
      // Optimistic update
      setState(() {
        _checkliste ??= {};
        _checkliste![field] = value;
      });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fehler: $e'), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final status   = widget.order['status']?.toString() ?? 'draft';
    final canCheck = appState.canAccessGleisbauLeitstand;

    return Column(children: [
      // Header
      Container(
        decoration: BoxDecoration(gradient: LinearGradient(colors: [_kDbBlue, _kDbLight])),
        child: Column(children: [
          Row(children: [
            const SizedBox(width: 16),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('SAKRA-Leitstand', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold, fontFamily: 'Inter')),
              Text(_statusLabels[status] ?? status, style: const TextStyle(color: Colors.white70, fontSize: 11, fontFamily: 'Inter')),
            ])),
            IconButton(icon: const Icon(Icons.refresh, color: Colors.white), onPressed: _load),
          ]),
          TabBar(
            controller: _tabs,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white54,
            indicatorColor: Colors.white,
            isScrollable: true,
            labelStyle: const TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.bold),
            tabs: [
              Tab(icon: const Icon(Icons.checklist, size: 16), text: 'Checkliste ${_erledigte}/${_checks.length}'),
              const Tab(icon: Icon(Icons.group, size: 16), text: 'Team'),
              const Tab(icon: Icon(Icons.warning_amber, size: 16), text: 'Ereignisse'),
              const Tab(icon: Icon(Icons.settings_suggest, size: 16), text: 'Aktionen'),
            ],
          ),
        ]),
      ),

      // Body
      Expanded(child: _loading
          ? const Center(child: CircularProgressIndicator(color: _kDbBlue))
          : TabBarView(controller: _tabs, children: [
              _buildChecklisteTab(canCheck),
              _buildTeamTab(),
              _buildEreignisseTab(appState),
              _buildAktionenTab(appState, status),
            ])),
    ]);
  }

  // ── Tab 1: Checkliste ──────────────────────────────────────
  Widget _buildChecklisteTab(bool canCheck) => ListView(padding: const EdgeInsets.all(12), children: [
    // Progress
    Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [_kDbBlue, _kDbLight]),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('Einsatz-Checkliste', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold, fontFamily: 'Inter')),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: _vollstaendig ? Colors.greenAccent.withOpacity(0.3) : Colors.white24,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text('$_erledigte / ${_checks.length}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontFamily: 'Inter')),
          ),
        ]),
        const SizedBox(height: 8),
        ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(
          value: _checks.isEmpty ? 0 : _erledigte / _checks.length,
          backgroundColor: Colors.white24,
          valueColor: AlwaysStoppedAnimation(_vollstaendig ? Colors.greenAccent : Colors.white),
          minHeight: 8,
        )),
        if (_vollstaendig) ...[const SizedBox(height: 6), const Row(children: [
          Icon(Icons.check_circle, color: Colors.greenAccent, size: 14),
          SizedBox(width: 4),
          Text('Bereit zum Einsatzbeginn!', style: TextStyle(color: Colors.greenAccent, fontSize: 12, fontFamily: 'Inter')),
        ])],
      ]),
    ),
    const SizedBox(height: 12),
    ..._checks.map((c) {
      final field = c['field'] as String;
      final val   = _checkliste?[field] == true;
      return Container(
        margin: const EdgeInsets.only(bottom: 6),
        decoration: BoxDecoration(
          color: val ? const Color(0xFFE8F5E9) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: val ? Colors.green.shade200 : Colors.grey.shade200),
        ),
        child: ListTile(
          dense: true,
          leading: Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: val ? Colors.green.withOpacity(0.15) : _kDbBlue.withOpacity(0.08),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Icon(c['icon'] as IconData, size: 16, color: val ? Colors.green : _kDbBlue),
          ),
          title: Text(c['label'] as String, style: TextStyle(
            fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.w500,
            color: val ? Colors.green.shade800 : Colors.black87,
          )),
          trailing: canCheck
              ? Checkbox(
                  value: val,
                  activeColor: Colors.green,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                  onChanged: (v) => _toggleCheck(field, v ?? false),
                )
              : Icon(val ? Icons.check_circle : Icons.radio_button_unchecked, color: val ? Colors.green : Colors.grey, size: 20),
        ),
      );
    }),
  ]);

  // ── Tab 2: Team ────────────────────────────────────────────
  Widget _buildTeamTab() {
    if (_team.isEmpty) return _emptyState('Kein Personal geplant', Icons.group_off, 'Weisen Sie Personal über die Planung zu.');
    return ListView(padding: const EdgeInsets.all(12), children: [
      Text('Eingesetzt: ${_team.length} Personen', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: _kDbBlue, fontFamily: 'Inter')),
      const SizedBox(height: 10),
      ..._team.map((p) {
        final u    = (p['user'] as Map<String, dynamic>?) ?? {};
        final name = '${u['first_name'] ?? ''} ${u['last_name'] ?? ''}'.trim();
        final role = p['gleisbau_rolle']?.toString() ?? '';
        final anw  = p['anwesenheit_bestaetigt'] == true;
        final unt  = p['unterweisung_bestaetigt'] == true;
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)]),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              CircleAvatar(radius: 18, backgroundColor: _kDbBlue, child: Text(name.isNotEmpty ? name[0] : '?', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(name.isEmpty ? 'Unbekannt' : name, style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Inter', fontSize: 13)),
                Text(gleisbauRoleLabel(role), style: const TextStyle(fontSize: 11, color: _kDbBlue, fontFamily: 'Inter')),
              ])),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              _badge('Anwesenheit', anw),
              const SizedBox(width: 6),
              _badge('Unterweisung', unt),
            ]),
          ]),
        );
      }),
    ]);
  }

  // ── Tab 3: Ereignisse ──────────────────────────────────────
  Widget _buildEreignisseTab(AppState appState) => Column(children: [
    if (appState.canErfassenGleisbauEvents)
      Padding(padding: const EdgeInsets.fromLTRB(12, 10, 12, 0), child: SizedBox(width: double.infinity,
        child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(backgroundColor: _kDbBlue, foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), padding: const EdgeInsets.symmetric(vertical: 12)),
          icon: const Icon(Icons.add), label: const Text('Neues Ereignis erfassen', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold)),
          onPressed: () => _showEreignisDialog(appState),
        ))),
    Expanded(child: _ereignisse.isEmpty
        ? _emptyState('Keine Ereignisse', Icons.event_note, 'Einsatzereignisse werden hier chronologisch erfasst.')
        : ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: _ereignisse.length,
            itemBuilder: (_, i) => _EreignisTile(_ereignisse[i]),
          )),
  ]);

  // ── Tab 4: Aktionen ────────────────────────────────────────
  Widget _buildAktionenTab(AppState appState, String status) => ListView(padding: const EdgeInsets.all(12), children: [
    _sectionTitle('Einsatz-Aktionen', 'Status: ${_statusLabels[status] ?? status}'),
    const SizedBox(height: 10),
    if (appState.canDurchfuehrenUnterweisung)
      _AktionCard(icon: Icons.school, color: _kPurple, title: 'Unterweisung', subtitle: 'Sicherheitsunterweisung durchführen',
        onTap: () => DefaultTabController.of(context).animateTo(
          _findParentTabIndex(context, 'unterweisung'), duration: Duration.zero)),
    const SizedBox(height: 6),
    if (appState.canErfassenGleisbauEvents)
      _AktionCard(icon: Icons.phone_in_talk, color: _kGreen, title: 'Ferngespräch', subtitle: 'Gespräch dokumentieren',
        onTap: () => DefaultTabController.of(context).animateTo(
          _findParentTabIndex(context, 'ferngespräch'), duration: Duration.zero)),
    const SizedBox(height: 6),
    if (appState.canErfassenGleisbauEvents)
      _AktionCard(icon: Icons.warning_amber, color: const Color(0xFFE65100), title: 'Problem melden', subtitle: 'Sicherheitsrelevantes Ereignis',
        onTap: () => _showEreignisDialog(appState)),
    const SizedBox(height: 6),
    // Status transitions
    if (status == 'einsatzbereit' || status == 'unterwiesen')
      _AktionCard(
        icon: Icons.play_arrow, color: Colors.green.shade700,
        title: 'Einsatz beginnen',
        subtitle: _vollstaendig ? 'Alle Punkte abgehakt – bereit!' : 'Checkliste unvollständig (${_erledigte}/${_checks.length})',
        onTap: _vollstaendig ? () => _changeStatus('einsatz_begonnen') : null,
      ),
    if (status == 'einsatz_begonnen') ...[
      const SizedBox(height: 6),
      _AktionCard(icon: Icons.pause, color: Colors.orange, title: 'Einsatz unterbrechen', subtitle: 'Unterbrechung dokumentieren',
        onTap: () => _changeStatus('einsatz_unterbrochen')),
      const SizedBox(height: 6),
      _AktionCard(icon: Icons.stop, color: _kDbRed, title: 'Einsatz beenden', subtitle: 'Einsatzende dokumentieren',
        onTap: () => _changeStatus('einsatz_beendet')),
    ],
    if (status == 'einsatz_unterbrochen') ...[
      const SizedBox(height: 6),
      _AktionCard(icon: Icons.play_arrow, color: Colors.green, title: 'Einsatz fortsetzen', subtitle: 'Weiterarbeit aufnehmen',
        onTap: () => _changeStatus('einsatz_begonnen')),
    ],
    if (status == 'einsatz_beendet' && appState.canGleisbauAbschluss) ...[
      const SizedBox(height: 6),
      _AktionCard(icon: Icons.task_alt, color: _kDbBlue, title: 'Intern abschließen', subtitle: 'An Abrechnung übergeben',
        onTap: () => _changeStatus('abgeschlossen')),
    ],
  ]);

  // helper — find correct parent tab index by label
  int _findParentTabIndex(BuildContext ctx, String target) {
    // Falls wir in einem eingebetteten Tab sind, können wir den übergeordneten
    // DefaultTabController nicht einfach animieren – stattdessen go back
    return 0;
  }

  Future<void> _changeStatus(String newStatus) async {
    final appState = context.read<AppState>();
    try {
      await SupabaseService.updateOrderStatus(widget.order['id'], newStatus, null, appState.userId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Status: ${_statusLabels[newStatus] ?? newStatus}'),
            backgroundColor: _kDbBlue));
        _load();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fehler: $e'), backgroundColor: Colors.red));
    }
  }

  Future<void> _showEreignisDialog(AppState appState) async {
    String? typ;
    final controller = TextEditingController();
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, ss) => AlertDialog(
        title: const Text('Neues Ereignis', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          DropdownButtonFormField<String>(
            value: typ,
            decoration: const InputDecoration(labelText: 'Ereignistyp *', border: OutlineInputBorder()),
            onChanged: (v) => ss(() => typ = v),
            items: const [
              DropdownMenuItem(value: 'problem_gemeldet',    child: Text('Problem gemeldet')),
              DropdownMenuItem(value: 'behinderung',         child: Text('Behinderung gemeldet')),
              DropdownMenuItem(value: 'personal_abweichung', child: Text('Personalabweichung')),
              DropdownMenuItem(value: 'geraete_abweichung',  child: Text('Geräteabweichung')),
              DropdownMenuItem(value: 'sicherheitsrelevant', child: Text('Sicherheitsrelevantes Ereignis')),
              DropdownMenuItem(value: 'einsatz_unterbrochen',child: Text('Unterbrechung')),
              DropdownMenuItem(value: 'einsatz_beendet',     child: Text('Einsatzende')),
            ],
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: controller,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Kurzbeschreibung *',
              hintText: 'Beschreiben Sie das Ereignis...',
              border: OutlineInputBorder(),
            ),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Abbrechen')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _kDbBlue),
            onPressed: () async {
              if (typ == null || controller.text.trim().isEmpty) {
                ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Bitte alle Pflichtfelder ausfüllen.')));
                return;
              }
              try {
                await SupabaseService.createGleisbauEreignis({
                  'order_id':           widget.order['id'],
                  'ereignis_typ':       typ,
                  'datum':              DateFormat('yyyy-MM-dd').format(DateTime.now()),
                  'uhrzeit':            DateFormat('HH:mm').format(DateTime.now()),
                  'meldende_person_id': appState.userId,
                  'kurzbeschreibung':   controller.text.trim(),
                });
                if (ctx.mounted) Navigator.pop(ctx);
                _load();
              } catch (e) {
                if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Fehler: $e'), backgroundColor: Colors.red));
              }
            },
            child: const Text('Speichern', style: TextStyle(color: Colors.white)),
          ),
        ],
      )),
    );
    controller.dispose();
  }

  static Widget _badge(String label, bool ok) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    decoration: BoxDecoration(
      color: ok ? Colors.green.withOpacity(0.12) : Colors.orange.withOpacity(0.12),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(ok ? Icons.check_circle : Icons.radio_button_unchecked, size: 11, color: ok ? Colors.green : Colors.orange),
      const SizedBox(width: 3),
      Text(label, style: TextStyle(fontSize: 11, color: ok ? Colors.green : Colors.orange, fontFamily: 'Inter')),
    ]),
  );

  static Widget _sectionTitle(String title, String sub) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, fontFamily: 'Inter', color: _kDbBlue)),
    Text(sub, style: const TextStyle(fontSize: 12, color: AppTheme.textSub, fontFamily: 'Inter')),
  ]);

  static Widget _emptyState(String title, IconData icon, String sub) => Center(child: Padding(
    padding: const EdgeInsets.all(32),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 52, color: _kDbBlue.withOpacity(0.25)),
      const SizedBox(height: 10),
      Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, fontFamily: 'Inter', color: _kDbBlue)),
      const SizedBox(height: 6),
      Text(sub, style: const TextStyle(fontSize: 12, color: AppTheme.textSub, fontFamily: 'Inter'), textAlign: TextAlign.center),
    ]),
  ));
}

// ══════════════════════════════════════════════════════════════
// UNTERWEISUNGSMODUL — embedded (no Scaffold)
// ══════════════════════════════════════════════════════════════
class GleisbauUnterweisungScreen extends StatefulWidget {
  final Map<String, dynamic> order;
  const GleisbauUnterweisungScreen({super.key, required this.order});
  @override
  State<GleisbauUnterweisungScreen> createState() => _GleisbauUnterweisungState();
}

class _GleisbauUnterweisungState extends State<GleisbauUnterweisungScreen> {
  bool _loading = true;
  bool _saving  = false;
  Map<String, dynamic>? _unterweisung;
  List<Map<String, dynamic>> _team = [];
  final _freitextController = TextEditingController();

  static const _inhalte = <String, String>{
    'inhalt_arbeitsstelle':      'Arbeitsstelle & Lage',
    'inhalt_gefahren':           'Gefahrenstellen',
    'inhalt_sicherungsmassnahmen': 'Sicherungsmaßnahmen',
    'inhalt_sicherheitsraeume':  'Sicherheitsräume',
    'inhalt_warnmittel':         'Warnmittel & Warnsignale',
    'inhalt_zustaendigkeiten':   'Zuständigkeiten',
    'inhalt_ereignisfall':       'Verhalten im Ereignisfall',
    'inhalt_besonderheiten':     'Tagesbezogene Besonderheiten',
    'inhalt_maschinen':          'Maschinen & Logistik',
  };

  Map<String, bool> _vals = {};

  @override
  void initState() {
    super.initState();
    _vals = {for (final k in _inhalte.keys) k: false};
    _load();
  }

  @override
  void dispose() { _freitextController.dispose(); super.dispose(); }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);
    final orderId = widget.order['id'] as String;
    try {
      final u = await SupabaseService.getGleisbauUnterweisung(orderId);
      final t = await SupabaseService.getGleisbauPersonal(orderId);
      if (!mounted) return;
      setState(() {
        _unterweisung = u;
        _team = t;
        if (u != null) {
          for (final k in _inhalte.keys) _vals[k] = u[k] == true;
          _freitextController.text = u['freitext_inhalte'] ?? '';
        }
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    final appState = context.read<AppState>();
    setState(() => _saving = true);
    final orderId = widget.order['id'] as String;
    try {
      final data = <String, dynamic>{
        'order_id':                orderId,
        'unterweisender_user_id':  appState.userId,
        'datum':                   DateFormat('yyyy-MM-dd').format(DateTime.now()),
        'uhrzeit':                 DateFormat('HH:mm').format(DateTime.now()),
        'freitext_inhalte':        _freitextController.text.trim(),
        'updated_at':              DateTime.now().toIso8601String(),
      };
      data.addAll(_vals);
      if (_unterweisung?['id'] != null) data['id'] = _unterweisung!['id'];
      await SupabaseService.upsertGleisbauUnterweisung(data);
      // Update checkliste flag
      await SupabaseService.upsertGleisbauCheckliste({'order_id': orderId, 'unterweisung_durchgefuehrt': true});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Unterweisung gespeichert'), backgroundColor: _kPurple));
        await _load();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fehler: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _bestaetigen(String userId) async {
    // Ensure unterweisung exists first
    if (_unterweisung == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bitte zuerst Unterweisung speichern.')));
      return;
    }
    final unterweisungId = _unterweisung!['id'] as String?;
    if (unterweisungId == null) return;
    try {
      await SupabaseService.bestaetigenGleisbauUnterweisung(unterweisungId, userId);
      // Also update personal_planung
      await SupabaseService.updateGleisbauPlanungField(widget.order['id'], userId, 'unterweisung_bestaetigt', true);
      _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fehler: $e'), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final canEdit  = appState.canDurchfuehrenUnterweisung;

    if (_loading) return const Center(child: CircularProgressIndicator(color: _kPurple));

    return Column(children: [
      // Header bar
      Container(
        color: _kPurple,
        padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
        child: Row(children: [
          const Icon(Icons.school, color: Colors.white, size: 20),
          const SizedBox(width: 8),
          const Expanded(child: Text('Unterweisung vor Arbeitsbeginn', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontFamily: 'Inter'))),
          if (canEdit)
            _saving
                ? const SizedBox(width: 36, height: 36, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : TextButton.icon(
                    icon: const Icon(Icons.save, color: Colors.white, size: 18),
                    label: const Text('Speichern', style: TextStyle(color: Colors.white, fontFamily: 'Inter')),
                    onPressed: _save,
                  ),
        ]),
      ),

      // Content
      Expanded(child: ListView(padding: const EdgeInsets.all(12), children: [
        // Inhalte
        _card('Unterweisungsinhalte', Icons.checklist, _kPurple, Column(children: [
          ..._inhalte.entries.map((e) => SwitchListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text(e.value, style: const TextStyle(fontFamily: 'Inter', fontSize: 13)),
            value: _vals[e.key] ?? false,
            activeColor: _kPurple,
            onChanged: canEdit ? (v) => setState(() => _vals[e.key] = v) : null,
          )),
          const SizedBox(height: 6),
          TextFormField(
            controller: _freitextController,
            maxLines: 3,
            enabled: canEdit,
            decoration: const InputDecoration(
              labelText: 'Weitere Inhalte (Freitext)',
              hintText: 'Besondere Hinweise, Abweichungen...',
              border: OutlineInputBorder(),
            ),
          ),
        ])),
        const SizedBox(height: 12),

        // Teilnehmer
        _card('Teilnehmerbestätigungen', Icons.how_to_reg, _kDbBlue,
          _team.isEmpty
              ? const Padding(padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text('Kein Personal geplant. Personal zuerst in der Planung eintragen.', style: TextStyle(color: AppTheme.textSub, fontFamily: 'Inter', fontSize: 13)))
              : Column(children: _team.map((p) {
                  final u     = (p['user'] as Map<String, dynamic>?) ?? {};
                  final uid   = u['id']?.toString() ?? '';
                  final name  = '${u['first_name'] ?? ''} ${u['last_name'] ?? ''}'.trim();
                  final bList = (_unterweisung?['gleisbau_unterweisung_bestaetigung'] as List?) ?? [];
                  final bObj  = bList.isEmpty
                      ? <String, dynamic>{}
                      : bList.firstWhere(
                          (b) => b['user_id']?.toString() == uid,
                          orElse: () => <String, dynamic>{},
                        );
                  final best = bObj['bestaetigt'] == true;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: best ? const Color(0xFFE8F5E9) : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: best ? Colors.green.shade200 : Colors.grey.shade200),
                    ),
                    child: Row(children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: best ? Colors.green : Colors.grey.shade300,
                        child: Icon(best ? Icons.check : Icons.person, color: Colors.white, size: 16),
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(name.isEmpty ? 'Unbekannt' : name, style: const TextStyle(fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.w500)),
                        Text(best ? 'Unterweisung bestätigt' : 'Noch nicht bestätigt',
                          style: TextStyle(fontSize: 11, color: best ? Colors.green : Colors.orange, fontFamily: 'Inter')),
                      ])),
                      if (!best && _unterweisung != null)
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _kDbBlue,
                            minimumSize: const Size(80, 30),
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                          ),
                          onPressed: () => _bestaetigen(uid),
                          child: const Text('Bestätigen', style: TextStyle(fontSize: 11, color: Colors.white, fontFamily: 'Inter')),
                        ),
                    ]),
                  );
                }).toList()),
        ),
      ])),
    ]);
  }

  static Widget _card(String title, IconData icon, Color color, Widget child) => Container(
    margin: const EdgeInsets.only(bottom: 4),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(padding: const EdgeInsets.all(5), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(7)),
          child: Icon(icon, color: color, size: 16)),
        const SizedBox(width: 8),
        Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Inter', fontSize: 13, color: color)),
      ]),
      const SizedBox(height: 10),
      child,
    ]),
  );
}

// ══════════════════════════════════════════════════════════════
// FERNGESPRÄCHSBUCH — embedded (no Scaffold)
// ══════════════════════════════════════════════════════════════
class GleisbauFerngespraechScreen extends StatefulWidget {
  final Map<String, dynamic> order;
  const GleisbauFerngespraechScreen({super.key, required this.order});
  @override
  State<GleisbauFerngespraechScreen> createState() => _GleisbauFerngespraechState();
}

class _GleisbauFerngespraechState extends State<GleisbauFerngespraechScreen> {
  List<Map<String, dynamic>> _eintraege = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final data = await SupabaseService.getGleisbauFerngespraeche(widget.order['id']);
      if (mounted) setState(() { _eintraege = data; _loading = false; });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    return Column(children: [
      // Header
      Container(
        color: _kGreen,
        padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
        child: Row(children: [
          const Icon(Icons.phone_in_talk, color: Colors.white, size: 20),
          const SizedBox(width: 8),
          const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Ferngesprächsbuch', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontFamily: 'Inter')),
            Text('Digitales Gesprächsprotokoll', style: TextStyle(color: Colors.white70, fontSize: 11, fontFamily: 'Inter')),
          ])),
          IconButton(icon: const Icon(Icons.refresh, color: Colors.white), onPressed: _load),
          if (appState.canFerngespraech)
            IconButton(
              icon: const Icon(Icons.add_circle, color: Colors.white, size: 28),
              onPressed: () => _showEintragDialog(context, appState),
            ),
        ]),
      ),

      // Content
      Expanded(child: _loading
          ? const Center(child: CircularProgressIndicator(color: _kGreen))
          : _eintraege.isEmpty
              ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.phone_missed, size: 52, color: _kGreen.withOpacity(0.25)),
                  const SizedBox(height: 10),
                  const Text('Noch keine Einträge', style: TextStyle(fontFamily: 'Inter', fontSize: 15, color: AppTheme.textSub)),
                  const SizedBox(height: 4),
                  Text(appState.canFerngespraech ? 'Tippen Sie auf + um ein Gespräch zu erfassen.' : 'Keine Erfassungsberechtigung für diese Rolle.',
                    style: const TextStyle(fontFamily: 'Inter', fontSize: 12, color: AppTheme.textSub)),
                ]))
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _eintraege.length,
                  itemBuilder: (_, i) => _FerngespraechTile(_eintraege[i]),
                )),
    ]);
  }

  Future<void> _showEintragDialog(BuildContext context, AppState appState) async {
    final gegenstelle = TextEditingController();
    final funktion    = TextEditingController();
    final betreff     = TextEditingController();
    final inhalt      = TextEditingController();
    final ergebnis    = TextEditingController();
    String? kategorie;
    bool sicherheitsrelevant = false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, ss) => AlertDialog(
        title: const Row(children: [
          Icon(Icons.phone_in_talk, color: _kGreen),
          SizedBox(width: 8),
          Text('Ferngespräch erfassen', style: TextStyle(fontFamily: 'Inter', fontSize: 15, fontWeight: FontWeight.bold)),
        ]),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          DropdownButtonFormField<String>(
            value: kategorie,
            decoration: const InputDecoration(labelText: 'Kategorie *', border: OutlineInputBorder()),
            onChanged: (v) => ss(() => kategorie = v),
            items: const [
              DropdownMenuItem(value: 'arbeitsbeginn',   child: Text('Arbeitsbeginnmeldung')),
              DropdownMenuItem(value: 'arbeitsende',     child: Text('Arbeitsendemeldung')),
              DropdownMenuItem(value: 'unterbrechung',   child: Text('Unterbrechungsmeldung')),
              DropdownMenuItem(value: 'sicherheit',      child: Text('Sicherheitsabstimmung')),
              DropdownMenuItem(value: 'personal',        child: Text('Personalthema')),
              DropdownMenuItem(value: 'geraet',          child: Text('Gerätestörung')),
              DropdownMenuItem(value: 'schalt',          child: Text('Schaltabstimmung')),
              DropdownMenuItem(value: 'einsatzaenderung',child: Text('Einsatzänderung')),
              DropdownMenuItem(value: 'stoerfall',       child: Text('Störfall / Abweichung')),
              DropdownMenuItem(value: 'notfall',         child: Text('Notfall / Eskalation')),
              DropdownMenuItem(value: 'organisatorisch', child: Text('Organisatorische Rückfrage')),
            ],
          ),
          const SizedBox(height: 10),
          TextFormField(controller: gegenstelle, decoration: const InputDecoration(labelText: 'Gesprächspartner *', border: OutlineInputBorder())),
          const SizedBox(height: 10),
          TextFormField(controller: funktion, decoration: const InputDecoration(labelText: 'Funktion der Gegenstelle', border: OutlineInputBorder())),
          const SizedBox(height: 10),
          TextFormField(controller: betreff, decoration: const InputDecoration(labelText: 'Kurzbetreff *', border: OutlineInputBorder())),
          const SizedBox(height: 10),
          TextFormField(controller: inhalt, maxLines: 3, decoration: const InputDecoration(labelText: 'Gesprächsinhalt *', hintText: 'Zusammenfassung...', border: OutlineInputBorder())),
          const SizedBox(height: 10),
          TextFormField(controller: ergebnis, maxLines: 2, decoration: const InputDecoration(labelText: 'Ergebnis / Maßnahme', border: OutlineInputBorder())),
          const SizedBox(height: 6),
          SwitchListTile(
            dense: true, contentPadding: EdgeInsets.zero,
            title: const Text('Sicherheitsrelevant', style: TextStyle(fontFamily: 'Inter', fontSize: 13)),
            value: sicherheitsrelevant,
            activeColor: _kDbRed,
            onChanged: (v) => ss(() => sicherheitsrelevant = v),
          ),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Abbrechen')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _kGreen),
            onPressed: () async {
              final errs = <String>[];
              if (kategorie == null)             errs.add('Kategorie');
              if (gegenstelle.text.trim().isEmpty) errs.add('Gesprächspartner');
              if (betreff.text.trim().isEmpty)   errs.add('Kurzbetreff');
              if (inhalt.text.trim().isEmpty)    errs.add('Gesprächsinhalt');
              if (errs.isNotEmpty) {
                ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                  content: Text('Pflichtfeld fehlt: ${errs.join(', ')}'),
                  backgroundColor: Colors.red,
                ));
                return;
              }
              try {
                await SupabaseService.createGleisbauFerngespraech({
                  'order_id':                    widget.order['id'],
                  'datum':                       DateFormat('yyyy-MM-dd').format(DateTime.now()),
                  'uhrzeit':                     DateFormat('HH:mm').format(DateTime.now()),
                  'gespraech_fuehrender_user_id': appState.userId,
                  'gegenstelle_name':            gegenstelle.text.trim(),
                  'gegenstelle_funktion':        funktion.text.trim().isEmpty ? null : funktion.text.trim(),
                  'kategorie':                   kategorie,
                  'kurzbetreff':                 betreff.text.trim(),
                  'gespraechsinhalt':            inhalt.text.trim(),
                  'ergebnis_massnahme':          ergebnis.text.trim().isEmpty ? null : ergebnis.text.trim(),
                  'sicherheitsrelevant':         sicherheitsrelevant,
                  'erstellt_von':                appState.userId,
                });
                if (ctx.mounted) Navigator.pop(ctx);
                _load();
              } catch (e) {
                if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(
                  SnackBar(content: Text('Fehler: $e'), backgroundColor: Colors.red));
              }
            },
            child: const Text('Speichern', style: TextStyle(color: Colors.white, fontFamily: 'Inter')),
          ),
        ],
      )),
    );
    gegenstelle.dispose(); funktion.dispose(); betreff.dispose();
    inhalt.dispose(); ergebnis.dispose();
  }
}

// ══════════════════════════════════════════════════════════════
// MITARBEITER MOBILANSICHT — embedded (no Scaffold)
// ══════════════════════════════════════════════════════════════
class GleisbauMitarbeiterView extends StatefulWidget {
  final Map<String, dynamic> order;
  const GleisbauMitarbeiterView({super.key, required this.order});
  @override
  State<GleisbauMitarbeiterView> createState() => _GleisbauMitarbeiterViewState();
}

class _GleisbauMitarbeiterViewState extends State<GleisbauMitarbeiterView> {
  Map<String, dynamic>? _myPlanung;
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final appState = context.read<AppState>();
    setState(() => _loading = true);
    try {
      final plan = await SupabaseService.getGleisbauMeinePlanung(widget.order['id'], appState.userId!);
      if (mounted) setState(() { _myPlanung = plan; _loading = false; });
    } catch (_) { if (mounted) setState(() => _loading = false); }
  }

  Future<void> _bestaetigen(String field) async {
    final appState = context.read<AppState>();
    try {
      await SupabaseService.updateGleisbauPlanungField(widget.order['id'], appState.userId!, field, true);
      _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fehler: $e'), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    if (_loading) return const Center(child: CircularProgressIndicator(color: _kDbBlue));

    final order    = widget.order;
    final orderNum = order['order_number']?.toString() ?? '–';
    final saName   = (order['service_area'] as Map?)?['name']?.toString() ?? '–';
    final anw      = _myPlanung?['anwesenheit_bestaetigt'] == true;
    final unt      = _myPlanung?['unterweisung_bestaetigt'] == true;
    final einsatz  = _myPlanung?['einsatz_bestaetigt'] == true;
    final meinRole = appState.dbGleisbauRole;

    if (_myPlanung == null) {
      return Center(child: Padding(padding: const EdgeInsets.all(32), child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.train_outlined, size: 56, color: _kDbBlue.withOpacity(0.3)),
        const SizedBox(height: 12),
        const Text('Sie sind diesem Einsatz nicht zugewiesen.', textAlign: TextAlign.center,
          style: TextStyle(fontFamily: 'Inter', fontSize: 14, color: AppTheme.textSub)),
      ])));
    }

    return ListView(padding: const EdgeInsets.all(12), children: [
      // Auftragskopf
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(gradient: LinearGradient(colors: [_kDbBlue, _kDbLight]), borderRadius: BorderRadius.circular(14)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [const Icon(Icons.train, color: Colors.white70, size: 14), const SizedBox(width: 5),
            const Text('DB-Gleisbausicherung', style: TextStyle(color: Colors.white70, fontSize: 11, fontFamily: 'Inter'))]),
          const SizedBox(height: 6),
          Text(orderNum, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold, fontFamily: 'Inter')),
          Text(saName, style: const TextStyle(color: Colors.white70, fontSize: 12, fontFamily: 'Inter')),
          const SizedBox(height: 10),
          Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(16)),
            child: Text('Meine Rolle: ${gleisbauRoleLabel(meinRole)}', style: const TextStyle(color: Colors.white, fontSize: 12, fontFamily: 'Inter'))),
        ]),
      ),
      const SizedBox(height: 12),

      // Bestätigungen
      _sectionCard('Meine Bestätigungen', Colors.green, [
        _ConfirmTile('Anwesenheit bestätigen', anw, onTap: () => _bestaetigen('anwesenheit_bestaetigt')),
        _ConfirmTile('Unterweisung bestätigen', unt, onTap: () => _bestaetigen('unterweisung_bestaetigt')),
        _ConfirmTile('Einsatz übernehmen', einsatz, onTap: () => _bestaetigen('einsatz_bestaetigt')),
      ]),
      const SizedBox(height: 10),

      // Einsatzende
      _sectionCard('Aktionen', Colors.orange.shade700, [
        ListTile(dense: true, leading: const Icon(Icons.flag, color: Colors.orange), title: const Text('Einsatzende bestätigen', style: TextStyle(fontFamily: 'Inter')),
          onTap: () => _bestaetigen('einsatz_ende_bestaetigt')),
      ]),
    ]);
  }

  static Widget _sectionCard(String title, Color color, List<Widget> children) => Container(
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)]),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(padding: const EdgeInsets.fromLTRB(14, 12, 14, 6), child: Row(children: [
        Container(width: 4, height: 16, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 8),
        Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Inter', fontSize: 13, color: color)),
      ])),
      ...children,
    ]),
  );
}

// ══════════════════════════════════════════════════════════════
// REUSABLE WIDGETS
// ══════════════════════════════════════════════════════════════
class _AktionCard extends StatelessWidget {
  final IconData icon; final Color color; final String title; final String subtitle;
  final VoidCallback? onTap;
  const _AktionCard({required this.icon, required this.color, required this.title, required this.subtitle, this.onTap});

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(12), child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: onTap != null ? Colors.white : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: onTap != null ? color.withOpacity(0.3) : Colors.grey.shade200),
        boxShadow: onTap != null ? [BoxShadow(color: color.withOpacity(0.08), blurRadius: 6, offset: const Offset(0, 2))] : [],
      ),
      child: Row(children: [
        Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(
            color: onTap != null ? color.withOpacity(0.1) : Colors.grey.shade200,
            borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, color: onTap != null ? color : Colors.grey, size: 20)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold, fontSize: 13,
              color: onTap != null ? Colors.black87 : Colors.grey)),
          Text(subtitle, style: const TextStyle(fontFamily: 'Inter', fontSize: 11, color: AppTheme.textSub)),
        ])),
        Icon(Icons.chevron_right, color: onTap != null ? color : Colors.grey.shade300, size: 20),
      ]),
    )),
  );
}

class _EreignisTile extends StatelessWidget {
  final Map<String, dynamic> e;
  const _EreignisTile(this.e);

  static Color _tyColor(String typ) {
    if (typ == 'sicherheitsrelevant') return _kDbRed;
    if (typ == 'problem_gemeldet' || typ == 'behinderung') return Colors.orange;
    return _kDbBlue;
  }

  static String _tyLabel(String typ) {
    const m = {
      'problem_gemeldet':    'Problem', 'behinderung': 'Behinderung',
      'personal_abweichung': 'Personalabweichung', 'geraete_abweichung': 'Geräteabweichung',
      'sicherheitsrelevant': 'Sicherheitsrelevant', 'einsatz_begonnen': 'Begonnen',
      'einsatz_unterbrochen':'Unterbrochen', 'einsatz_fortgesetzt': 'Fortgesetzt',
      'einsatz_beendet':     'Beendet',
    };
    return m[typ] ?? typ;
  }

  @override
  Widget build(BuildContext context) {
    final typ   = e['ereignis_typ']?.toString() ?? '';
    final datum = e['datum']?.toString() ?? '';
    final zeit  = e['uhrzeit']?.toString() ?? '';
    final beschr = e['kurzbeschreibung']?.toString() ?? '';
    final color = _tyColor(typ);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.25)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 4)]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(5)),
            child: Text(_tyLabel(typ), style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color, fontFamily: 'Inter'))),
          const Spacer(),
          Text('$datum  $zeit', style: const TextStyle(fontSize: 11, color: AppTheme.textSub, fontFamily: 'Inter')),
        ]),
        if (beschr.isNotEmpty) ...[const SizedBox(height: 6), Text(beschr, style: const TextStyle(fontFamily: 'Inter', fontSize: 12))],
      ]),
    );
  }
}

class _FerngespraechTile extends StatelessWidget {
  final Map<String, dynamic> e;
  const _FerngespraechTile(this.e);

  static String _kat(String k) {
    const m = {
      'arbeitsbeginn':    'Arbeitsbeginn', 'arbeitsende':  'Arbeitsende',
      'unterbrechung':    'Unterbrechung', 'sicherheit':   'Sicherheit',
      'personal':         'Personal',      'geraet':       'Gerätestörung',
      'schalt':           'Schaltfragen',  'einsatzaenderung': 'Einsatzänderung',
      'stoerfall':        'Störfall',      'notfall':      'Notfall / Eskalation',
      'organisatorisch':  'Organisatorisch',
    };
    return m[k] ?? k;
  }

  @override
  Widget build(BuildContext context) {
    final betreff     = e['kurzbetreff']?.toString() ?? '–';
    final gegenstelle = e['gegenstelle_name']?.toString() ?? '–';
    final datum       = e['datum']?.toString() ?? '';
    final zeit        = e['uhrzeit']?.toString() ?? '';
    final kat         = e['kategorie']?.toString() ?? '';
    final inhalt      = e['gespraechsinhalt']?.toString() ?? '';
    final sicher      = e['sicherheitsrelevant'] == true;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: sicher ? _kDbRed.withOpacity(0.3) : Colors.grey.shade200),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 4)],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.phone, size: 14, color: _kGreen),
          const SizedBox(width: 5),
          Expanded(child: Text(betreff, style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Inter', fontSize: 13))),
          if (sicher) Container(padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            decoration: BoxDecoration(color: _kDbRed.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
            child: const Text('Sicherheitsrelevant', style: TextStyle(fontSize: 10, color: _kDbRed, fontWeight: FontWeight.bold, fontFamily: 'Inter'))),
        ]),
        const SizedBox(height: 3),
        Text('$gegenstelle  ·  $_kat(kat)  ·  $datum $zeit',
          style: const TextStyle(fontSize: 11, color: AppTheme.textSub, fontFamily: 'Inter')),
        if (inhalt.isNotEmpty) ...[const SizedBox(height: 6), Text(inhalt, style: const TextStyle(fontFamily: 'Inter', fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis)],
      ]),
    );
  }
}

class _ConfirmTile extends StatelessWidget {
  final String label; final bool confirmed; final VoidCallback? onTap;
  const _ConfirmTile(this.label, this.confirmed, {this.onTap});

  @override
  Widget build(BuildContext context) => ListTile(
    dense: true,
    leading: Icon(confirmed ? Icons.check_circle : Icons.radio_button_unchecked,
        color: confirmed ? Colors.green : Colors.grey, size: 22),
    title: Text(label, style: TextStyle(fontFamily: 'Inter', fontSize: 13,
        color: confirmed ? Colors.green.shade800 : Colors.black87)),
    trailing: confirmed ? null : ElevatedButton(
      style: ElevatedButton.styleFrom(backgroundColor: _kDbBlue, minimumSize: const Size(90, 30),
        padding: const EdgeInsets.symmetric(horizontal: 10)),
      onPressed: onTap,
      child: const Text('Bestätigen', style: TextStyle(fontSize: 11, color: Colors.white, fontFamily: 'Inter')),
    ),
  );
}

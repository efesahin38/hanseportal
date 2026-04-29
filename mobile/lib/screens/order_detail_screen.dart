import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../theme/web_utils.dart';
import '../providers/app_state.dart';
import '../services/supabase_service.dart';
import '../services/localization_service.dart';
import 'operation_plan_form_screen.dart';
import 'extra_work_form_screen.dart';
import 'work_report_screen.dart';
import 'order_formulare_tab.dart';
import 'gws_tagesplan_screen.dart';
import 'gleisbau_screens.dart';

class OrderDetailScreen extends StatefulWidget {
  final String orderId;
  const OrderDetailScreen({super.key, required this.orderId});

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> with TickerProviderStateMixin {
  Map<String, dynamic>? _order;
  List<Map<String, dynamic>> _siteUpdates = [];
  List<Map<String, dynamic>> _gwsTagesplaene = [];
  List<Map<String, dynamic>> _internalContacts = [];
  bool _loading = true;
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 6, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final order = await SupabaseService.getOrder(widget.orderId);
      final updates = await SupabaseService.getSiteUpdates(widget.orderId);
      
      // GWS siparişi ise o müşteriye ait Tagespläne'yi de yükle
      List<Map<String, dynamic>> gwsPlans = [];
      final saName = order?['service_area']?['name']?.toString().toLowerCase() ?? '';
      final customerId = order?['customer_id']?.toString();
      if (saName.contains('gastwirtschaft') && customerId != null) {
        try {
          gwsPlans = await SupabaseService.getGwsDailyPlans(objectId: customerId, orderId: widget.orderId);
        } catch (_) {}
      }

      // v19.7.6: Şirket iletişim kişilerini yükle
      List<Map<String, dynamic>> internal = [];
      if (order != null && order['department_id'] != null) {
        internal = await SupabaseService.getManagementUsersForOrder(order['department_id'].toString());
      }

      if (mounted) {
        setState(() {
          _order = order;
          _siteUpdates = updates;
          _gwsTagesplaene = gwsPlans;
          _internalContacts = internal;
          
          final saName = (order?['service_area']?['name'] ?? '').toString().toLowerCase();
          final appState = Provider.of<AppState>(context, listen: false);
          final bool isAssignedForeman = (order?['operation_plans'] as List? ?? []).any((p) => 
               (p['operation_plan_personnel'] as List? ?? []).any((pp) => (pp['user_id'] == appState.userId || pp['user']?['id'] == appState.userId) && pp['is_supervisor'] == true));
          final canSeeFormsAndPlanlama = appState.canPlanOperations || appState.isExternalManager || isAssignedForeman;
          
          final isFormEnabled = saName.contains('gebäude') || saName.contains('gastwirtschaft');
          final isGleisbau = saName.contains('gleis') || saName.contains('db') || saName.contains('rail');
          
          int tLen = 4;
          if (canSeeFormsAndPlanlama) tLen++;
          if (canSeeFormsAndPlanlama && isFormEnabled) tLen++;
          // v19.8.0: Gleisbausicherung spezifische Tabs
          if (isGleisbau && appState.canAccessGleisbauLeitstand) tLen++; // SAKRA-Leitstand
          if (isGleisbau && appState.canDurchfuehrenUnterweisung) tLen++; // Unterweisung
          if (isGleisbau) tLen++; // Ferngesprächsbuch

          if (_tabs.length != tLen) {
            _tabs.dispose();
            _tabs = TabController(length: tLen, vsync: this);
          }
          
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  // _showStatusDialog removed to enforce automated workflow

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_order == null) {
      return Scaffold(
        appBar: AppBar(title: Text(tr('Auftragsdetail'))),
        body: Center(child: Text(tr('Auftrag nicht gefunden'), style: const TextStyle(fontFamily: 'Inter'))),
      );
    }

    final o = _order!;
    final status = o['status'] ?? '';
    final customer = o['customer'];
    final serviceArea = o['service_area'];
    final responsible = o['responsible_user'];
    final plans = o['operation_plans'] as List? ?? [];
    final docs = o['documents'] as List? ?? [];
    final history = o['order_status_history'] as List? ?? [];

    final appState = context.watch<AppState>();
    final isAssignedForeman = plans.any((p) {
      final isSiteSupervisor = p['site_supervisor_id']?.toString() == appState.userId?.toString();
      final isPersonnelSupervisor = (p['operation_plan_personnel'] as List? ?? []).any((pp) => 
        (pp['user_id']?.toString() == appState.userId?.toString() || pp['user']?['id']?.toString() == appState.userId?.toString()) && 
        (pp['is_supervisor'] == true || pp['is_supervisor']?.toString() == 'true' || pp['is_supervisor'] == 1));
      return isSiteSupervisor || isPersonnelSupervisor;
    });
    
    // İş sonu raporunu (yeşil buton) sadece yönetici, muhasebe ve sistem admin görebilir.
    final canSeeReport = appState.isBetriebsleiter || appState.isGeschaeftsfuehrer || appState.isBuchhaltung || appState.isSystemAdmin;
    final canApprove = appState.isBetriebsleiter || appState.isGeschaeftsfuehrer || appState.isSystemAdmin || appState.canPlanOperations;
    final canDelete = canApprove;
    final canSendToExt = canApprove || isAssignedForeman;
    final canAddExtraWork = isAssignedForeman || appState.isBetriebsleiter || appState.isGeschaeftsfuehrer || appState.isSystemAdmin;
    final saName = serviceArea?['name']?.toString().toLowerCase() ?? '';
    final isFormEnabled = saName.contains('gebäude') || saName.contains('gastwirtschaft');
    final isGleisbau = saName.contains('gleis') || saName.contains('db') || saName.contains('rail');
    final canSeeFormsAndPlanlama = appState.canPlanOperations || appState.isExternalManager || isAssignedForeman;

    // Gleisbausicherung: Operative Mitarbeiter-Ansicht (nur ihre eigene reduzierte Sicht)
    final isGleisbauOperativMitarbeiter = isGleisbau && appState.isGleisbauOperativ;

    return Scaffold(
      floatingActionButton: (canSeeReport || canAddExtraWork || appState.canPlanOperations) ? Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (canSeeReport)
            FloatingActionButton.small(
              heroTag: 'work_report',
              backgroundColor: AppTheme.success,
              tooltip: tr('Abschlussbericht'),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => WorkReportScreen(orderId: widget.orderId))).then((_) => _load()),
              child: const Icon(Icons.summarize_outlined, color: Colors.white),
            ),
          if (canSeeReport) const SizedBox(height: 8),
          if (canAddExtraWork)
            FloatingActionButton.small(
              heroTag: 'extra_work',
              backgroundColor: AppTheme.warning,
              tooltip: tr('Ek İş Ekle'),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ExtraWorkFormScreen(orderId: widget.orderId))).then((_) => _load()),
              child: const Icon(Icons.add_task, color: Colors.white),
            ),
          if (canAddExtraWork) const SizedBox(height: 8),
          if (appState.canPlanOperations)
            FloatingActionButton.extended(
              heroTag: 'add_plan',
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => OperationPlanFormScreen(orderId: widget.orderId))).then((_) => _load()),
              icon: const Icon(Icons.calendar_today),
              label: Text(tr('Plan Ekle')),
            ),
        ],
      ) : null,
      appBar: AppBar(
        title: Text(o['order_number'] ?? tr('Auftragsdetail')),
        actions: [
          // 🏠 Ana sayfaya git
          IconButton(
            icon: const Icon(Icons.home_outlined),
            tooltip: 'Zur Startseite (Aufträge)',
            onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: WebContentWrapper(
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            // ── Başlık Alanı ─────────────────────────────────
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(child: Text(o['title'] ?? '', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Inter'))),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.statusColor(status).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(AppTheme.statusLabel(status),
                        style: TextStyle(fontSize: 12, color: AppTheme.statusColor(status), fontWeight: FontWeight.w600, fontFamily: 'Inter')),
                    ),
                  ]),
                  const SizedBox(height: 6),
                  if (customer != null)
                    Text(customer['name'] ?? '', style: const TextStyle(fontSize: 14, color: AppTheme.textSub, fontFamily: 'Inter')),
                  if (serviceArea != null) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: AppTheme.primary.withOpacity(0.08), borderRadius: BorderRadius.circular(6)),
                      child: Text(serviceArea['name'] ?? '', style: const TextStyle(fontSize: 12, color: AppTheme.primary, fontFamily: 'Inter')),
                    ),
                  ],
                  const SizedBox(height: 12),
                  TabBar(
                    controller: _tabs,
                    isScrollable: true,
                    labelStyle: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600, fontSize: 12),
                    unselectedLabelStyle: const TextStyle(fontFamily: 'Inter', fontSize: 12),
                    tabs: [
                        Tab(text: tr('Bilgiler')),
                        if (canSeeFormsAndPlanlama) Tab(text: '${tr('Planlama')} (${plans.length})'),
                        Tab(text: '${tr('Saha Günlüğü')} (${_siteUpdates.length})'),
                        Tab(text: '${tr('Belgeler')} (${docs.length})'),
                        Tab(text: '${tr('Geçmiş')} (${history.length})'),
                        if (canSeeFormsAndPlanlama && isFormEnabled) const Tab(text: 'Formulare'),
                        // v19.8.0: Gleisbausicherung Tabs
                        if (isGleisbau && appState.canAccessGleisbauLeitstand) const Tab(icon: Icon(Icons.security, size: 16), text: 'Leitstand'),
                        if (isGleisbau && appState.canDurchfuehrenUnterweisung) const Tab(icon: Icon(Icons.school, size: 16), text: 'Unterweisung'),
                        if (isGleisbau) const Tab(icon: Icon(Icons.phone_in_talk, size: 16), text: 'Ferngespräch'),
                      ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabs,
                children: [
                  // Tab 1: Temel Bilgiler
                  SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(children: [
                      // v19.7.4: Muhattap & Sachbearbeiter bilgileri artık ana kartta (Daha görünür olması için)
                      _InfoCard(tr('Auftragsinformationen'), [
                        _InfoRow(tr('Auftragsnummer'), o['order_number']),
                        _InfoRow(tr('Priorität'), o['priority']),
                        _InfoRow(tr('Başlangıç'), o['planned_start_date']),
                        _InfoRow(tr('Bitiş'), o['planned_end_date']),
                        _InfoRow(tr('Saha Adresi'), [
                          o['street'],
                          o['house_number'],
                          o['postal_code'],
                          o['city']
                        ].where((e) => e != null && e.toString().isNotEmpty).join(' ')),
                        
                        // v19.7.6: Muhattap (Ext. Manager) Detaylı
                        if (o['customer_contact'] != null) ...[
                          _InfoRow(
                            'Muhattap', 
                            (o['customer_contact'] as Map)['name'],
                            trailing: _ContactActions(
                              phone: (o['customer_contact'] as Map)['phone'],
                              email: (o['customer_contact'] as Map)['email'],
                            ),
                          ),
                          if ((o['customer_contact'] as Map)['phone'] != null)
                             _InfoRow('Muhattap Tel', (o['customer_contact'] as Map)['phone']),
                        ],
                        // Sachbearbeiter (Müşteri Yetkilisi)
                        if (o['sachbearbeiter_contact'] != null)
                          _InfoRow('Sachbearbeiter', (o['sachbearbeiter_contact'] as Map)['name']),

                        _InfoRow(tr('Min. Faturalanacak Saat'), o['minimum_billable_hours']?.toString()),
                        _InfoRow(tr('Malzeme/Ekipman'), o['material_notes']),
                        // Fiyat bilgisi sadece yetkili roller
                        if (appState.canSeeFinancialDetails) ...[
                          _InfoRow('Verhandlungsart', o['negotiation_type']),
                          if ((o['net_amount'] as num?) != null)
                            _InfoRow('Summe netto', '${(o['net_amount'] as num).toStringAsFixed(2)} €'),
                        ],
                        
                        // Subunternehmen
                        if (o['is_subcontractor'] == true) ...[
                          const Divider(height: 16),
                          Row(
                            children: [
                              const Icon(Icons.handshake_outlined, size: 20, color: Color(0xFF00ACC1)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text('Subunternehmen: ${o['subcontractor']?['name'] ?? 'Unbekannt'}', 
                                  style: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold, color: Color(0xFF00ACC1))),
                              ),
                            ],
                          ),
                        ],
                      ]),
                      const SizedBox(height: 12),
                      _InfoCard(tr('Kunde'), [
                        _InfoRow(tr('Kunde'), customer?['name']),
                        _InfoRow(tr('Telefon'), customer?['phone'], isMasked: !appState.canSeeFullCustomerDetails),
                        _InfoRow(tr('E-Mail'), customer?['email'], isMasked: !appState.canSeeFullCustomerDetails),
                      ]),
                      const SizedBox(height: 12),
                      if (o['short_description'] != null || o['detailed_description'] != null)
                        _InfoCard(tr('Açıklama'), [
                          if (o['short_description'] != null)
                            Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(o['short_description'], style: const TextStyle(fontFamily: 'Inter', fontSize: 14))),
                          if (o['detailed_description'] != null)
                            Text(o['detailed_description'], style: const TextStyle(fontFamily: 'Inter', fontSize: 13, color: AppTheme.textSub)),
                        ]),

                      // ── v19.7.6: Unsere Ansprechpartner (Hanse Kollektiv Yetkilileri) ──
                      if (_internalContacts.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        _InfoCard('Unsere Ansprechpartner (Hanse Kollektiv)', [
                          ..._internalContacts.map((u) {
                            final roleMap = {
                              'geschaeftsfuehrer': 'Geschäftsführer',
                              'betriebsleiter': 'Betriebsleiter',
                              'bereichsleiter': 'Bereichsleiter (${u['department']?['name'] ?? ''})',
                            };
                            final roleLabel = roleMap[u['role']?.toString().toLowerCase()] ?? u['role']?.toString() ?? '';
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8.0),
                              child: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.grey.withOpacity(0.05),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.grey.withOpacity(0.1)),
                                ),
                                child: Row(children: [
                                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    Text('$roleLabel:', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.primary, fontFamily: 'Inter')),
                                    Text('${u['first_name']} ${u['last_name']}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, fontFamily: 'Inter')),
                                  ])),
                                  _ContactActions(phone: u['phone'], email: u['email']),
                                ]),
                              ),
                            );
                          }),
                        ]),
                      ],
                      // ── GWS Tagesplanung Bölümü ──
                      if (canSeeFormsAndPlanlama && isFormEnabled && saName.contains('gastwirtschaft')) ...[
                        const SizedBox(height: 12),
                        _GwsTagesplanSection(
                          orderId: widget.orderId,
                          customerId: customer?['id']?.toString(),
                          customerName: customer?['name'] ?? '',
                          plans: _gwsTagesplaene,
                          objects: customer != null ? [customer] : [],
                          departmentId: o['department_id']?.toString(),
                          onRefresh: _load,
                          isAssignedForeman: isAssignedForeman,
                        ),
                      ],
                    ]),
                  ),
                  // Tab 2: Planlama
                  if (canSeeFormsAndPlanlama)
                    plans.isEmpty
                          ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                            const Icon(Icons.calendar_today_outlined, size: 48, color: AppTheme.textSub),
                            const SizedBox(height: 12),
                            Text(tr('Henüz plan yok'), style: const TextStyle(color: AppTheme.textSub, fontFamily: 'Inter')),
                          ]))
                        : ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: plans.length,
                          itemBuilder: (_, i) {
                            final p = plans[i];
                            final personnel = p['operation_plan_personnel'] as List? ?? [];
                            final startTime = p['start_time'] ?? '';
                            final endTime = p['end_time'] ?? '';
                            final supervisor = p['site_supervisor'] as Map<String, dynamic>?;

                            return Card(
                              margin: const EdgeInsets.only(bottom: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: appState.canPlanOperations ? () => Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => OperationPlanFormScreen(orderId: widget.orderId, planId: p['id'])),
                                ).then((_) => _load()) : null,
                                child: Padding(
                                  padding: const EdgeInsets.all(14),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Üst satır: Tarih + Durum
                                      Row(
                                        children: [
                                          const Icon(Icons.calendar_today, size: 14, color: AppTheme.primary),
                                          const SizedBox(width: 6),
                                          Text(
                                            p['plan_date'] ?? '',
                                            style: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold, fontSize: 14),
                                          ),
                                          const Spacer(),
                                          Builder(
                                            builder: (context) {
                                              String dispStatus = p['status'] ?? 'draft';
                                              final oStatus = _order?['status'] ?? '';
                                              if (oStatus == 'completed' || oStatus == 'invoiced' || oStatus == 'archived' || oStatus == 'in_progress') {
                                                dispStatus = oStatus;
                                              } else if (personnel.isNotEmpty && dispStatus == 'draft') {
                                                dispStatus = 'approved'; // Atanmış plan
                                              }
                                              
                                              return Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                decoration: BoxDecoration(
                                                  color: AppTheme.statusColor(dispStatus).withOpacity(0.12),
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                                child: Text(
                                                  AppTheme.statusLabel(dispStatus),
                                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, fontFamily: 'Inter', color: AppTheme.statusColor(dispStatus)),
                                                ),
                                              );
                                            }
                                          ),
                                        ],
                                      ),
                                      // Saat bilgisi
                                      if (startTime.isNotEmpty) ...[
                                        const SizedBox(height: 6),
                                        Row(children: [
                                          const Icon(Icons.access_time, size: 13, color: AppTheme.textSub),
                                          const SizedBox(width: 4),
                                          Text(
                                            endTime.isNotEmpty ? '$startTime – $endTime' : startTime,
                                            style: const TextStyle(fontSize: 12, fontFamily: 'Inter', color: AppTheme.textSub),
                                          ),
                                        ]),
                                      ],
                                      // Saha sorumlusu
                                      if (supervisor != null) ...[
                                        const SizedBox(height: 6),
                                        Row(children: [
                                          const Icon(Icons.star_outline, size: 13, color: AppTheme.warning),
                                          const SizedBox(width: 4),
                                          Text(
                                            '${tr('Saha Sorumlusu')}: ${supervisor['first_name']} ${supervisor['last_name']}',
                                            style: const TextStyle(fontSize: 12, fontFamily: 'Inter', color: AppTheme.warning, fontWeight: FontWeight.w600),
                                          ),
                                        ]),
                                      ],
                                      // Personel listesi
                                      if (personnel.isNotEmpty) ...[
                                        const SizedBox(height: 10),
                                        const Divider(height: 1),
                                        const SizedBox(height: 8),
                                        Row(children: [
                                          const Icon(Icons.people_outline, size: 13, color: AppTheme.textSub),
                                          const SizedBox(width: 4),
                                          Text('${tr('Atanan Personel')} (${personnel.length} ${tr('Personen')})', style: const TextStyle(fontSize: 12, fontFamily: 'Inter', color: AppTheme.textSub, fontWeight: FontWeight.w600)),
                                        ]),
                                        const SizedBox(height: 6),
                                        ...personnel.map((pp) {
                                          final u = pp['user'] as Map<String, dynamic>? ?? {};
                                          final name = '${u['first_name'] ?? ''} ${u['last_name'] ?? ''}'.trim();
                                          final isSup = pp['is_supervisor'] == true;
                                          return Padding(
                                            padding: const EdgeInsets.only(bottom: 4),
                                            child: Row(children: [
                                              Icon(
                                                isSup ? Icons.star : Icons.person_outline,
                                                size: 13,
                                                color: isSup ? AppTheme.warning : AppTheme.textSub,
                                              ),
                                              const SizedBox(width: 6),
                                              Text(
                                                name,
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  fontFamily: 'Inter',
                                                  fontWeight: isSup ? FontWeight.w600 : FontWeight.normal,
                                                ),
                                              ),
                                            ]),
                                          );
                                        }),
                                      ] else ...[
                                        const SizedBox(height: 6),
                                        Text(tr('Henüz personel atanmadı'), style: const TextStyle(fontSize: 12, fontFamily: 'Inter', color: AppTheme.textSub, fontStyle: FontStyle.italic)),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),

                  // Tab 3: Saha Günlüğü
                  _siteUpdates.isEmpty
                      ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                          const Icon(Icons.auto_stories_outlined, size: 48, color: AppTheme.textSub),
                          const SizedBox(height: 12),
                          Text(tr('Henüz saha bildirimi yok'), style: const TextStyle(color: AppTheme.textSub, fontFamily: 'Inter')),
                        ]))
                      : ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: _siteUpdates.length,
                          itemBuilder: (_, i) {
                            final u = _siteUpdates[i];
                            final user = u['user'] as Map<String, dynamic>? ?? {};
                            final userName = '${user['first_name'] ?? ''} ${user['last_name'] ?? ''}'.trim();
                            final date = u['created_at'] != null ? DateTime.parse(u['created_at']).toLocal() : null;
                            
                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(children: [
                                      CircleAvatar(
                                        radius: 12,
                                        backgroundColor: AppTheme.primary.withOpacity(0.1),
                                        child: Text(userName.isNotEmpty ? userName[0].toUpperCase() : '?', 
                                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.primary)),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(child: Text(userName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, fontFamily: 'Inter'))),
                                      if (date != null)
                                        Text('${date.day}/${date.month} ${date.hour}:${date.minute.toString().padLeft(2, '0')}', 
                                          style: const TextStyle(color: AppTheme.textSub, fontSize: 11, fontFamily: 'Inter')),
                                    ]),
                                    const SizedBox(height: 8),
                                    if ((u['description'] ?? '').isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(bottom: 8),
                                        child: Text(u['description'], style: const TextStyle(fontSize: 13, fontFamily: 'Inter')),
                                      ),
                                    if (u['photo_url'] != null)
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Image.network(
                                          u['photo_url'],
                                          fit: BoxFit.cover,
                                          width: double.infinity,
                                          loadingBuilder: (context, child, loadingProgress) {
                                            if (loadingProgress == null) return child;
                                            return Container(
                                              height: 150,
                                              color: AppTheme.bg,
                                              child: const Center(child: CircularProgressIndicator()),
                                            );
                                          },
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                  // Tab 4: Belgeler
                  docs.isEmpty
                      ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                          const Icon(Icons.folder_open_outlined, size: 48, color: AppTheme.textSub),
                          const SizedBox(height: 12),
                          Text(tr('Belge yok'), style: const TextStyle(color: AppTheme.textSub, fontFamily: 'Inter')),
                        ]))
                      : ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: docs.length,
                          itemBuilder: (_, i) {
                            final d = docs[i];
                            return Card(
                              child: ListTile(
                                leading: const Icon(Icons.insert_drive_file_outlined, color: AppTheme.primary),
                                title: Text(d['title'] ?? '', style: const TextStyle(fontFamily: 'Inter')),
                                subtitle: Text(d['document_type'] ?? '', style: const TextStyle(fontFamily: 'Inter', fontSize: 12, color: AppTheme.textSub)),
                              ),
                            );
                          },
                        ),
                  // Tab 5: Durum Geçmişi
                  history.isEmpty
                      ? Center(child: Text(tr('Geçmiş yok'), style: const TextStyle(color: AppTheme.textSub, fontFamily: 'Inter')))
                      : ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: history.length,
                          itemBuilder: (_, i) {
                            final h = history[i];
                            final createdAt = h['created_at'] != null
                                ? DateTime.parse(h['created_at']).toLocal()
                                : null;
                            return ListTile(
                              leading: Container(
                                width: 8, height: 8,
                                decoration: BoxDecoration(color: AppTheme.statusColor(h['new_status'] ?? ''), shape: BoxShape.circle),
                              ),
                              title: Text(
                                '${AppTheme.statusLabel(h['old_status'] ?? '?')} → ${AppTheme.statusLabel(h['new_status'] ?? '')}',
                                style: const TextStyle(fontFamily: 'Inter', fontSize: 13),
                              ),
                              subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                if (h['note'] != null) Text(h['note'], style: const TextStyle(fontFamily: 'Inter', fontSize: 12, color: AppTheme.textSub)),
                                if (createdAt != null)
                                  Text('${createdAt.day}.${createdAt.month}.${createdAt.year}',
                                    style: const TextStyle(fontFamily: 'Inter', fontSize: 11, color: AppTheme.textSub)),
                              ]),
                            );
                          },
                        ),
                  // Tab 6: Formulare (Gebäude & GWS)
                  if (canSeeFormsAndPlanlama && isFormEnabled)
                    OrderFormulareTab(
                      orderId: widget.orderId,
                      orderCompanyId: (o['company'] as Map<String, dynamic>?)?['id'] as String?,
                      orderDepartmentId: o['department_id']?.toString(),
                      isForeman: isAssignedForeman,
                      supervisorIds: plans
                          .expand((p) {
                            final siteSupervisor = p['site_supervisor_id']?.toString() ?? '';
                            final personnel = (p['operation_plan_personnel'] as List? ?? [])
                                .where((pp) => pp['is_supervisor'] == true)
                                .map((pp) => (pp['user'] as Map?)?['id']?.toString() ?? '')
                                .where((id) => id.isNotEmpty).toList();
                            return [...personnel, siteSupervisor];
                          })
                          .where((id) => id.isNotEmpty)
                          .toList(),
                    ),
                  // v19.8.0: Gleisbausicherung Tabs
                  // Tab: SAKRA-Leitstand
                  if (isGleisbau && appState.canAccessGleisbauLeitstand)
                    isGleisbauOperativMitarbeiter
                        ? GleisbauMitarbeiterView(order: o)
                        : GleisbauSakraLeitstandScreen(order: o),
                  // Tab: Unterweisung
                  if (isGleisbau && appState.canDurchfuehrenUnterweisung)
                    GleisbauUnterweisungScreen(order: o),
                  // Tab: Ferngesprächsbuch
                  if (isGleisbau)
                    GleisbauFerngespraechScreen(order: o),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── GWS Tagesplanung Bölümü ──────────────────────────────────────────────────

class _GwsTagesplanSection extends StatelessWidget {
  final String orderId;
  final String? customerId;
  final String customerName;
  final List<Map<String, dynamic>> plans;
  final List<Map<String, dynamic>> objects;
  final String? departmentId;
  final bool isAssignedForeman;
  final VoidCallback onRefresh;

  const _GwsTagesplanSection({
    required this.orderId,
    required this.customerId,
    required this.customerName,
    required this.plans,
    required this.objects,
    required this.onRefresh,
    required this.isAssignedForeman,
    this.departmentId,
  });

  static const Color _color = AppTheme.gwsColor;

  String _planStatusLabel(String? s) {
    switch (s) {
      case 'draft': return 'Entwurf';
      case 'released': return 'Freigegeben';
      case 'in_progress': return 'In Bearbeitung';
      case 'completed': return 'Abgeschlossen';
      case 'in_bearbeitung': return 'In Bearbeitung';
      case 'vom_kunden_gemeldet': return 'Vom Kunden gemeldet';
      default: return s ?? 'Entwurf';
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _color.withOpacity(0.3)),
        boxShadow: [BoxShadow(color: _color.withOpacity(0.07), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(color: _color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: Icon(Icons.hotel, color: _color, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text('GWS Tagesplanung', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: _color, fontFamily: 'Inter')),
              ),
              if (appState.canPlanOperations)
                TextButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => GwsTagesplanScreen(
                      departmentId: departmentId,
                      initialOrderId: orderId,
                      objects: objects,
                  )),
                ).then((_) => onRefresh()),
                icon: Icon(Icons.add_circle_outline, color: _color, size: 16),
                label: Text('Neu', style: TextStyle(color: _color, fontFamily: 'Inter', fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (plans.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              alignment: Alignment.center,
              child: Column(
                children: [
                  Icon(Icons.event_note_outlined, size: 32, color: _color.withOpacity(0.3)),
                  const SizedBox(height: 6),
                  Text('Noch kein Tagesplan für diesen Auftrag', style: TextStyle(color: AppTheme.textSub, fontFamily: 'Inter', fontSize: 12)),
                ],
              ),
            )
          else
            ...plans.take(5).map((plan) => InkWell(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => GwsTagesplanScreen(
                  planId: plan['id'],
                  objects: objects,
                )),
              ).then((_) => onRefresh()),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: _color.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _color.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.calendar_today, size: 13, color: _color),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        plan['plan_date'] ?? '',
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, fontFamily: 'Inter'),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: _color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                      child: Text(
                        _planStatusLabel(plan['status']),
                        style: TextStyle(fontSize: 10, color: _color, fontWeight: FontWeight.w600, fontFamily: 'Inter'),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.chevron_right, color: _color.withOpacity(0.5), size: 16),
                  ],
                ),
              ),
            )),
          if (plans.length > 5)
            Center(
              child: TextButton(
                onPressed: () {},
                child: Text('+ ${plans.length - 5} weitere Tagespläne', style: TextStyle(color: _color, fontFamily: 'Inter', fontSize: 12)),
              ),
            ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _InfoCard(this.title, this.children);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, fontFamily: 'Inter')),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

Widget _InfoRow(String label, String? value, {bool isMasked = false, Widget? trailing}) {
  if (value == null || value.isEmpty) return const SizedBox.shrink();
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 4,
          child: Text(label, style: const TextStyle(color: AppTheme.textSub, fontSize: 13, fontFamily: 'Inter')),
        ),
        Expanded(
          flex: 6,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  isMasked ? '• • • • • •' : value,
                  style: TextStyle(
                    fontSize: 13,
                    fontFamily: 'Inter',
                    color: isMasked ? AppTheme.textSub : AppTheme.textMain,
                    fontStyle: isMasked ? FontStyle.italic : FontStyle.normal,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (trailing != null) trailing,
            ],
          ),
        ),
      ],
    ),
  );
}

class _ContactActions extends StatelessWidget {
  final String? phone;
  final String? email;
  const _ContactActions({this.phone, this.email});

  void _showPhoneOptions(BuildContext context, String p) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(
          leading: const Icon(Icons.phone, color: Colors.blue),
          title: const Text('Anrufen (Ara)'),
          onTap: () { Navigator.pop(ctx); launchUrl(Uri.parse('tel:$p')); },
        ),
        ListTile(
          leading: const Icon(Icons.message, color: Colors.green),
          title: const Text('WhatsApp Message'),
          onTap: () {
            Navigator.pop(ctx);
            final clean = p.replaceAll(RegExp(r'[^0-9+]'), '');
            final waUrl = "https://wa.me/${clean.startsWith('+') ? clean : '+$clean'}";
            launchUrl(Uri.parse(waUrl), mode: LaunchMode.externalApplication);
          },
        ),
      ])),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      if (phone != null && phone!.trim().isNotEmpty)
        IconButton(
          icon: const Icon(Icons.phone_android, size: 18, color: AppTheme.primary),
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          onPressed: () => _showPhoneOptions(context, phone!),
        ),
      if (email != null && email!.trim().isNotEmpty)
        IconButton(
          icon: const Icon(Icons.email_outlined, size: 18, color: Colors.blueGrey),
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          onPressed: () => launchUrl(Uri.parse('mailto:$email')),
        ),
    ]);
  }
}

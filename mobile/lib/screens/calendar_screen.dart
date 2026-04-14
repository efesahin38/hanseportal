import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import '../theme/web_utils.dart';
import '../providers/app_state.dart';
import '../services/localization_service.dart';

// ─── Renk sabitleri ───────────────────────────────────────────────────────────
const _kColorVertragsende  = Color(0xFFEF4444); // Kırmızı
const _kColorProbezeit     = Color(0xFFF97316); // Turuncu
const _kColorAusweis       = Color(0xFFEAB308); // Sarı
const _kColorVehicle       = Color(0xFFEC4899); // Pembe (TÜV/Servis/Reifen/FS)
const _kColorPlan          = Color(0xFF3B82F6); // Mavi (Operasyon)
const _kColorEvent         = Color(0xFF8B5CF6); // Mor (Manuel etkinlik)
const _kColorLeaveOther    = Color(0xFF06B6D4); // Turkuaz (başkasının izni)
const _kColorLeaveOwn      = Color(0xFF1D4ED8); // Koyu Mavi (kendi izni)
const _kColorReminder      = Color(0xFF14B8A6); // Teal (Hatırlatıcı)

Color _eventColor(String? type) {
  switch (type) {
    case 'vertragsende': return _kColorVertragsende;
    case 'probezeit':    return _kColorProbezeit;
    case 'ausweis_ablauf': return _kColorAusweis;
    case 'tuev':
    case 'reifen':
    case 'wartung':
    case 'fs_kontrolle': return _kColorVehicle;
    case 'plan':         return _kColorPlan;
    case 'leave_own':    return _kColorLeaveOwn;
    case 'leave_other':  return _kColorLeaveOther;
    case 'reminder':     return _kColorReminder;
    default:             return _kColorEvent;
  }
}

IconData _eventIcon(String? type) {
  switch (type) {
    case 'vertragsende': return Icons.gavel;
    case 'probezeit':    return Icons.timer_outlined;
    case 'ausweis_ablauf': return Icons.badge_outlined;
    case 'tuev':         return Icons.verified_outlined;
    case 'reifen':       return Icons.tire_repair;
    case 'wartung':      return Icons.build_outlined;
    case 'fs_kontrolle': return Icons.drive_eta_outlined;
    case 'plan':         return Icons.engineering;
    case 'leave_own':
    case 'leave_other':  return Icons.beach_access;
    case 'reminder':     return Icons.notifications_active;
    default:             return Icons.event;
  }
}

String _eventLabel(String? type) {
  switch (type) {
    case 'vertragsende': return 'Vertragsende';
    case 'probezeit':    return 'Probezeit';
    case 'ausweis_ablauf': return 'Ausweis-Ablauf';
    case 'tuev':         return 'TÜV-Termin';
    case 'reifen':       return 'Reifenwechsel';
    case 'wartung':      return 'Fahrzeug-Wartung';
    case 'fs_kontrolle': return 'FS-Kontrolle';
    case 'plan':         return 'Einsatzplan';
    case 'leave_own':    return 'Mein Urlaub';
    case 'leave_other':  return 'Urlaub';
    case 'reminder':     return 'Erinnerung (Privat)';
    default:             return 'Ereignis';
  }
}

// ─── Aktif filtre chip modeli ─────────────────────────────────────────────────
class _Filter {
  final String key, label;
  final Color color;
  bool active;
  _Filter(this.key, this.label, this.color, {this.active = true});
}

// ═════════════════════════════════════════════════════════════════════════════
class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});
  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  bool _loading = true;

  // Management Collaboration
  List<Map<String, dynamic>> _managementUsers = [];
  Map<String, dynamic>? _selectedUser;

  // Tüm veri listeleri
  List<Map<String, dynamic>> _events   = [];  // Manuel etkinlikler
  List<Map<String, dynamic>> _plans    = [];  // Operasyon planları
  List<Map<String, dynamic>> _leaves   = [];  // İzinler
  List<Map<String, dynamic>> _vehicle  = [];  // Araç tarihleri
  List<Map<String, dynamic>> _expiry   = [];  // Personel kritik tarihleri

  // Filtreler (GF/BL için)
  late List<_Filter> _filters;
  bool _filtersInitialized = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  bool get _isAdmin {
    final a = context.read<AppState>();
    return a.isGeschaeftsfuehrer || a.isBetriebsleiter || a.isSystemAdmin;
  }

  bool get _isBereichsleiter => context.read<AppState>().isBereichsleiter;
  bool get _isMitarbeiter {
    final a = context.read<AppState>();
    return a.isMitarbeiter || a.isVorarbeiter;
  }

  void _initFilters() {
    if (_filtersInitialized) return;
    _filtersInitialized = true;
    _filters = [
      if (_isAdmin || _isBereichsleiter) _Filter('plan', tr('Einsatzpläne'), _kColorPlan),
      if (_isAdmin || _isBereichsleiter || _isMitarbeiter) _Filter('event', tr('Ereignisse'), _kColorEvent),
      if (_isAdmin || _isBereichsleiter) _Filter('leave', tr('Urlaub'), _kColorLeaveOther),
      _Filter('reminder', tr('Erinnerungen'), _kColorReminder),
      if (_isAdmin || _isBereichsleiter) _Filter('vehicle', tr('Fahrzeuge'), _kColorVehicle),
      if (_isAdmin) _Filter('vertragsende', tr('Vertragsende'), _kColorVertragsende),
      if (_isAdmin) _Filter('probezeit', tr('Probezeit'), _kColorProbezeit),
      if (_isAdmin) _Filter('ausweis', tr('Ausweis-Ablauf'), _kColorAusweis),
    ];
  }

  Future<void> _load() async {
    _initFilters();
    final appState = context.read<AppState>();
    setState(() => _loading = true);

    // Initial load: Fetch management users if authorized (Excluding Bereichsleiter from switching)
    if (_managementUsers.isEmpty && (appState.isGeschaeftsfuehrer || appState.isBetriebsleiter || appState.isBackoffice || appState.isBuchhaltung || appState.isSystemAdmin)) {
      try {
        final users = await SupabaseService.getManagementUsers();
        _managementUsers = users;
        // Default to current user
        _selectedUser = _managementUsers.firstWhere((u) => u['id'] == appState.userId, orElse: () => _managementUsers.first);
      } catch (e) {
        debugPrint('[Calendar] Error fetching management users: $e');
      }
    }

    final from = DateTime(_focusedDay.year, _focusedDay.month, 1);
    final to   = DateTime(_focusedDay.year, _focusedDay.month + 1, 0);

    final targetUserId = _selectedUser?['id'] ?? appState.userId;
    final targetDeptId = _selectedUser?['department_id'] ?? appState.departmentId;
    final isTargetMitarbeiter = _selectedUser == null ? _isMitarbeiter : (_selectedUser?['role'] == 'mitarbeiter' || _selectedUser?['role'] == 'vorarbeiter');
    final isTargetAdmin = _selectedUser == null ? _isAdmin : (_selectedUser?['role'] == 'geschaeftsfuehrer' || _selectedUser?['role'] == 'betriebsleiter' || _selectedUser?['role'] == 'system_admin' || _selectedUser?['role'] == 'backoffice' || _selectedUser?['role'] == 'buchhaltung');
    final isTargetBL = _selectedUser == null ? _isBereichsleiter : (_selectedUser?['role'] == 'bereichsleiter');

    try {
      // 1. Manuel etkinlikler
      final events = await SupabaseService.getCalendarEventsEnhanced(
        from: from, to: to,
        targetUserId: targetUserId,
        targetDepartmentId: isTargetBL ? targetDeptId : null,
      );

      // 2. Operasyon planları
      List<Map<String, dynamic>> plans = [];
      if (!isTargetMitarbeiter || isTargetBL || isTargetAdmin) {
        plans = await SupabaseService.getOperationPlans(
          dateFrom: from, dateTo: to,
          departmentId: isTargetBL ? targetDeptId : null,
          userId: isTargetMitarbeiter ? targetUserId : null,
        );
      } else {
        // Mitarbeiter sadece kendi planlarını görür
        plans = await SupabaseService.getOperationPlans(
          dateFrom: from, dateTo: to,
          userId: targetUserId,
        );
      }

      // 3. İzinler (leave_requests)
      List<Map<String, dynamic>> leaves = [];
      try {
        leaves = await SupabaseService.getLeaveRequests(
          from: from, to: to,
          userId: isTargetMitarbeiter ? targetUserId : null,
          departmentId: isTargetBL ? targetDeptId : null,
        );
      } catch (_) {} // Tablo henüz yoksa sessizce geç

      // 4. Araç tarihleri (GF/BL/Bereichsleiter)
      List<Map<String, dynamic>> vehicle = [];
      if (isTargetAdmin || isTargetBL) {
        try {
          final deptName = isTargetBL
              ? (_selectedUser?['department']?['name'] as String?)
              : null;
          vehicle = await SupabaseService.getVehicleCalendarDates(
            from: from, to: to,
            department: deptName,
          );
        } catch (_) {}
      }

      // 5. Personel kritik tarihleri (sadece GF/BL)
      List<Map<String, dynamic>> expiry = [];
      if (isTargetAdmin) {
        try {
          expiry = await SupabaseService.getPersonnelExpiryDates(
            from: from, to: to,
            includeContractEnd: true,
            includeProbezeit: true,
            includeAusweis: true,
          );
        } catch (_) {}
      }

      if (mounted) {
        setState(() {
          _events  = events;
          _plans   = plans;
          _leaves  = leaves;
          _vehicle = vehicle;
          _expiry  = expiry;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ─── Bir güne ait tüm öğeleri topla ──────────────────────────────────────
  List<Map<String, dynamic>> _getItemsForDay(DateTime day) {
    final dateStr = '${day.year}-${day.month.toString().padLeft(2,'0')}-${day.day.toString().padLeft(2,'0')}';
    final appState = context.read<AppState>();
    final myId = appState.userId;

    final items = <Map<String, dynamic>>[];

    // Manuel etkinlikler ve Hatırlatıcılar
    if (_filterActive('event') || _filterActive('reminder')) {
      for (final e in _events) {
        if ((e['event_date'] ?? '').toString().startsWith(dateStr)) {
          final type = e['event_type'];
          final isPrivate = e['is_private'] == true;
          final createdBy = e['created_by'];
          
          // Gizli etkinlik sadece yaratıcısına görünür
          if (isPrivate && createdBy != myId) continue;

          if (type == 'reminder') {
            if (_filterActive('reminder') && createdBy == myId) {
              items.add({...e, '_type': 'reminder', '_color': _kColorReminder});
            }
          } else if (_filterActive('event')) {
            items.add({...e, '_type': 'event', '_color': _eventColor(type)});
          }
        }
      }
    }

    // Operasyon planları
    if (_filterActive('plan')) {
      for (final p in _plans) {
        if ((p['plan_date'] ?? '').toString().startsWith(dateStr)) {
          items.add({...p, '_type': 'plan', '_color': _kColorPlan});
        }
      }
    }

    // İzinler – çok günlü olabilir
    if (_filterActive('leave')) {
      for (final l in _leaves) {
        final sd = DateTime.tryParse(l['start_date'] ?? '');
        final ed = DateTime.tryParse(l['end_date'] ?? '');
        if (sd != null && ed != null) {
          final dayOnly = DateTime(day.year, day.month, day.day);
          final sdOnly  = DateTime(sd.year, sd.month, sd.day);
          final edOnly  = DateTime(ed.year, ed.month, ed.day);
          if (!dayOnly.isBefore(sdOnly) && !dayOnly.isAfter(edOnly)) {
            final isOwnLeave = l['user_id'] == myId;
            final empName = l['employee'] != null
                ? '${l['employee']['first_name'] ?? ''} ${l['employee']['last_name'] ?? ''}'.trim()
                : '';
            final type = isOwnLeave ? 'leave_own' : 'leave_other';
            final leaveTypeLabel = _leaveTypeLabel(l['leave_type']);
            items.add({
              ...l,
              '_type': type,
              '_color': isOwnLeave ? _kColorLeaveOwn : _kColorLeaveOther,
              'title': isOwnLeave ? 'Mein Urlaub ($leaveTypeLabel)' : '$empName – $leaveTypeLabel',
              'description': l['note'],
            });
          }
        }
      }
    }

    // Araç tarihleri
    if (_filterActive('vehicle')) {
      for (final v in _vehicle) {
        if ((v['date'] ?? '').toString().startsWith(dateStr)) {
          items.add({...v, '_color': _kColorVehicle});
        }
      }
    }

    // Personel kritik tarihleri
    for (final e in _expiry) {
      if ((e['event_date'] ?? '').toString().startsWith(dateStr)) {
        final type = e['event_type'];
        if (type == 'vertragsende' && !_filterActive('vertragsende')) continue;
        if (type == 'probezeit' && !_filterActive('probezeit')) continue;
        if (type == 'ausweis_ablauf' && !_filterActive('ausweis')) continue;
        items.add({...e, '_color': _eventColor(type)});
      }
    }

    return items;
  }

  String _leaveTypeLabel(String? type) {
    switch (type) {
      case 'krank': return 'Krankheit';
      case 'sonderurlaub': return 'Sonderurlaub';
      default: return 'Urlaub';
    }
  }

  bool _filterActive(String key) {
    if (_filters.isEmpty) return true;
    final f = _filters.where((f) => f.key == key);
    return f.isEmpty || f.first.active;
  }

  // ─── Bir günde gösterilecek renk bar'ları ve Çan (Bell) işareti ────────────────────────
  List<Color> _getDayColors(DateTime day) {
    final items = _getItemsForDay(day);
    final colors = <Color>{};
    for (final i in items) {
      if (i['_type'] == 'reminder') continue; // Hatırlatıcıları alt noktada değil de ikon olarak göstermek isteyebiliriz
      final c = i['_color'];
      if (c is Color) colors.add(c);
    }
    return colors.take(4).toList(); // Max 4 renk
  }

  bool _hasReminderForDay(DateTime day) {
    return _getItemsForDay(day).any((i) => i['_type'] == 'reminder');
  }

  bool _hasItems(DateTime day) => _getItemsForDay(day).isNotEmpty;

  // ─── Mini Dashboard istatistikleri ──────────────────────────────────────
  Map<String, int> _getMiniStats() {
    final now = DateTime.now();
    final today = '${now.year}-${now.month.toString().padLeft(2,'0')}-${now.day.toString().padLeft(2,'0')}';
    return {
      'plans': _plans.where((p) => (p['plan_date'] ?? '').toString().startsWith(today)).length,
      'vertragsende': _expiry.where((e) => e['event_type'] == 'vertragsende').length,
      'vehicle': _vehicle.length,
      'leaves': _leaves.length,
    };
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    _initFilters();
    final selectedItems = _getItemsForDay(_selectedDay);

    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        toolbarHeight: kIsWeb ? 80 : 120,
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
          decoration: AppTheme.gradientBox(),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left, color: Colors.white),
                    onPressed: () {
                      setState(() {
                        _focusedDay = DateTime(_focusedDay.year, _focusedDay.month - 1);
                        _selectedDay = DateTime(_focusedDay.year, _focusedDay.month, 1);
                      });
                      _load();
                    },
                  ),
                  Expanded(
                    child: _managementUsers.isEmpty 
                      ? Text(
                          _monthLabel(_focusedDay),
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white, fontSize: kIsWeb ? 20 : 18, fontWeight: FontWeight.bold, fontFamily: 'Inter'),
                        )
                      : Container(
                          height: 36,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<Map<String, dynamic>>(
                              value: _selectedUser,
                              isExpanded: true,
                              dropdownColor: AppTheme.primary,
                              icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
                              onChanged: (Map<String, dynamic>? newValue) {
                                if (newValue != null) {
                                  setState(() => _selectedUser = newValue);
                                  _load();
                                }
                              },
                              items: _managementUsers.map<DropdownMenuItem<Map<String, dynamic>>>((u) {
                                return DropdownMenuItem<Map<String, dynamic>>(
                                  value: u,
                                  child: Text(
                                    '${AppTheme.roleLabel(u['role'] ?? '')}: ${u['first_name']} ${u['last_name']} (${_monthLabel(_focusedDay)})',
                                    style: const TextStyle(color: Colors.white, fontSize: 13),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right, color: Colors.white),
                    onPressed: () {
                      setState(() {
                        _focusedDay = DateTime(_focusedDay.year, _focusedDay.month + 1);
                        _selectedDay = DateTime(_focusedDay.year, _focusedDay.month, 1);
                      });
                      _load();
                    },
                  ),
                ],
              ),
              if (!kIsWeb) ...[
                const SizedBox(height: 8),
                Row(
                  children: [tr('Pzt'), tr('Sal'), tr('Çar'), tr('Per'), tr('Cum'), tr('Cmt'), tr('Paz')]
                      .map((d) => Expanded(child: Text(d, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 12, fontFamily: 'Inter'))))
                      .toList(),
                ),
              ],
            ],
          ),
        ),
      ),
      body: Column(
        children: [
          // ── Mini Dashboard (sadece GF/BL) ──
          if (_isAdmin) _buildMiniDashboard(),

          // ── Filter chips ──
          if (_filters.isNotEmpty) _buildFilterChips(),

          // ── Takvim Grid + Detay ──
          Expanded(
            child: LayoutBuilder(builder: (context, constraints) {
              final isWide = constraints.maxWidth > 800;
              if (isWide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 460,
                      child: Column(children: [
                        _buildWebDayHeaders(),
                        _buildCalendarGrid(),
                        const Spacer(),
                      ]),
                    ),
                    const VerticalDivider(width: 1),
                    Expanded(
                      child: Column(children: [
                        _buildSelectedDayHeader(selectedItems),
                        Expanded(child: _buildEventList(selectedItems)),
                      ]),
                    ),
                  ],
                );
              }
              return Column(children: [
                _buildCalendarGrid(),
                const SizedBox(height: 4),
                _buildSelectedDayHeader(selectedItems),
                Expanded(child: _buildEventList(selectedItems)),
              ]);
            }),
          ),
        ],
      ),
      // FABs (GF, BL, SysAdmin)
      floatingActionButton: _isAdmin
          ? Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                FloatingActionButton.extended(
                  heroTag: 'fabReminder',
                  onPressed: () => _showAddEventDialog(appState, defaultType: 'reminder'),
                  backgroundColor: _kColorReminder,
                  icon: const Icon(Icons.notifications_active, color: Colors.white),
                  label: const Text('Erinnerung', style: TextStyle(color: Colors.white, fontFamily: 'Inter')),
                ),
                const SizedBox(height: 12),
                FloatingActionButton.extended(
                  heroTag: 'fabEvent',
                  onPressed: () => _showAddEventDialog(appState, defaultType: 'general'),
                  backgroundColor: AppTheme.primary,
                  icon: const Icon(Icons.add, color: Colors.white),
                  label: const Text('Ereignis hinzufügen', style: TextStyle(color: Colors.white, fontFamily: 'Inter')),
                ),
              ],
            )
          : null,
    );
  }

  // ─── Mini Dashboard ───────────────────────────────────────────────────────
  Widget _buildMiniDashboard() {
    final stats = _getMiniStats();
    final items = [
      {'label': tr('Heute aktiv'), 'value': stats['plans'].toString(), 'icon': Icons.engineering, 'color': _kColorPlan},
      {'label': tr('Vertragsende'), 'value': stats['vertragsende'].toString(), 'icon': Icons.gavel, 'color': _kColorVertragsende},
      {'label': tr('Fahrzeug-Termine'), 'value': stats['vehicle'].toString(), 'icon': Icons.directions_car, 'color': _kColorVehicle},
      {'label': tr('Urlaubstage'), 'value': stats['leaves'].toString(), 'icon': Icons.beach_access, 'color': _kColorLeaveOther},
    ];
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Row(
        children: items.map((item) {
          final color = item['color'] as Color;
          return Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
              decoration: BoxDecoration(
                color: color.withOpacity(0.06),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: color.withOpacity(0.15)),
              ),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(item['icon'] as IconData, color: color, size: 18),
                const SizedBox(height: 2),
                Text(item['value'] as String, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: color, fontFamily: 'Inter')),
                Text(item['label'] as String, style: const TextStyle(fontSize: 9, color: AppTheme.textSub, fontFamily: 'Inter'), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
              ]),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ─── Filter chips ─────────────────────────────────────────────────────────
  Widget _buildFilterChips() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: _filters.map((f) {
            return Padding(
              padding: const EdgeInsets.only(right: 6),
              child: FilterChip(
                label: Text(f.label, style: TextStyle(fontSize: 11, color: f.active ? Colors.white : AppTheme.textSub, fontFamily: 'Inter')),
                selected: f.active,
                selectedColor: f.color,
                backgroundColor: AppTheme.bg,
                checkmarkColor: Colors.white,
                side: BorderSide(color: f.color.withOpacity(0.4)),
                onSelected: (v) => setState(() { f.active = v; }),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  // ─── Gün başlıkları (web) ─────────────────────────────────────────────────
  Widget _buildWebDayHeaders() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [tr('Pzt'), tr('Sal'), tr('Çar'), tr('Per'), tr('Cum'), tr('Cmt'), tr('Paz')]
            .map((d) => Expanded(child: Text(d, textAlign: TextAlign.center, style: const TextStyle(color: AppTheme.textSub, fontSize: 13, fontWeight: FontWeight.bold, fontFamily: 'Inter'))))
            .toList(),
      ),
    );
  }

  // ─── Takvim Grid ─────────────────────────────────────────────────────────
  Widget _buildCalendarGrid() {
    final firstDay = DateTime(_focusedDay.year, _focusedDay.month, 1);
    final daysInMonth = DateTime(_focusedDay.year, _focusedDay.month + 1, 0).day;
    final startOffset = firstDay.weekday - 1;
    final totalCells = startOffset + daysInMonth;
    final rows = (totalCells / 7).ceil();

    return Container(
      color: Colors.white,
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 7,
          childAspectRatio: 1,
          mainAxisSpacing: 2,
          crossAxisSpacing: 2,
        ),
        itemCount: rows * 7,
        itemBuilder: (_, index) {
          final dayNum = index - startOffset + 1;
          if (dayNum < 1 || dayNum > daysInMonth) return const SizedBox.shrink();
          final day = DateTime(_focusedDay.year, _focusedDay.month, dayNum);
          final isSelected = _isSameDay(day, _selectedDay);
          final isToday = _isSameDay(day, DateTime.now());
          final dayColors = _getDayColors(day);
          final hasReminder = _hasReminderForDay(day);

          return InkWell(
            onTap: () => setState(() => _selectedDay = day),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              margin: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: isSelected ? AppTheme.primary : isToday ? AppTheme.primary.withOpacity(0.08) : null,
                borderRadius: BorderRadius.circular(10),
                border: isToday && !isSelected ? Border.all(color: AppTheme.primary.withOpacity(0.4)) : null,
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '$dayNum',
                        style: TextStyle(
                          fontSize: kIsWeb ? 14 : 13,
                          fontWeight: isToday || isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected ? Colors.white : isToday ? AppTheme.primary : AppTheme.textMain,
                          fontFamily: 'Inter',
                        ),
                      ),
                      if (dayColors.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: dayColors.map((c) => Container(
                            width: 5, height: 5,
                            margin: const EdgeInsets.symmetric(horizontal: 1),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isSelected ? Colors.white.withOpacity(0.85) : c,
                            ),
                          )).toList(),
                        ),
                      ],
                    ],
                  ),
                  if (hasReminder)
                    Positioned(
                      top: 2, right: 4,
                      child: Icon(Icons.notifications_active, size: 10, color: isSelected ? Colors.white : _kColorReminder),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ─── Seçili gün başlığı ───────────────────────────────────────────────────
  Widget _buildSelectedDayHeader(List<Map<String, dynamic>> items) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
      child: Row(
        children: [
          Text(_dayLabel(_selectedDay), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, fontFamily: 'Inter')),
          if (items.isNotEmpty) ...[
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
              decoration: BoxDecoration(color: AppTheme.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
              child: Text('${items.length}', style: const TextStyle(fontSize: 12, color: AppTheme.primary, fontWeight: FontWeight.bold)),
            ),
          ],
        ],
      ),
    );
  }

  // ─── Etkinlik listesi ─────────────────────────────────────────────────────
  Widget _buildEventList(List<Map<String, dynamic>> items) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (items.isEmpty) {
      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.event_busy_outlined, size: 64, color: AppTheme.textSub.withOpacity(0.2)),
        const SizedBox(height: 16),
        Text(tr('Kein Eintrag für diesen Tag'), style: const TextStyle(color: AppTheme.textSub, fontSize: 15, fontFamily: 'Inter')),
      ]));
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 80),
      itemCount: items.length,
      itemBuilder: (_, i) => _CalendarItemCard(item: items[i]),
    );
  }

  // ─── Etkinlik ekleme diyaloğu ─────────────────────────────────────────────
  Future<void> _showAddEventDialog(AppState appState, {String defaultType = 'general'}) async {
    final titleCtrl = TextEditingController();
    final descCtrl  = TextEditingController();
    DateTime selectedDate = _selectedDay;
    String eventType = defaultType;
    String targetMode = eventType == 'reminder' ? 'person' : 'all'; // 'all' | 'dept' | 'person'
    bool isPrivate = (eventType == 'reminder');
    String? selectedDeptId;
    String? selectedUserId = eventType == 'reminder' ? appState.userId : null;
    String? selectedUserName;

    // Departman + Personel listelerini yükle
    final depts = await SupabaseService.getDepartments();
    final users = await SupabaseService.getUsers(status: 'active');

    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, ss) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(children: [
            const Icon(Icons.add_circle_outline, color: AppTheme.primary),
            const SizedBox(width: 8),
            Text(tr('Neue Veranstaltung'), style: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold, fontSize: 18)),
          ]),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                // Başlık
                TextField(
                  controller: titleCtrl,
                  decoration: InputDecoration(labelText: '${tr('Başlık')} *', border: const OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                // Açıklama
                TextField(
                  controller: descCtrl,
                  maxLines: 2,
                  decoration: InputDecoration(labelText: tr('Beschreibung'), border: const OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                // Etkinlik tipi
                DropdownButtonFormField<String>(
                  value: eventType,
                  decoration: InputDecoration(labelText: tr('Typ'), border: const OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: 'general', child: Text('📋 Allgemein')),
                    DropdownMenuItem(value: 'meeting', child: Text('🤝 Besprechung')),
                    DropdownMenuItem(value: 'task', child: Text('📌 Aufgabe')),
                    DropdownMenuItem(value: 'reminder', child: Text('🔔 Erinnerung (Privat)')),
                  ],
                  onChanged: (v) {
                    ss(() {
                      eventType = v!;
                      if (eventType == 'reminder') {
                        targetMode = 'person';
                        selectedUserId = appState.userId;
                      }
                    });
                  },
                ),
                const SizedBox(height: 12),
                // Tarih
                InkWell(
                  onTap: () async {
                    final d = await showDatePicker(
                      context: ctx,
                      initialDate: selectedDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030),
                    );
                    if (d != null) ss(() => selectedDate = d);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                    decoration: BoxDecoration(border: Border.all(color: AppTheme.border), borderRadius: BorderRadius.circular(8)),
                    child: Row(children: [
                      const Icon(Icons.calendar_today, size: 18, color: AppTheme.textSub),
                      const SizedBox(width: 8),
                      Text('${selectedDate.day.toString().padLeft(2,'0')}.${selectedDate.month.toString().padLeft(2,'0')}.${selectedDate.year}', style: const TextStyle(fontFamily: 'Inter')),
                    ]),
                  ),
                ),
                // Hedef seçimi (Hatırlatıcı ise gizle)
                if (eventType != 'reminder') ...[
                  Text(tr('Empfänger'), style: const TextStyle(fontSize: 12, color: AppTheme.textSub, fontFamily: 'Inter', fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Wrap(spacing: 8, children: [
                    ChoiceChip(label: Text(tr('Alle')), selected: targetMode=='all', onSelected: (_) => ss(() => targetMode='all'), selectedColor: AppTheme.primary, labelStyle: TextStyle(color: targetMode=='all' ? Colors.white : null)),
                    ChoiceChip(label: Text(tr('Abteilung')), selected: targetMode=='dept', onSelected: (_) => ss(() => targetMode='dept'), selectedColor: AppTheme.primary, labelStyle: TextStyle(color: targetMode=='dept' ? Colors.white : null)),
                    ChoiceChip(label: Text(tr('Person')), selected: targetMode=='person', onSelected: (_) => ss(() => targetMode='person'), selectedColor: AppTheme.primary, labelStyle: TextStyle(color: targetMode=='person' ? Colors.white : null)),
                  ]),
                  if (targetMode == 'dept') ...[
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      value: selectedDeptId,
                      decoration: InputDecoration(labelText: tr('Abteilung auswählen'), border: const OutlineInputBorder()),
                      items: depts.map((d) => DropdownMenuItem(value: d['id'].toString(), child: Text(d['name'] ?? ''))).toList(),
                      onChanged: (v) => ss(() => selectedDeptId = v),
                    ),
                  ],
                  if (targetMode == 'person') ...[
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      value: selectedUserId,
                      decoration: InputDecoration(labelText: tr('Person auswählen'), border: const OutlineInputBorder()),
                      items: users.map((u) {
                        final name = '${u['first_name']} ${u['last_name']}';
                        return DropdownMenuItem(value: u['id'].toString(), child: Text(name));
                      }).toList(),
                      onChanged: (v) {
                        ss(() {
                          selectedUserId = v;
                          final u = users.firstWhere((u) => u['id'].toString() == v, orElse: () => {});
                          selectedUserName = u.isNotEmpty ? '${u['first_name']} ${u['last_name']}' : null;
                        });
                      },
                    ),
                  ],
                ],
                const SizedBox(height: 16),
                CheckboxListTile(
                  title: Text(tr('Privater Termin')),
                  subtitle: Text(tr('Nur Sie können diesen Termin sehen')),
                  value: isPrivate,
                  activeColor: AppTheme.primary,
                  onChanged: (v) => ss(() => isPrivate = v ?? false),
                  contentPadding: EdgeInsets.zero,
                ),
              ]),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(tr('Abbrechen'))),
            ElevatedButton.icon(
              icon: const Icon(Icons.check, size: 18),
              label: Text(tr('Speichern')),
              onPressed: () async {
                if (titleCtrl.text.trim().isEmpty) return;
                final dateStr = '${selectedDate.year}-${selectedDate.month.toString().padLeft(2,'0')}-${selectedDate.day.toString().padLeft(2,'0')}';

                await SupabaseService.createCalendarEvent({
                  'title': titleCtrl.text.trim(),
                  'description': descCtrl.text.trim().isNotEmpty ? descCtrl.text.trim() : null,
                  'event_date': dateStr,
                  'event_type': eventType,
                  'created_by': appState.userId,
                  'target_user_id': targetMode == 'person' ? selectedUserId : null,
                  'target_department_id': targetMode == 'dept' ? selectedDeptId : null,
                  'is_system_generated': false,
                  'is_private': isPrivate,
                });

                // Bildirimler
                final senderName = appState.fullName;
                if (eventType == 'reminder') {
                  // Erinnerung (Privat)
                  await SupabaseService.sendCalendarNotification(
                    recipientId: appState.userId,
                    senderName: 'Sistem',
                    eventTitle: 'Erinnerung: ${titleCtrl.text.trim()}',
                    eventDate: dateStr,
                    sentBy: appState.userId,
                  );
                } else if (targetMode == 'person' && selectedUserId != null) {
                  await SupabaseService.sendCalendarNotification(
                    recipientId: selectedUserId!,
                    senderName: senderName,
                    eventTitle: titleCtrl.text.trim(),
                    eventDate: dateStr,
                    sentBy: appState.userId,
                  );
                } else if (targetMode == 'dept' && selectedDeptId != null) {
                  await SupabaseService.sendCalendarNotificationToDepartment(
                    departmentId: selectedDeptId!,
                    senderName: senderName,
                    eventTitle: titleCtrl.text.trim(),
                    eventDate: dateStr,
                    sentBy: appState.userId,
                  );
                } else if (targetMode == 'all') {
                  await SupabaseService.sendCalendarNotificationToAll(
                    senderName: senderName,
                    eventTitle: titleCtrl.text.trim(),
                    eventDate: dateStr,
                    sentBy: appState.userId,
                  );
                }

                if (ctx.mounted) Navigator.pop(ctx);
                _load();
              },
            ),
          ],
        ),
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

  String _monthLabel(DateTime d) {
    const months = ['Januar','Februar','März','April','Mai','Juni','Juli','August','September','Oktober','November','Dezember'];
    return '${months[d.month - 1]} ${d.year}';
  }

  String _dayLabel(DateTime d) {
    const days = ['', 'Montag','Dienstag','Mittwoch','Donnerstag','Freitag','Samstag','Sonntag'];
    const months = ['','Jan','Feb','Mär','Apr','Mai','Jun','Jul','Aug','Sep','Okt','Nov','Dez'];
    return '${days[d.weekday]}, ${d.day} ${months[d.month]}';
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Etkinlik Kartı
// ═════════════════════════════════════════════════════════════════════════════
class _CalendarItemCard extends StatelessWidget {
  final Map<String, dynamic> item;
  const _CalendarItemCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final type  = item['event_type'] ?? item['_type'] ?? 'general';
    final color = (item['_color'] is Color) ? item['_color'] as Color : _eventColor(type.toString());
    final icon  = _eventIcon(type.toString());
    final label = _eventLabel(type.toString());
    final title = item['title'] ?? label;
    String subtitle = '';

    if (item['_type'] == 'plan') {
      final start = item['start_time'] ?? '';
      final end   = item['end_time'] ?? '';
      final cust  = item['order']?['customer']?['name'] ?? '';
      final deptName = item['order']?['department']?['name'] ?? '';
      
      final personnelList = item['operation_plan_personnel'] as List?;
      final workers = personnelList?.map((p) => '${p['users']?['first_name'] ?? ''} ${p['users']?['last_name'] ?? ''}').where((s) => s.trim().isNotEmpty).join(', ') ?? '';

      final lines = <String>[];
      if (start.isNotEmpty && end.isNotEmpty) lines.add('${tr('Zeit')}: $start – $end');
      if (deptName.isNotEmpty) lines.add('${tr('Abteilung')}: $deptName');
      if (cust.isNotEmpty) lines.add('${tr('Kunde')}: $cust');
      if (workers.isNotEmpty) lines.add('${tr('Team')}: $workers');
      
      subtitle = lines.join(' | ');
    } else if (item['_type'] == 'vehicle') {
      subtitle = item['department'] ?? '';
    } else if (type == 'leave_own' || type == 'leave_other') {
      final s = _fmtDate(item['start_date']);
      final e = _fmtDate(item['end_date']);
      subtitle = '$s – $e';
      if (item['note'] != null && (item['note'] as String).isNotEmpty) {
        subtitle += '\n${item['note']}';
      }
    } else {
      subtitle = item['description'] ?? '';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 1,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _showDetail(context, title, subtitle, label, color, icon),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, fontFamily: 'Inter')),
                  if (subtitle.isNotEmpty)
                    Text(subtitle, style: const TextStyle(fontSize: 11, color: AppTheme.textSub, fontFamily: 'Inter'), maxLines: 2, overflow: TextOverflow.ellipsis),
                ]),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600, fontFamily: 'Inter')),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _fmtDate(String? s) {
    if (s == null) return '-';
    final d = DateTime.tryParse(s);
    return d == null ? s : '${d.day.toString().padLeft(2,'0')}.${d.month.toString().padLeft(2,'0')}.${d.year}';
  }

  void _showDetail(BuildContext context, String title, String subtitle, String label, Color color, IconData icon) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 32),
          ),
          const SizedBox(height: 16),
          Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.bold, fontFamily: 'Inter')),
          const SizedBox(height: 4),
          Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, fontFamily: 'Inter'), textAlign: TextAlign.center),
          if (subtitle.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(subtitle, style: const TextStyle(fontSize: 13, color: AppTheme.textSub, fontFamily: 'Inter'), textAlign: TextAlign.center),
          ],
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
        ],
      ),
    );
  }
}

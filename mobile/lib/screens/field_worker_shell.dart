import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../providers/app_state.dart';
import '../services/localization_service.dart';
import 'field_my_tasks_screen.dart';
import 'notifications_screen.dart';
import 'my_documents_screen.dart';
import 'chat_screen.dart';
import 'calendar_screen.dart';
import 'personnel_detail_dashboard.dart';
import 'field_dashboard_screen.dart';
import 'work_session_approval_screen.dart';
import 'order_calendar_screen.dart';
import 'gws_operative_view_screen.dart';
import 'gws_tagesplan_screen.dart';
import '../services/supabase_service.dart';


/// Mitarbeiter ve Vorarbeiter için sade mobil saha ekranı.
class FieldWorkerShell extends StatefulWidget {
  const FieldWorkerShell({super.key});

  @override
  State<FieldWorkerShell> createState() => _FieldWorkerShellState();
}

class _FieldWorkerShellState extends State<FieldWorkerShell> {
  int _selectedIndex = 0;
  List<Map<String, dynamic>> _leaderPlans = [];

  @override
  void initState() {
    super.initState();
    _checkLeaderStatus();
  }

  Future<void> _checkLeaderStatus() async {
    final appState = context.read<AppState>();
    try {
      final plans = await SupabaseService.getGwsPlansForLeader(appState.userId);
      if (mounted) setState(() { _leaderPlans = plans; });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();

    // Building the items list dynamically based on user role
    final List<Map<String, dynamic>> items = [
      {
        'title': tr('Statistik'),
        'icon': Icons.dashboard,
        'iconOut': Icons.dashboard_outlined,
        'screen': const FieldDashboardScreen(),
      },
      if (appState.isBereichsleiter)
        {
          'title': tr('Genehmigungen'),
          'icon': Icons.fact_check,
          'iconOut': Icons.fact_check_outlined,
          'screen': const WorkSessionApprovalScreen(),
        },
      if (appState.isBereichsleiter)
        {
          'title': tr('Auftragskalender'),
          'icon': Icons.event_note,
          'iconOut': Icons.event_note_outlined,
          'screen': const OrderCalendarScreen(),
        },
      {
        'title': tr('Meine Aufgaben'),
        'icon': Icons.task,
        'iconOut': Icons.task_outlined,
        'screen': const FieldMyTasksScreen(),
      },
      if (appState.serviceAreaIds.any((id) => id.toString().toLowerCase().contains('gast')) || appState.departmentId?.toLowerCase().contains('gast') == true)
        {
          'title': 'GWS Zimmerliste',
          'icon': Icons.bed,
          'iconOut': Icons.bed_outlined,
          'screen': const GwsOperativeViewScreen(),
        },
      if (_leaderPlans.isNotEmpty) ...[
        ..._leaderPlans.map((p) => {
          'title': '${p['object']?['name'] ?? 'GWS'} (Lider)',
          'icon': Icons.stars,
          'iconOut': Icons.stars_outlined,
          'screen': GwsTagesplanScreen(departmentId: 'GWS', objects: [Map<String, dynamic>.from(p['object'] ?? {})]),
        }),
      ],
      {
        'title': tr('Kalender'),
        'icon': Icons.calendar_month,
        'iconOut': Icons.calendar_month_outlined,
        'screen': const CalendarScreen(),
      },
      {
        'title': tr('Meine Dokumente'),
        'icon': Icons.folder_shared,
        'iconOut': Icons.folder_shared_outlined,
        'screen': const MyDocumentsScreen(),
      },
      {
        'title': tr('Benachrichtigungen'),
        'icon': Icons.notifications,
        'iconOut': Icons.notifications_outlined,
        'screen': const NotificationsScreen(),
      },
      {
        'title': tr('Chatten'),
        'icon': Icons.chat,
        'iconOut': Icons.chat_outlined,
        'screen': const ChatScreen(),
      },
      {
        'title': tr('Mein Profil'),
        'icon': Icons.account_circle,
        'iconOut': Icons.account_circle_outlined,
        'screen': PersonnelDetailDashboard(user: appState.currentUser!),
      },
    ];

    // Safety check for index overflow after role-based filtering
    if (_selectedIndex >= items.length) _selectedIndex = 0;

    return Scaffold(
      appBar: AppBar(
        title: Text(items[_selectedIndex]['title']),
        actions: [
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined),
                onPressed: () {
                  // Find index of Notifications screen
                  final idx = items.indexWhere((it) => it['screen'] is NotificationsScreen);
                  if (idx != -1) setState(() => _selectedIndex = idx);
                },
              ),
              if (appState.unreadNotifications > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(color: AppTheme.error, shape: BoxShape.circle),
                    constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                    child: Text(
                      '${appState.unreadNotifications}',
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      drawer: Drawer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppTheme.primary, AppTheme.secondary],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          color: Colors.white,
                          padding: const EdgeInsets.all(2),
                          child: Image.asset('assets/icon/hanse.png', width: 44, height: 44, fit: BoxFit.cover),
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Hanse Kollektiv',
                          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Inter'),
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Text(appState.fullName, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'Inter'), maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text(AppTheme.roleLabel(appState.role), style: const TextStyle(color: Colors.white70, fontSize: 13, fontFamily: 'Inter')),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: EdgeInsets.zero,
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final it = items[index];
                  final isSelected = _selectedIndex == index;
                  return ListTile(
                    leading: Icon(
                      isSelected ? it['icon'] : it['iconOut'],
                      color: isSelected ? AppTheme.primary : AppTheme.textSub,
                    ),
                    title: Text(
                      it['title'],
                      style: TextStyle(
                        color: isSelected ? AppTheme.primary : AppTheme.textMain,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                        fontFamily: 'Inter',
                      ),
                    ),
                    selected: isSelected,
                    selectedTileColor: AppTheme.primary.withOpacity(0.1),
                    onTap: () {
                      setState(() => _selectedIndex = index);
                      Navigator.pop(context);
                    },
                  );
                },
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.logout, color: AppTheme.error),
              title: Text(tr('Abmelden'), style: const TextStyle(color: AppTheme.error, fontWeight: FontWeight.w600, fontFamily: 'Inter')),
              onTap: () async {
                Navigator.pop(context);
                await context.read<AppState>().signOut();
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
      body: items[_selectedIndex]['screen'],
    );
  }
}

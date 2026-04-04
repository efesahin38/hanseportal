import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../providers/app_state.dart';
import '../services/localization_service.dart';
import 'field_my_tasks_screen.dart';
import 'notifications_screen.dart';
import 'my_documents_screen.dart';

/// Mitarbeiter ve Vorarbeiter için sade mobil saha ekranı.
class FieldWorkerShell extends StatefulWidget {
  const FieldWorkerShell({super.key});

  @override
  State<FieldWorkerShell> createState() => _FieldWorkerShellState();
}

class _FieldWorkerShellState extends State<FieldWorkerShell> {
  int _selectedIndex = 0;

  final _screens = const [
    FieldMyTasksScreen(),
    MyDocumentsScreen(),
    NotificationsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final titles = [
      tr('Meine Aufgaben'),
      tr('Meine Dokumente'),
      tr('Benachrichtigungen'),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(titles[_selectedIndex]),
        actions: [
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined),
                onPressed: () => setState(() => _selectedIndex = 2),
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
            ListTile(
              leading: Icon(_selectedIndex == 0 ? Icons.task : Icons.task_outlined, color: _selectedIndex == 0 ? AppTheme.primary : AppTheme.textSub),
              title: Text(tr('Meine Aufgaben'), style: TextStyle(color: _selectedIndex == 0 ? AppTheme.primary : AppTheme.textMain, fontWeight: _selectedIndex == 0 ? FontWeight.w600 : FontWeight.normal, fontFamily: 'Inter')),
              selected: _selectedIndex == 0,
              selectedTileColor: AppTheme.primary.withOpacity(0.1),
              onTap: () {
                setState(() => _selectedIndex = 0);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: Icon(_selectedIndex == 1 ? Icons.folder_shared : Icons.folder_shared_outlined, color: _selectedIndex == 1 ? AppTheme.primary : AppTheme.textSub),
              title: Text(tr('Meine Dokumente'), style: TextStyle(color: _selectedIndex == 1 ? AppTheme.primary : AppTheme.textMain, fontWeight: _selectedIndex == 1 ? FontWeight.w600 : FontWeight.normal, fontFamily: 'Inter')),
              selected: _selectedIndex == 1,
              selectedTileColor: AppTheme.primary.withOpacity(0.1),
              onTap: () {
                setState(() => _selectedIndex = 1);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: Icon(_selectedIndex == 2 ? Icons.notifications : Icons.notifications_outlined, color: _selectedIndex == 2 ? AppTheme.primary : AppTheme.textSub),
              title: Text(tr('Benachrichtigungen'), style: TextStyle(color: _selectedIndex == 2 ? AppTheme.primary : AppTheme.textMain, fontWeight: _selectedIndex == 2 ? FontWeight.w600 : FontWeight.normal, fontFamily: 'Inter')),
              selected: _selectedIndex == 2,
              selectedTileColor: AppTheme.primary.withOpacity(0.1),
              onTap: () {
                setState(() => _selectedIndex = 2);
                Navigator.pop(context);
              },
            ),
            const Spacer(),
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
      body: _screens[_selectedIndex],
    );
  }
}

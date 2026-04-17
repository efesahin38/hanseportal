import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../theme/web_utils.dart';
import '../providers/app_state.dart';
import '../services/localization_service.dart';
import 'external_manager_auftraege_screen.dart';
import 'personnel_detail_dashboard.dart';
import 'chat_screen.dart';
import 'notifications_screen.dart';

/// Externer Manager'ların ana kabuk ekranı.
/// Sadece: Aufträge (kendi muhattabı olduğu) | Chat | Mein Profil
class ExternalManagerShell extends StatefulWidget {
  const ExternalManagerShell({super.key});
  @override
  State<ExternalManagerShell> createState() => _ExternalManagerShellState();
}

class _ExternalManagerShellState extends State<ExternalManagerShell> {
  int _selectedIndex = 0;

  static const Color _color = AppTheme.gwsColor;

  List<_NavItem> _buildNavItems(AppState appState) {
    return [
      _NavItem(
        icon: Icons.assignment_outlined,
        activeIcon: Icons.assignment,
        label: 'Meine Aufträge',
        screen: const ExternalManagerAuftraegeScreen(),
      ),
      _NavItem(
        icon: Icons.chat_outlined,
        activeIcon: Icons.chat,
        label: tr('Chatten'),
        screen: const ChatScreen(),
      ),
      _NavItem(
        icon: Icons.account_circle_outlined,
        activeIcon: Icons.account_circle,
        label: tr('Mein Profil'),
        screen: PersonnelDetailDashboard(user: appState.currentUser!),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final items = _buildNavItems(appState);
    if (_selectedIndex >= items.length) _selectedIndex = 0;

    if (kIsWeb && WebUtils.isWide(context)) {
      return _WebLayout(
        items: items,
        selectedIndex: _selectedIndex,
        onSelect: (i) => setState(() => _selectedIndex = i),
        appState: appState,
        color: _color,
      );
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: _color,
        title: Text(items[_selectedIndex].label),
        actions: [
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined),
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen())),
              ),
              if (appState.unreadNotifications > 0)
                Positioned(
                  right: 8, top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(color: AppTheme.error, shape: BoxShape.circle),
                    constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                    child: Text('${appState.unreadNotifications}', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                  ),
                ),
            ],
          ),
        ],
      ),
      drawer: _buildDrawer(context, items, appState),
      body: IndexedStack(index: _selectedIndex, children: items.map((e) => e.screen).toList()),
    );
  }

  Widget _buildDrawer(BuildContext context, List<_NavItem> items, AppState appState) {
    return Drawer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [_color, _color.withOpacity(0.7)],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                const Icon(Icons.hotel, color: Colors.white, size: 36),
                const SizedBox(height: 8),
                Text(appState.fullName, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'Inter'), maxLines: 1, overflow: TextOverflow.ellipsis),
                const Text('Externer Manager', style: TextStyle(color: Colors.white70, fontSize: 13, fontFamily: 'Inter')),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.zero,
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                final isSelected = _selectedIndex == index;
                return ListTile(
                  leading: Icon(isSelected ? item.activeIcon : item.icon, color: isSelected ? _color : AppTheme.textSub),
                  title: Text(item.label, style: TextStyle(color: isSelected ? _color : AppTheme.textMain, fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal, fontFamily: 'Inter')),
                  selected: isSelected,
                  selectedTileColor: _color.withOpacity(0.1),
                  onTap: () { setState(() => _selectedIndex = index); Navigator.pop(context); },
                );
              },
            ),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.logout, color: AppTheme.error),
            title: Text(tr('Çıkış Yap'), style: const TextStyle(color: AppTheme.error, fontWeight: FontWeight.w600, fontFamily: 'Inter')),
            onTap: () async { Navigator.pop(context); await context.read<AppState>().signOut(); },
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _WebLayout extends StatelessWidget {
  final List<_NavItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final AppState appState;
  final Color color;

  const _WebLayout({
    required this.items,
    required this.selectedIndex,
    required this.onSelect,
    required this.appState,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: Row(
        children: [
          Container(
            width: WebUtils.sidebarWidth,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [color, color.withOpacity(0.8)],
              ),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 10, offset: const Offset(2, 0))],
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 20),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.1))),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(10)),
                            child: const Icon(Icons.hotel, color: Colors.white, size: 28),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: const [
                                Text('HansePortal', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold, fontFamily: 'Inter')),
                                Text('Externer Manager', style: TextStyle(color: Colors.white70, fontSize: 11, fontFamily: 'Inter')),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: Colors.white.withOpacity(0.08), borderRadius: BorderRadius.circular(10)),
                        child: Row(
                          children: [
                            CircleAvatar(radius: 16, backgroundColor: Colors.white.withOpacity(0.2), child: const Icon(Icons.person, color: Colors.white, size: 18)),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(appState.fullName, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600, fontFamily: 'Inter'), maxLines: 1, overflow: TextOverflow.ellipsis),
                                  const Text('Externer Manager', style: TextStyle(color: Colors.white60, fontSize: 10, fontFamily: 'Inter')),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];
                      final isSelected = selectedIndex == index;
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        child: Material(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                          child: InkWell(
                            onTap: () => onSelect(index),
                            borderRadius: BorderRadius.circular(10),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: isSelected ? Colors.white.withOpacity(0.15) : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                                border: isSelected ? Border.all(color: Colors.white.withOpacity(0.2)) : null,
                              ),
                              child: Row(
                                children: [
                                  Icon(isSelected ? item.activeIcon : item.icon, color: isSelected ? Colors.white : Colors.white60, size: 20),
                                  const SizedBox(width: 10),
                                  Expanded(child: Text(item.label, style: TextStyle(color: isSelected ? Colors.white : Colors.white70, fontSize: 13, fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal, fontFamily: 'Inter'))),
                                  if (isSelected) Container(width: 6, height: 6, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                Container(
                  decoration: BoxDecoration(border: Border(top: BorderSide(color: Colors.white.withOpacity(0.1)))),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    leading: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(color: AppTheme.error.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                      child: const Icon(Icons.logout, color: Colors.white70, size: 18),
                    ),
                    title: Text(tr('Çıkış Yap'), style: const TextStyle(color: Colors.white70, fontSize: 13, fontFamily: 'Inter')),
                    onTap: () async => await context.read<AppState>().signOut(),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
          Expanded(
            child: Column(
              children: [
                Container(
                  height: 64,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border(bottom: BorderSide(color: AppTheme.divider)),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4, offset: const Offset(0, 2))],
                  ),
                  child: Row(
                    children: [
                      Container(width: 4, height: 24, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
                      const SizedBox(width: 12),
                      Text(items[selectedIndex].label, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.textMain, fontFamily: 'Inter')),
                      const Spacer(),
                      Stack(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.notifications_outlined, color: AppTheme.textMain),
                            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen())),
                          ),
                          if (appState.unreadNotifications > 0)
                            Positioned(
                              right: 8, top: 8,
                              child: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: const BoxDecoration(color: AppTheme.error, shape: BoxShape.circle),
                                constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                                child: Text('${appState.unreadNotifications}', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: IndexedStack(index: selectedIndex, children: items.map((e) => e.screen).toList()),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final Widget screen;
  _NavItem({required this.icon, required this.activeIcon, required this.label, required this.screen});
}

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../theme/web_utils.dart';
import '../providers/app_state.dart';
import '../services/localization_service.dart';


// Tüm sekme ekranları
import 'notifications_screen.dart';
import 'orders_hub_screen.dart';
import 'customers_screen.dart';
import 'personnel_screen.dart';
import 'personnel_detail_dashboard.dart';
import 'stammdaten_screen.dart';
import 'verwaltung_screen.dart';
import 'chat_screen.dart';
import 'calendar_screen.dart';
import 'order_calendar_screen.dart';

/// Yönetim rollerinin ana kabuk ekranı.
/// Web'de: sabit sol sidebar + içerik alanı.
/// Mobilde: drawer + AppBar (eski davranış).
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _selectedIndex = 0;

  List<_NavItem> _buildNavItems(AppState appState) {
    // v19.3.7: Aufträge her zaman İLK (index 0) ve ana sayfa
    // Meine Stammdaten: sadece GF, Betriebsleiter, Backoffice, Buchhaltung görebilir
    final canSeeStammdaten = appState.isGeschaeftsfuehrer ||
        appState.isSystemAdmin ||
        appState.isBetriebsleiter ||
        appState.isBackoffice ||
        appState.isBuchhaltung;

    return [
      // 1. Aufträge – herkes için ana sayfa
      _NavItem(icon: Icons.work_outline, activeIcon: Icons.work, label: tr('Aufträge'), screen: const OrdersHubScreen()),
      // 2. Kunden
      _NavItem(icon: Icons.group_outlined, activeIcon: Icons.group, label: tr('Kunden'), screen: const CustomersScreen()),
      // 3. Personal
      _NavItem(icon: Icons.badge_outlined, activeIcon: Icons.badge, label: tr('Personal'), screen: const PersonnelScreen()),
      // 5. Kalender (Personal/Availability)
      _NavItem(icon: Icons.calendar_month_outlined, activeIcon: Icons.calendar_month, label: tr('Kalender'), screen: const CalendarScreen()),
      // 6. Chatten
      _NavItem(icon: Icons.chat_outlined, activeIcon: Icons.chat, label: tr('Chatten'), screen: const ChatScreen()),
      // 6. Verwaltung: GF, Admin, BL, Betriebsleiter, Bereichsleiter
      if (appState.isGeschaeftsfuehrer || appState.isSystemAdmin || appState.isBetriebsleiter || appState.isBereichsleiter || appState.isBackoffice || appState.isBuchhaltung)
        _NavItem(icon: Icons.admin_panel_settings_outlined, activeIcon: Icons.admin_panel_settings, label: tr('Verwaltung'), screen: const VerwaltungScreen()),
      // 7. Meine Stammdaten: sadece GF, Betriebsleiter, Backoffice, Buchhaltung
      if (canSeeStammdaten)
        _NavItem(icon: Icons.business_center_outlined, activeIcon: Icons.business_center, label: tr('Meine Stammdaten'), screen: const StammdatenScreen()),
      // 8. Mein Profil: HERKES için (EKLENDİ)
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

    if (_selectedIndex >= items.length) {
      _selectedIndex = 0;
    }

    // ── WEB LAYOUT ─────────────────────────────────────────
    if (kIsWeb && WebUtils.isWide(context)) {
      return _WebLayout(
        items: items,
        selectedIndex: _selectedIndex,
        onSelect: (i) => setState(() => _selectedIndex = i),
        appState: appState,
      );
    }

    // ── MOBİL LAYOUT (değişmedi) ────────────────────────────
    return Scaffold(
      appBar: AppBar(
        title: Text(items[_selectedIndex].label),
        actions: [
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const NotificationsScreen()),
                ),
              ),
              if (appState.unreadNotifications > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      color: AppTheme.error,
                      shape: BoxShape.circle,
                    ),
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
      drawer: _buildDrawer(context, items, appState),
      body: IndexedStack(
        index: _selectedIndex,
        children: items.map((e) => e.screen).toList(),
      ),
    );
  }

  Widget _buildDrawer(BuildContext context, List<_NavItem> items, AppState appState) {
    return Drawer(
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
                          'HansePortal v19.3.7',
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
                final item = items[index];
                final isSelected = _selectedIndex == index;
                return ListTile(
                  leading: Icon(isSelected ? item.activeIcon : item.icon, color: isSelected ? AppTheme.primary : AppTheme.textSub),
                  title: Text(item.label, style: TextStyle(color: isSelected ? AppTheme.primary : AppTheme.textMain, fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal, fontFamily: 'Inter')),
                  selected: isSelected,
                  selectedTileColor: AppTheme.primary.withOpacity(0.1),
                  onTap: () {
                    setState(() {
                      _selectedIndex = index;
                    });
                    Navigator.pop(context);
                  },
                );
              },
            ),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.logout, color: AppTheme.error),
            title: Text(tr('Çıkış Yap'), style: const TextStyle(color: AppTheme.error, fontWeight: FontWeight.w600, fontFamily: 'Inter')),
            onTap: () async {
              Navigator.pop(context);
              await context.read<AppState>().signOut();
            },
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

// ── Web Layout Widget ──────────────────────────────────────────────────────────
class _WebLayout extends StatelessWidget {
  final List<_NavItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final AppState appState;

  const _WebLayout({
    required this.items,
    required this.selectedIndex,
    required this.onSelect,
    required this.appState,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: Row(
        children: [
          // ── Sol Sidebar ────────────────────────────────────
          _WebSidebar(
            items: items,
            selectedIndex: selectedIndex,
            onSelect: onSelect,
            appState: appState,
          ),
          // ── İçerik Alanı ──────────────────────────────────
          Expanded(
            child: Column(
              children: [
                // Top bar
                _WebTopBar(
                  title: items[selectedIndex].label,
                  appState: appState,
                ),
                // Page content
                Expanded(
                  child: IndexedStack(
                    index: selectedIndex,
                    children: items.map((e) => e.screen).toList(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WebSidebar extends StatelessWidget {
  final List<_NavItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final AppState appState;

  const _WebSidebar({
    required this.items,
    required this.selectedIndex,
    required this.onSelect,
    required this.appState,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: WebUtils.sidebarWidth,
      decoration: BoxDecoration(
        color: AppTheme.primary,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 10,
            offset: const Offset(2, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          // Logo / Başlık
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
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        color: Colors.white,
                        padding: const EdgeInsets.all(3),
                        child: Image.asset('assets/icon/hanse.png', width: 36, height: 36, fit: BoxFit.cover),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('HansePortal v19.3.7', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'Inter')),
                          const Text('v19.3.7', style: TextStyle(color: Colors.white70, fontSize: 12, fontFamily: 'Inter')),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // User info
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: Colors.white.withOpacity(0.2),
                        child: const Icon(Icons.person, color: Colors.white, size: 18),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              appState.fullName,
                              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600, fontFamily: 'Inter'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              AppTheme.roleLabel(appState.role),
                              style: const TextStyle(color: Colors.white60, fontSize: 10, fontFamily: 'Inter'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Nav items
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                final isSelected = selectedIndex == index;
                return _SidebarNavItem(
                  item: item,
                  isSelected: isSelected,
                  onTap: () => onSelect(index),
                );
              },
            ),
          ),

          // Çıkış
          Container(
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: Colors.white.withOpacity(0.1))),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              leading: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppTheme.error.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.logout, color: Colors.white70, size: 18),
              ),
              title: Text(
                tr('Çıkış Yap'),
                style: const TextStyle(color: Colors.white70, fontSize: 13, fontFamily: 'Inter'),
              ),
              onTap: () async {
                await context.read<AppState>().signOut();
              },
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _SidebarNavItem extends StatelessWidget {
  final _NavItem item;
  final bool isSelected;
  final VoidCallback onTap;

  const _SidebarNavItem({
    required this.item,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected ? Colors.white.withOpacity(0.15) : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              border: isSelected
                  ? Border.all(color: Colors.white.withOpacity(0.2))
                  : null,
            ),
            child: Row(
              children: [
                Icon(
                  isSelected ? item.activeIcon : item.icon,
                  color: isSelected ? Colors.white : Colors.white60,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    item.label,
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.white70,
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      fontFamily: 'Inter',
                    ),
                  ),
                ),
                if (isSelected)
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WebTopBar extends StatelessWidget {
  final String title;
  final AppState appState;

  const _WebTopBar({required this.title, required this.appState});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: AppTheme.divider),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppTheme.textMain,
              fontFamily: 'Inter',
            ),
          ),
          const Spacer(),
          // Bildirimler
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined, color: AppTheme.textMain),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const NotificationsScreen()),
                ),
              ),
              if (appState.unreadNotifications > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      color: AppTheme.error,
                      shape: BoxShape.circle,
                    ),
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

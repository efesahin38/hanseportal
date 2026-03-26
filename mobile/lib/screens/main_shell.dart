import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../providers/app_state.dart';

// Tüm sekme ekranları
import 'dashboard_screen.dart';
import 'orders_screen.dart';
import 'customers_screen.dart';
import 'personnel_screen.dart';
import 'companies_screen.dart';
import 'planning_screen.dart';
import 'calendar_screen.dart';
import 'notifications_screen.dart';
import 'reports_screen.dart';

/// Yönetim rollerinin ana kabuk ekranı.
/// Rolle birlikte hangi menü maddeleri göründüğü kontrol edilir.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _selectedIndex = 0;

  List<_NavItem> _buildNavItems(AppState appState) {
    return [
      _NavItem(icon: Icons.dashboard_outlined, activeIcon: Icons.dashboard, label: 'Dashboard', screen: const DashboardScreen()),
      _NavItem(icon: Icons.work_outline, activeIcon: Icons.work, label: 'İşler', screen: const OrdersScreen()),
      if (appState.canManageCustomers)
        _NavItem(icon: Icons.business_outlined, activeIcon: Icons.business, label: 'Müşteriler', screen: const CustomersScreen()),
      if (appState.canPlanOperations)
        _NavItem(icon: Icons.calendar_today_outlined, activeIcon: Icons.calendar_today, label: 'Planlama', screen: const PlanningScreen()),
      if (appState.canPlanOperations)
        _NavItem(icon: Icons.calendar_month_outlined, activeIcon: Icons.calendar_month, label: 'Takvim', screen: const CalendarScreen()),
      if (appState.canManageUsers)
        _NavItem(icon: Icons.people_outline, activeIcon: Icons.people, label: 'Personel', screen: const PersonnelScreen()),
      if (appState.canManageCompanies)
        _NavItem(icon: Icons.apartment_outlined, activeIcon: Icons.apartment, label: 'Şirketler', screen: const CompaniesScreen()),
      if (appState.canViewReports)
        _NavItem(icon: Icons.bar_chart_outlined, activeIcon: Icons.bar_chart, label: 'Raporlar', screen: const ReportsScreen()),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final items = _buildNavItems(appState);

    if (_selectedIndex >= items.length) {
      _selectedIndex = 0;
    }

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.business, size: 18),
            const SizedBox(width: 8),
            Text(items[_selectedIndex].label),
          ],
        ),
        actions: [
          // Bildirimler
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
          // Profil & Çıkış
          PopupMenuButton<String>(
            icon: CircleAvatar(
              radius: 16,
              backgroundColor: Colors.white.withOpacity(0.2),
              child: Text(
                appState.fullName.isNotEmpty ? appState.fullName[0].toUpperCase() : 'U',
                style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ),
            onSelected: (v) async {
              if (v == 'logout') await context.read<AppState>().signOut();
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                enabled: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(appState.fullName, style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text(AppTheme.roleLabel(appState.role), style: const TextStyle(fontSize: 12, color: AppTheme.textSub)),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(value: 'logout', child: Row(
                children: [Icon(Icons.logout, size: 18), SizedBox(width: 8), Text('Çıkış Yap')],
              )),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: items.map((e) => e.screen).toList(),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (i) => setState(() => _selectedIndex = i),
        backgroundColor: Colors.white,
        elevation: 8,
        destinations: items.map((e) => NavigationDestination(
          icon: Icon(e.icon),
          selectedIcon: Icon(e.activeIcon),
          label: e.label,
        )).toList(),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final Widget screen;
  const _NavItem({required this.icon, required this.activeIcon, required this.label, required this.screen});
}

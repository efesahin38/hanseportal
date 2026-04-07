import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../theme/web_utils.dart';
import '../providers/app_state.dart';
import '../services/localization_service.dart';
import 'accounting_overview_screen.dart';
import 'interne_pq_screen.dart';
import 'vertragsmanagement_screen.dart';
import 'fuhrpark_screen.dart';

/// Verwaltung-Hub Screen
class VerwaltungScreen extends StatelessWidget {
  const VerwaltungScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();

    final sections = <_VerwaltungItem>[
      _VerwaltungItem(
        icon: Icons.folder_special,
        title: tr('Interne PQ'),
        subtitle: tr('Firmenunterlagen & Qualifikationsdokumente'),
        color: const Color(0xFF3B82F6),
        screen: const InternePqScreen(),
      ),
      _VerwaltungItem(
        icon: Icons.account_balance,
        title: tr('Buchhaltung'),
        subtitle: tr('Rechnungsentwürfe & Lohnabrechnung'),
        color: const Color(0xFF10B981),
        screen: const AccountingOverviewScreen(),
      ),
      _VerwaltungItem(
        icon: Icons.description,
        title: tr('Vertragsmanagement'),
        subtitle: tr('Verträge, Fristen & Erinnerungen'),
        color: const Color(0xFFF59E0B),
        screen: const VertragsmanagementScreen(),
      ),
      _VerwaltungItem(
        icon: Icons.directions_car,
        title: tr('Fuhrpark'),
        subtitle: tr('Fahrzeuge, TÜV, Service & Fristen'),
        color: const Color(0xFFEF4444),
        screen: const FuhrparkScreen(),
      ),
    ];

    return Scaffold(
      body: WebContentWrapper(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: AppTheme.gradientBox().copyWith(borderRadius: BorderRadius.circular(20)),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(14)),
                    child: const Icon(Icons.admin_panel_settings, color: Colors.white, size: 28),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(tr('Verwaltung'), style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold, fontFamily: 'Inter')),
                        Text(tr('Interne Prozesse & Dokumentation'), style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13, fontFamily: 'Inter')),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Grid with 2 columns
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: WebUtils.gridColumns(context, mobile: 1, tablet: 2, desktop: 2),
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
                childAspectRatio: 2.2,
              ),
              itemCount: sections.length,
              itemBuilder: (_, i) {
                final s = sections[i];
                return InkWell(
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => s.screen)),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppTheme.divider),
                      boxShadow: [BoxShadow(color: s.color.withOpacity(0.1), blurRadius: 16, offset: const Offset(0, 4))],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: [s.color.withOpacity(0.15), s.color.withOpacity(0.05)]),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(s.icon, color: s.color, size: 30),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(s.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, fontFamily: 'Inter')),
                              const SizedBox(height: 4),
                              Text(s.subtitle, style: const TextStyle(fontSize: 12, color: AppTheme.textSub, fontFamily: 'Inter'), maxLines: 2, overflow: TextOverflow.ellipsis),
                            ],
                          ),
                        ),
                        Icon(Icons.chevron_right, color: s.color.withOpacity(0.5)),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _VerwaltungItem {
  final IconData icon;
  final String title, subtitle;
  final Color color;
  final Widget screen;
  _VerwaltungItem({required this.icon, required this.title, required this.subtitle, required this.color, required this.screen});
}

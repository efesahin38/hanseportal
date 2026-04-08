import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../theme/web_utils.dart';
import '../services/localization_service.dart';
import 'personnel_form_screen.dart';
import 'employee_folder_screen.dart';
import 'work_session_approval_screen.dart';

class PersonnelDetailDashboard extends StatelessWidget {
  final Map<String, dynamic> user;
  const PersonnelDetailDashboard({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${user['first_name']} ${user['last_name']}')),
      body: WebContentWrapper(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // User Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [AppTheme.primary, AppTheme.accent], begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.white24,
                    child: Text('${user['first_name']?[0] ?? ''}${user['last_name']?[0] ?? ''}', style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${user['first_name']} ${user['last_name']}', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold, fontFamily: 'Inter')),
                        Text(AppTheme.roleLabel(user['role'] ?? ''), style: const TextStyle(color: Colors.white70, fontSize: 13, fontFamily: 'Inter')),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            _MenuCard(
              icon: Icons.person,
              title: tr('Meine Stammdaten'),
              subtitle: tr('Persönliche Daten, Vertrag & Qualifikationen'),
              color: const Color(0xFF3B82F6),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PersonnelFormScreen(userId: user['id']))),
            ),

            _MenuCard(
              icon: Icons.folder,
              title: tr('Unterlagen / Dokumente'),
              subtitle: tr('Lohnabrechnungen, Urlaubsanträge, Krankmeldungen'),
              color: const Color(0xFF10B981),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => EmployeeFolderScreen(initialEmployee: user))),
            ),

            _MenuCard(
              icon: Icons.access_time,
              title: tr('Arbeitszeiterfassung'),
              subtitle: tr('Einsatzdaten & Stundenzettel'),
              color: const Color(0xFFF59E0B),
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const WorkSessionApprovalScreen()));
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuCard extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final Color color;
  final VoidCallback onTap;
  const _MenuCard({required this.icon, required this.title, required this.subtitle, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppTheme.divider), boxShadow: [BoxShadow(color: color.withOpacity(0.08), blurRadius: 12, offset: const Offset(0, 4))]),
          child: Row(
            children: [
              Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: color, size: 28)),
              const SizedBox(width: 16),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, fontFamily: 'Inter')),
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(fontSize: 12, color: AppTheme.textSub, fontFamily: 'Inter'), maxLines: 2),
              ])),
              Icon(Icons.chevron_right, color: color.withOpacity(0.6)),
            ],
          ),
        ),
      ),
    );
  }
}

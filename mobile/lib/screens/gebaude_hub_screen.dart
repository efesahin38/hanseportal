import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../theme/web_utils.dart';
import '../services/supabase_service.dart';
import '../services/localization_service.dart';
import 'orders_screen.dart';

/// Gebäudedienstleistungen alt klasör hub'ı (v17.0)
/// 4 alt hizmet alanı: Gebäudedienstleistungen, Bau-Logistik, Hausmeisterservice, Gartenpflege
class GebaudeHubScreen extends StatefulWidget {
  final String? departmentId; // Gebäude departman ID'si
  const GebaudeHubScreen({super.key, this.departmentId});

  @override
  State<GebaudeHubScreen> createState() => _GebaudeHubScreenState();
}

class _GebaudeHubScreenState extends State<GebaudeHubScreen> {
  // 4 alt bölüm tanımı
  static const List<_SubSectionDef> _subSections = [
    _SubSectionDef(
      label: 'Gebäudedienstleistungen',
      emoji: '🏗️',
      icon: Icons.apartment,
      color: Color(0xFF3B82F6),
      description: 'Gebäudereinigung & Dienstleistungen',
    ),
    _SubSectionDef(
      label: 'Bau-Logistik',
      emoji: '🚧',
      icon: Icons.construction,
      color: Color(0xFFF97316),
      description: 'Baulogistik & Transport',
    ),
    _SubSectionDef(
      label: 'Hausmeisterservice',
      emoji: '🔧',
      icon: Icons.handyman,
      color: Color(0xFF8B5CF6),
      description: 'Wartung & Instandhaltung',
    ),
    _SubSectionDef(
      label: 'Gartenpflege',
      emoji: '🌿',
      icon: Icons.yard,
      color: Color(0xFF22C55E),
      description: 'Gartenpflege & Grünanlagen',
    ),
  ];

  Map<String, String?> _serviceAreaIds = {}; // label → service_area_id
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final areas = await SupabaseService.getServiceAreas(activeOnly: false);
      final depts = await SupabaseService.getDepartments();

      final Map<String, String?> ids = {};
      for (final sec in _subSections) {
        final labelLow = sec.label.toLowerCase();
        // Önce hizmet alanı içinde ara
        var match = areas.firstWhere(
          (a) {
            final aName = (a['name'] as String? ?? '').toLowerCase();
            return aName.contains(labelLow) ||
                labelLow.contains(aName) ||
                _keywordMatch(aName, sec.label);
          },
          orElse: () => {},
        );

        // Hizmet alanı bulunamazsa departman ID'sini kullan
        if (match.isEmpty) {
          final dept = depts.firstWhere(
            (d) {
              final dName = (d['name'] as String? ?? '').toLowerCase();
              return dName.contains(labelLow) || _keywordMatch(dName, sec.label);
            },
            orElse: () => {},
          );
          if (dept.isNotEmpty) {
            match = {'id': dept['id'], 'department_id': dept['id']};
          }
        }

        ids[sec.label] = match['id']?.toString();
      }

      if (mounted) setState(() {
        _serviceAreaIds = ids;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool _keywordMatch(String dbName, String label) {
    final l = label.toLowerCase();
    if (l.contains('bau-logistik') && (dbName.contains('bau') || dbName.contains('logistik'))) return true;
    if (l.contains('hausmeister') && dbName.contains('hausmeister')) return true;
    if (l.contains('gartenpflege') && (dbName.contains('garten') || dbName.contains('grün'))) return true;
    if (l.contains('gebäude') && dbName.contains('gebäu')) return true;
    return false;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gebäudedienstleistungen', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold)),
        leading: const BackButton(),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.textMain,
        actions: [
          // 🏠 Ana sayfaya git
          IconButton(
            icon: const Icon(Icons.home_outlined),
            tooltip: 'Zur Startseite',
            onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: WebContentWrapper(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.apartment, color: Colors.white, size: 28),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Gebäudedienstleistungen',
                          style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold, fontFamily: 'Inter'),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Bitte Unterbereich wählen',
                          style: TextStyle(color: Colors.white70, fontSize: 13, fontFamily: 'Inter'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // 4 Alt Bölüm Kartları
            ..._subSections.map((sec) => _SubSectionCard(
              def: sec,
              serviceAreaId: _serviceAreaIds[sec.label],
              departmentId: widget.departmentId,
            )),
          ],
        ),
      ),
    );
  }
}

class _SubSectionCard extends StatelessWidget {
  final _SubSectionDef def;
  final String? serviceAreaId;
  final String? departmentId;

  const _SubSectionCard({
    required this.def,
    this.serviceAreaId,
    this.departmentId,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => OrdersScreen(
              serviceAreaId: serviceAreaId,
              departmentId: departmentId,
              customTitle: '${def.emoji} ${def.label}',
            ),
          ),
        ),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.divider),
            boxShadow: [
              BoxShadow(
                color: def.color.withOpacity(0.12),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              // Emoji + İkon
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: def.color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(def.emoji, style: const TextStyle(fontSize: 20)),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      def.label,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        fontFamily: 'Inter',
                        color: def.color,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      def.description,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSub,
                        fontFamily: 'Inter',
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.folder_open_outlined, color: def.color, size: 24),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right, color: def.color.withOpacity(0.6), size: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _SubSectionDef {
  final String label;
  final String emoji;
  final IconData icon;
  final Color color;
  final String description;
  const _SubSectionDef({
    required this.label,
    required this.emoji,
    required this.icon,
    required this.color,
    required this.description,
  });
}

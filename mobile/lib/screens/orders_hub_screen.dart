import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../theme/web_utils.dart';
import '../providers/app_state.dart';
import '../services/supabase_service.dart';
import '../services/localization_service.dart';
import 'orders_screen.dart';

// Sabit GmbH tanımları: her bölümün adı, GmbH adı, sorumlusu ve rengi
class _GmbhDef {
  final String departmentKey; // kDepartmentOptions değeriyle eşleşen anahtar
  final String gmbhName;
  final String responsible;
  final IconData icon;
  final Color color;
  const _GmbhDef({
    required this.departmentKey,
    required this.gmbhName,
    required this.responsible,
    required this.icon,
    required this.color,
  });
}

const List<_GmbhDef> kGmbhDefs = [
  _GmbhDef(
    departmentKey: 'Gebäude',
    gmbhName: 'Gebäudedienstleistungen', // veya Gebäudereinigung
    responsible: 'Sandra',
    icon: Icons.apartment,
    color: Color(0xFF3B82F6),
  ),
  _GmbhDef(
    departmentKey: 'Rail',
    gmbhName: 'Rail Service', // veya Gleisbausicherung
    responsible: 'Peter',
    icon: Icons.train,
    color: Color(0xFF10B981),
  ),
  _GmbhDef(
    departmentKey: 'Gast',
    gmbhName: 'Gastwirtschaftsservice', // veya Hotelservice
    responsible: 'Fatma',
    icon: Icons.restaurant,
    color: Color(0xFFF59E0B),
  ),
  _GmbhDef(
    departmentKey: 'Personal',
    gmbhName: 'Personalüberlassung', // veya Verwaltung
    responsible: 'Markus',
    icon: Icons.people,
    color: Color(0xFF8B5CF6),
  ),
];

class OrdersHubScreen extends StatefulWidget {
  const OrdersHubScreen({super.key});
  @override
  State<OrdersHubScreen> createState() => _OrdersHubScreenState();
}

class _OrdersHubScreenState extends State<OrdersHubScreen> {
  /// Departman listesini DB'den alıp GmbhDef ile eşleştiriyoruz.
  Map<String, String?> _departmentIds = {}; // departmentKey → departmentId
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final depts = await SupabaseService.getDepartments();
      final Map<String, String?> ids = {};
      for (final def in kGmbhDefs) {
        // DB'deki departman adı ile eşleştir (çoklu anahtar kelime mantığı)
        final match = depts.firstWhere(
          (d) {
            final dbName = (d['name'] as String? ?? '').toLowerCase();
            final key = def.departmentKey.toLowerCase();
            final gmbh = def.gmbhName.toLowerCase();
            
            // Eğer veritabanındaki isim, bizim anahtarımızı veya GmbH ismimizi İÇERİYORSA
            return dbName.contains(key) || 
                   dbName.contains(gmbh) || 
                   key.contains(dbName) || 
                   gmbh.contains(dbName) ||
                   (key == 'rail' && dbName.contains('gleis')) || // Rail -> Gleis özel eşleşmesi
                   (key == 'gast' && dbName.contains('hotel')) || // Gast -> Hotel özel eşleşmesi
                   (key == 'personal' && dbName.contains('verwal')); // Personal -> Verwaltung eşleşmesi
          },
          orElse: () => {},
        );
        ids[def.departmentKey] = match['id']?.toString();
      }
      if (mounted) setState(() { _departmentIds = ids; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Bereichsleiter'ın bölüm adını döner (diğerleri için null)
  String? _bereichsleiterDept(AppState appState) {
    if (!appState.isBereichsleiter) return null;
    return appState.currentUser?['department']?['name'] as String?;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    final appState = context.watch<AppState>();
    final bereichDept = _bereichsleiterDept(appState);

    // 🛡️ NAILED ISOLATION: Sandra, Peter, Fatma, Markus için kesin kilit
    List<_GmbhDef> visibleDefs = kGmbhDefs;

    if (appState.isBereichsleiter) {
      final firstName = (appState.currentUser?['first_name'] as String? ?? '').toLowerCase();
      
      if (firstName == 'sandra') {
        visibleDefs = kGmbhDefs.where((d) => d.responsible == 'Sandra').toList();
      } else if (firstName == 'peter') {
        visibleDefs = kGmbhDefs.where((d) => d.responsible == 'Peter').toList();
      } else if (firstName == 'fatma') {
        visibleDefs = kGmbhDefs.where((d) => d.responsible == 'Fatma').toList();
      } else if (firstName == 'markus') {
        visibleDefs = kGmbhDefs.where((d) => d.responsible == 'Markus').toList();
      } else if (bereichDept != null) {
        // Diğer Bereichsleiter'lar için mevcut departman bazlı mantık
        final bDept = bereichDept.toLowerCase();
        visibleDefs = kGmbhDefs.where((d) => 
          bDept.contains(d.departmentKey.toLowerCase()) || 
          d.departmentKey.toLowerCase().contains(bDept)).toList();
      } else {
        visibleDefs = [];
      }
    }

    return Scaffold(
      body: WebContentWrapper(
        child: RefreshIndicator(
          onRefresh: _load,
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
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.work, color: Colors.white, size: 28),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tr('Aufträge'),
                            style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold, fontFamily: 'Inter'),
                          ),
                          Text(
                            bereichDept != null
                                ? tr('Ihre Bereichsaufträge')
                                : tr('Bitte Bereich wählen'),
                            style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13, fontFamily: 'Inter'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              if (visibleDefs.isEmpty)
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.work_off_outlined, size: 56, color: AppTheme.textSub),
                      const SizedBox(height: 12),
                      Text(
                        tr('Kein Bereich zugewiesen'),
                        style: const TextStyle(color: AppTheme.textSub, fontSize: 15, fontFamily: 'Inter'),
                      ),
                    ],
                  ),
                )
              else
                ...visibleDefs.map((def) => _GmbhCard(
                  def: def,
                  departmentId: _departmentIds[def.departmentKey],
                )),
            ],
          ),
        ),
      ),
    );
  }
}

class _GmbhCard extends StatelessWidget {
  final _GmbhDef def;
  final String? departmentId;
  const _GmbhCard({required this.def, this.departmentId});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => OrdersScreen(departmentId: departmentId, customTitle: def.gmbhName),
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
                color: def.color.withOpacity(0.10),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              // İkon
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: def.color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(def.icon, color: def.color, size: 28),
              ),
              const SizedBox(width: 16),
              // Bilgiler
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      def.gmbhName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        fontFamily: 'Inter',
                        color: AppTheme.textMain,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.person_outline, size: 14, color: def.color),
                        const SizedBox(width: 4),
                        Text(
                          '${tr('Bereichsleiter')}: ${def.responsible}',
                          style: TextStyle(
                            fontSize: 13,
                            color: def.color,
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: def.color.withOpacity(0.6), size: 24),
            ],
          ),
        ),
      ),
    );
  }
}

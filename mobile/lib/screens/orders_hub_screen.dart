import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../theme/web_utils.dart';
import '../providers/app_state.dart';
import '../services/supabase_service.dart';
import '../services/localization_service.dart';
import 'orders_screen.dart';
import 'gebaude_hub_screen.dart';
import 'gws_hub_screen.dart';
import 'order_calendar_screen.dart';

class _GmbhDef {
  final String departmentKey;
  final String gmbhName;
  final String emoji;
  final String responsible;
  final IconData icon;
  final Color color;
  final bool hasSubSections;
  const _GmbhDef({
    required this.departmentKey,
    required this.gmbhName,
    required this.emoji,
    required this.responsible,
    required this.icon,
    required this.color,
    this.hasSubSections = false,
  });
}

const List<_GmbhDef> kGmbhDefs = [
  _GmbhDef(
    departmentKey: 'Gebäude',
    gmbhName: 'Gebäudedienstleistungen',
    emoji: '🏗️',
    responsible: 'Sandra',
    icon: Icons.apartment,
    color: Color(0xFF3B82F6),
    hasSubSections: true,
  ),
  _GmbhDef(
    departmentKey: 'Rail',
    gmbhName: 'DB-Gleisbausicherung',
    emoji: '🚂',
    responsible: 'Peter',
    icon: Icons.train,
    color: Color(0xFF10B981),
  ),
  _GmbhDef(
    departmentKey: 'Personal',
    gmbhName: 'Personalüberlassung',
    emoji: '👥',
    responsible: 'Markus',
    icon: Icons.people,
    color: Color(0xFF8B5CF6),
  ),
  _GmbhDef(
    departmentKey: 'Gastwirtschaft',
    gmbhName: 'Gastwirtschaftsservice',
    emoji: '🏨',
    responsible: 'Fatma',
    icon: Icons.hotel,
    color: AppTheme.gwsColor,
    hasSubSections: true,
  ),
];

class OrdersHubScreen extends StatefulWidget {
  const OrdersHubScreen({super.key});
  @override
  State<OrdersHubScreen> createState() => _OrdersHubScreenState();
}

class _OrdersHubScreenState extends State<OrdersHubScreen> {
  Map<String, String?> _departmentIds = {};
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
        final match = depts.firstWhere(
          (d) {
            final dbName = (d['name'] as String? ?? '').toLowerCase();
            final key = def.departmentKey.toLowerCase();
            final gmbh = def.gmbhName.toLowerCase();
            return dbName.contains(key) ||
                   dbName.contains(gmbh) ||
                   key.contains(dbName) ||
                   gmbh.contains(dbName) ||
                   (key == 'rail' && dbName.contains('gleis')) ||
                   (key == 'personal' && dbName.contains('verwal')) ||
                   (key == 'gastwirtschaft' && (dbName.contains('gast') || dbName.contains('hotel')));
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

  String? _bereichsleiterDept(AppState appState) {
    if (!appState.isBereichsleiter) return null;
    return appState.currentUser?['department']?['name'] as String?;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    final appState = context.watch<AppState>();
    final bereichDept = _bereichsleiterDept(appState);

    List<_GmbhDef> visibleDefs = kGmbhDefs;

    if (appState.isBereichsleiter) {
      final firstName = (appState.currentUser?['first_name'] as String? ?? '').toLowerCase();
      final lastName = (appState.currentUser?['last_name'] as String? ?? '').toLowerCase();
      final email = (appState.currentUser?['email'] as String? ?? '').toLowerCase();
      final fullNameAndEmail = '$firstName $lastName $email';

      if (fullNameAndEmail.contains('sandra')) {
        visibleDefs = kGmbhDefs.where((d) => d.responsible == 'Sandra').toList();
      } else if (fullNameAndEmail.contains('peter')) {
        visibleDefs = kGmbhDefs.where((d) => d.responsible == 'Peter').toList();
      } else if (fullNameAndEmail.contains('markus')) {
        visibleDefs = kGmbhDefs.where((d) => d.responsible == 'Markus').toList();
      } else if (fullNameAndEmail.contains('fatma')) {
        visibleDefs = kGmbhDefs.where((d) => d.responsible == 'Fatma').toList();
      } else if (bereichDept != null) {
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
              _buildHeader(appState),
              const SizedBox(height: 16),
              LayoutBuilder(
                builder: (context, constraints) {
                  final bool isWide = constraints.maxWidth > 800;
                  if (isWide) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 450,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (visibleDefs.isEmpty)
                                _buildEmptyState()
                              else
                                ...visibleDefs.map((def) => _GmbhCard(
                                  def: def,
                                  departmentId: _departmentIds[def.departmentKey],
                                  compact: true,
                                )),
                            ],
                          ),
                        ),
                        const SizedBox(width: 24),
                        Expanded(
                          child: Container(
                            height: 650,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: const OrderCalendarWidget(showHeader: false),
                          ),
                        ),
                      ],
                    );
                  }
                  return Column(
                    children: [
                      if (visibleDefs.isEmpty)
                        _buildEmptyState()
                      else
                        ...visibleDefs.map((def) => _GmbhCard(
                          def: def,
                          departmentId: _departmentIds[def.departmentKey],
                        )),
                      const SizedBox(height: 16),
                      const Card(
                        child: Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                            height: 600,
                            child: OrderCalendarWidget(showHeader: true),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(AppState appState) {
    return Container(
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
                const Text(
                  'HansePortal v1.0.2',
                  style: TextStyle(color: Colors.white70, fontSize: 12, fontFamily: 'Inter'),
                ),
                Text(
                  appState.isBereichsleiter
                      ? tr('Ihre Bereichsaufträge')
                      : tr('Hizmetler ve İş Planı'),
                  style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13, fontFamily: 'Inter'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
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
    );
  }
}

class _GmbhCard extends StatelessWidget {
  final _GmbhDef def;
  final String? departmentId;
  final bool compact;
  const _GmbhCard({required this.def, this.departmentId, this.compact = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: InkWell(
        onTap: () {
          if (def.hasSubSections && def.departmentKey == 'Gastwirtschaft') {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => GwsHubScreen(departmentId: departmentId),
              ),
            );
          } else if (def.hasSubSections) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => GebaudeHubScreen(departmentId: departmentId),
              ),
            );
          } else {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => OrdersScreen(departmentId: departmentId, customTitle: '${def.emoji} ${def.gmbhName}'),
              ),
            );
          }
        },
        borderRadius: BorderRadius.circular(compact ? 12 : 20),
        child: Container(
          padding: EdgeInsets.all(compact ? 12 : 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(compact ? 12 : 20),
            border: Border.all(color: AppTheme.divider),
            boxShadow: [
              BoxShadow(
                color: def.color.withOpacity(0.10),
                blurRadius: compact ? 8 : 16,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: compact ? 44 : 60,
                height: compact ? 44 : 60,
                decoration: BoxDecoration(
                  color: def.color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(compact ? 10 : 16),
                ),
                child: Center(
                  child: Text(def.emoji, style: TextStyle(fontSize: compact ? 18 : 24)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      def.gmbhName,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: compact ? 14 : 16,
                        fontFamily: 'Inter',
                        color: def.color,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (!compact) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.person_outline, size: 14, color: def.color.withOpacity(0.7)),
                          const SizedBox(width: 4),
                          Text(
                            'Bereichsleiter: ${def.responsible}',
                            style: TextStyle(
                              fontSize: 12,
                              color: def.color.withOpacity(0.8),
                              fontFamily: 'Inter',
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      if (def.hasSubSections) ...[
                        const SizedBox(height: 4),
                        Text(
                          '4 Unterbereiche',
                          style: TextStyle(
                            fontSize: 11,
                            color: def.color.withOpacity(0.6),
                            fontFamily: 'Inter',
                          ),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
              Icon(
                def.hasSubSections ? Icons.folder_open_outlined : Icons.chevron_right,
                color: def.color.withOpacity(0.7),
                size: compact ? 18 : 24,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

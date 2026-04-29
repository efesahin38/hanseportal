import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../theme/web_utils.dart';
import '../providers/app_state.dart';
import '../services/supabase_service.dart';
import '../services/localization_service.dart';
import 'package:intl/intl.dart';

class FieldDashboardScreen extends StatefulWidget {
  const FieldDashboardScreen({super.key});

  @override
  State<FieldDashboardScreen> createState() => _FieldDashboardScreenState();
}

class _FieldDashboardScreenState extends State<FieldDashboardScreen> {
  DateTime _selectedMonth = DateTime.now();
  double _approvedHours = 0;
  bool _loading = true;
  List<Map<String, dynamic>> _recentSessions = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final appState = context.read<AppState>();
      final hours = await SupabaseService.getApprovedHoursByMonth(appState.userId, _selectedMonth);
      
      // Also get recent approved sessions for the list
      final start = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
      final end = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0);
      
      final sessions = await SupabaseService.client
          .from('work_sessions')
          .select('*, order:orders(title)')
          .eq('user_id', appState.userId)
          .eq('approval_status', 'approved')
          .gte('actual_start', start.toIso8601String())
          .lte('actual_start', end.toIso8601String())
          .order('actual_start', ascending: false)
          .limit(5);

      if (mounted) {
        setState(() {
          _approvedHours = hours;
          _recentSessions = List<Map<String, dynamic>>.from(sessions);
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _changeMonth(int delta) {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + delta);
    });
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.read<AppState>();
    final user = appState.currentUser;
    double targetHours = 160.0;
    if (user != null) {
      if (user['monthly_hours'] != null) {
        targetHours = (user['monthly_hours'] as num).toDouble();
      } else if (user['weekly_hours'] != null) {
        targetHours = (user['weekly_hours'] as num).toDouble() * 4.3; // Approx month
      }
    }
    if (targetHours <= 0) targetHours = 160.0;

    final monthName = DateFormat('MMMM yyyy', Localizations.localeOf(context).languageCode).format(_selectedMonth);

    final percent = (_approvedHours / targetHours).clamp(0.0, 1.0);


    return WebContentWrapper(
      child: RefreshIndicator(
        onRefresh: _load,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // ── Month Selection ──
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(onPressed: () => _changeMonth(-1), icon: const Icon(Icons.chevron_left)),
                  Text(monthName.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, fontFamily: 'Inter')),
                  IconButton(onPressed: () => _changeMonth(1), icon: const Icon(Icons.chevron_right)),
                ],
              ),
              const SizedBox(height: 20),

              // ── Circular Dashboard ──
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 32),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 10))],
                ),
                child: Column(
                  children: [
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 180,
                          height: 180,
                          child: CircularProgressIndicator(
                            value: percent,
                            strokeWidth: 14,
                            backgroundColor: AppTheme.bg,
                            valueColor: AlwaysStoppedAnimation<Color>(_approvedHours >= targetHours ? AppTheme.success : AppTheme.primary),
                          ),
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _approvedHours.toStringAsFixed(1),
                              style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w900, fontFamily: 'Inter', color: AppTheme.textMain),
                            ),
                            Text(
                              tr('Std.'),
                              style: const TextStyle(fontSize: 14, color: AppTheme.textSub, fontWeight: FontWeight.w500, fontFamily: 'Inter'),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Text(
                      _approvedHours >= targetHours 
                        ? tr('Hedef Tamamlandı! 🎉') 
                        : tr('{total} saatlik hedefin {current}\'si tamamlandı.', args: {
                            'total': targetHours.toInt().toString(),
                            'current': _approvedHours.toStringAsFixed(1)
                          }),
                      style: const TextStyle(fontSize: 13, color: AppTheme.textSub, fontFamily: 'Inter'),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // ── Recent Approved Sessions ──
              Row(
                children: [
                  const Icon(Icons.history, size: 20, color: AppTheme.primary),
                  const SizedBox(width: 8),
                  Text(tr('Genehmigte Schichten'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, fontFamily: 'Inter')),
                ],
              ),
              const SizedBox(height: 16),
              if (_loading)
                const Center(child: CircularProgressIndicator())
              else if (_recentSessions.isEmpty)
                _buildEmptyState()
              else
                ..._recentSessions.map((s) => _SessionCard(session: s)),
              
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: AppTheme.bg, borderRadius: BorderRadius.circular(16)),
      child: Center(
        child: Column(
          children: [
            const Icon(Icons.info_outline, color: AppTheme.textSub, size: 32),
            const SizedBox(height: 8),
            Text(tr('Bu ay onaylanmış mesai bulunamadı.'), style: const TextStyle(color: AppTheme.textSub, fontSize: 13, fontFamily: 'Inter')),
          ],
        ),
      ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  final Map<String, dynamic> session;
  const _SessionCard({required this.session});

  @override
  Widget build(BuildContext context) {
    final start = DateTime.parse(session['actual_start']).toLocal();
    final dateStr = DateFormat('dd.MM.yyyy').format(start);
    final hours = (session['approved_billable_hours'] as num?)?.toDouble() ?? 0.0;
    final orderTitle = session['order']?['title'] ?? tr('Unbenannte Aufgabe');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: AppTheme.success.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.check_circle, color: AppTheme.success, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(orderTitle, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, fontFamily: 'Inter')),
                Text(dateStr, style: const TextStyle(fontSize: 12, color: AppTheme.textSub, fontFamily: 'Inter')),
              ],
            ),
          ),
          Text(
            '+${hours.toStringAsFixed(1)}h',
            style: const TextStyle(fontWeight: FontWeight.w900, color: AppTheme.success, fontSize: 16, fontFamily: 'Inter'),
          ),
        ],
      ),
    );
  }
}

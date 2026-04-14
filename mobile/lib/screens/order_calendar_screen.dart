import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import '../providers/app_state.dart';
import '../services/localization_service.dart';

class OrderCalendarScreen extends StatefulWidget {
  const OrderCalendarScreen({super.key});

  @override
  State<OrderCalendarScreen> createState() => _OrderCalendarScreenState();
}

class _OrderCalendarScreenState extends State<OrderCalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  bool _isLoading = true;
  List<Map<String, dynamic>> _plans = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final appState = Provider.of<AppState>(context, listen: false);
      final startOfMonth = DateTime(_focusedDay.year, _focusedDay.month, 1);
      final endOfMonth = DateTime(_focusedDay.year, _focusedDay.month + 1, 0);

      // Fetch plans for the month
      // Admin roles see all, Bereichsleiter see only their department
      final departmentId = appState.isBereichsleiter ? appState.departmentId : null;
      
      final plans = await SupabaseService.getOperationPlans(
        dateFrom: startOfMonth,
        dateTo: endOfMonth,
        departmentId: departmentId,
      );

      setState(() {
        _plans = plans;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('[OrderCalendar] Error: $e');
      setState(() => _isLoading = false);
    }
  }

  // --- Helper Methods ---

  Color _getServiceColor(String departmentName) {
    final name = departmentName.toLowerCase();
    if (name.contains('ray') || name.contains('gleis')) return AppTheme.orderServiceColors['ray-servis']!;
    if (name.contains('hausmeister')) return AppTheme.orderServiceColors['hausmeister']!;
    if (name.contains('gebäud')) return AppTheme.orderServiceColors['gebaeude']!;
    if (name.contains('garten')) return AppTheme.orderServiceColors['garten']!;
    if (name.contains('logistik')) return AppTheme.orderServiceColors['logistik']!;
    if (name.contains('gast') || name.contains('gastro') || name.contains('hospitality')) return AppTheme.orderServiceColors['hospitality']!;
    return AppTheme.textSub;
  }

  List<Map<String, dynamic>> _getPlansForDay(DateTime day) {
    final dayStr = DateFormat('yyyy-MM-dd').format(day);
    return _plans.where((p) => p['plan_date'] == dayStr).toList();
  }

  Set<Color> _getDayColors(DateTime day) {
    final dayPlans = _getPlansForDay(day);
    return dayPlans.map((p) {
      final deptName = p['order']?['department']?['name'] ?? '';
      return _getServiceColor(deptName);
    }).toSet();
  }

  // --- UI Builders ---

  @override
  Widget build(BuildContext context) {
    final monthStr = DateFormat('MMMM yyyy', Localizations.localeOf(context).toString()).format(_focusedDay);

    return Scaffold(
      appBar: AppBar(
        title: Text(tr('İş Takvimi')),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: Column(
        children: [
          // Month Selector
          _buildMonthHeader(monthStr),
          
          if (_isLoading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else ...[
            // Weekday Headers
            _buildDayHeaders(),
            // Calendar Grid
            _buildCalendarGrid(),
            // Daily Detail List
            Expanded(child: _buildDayDetails()),
          ],
        ],
      ),
    );
  }

  Widget _buildMonthHeader(String monthStr) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: AppTheme.primary,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4)],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left, color: Colors.white),
            onPressed: () {
              setState(() => _focusedDay = DateTime(_focusedDay.year, _focusedDay.month - 1));
              _loadData();
            },
          ),
          Text(
            monthStr.toUpperCase(),
            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1.2),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right, color: Colors.white),
            onPressed: () {
              setState(() => _focusedDay = DateTime(_focusedDay.year, _focusedDay.month + 1));
              _loadData();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDayHeaders() {
    final labels = [tr('Pzt'), tr('Sal'), tr('Çar'), tr('Per'), tr('Cum'), tr('Cmt'), tr('Paz')];
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: labels.map((d) => Expanded(
          child: Text(d, textAlign: TextAlign.center, style: const TextStyle(color: AppTheme.textSub, fontSize: 13, fontWeight: FontWeight.bold))
        )).toList(),
      ),
    );
  }

  Widget _buildCalendarGrid() {
    final firstDay = DateTime(_focusedDay.year, _focusedDay.month, 1);
    final daysInMonth = DateTime(_focusedDay.year, _focusedDay.month + 1, 0).day;
    final startOffset = firstDay.weekday - 1;
    final totalCells = startOffset + daysInMonth;
    final rows = (totalCells / 7).ceil();

    return Container(
      color: Colors.white,
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 7,
          childAspectRatio: 1,
        ),
        itemCount: rows * 7,
        itemBuilder: (_, index) {
          final dayNum = index - startOffset + 1;
          if (dayNum < 1 || dayNum > daysInMonth) return const SizedBox.shrink();
          
          final day = DateTime(_focusedDay.year, _focusedDay.month, dayNum);
          final isSelected = _isSameDay(day, _selectedDay);
          final isToday = _isSameDay(day, DateTime.now());
          final colors = _getDayColors(day);

          return InkWell(
            onTap: () => setState(() => _selectedDay = day),
            child: Container(
              margin: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: isSelected ? AppTheme.primary.withOpacity(0.1) : null,
                borderRadius: BorderRadius.circular(8),
                border: isSelected ? Border.all(color: AppTheme.primary, width: 1.5) : (isToday ? Border.all(color: AppTheme.primary.withOpacity(0.3)) : null),
              ),
              child: Stack(
                children: [
                   Center(
                    child: Text(
                      '$dayNum',
                      style: TextStyle(
                        fontWeight: isSelected || isToday ? FontWeight.bold : FontWeight.normal,
                        color: isSelected ? AppTheme.primary : AppTheme.textMain,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  if (colors.isNotEmpty)
                    Positioned(
                      bottom: 4,
                      left: 0,
                      right: 0,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: colors.map((c) => Container(
                          width: 6,
                          height: 6,
                          margin: const EdgeInsets.symmetric(horizontal: 1),
                          decoration: BoxDecoration(color: c, shape: BoxShape.circle),
                        )).toList(),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDayDetails() {
    final dayPlans = _getPlansForDay(_selectedDay);
    if (dayPlans.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_busy, size: 48, color: AppTheme.textSub.withOpacity(0.3)),
            const SizedBox(height: 12),
            Text(tr('Bu gün için planlanmış iş bulunmuyor.'), style: const TextStyle(color: AppTheme.textSub)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: dayPlans.length,
      itemBuilder: (context, index) {
        final plan = dayPlans[index];
        final order = plan['order'] ?? {};
        final deptName = order['department']?['name'] ?? tr('Genel');
        final color = _getServiceColor(deptName);
        final personnel = plan['operation_plan_personnel'] as List? ?? [];
        
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ExpansionTile(
            leading: Container(
              width: 12,
              height: 40,
              decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
            ),
            title: Text(order['title'] ?? tr('İsimsiz Sipariş'), style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('${plan['start_time']} - ${plan['end_time']} | $deptName'),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Divider(),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.location_on, size: 16, color: AppTheme.textSub),
                        const SizedBox(width: 8),
                        Expanded(child: Text(order['site_address'] ?? tr('Konum belirsiz'), style: const TextStyle(fontSize: 13))),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text('${tr('Çalışan Personeller')} (${personnel.length}):', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    const SizedBox(height: 6),
                    ...personnel.map((p) {
                      final u = p['users'] ?? {};
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          children: [
                            const Icon(Icons.person, size: 14, color: AppTheme.primary),
                            const SizedBox(width: 8),
                            Text('${u['first_name']} ${u['last_name']}', style: const TextStyle(fontSize: 13)),
                            if (p['is_supervisor'] == true)
                              Padding(
                                padding: const EdgeInsets.only(left: 8),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                  decoration: BoxDecoration(color: AppTheme.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                                  child: const Text('Supervisor', style: TextStyle(fontSize: 10, color: AppTheme.primary, fontWeight: FontWeight.bold)),
                                ),
                              ),
                          ],
                        ),
                      );
                    }).toList(),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}

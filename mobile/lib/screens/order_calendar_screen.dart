import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import '../providers/app_state.dart';
import '../services/localization_service.dart';

class OrderCalendarScreen extends StatelessWidget {
  const OrderCalendarScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(tr('İş Takvimi')),
      ),
      body: const OrderCalendarWidget(showHeader: true),
    );
  }
}

class OrderCalendarWidget extends StatefulWidget {
  final bool showHeader;
  const OrderCalendarWidget({super.key, this.showHeader = true});

  @override
  State<OrderCalendarWidget> createState() => _OrderCalendarWidgetState();
}

class _OrderCalendarWidgetState extends State<OrderCalendarWidget> {
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
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final appState = Provider.of<AppState>(context, listen: false);
      final startOfMonth = DateTime(_focusedDay.year, _focusedDay.month, 1);
      final endOfMonth = DateTime(_focusedDay.year, _focusedDay.month + 1, 0);

      final departmentId = appState.isBereichsleiter ? appState.departmentId : null;
      
      final plans = await SupabaseService.getOperationPlans(
        dateFrom: startOfMonth,
        dateTo: endOfMonth,
        departmentId: departmentId,
      );

      if (mounted) {
        setState(() {
          _plans = plans;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('[OrderCalendar] Error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Color _getServiceColor(String departmentName) {
    final name = departmentName.toLowerCase();
    if (name.contains('ray') || name.contains('gleis')) return AppTheme.orderServiceColors['ray-servis']!;
    if (name.contains('hausmeister')) return AppTheme.orderServiceColors['hausmeister']!;
    if (name.contains('gebäud')) return AppTheme.orderServiceColors['gebaeude']!;
    if (name.contains('garten')) return AppTheme.orderServiceColors['garten']!;
    if (name.contains('logistik')) return AppTheme.orderServiceColors['logistik']!;
    if (name.contains('gast') || name.contains('gastro') || name.contains('hospitality')) return AppTheme.orderServiceColors['hospitality']!;
    if (name.contains('personal')) return AppTheme.orderServiceColors['personal']!;
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

  @override
  Widget build(BuildContext context) {
    final monthStr = DateFormat('MMMM yyyy', Localizations.localeOf(context).toString()).format(_focusedDay);

    return Column(
      children: [
        if (widget.showHeader) _buildMonthHeader(monthStr),
        
        if (_isLoading)
          const Expanded(child: Center(child: CircularProgressIndicator()))
        else ...[
          _buildDayHeaders(),
          _buildCalendarGrid(),
          const Divider(height: 1),
          // Seçili Gün Başlığı
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            color: AppTheme.primary.withOpacity(0.05),
            child: Text(
              '${_selectedDay.day}.${_selectedDay.month}.${_selectedDay.year} - ${tr('Tagesplan')}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.primary),
            ),
          ),
          Expanded(child: _buildDayDetails()),
        ],
      ],
    );
  }

  Widget _buildMonthHeader(String monthStr) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      decoration: BoxDecoration(
        color: AppTheme.primary,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4)],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left, color: Colors.white, size: 20),
            onPressed: () {
              setState(() => _focusedDay = DateTime(_focusedDay.year, _focusedDay.month - 1));
              _loadData();
            },
          ),
          Text(
            monthStr.toUpperCase(),
            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.1),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right, color: Colors.white, size: 20),
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
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: labels.map((d) => Expanded(
          child: Text(d, textAlign: TextAlign.center, style: const TextStyle(color: AppTheme.textSub, fontSize: 11, fontWeight: FontWeight.bold))
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
          childAspectRatio: 1.1,
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
              margin: const EdgeInsets.all(1),
              decoration: BoxDecoration(
                color: isSelected ? AppTheme.primary.withOpacity(0.05) : null,
                borderRadius: BorderRadius.circular(6),
                border: isSelected ? Border.all(color: AppTheme.primary, width: 1.2) : (isToday ? Border.all(color: AppTheme.primary.withOpacity(0.2)) : null),
              ),
              child: Stack(
                children: [
                   Center(
                    child: Text(
                      '$dayNum',
                      style: TextStyle(
                        fontWeight: isSelected || isToday ? FontWeight.bold : FontWeight.normal,
                        color: isSelected ? AppTheme.primary : AppTheme.textMain,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  if (colors.isNotEmpty)
                    Positioned(
                      bottom: 2,
                      left: 0,
                      right: 0,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: colors.take(3).map((c) => Container(
                          width: 4,
                          height: 4,
                          margin: const EdgeInsets.symmetric(horizontal: 0.5),
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
            Icon(Icons.event_busy, size: 32, color: AppTheme.textSub.withOpacity(0.2)),
            const SizedBox(height: 8),
            Text(tr('Plan yok'), style: const TextStyle(color: AppTheme.textSub, fontSize: 12)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: dayPlans.length,
      itemBuilder: (context, index) {
        final plan = dayPlans[index];
        final order = plan['order'] ?? {};
        final deptName = order['department']?['name'] ?? tr('Genel');
        final color = _getServiceColor(deptName);
        final personnel = plan['operation_plan_personnel'] as List? ?? [];
        
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(color: AppTheme.divider.withOpacity(0.5)),
          ),
          child: ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(horizontal: 12),
            leading: Container(
              width: 4,
              height: 24,
              decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
            ),
            title: Text(
              order['title'] ?? tr('İsimsiz Sipariş'), 
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              '${plan['start_time']} - ${plan['end_time']} | $deptName',
              style: const TextStyle(fontSize: 11),
            ),
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
                        const Icon(Icons.location_on, size: 14, color: AppTheme.textSub),
                        const SizedBox(width: 8),
                        Expanded(child: Text(order['site_address'] ?? tr('Konum belirsiz'), style: const TextStyle(fontSize: 12))),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text('${tr('Personeller')} (${personnel.length}):', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                    const SizedBox(height: 4),
                    ...personnel.map((p) {
                      final u = p['users'] ?? {};
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Row(
                          children: [
                            const Icon(Icons.person, size: 12, color: AppTheme.primary),
                            const SizedBox(width: 8),
                            Text('${u['first_name']} ${u['last_name']}', style: const TextStyle(fontSize: 12)),
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

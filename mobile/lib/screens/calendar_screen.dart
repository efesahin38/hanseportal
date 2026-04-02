import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import '../theme/web_utils.dart';
import '../providers/app_state.dart';
import '../services/localization_service.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  List<Map<String, dynamic>> _events = [];
  List<Map<String, dynamic>> _plans = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final appState = context.read<AppState>();
    setState(() => _loading = true);
    try {
      final departmentId = appState.isBereichsleiter ? appState.departmentId : null;
      final from = DateTime(_focusedDay.year, _focusedDay.month, 1);
      final to = DateTime(_focusedDay.year, _focusedDay.month + 1, 0);

      final events = await SupabaseService.getCalendarEvents(from: from, to: to);
      final plans = await SupabaseService.getOperationPlans(
        dateFrom: from,
        dateTo: to,
        departmentId: departmentId,
      );

      if (mounted) {
        setState(() {
          _events = events;
          _plans = plans;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> _getItemsForDay(DateTime day) {
    final dateStr = '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
    final dayEvents = _events.where((e) => (e['event_date'] ?? '').toString().startsWith(dateStr)).toList();
    final dayPlans = _plans.where((p) => (p['plan_date'] ?? '').toString().startsWith(dateStr)).toList();
    return [...dayEvents.map((e) => {...e, '_type': 'event'}), ...dayPlans.map((p) => {...p, '_type': 'plan'})];
  }

  bool _hasItems(DateTime day) => _getItemsForDay(day).isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final selectedItems = _getItemsForDay(_selectedDay);

    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        toolbarHeight: kIsWeb ? 80 : 120, // Adjust height as needed for the content
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
          decoration: AppTheme.gradientBox(),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left, color: Colors.white),
                    onPressed: () {
                      setState(() {
                        _focusedDay = DateTime(_focusedDay.year, _focusedDay.month - 1);
                        _selectedDay = DateTime(_focusedDay.year, _focusedDay.month, 1);
                      });
                      _load();
                    },
                  ),
                  Text(
                    _monthLabel(_focusedDay),
                    style: TextStyle(color: Colors.white, fontSize: kIsWeb ? 20 : 18, fontWeight: FontWeight.bold, fontFamily: 'Inter'),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right, color: Colors.white),
                    onPressed: () {
                      setState(() {
                        _focusedDay = DateTime(_focusedDay.year, _focusedDay.month + 1);
                        _selectedDay = DateTime(_focusedDay.year, _focusedDay.month, 1);
                      });
                      _load();
                    },
                  ),
                ],
              ),
              if (!kIsWeb) ...[
                const SizedBox(height: 8),
                // Gün başlıkları - Mobile only (Web shows it inside grid)
                Row(
                  children: [
                    tr('Pzt'),
                    tr('Sal'),
                    tr('Çar'),
                    tr('Per'),
                    tr('Cum'),
                    tr('Cmt'),
                    tr('Paz')
                  ]
                      .map((d) => Expanded(
                            child: Text(d,
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: Colors.white70, fontSize: 12, fontFamily: 'Inter')),
                          ))
                      .toList(),
                ),
              ],
            ],
          ),
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth > 800;
          
          if (isWide) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left: Calendar Grid
                SizedBox(
                  width: 450,
                  child: Column(
                    children: [
                      _buildWebDayHeaders(),
                      _buildCalendarGrid(),
                      const Spacer(),
                    ],
                  ),
                ),
                const VerticalDivider(width: 1),
                // Right: Events
                Expanded(
                  child: Column(
                    children: [
                      _buildSelectedDayHeader(selectedItems),
                      Expanded(child: _buildEventList(selectedItems)),
                    ],
                  ),
                ),
              ],
            );
          }

          return Column(
            children: [
              _buildCalendarGrid(),
              const SizedBox(height: 4),
              _buildSelectedDayHeader(selectedItems),
              Expanded(child: _buildEventList(selectedItems)),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddEventDialog(),
        backgroundColor: AppTheme.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text(tr('Etkinlik Ekle'), style: const TextStyle(color: Colors.white, fontFamily: 'Inter')),
      ),
    );
  }

  Widget _buildWebDayHeaders() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          tr('Pzt'),
          tr('Sal'),
          tr('Çar'),
          tr('Per'),
          tr('Cum'),
          tr('Cmt'),
          tr('Paz')
        ]
            .map((d) => Expanded(
                  child: Text(d,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppTheme.textSub, fontSize: 13, fontWeight: FontWeight.bold, fontFamily: 'Inter')),
                ))
            .toList(),
      ),
    );
  }

  Widget _buildSelectedDayHeader(List<Map<String, dynamic>> selectedItems) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          Text(
            _dayLabel(_selectedDay),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'Inter'),
          ),
          if (selectedItems.isNotEmpty) ...[
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
              decoration: BoxDecoration(color: AppTheme.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
              child: Text('${selectedItems.length} ${tr('Etkinlik')}', style: const TextStyle(fontSize: 12, color: AppTheme.primary, fontWeight: FontWeight.bold)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEventList(List<Map<String, dynamic>> selectedItems) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (selectedItems.isEmpty) {
      return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.event_busy_outlined, size: 64, color: AppTheme.textSub.withOpacity(0.2)),
          const SizedBox(height: 16),
          Text(tr('Bu gün için aktivite yok'), style: const TextStyle(color: AppTheme.textSub, fontSize: 16, fontFamily: 'Inter')),
        ]),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: selectedItems.length,
      itemBuilder: (_, i) => _CalendarItemCard(item: selectedItems[i]),
    );
  }

  Widget _buildCalendarGrid() {
    final firstDay = DateTime(_focusedDay.year, _focusedDay.month, 1);
    final daysInMonth = DateTime(_focusedDay.year, _focusedDay.month + 1, 0).day;
    // Pazartesi = 1, Pazar = 7 → offset
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
          mainAxisSpacing: 4,
          crossAxisSpacing: 4,
        ),
        itemCount: rows * 7,
          itemBuilder: (_, index) {
            final dayNum = index - startOffset + 1;
            if (dayNum < 1 || dayNum > daysInMonth) return const SizedBox.shrink();
            final day = DateTime(_focusedDay.year, _focusedDay.month, dayNum);
            final isSelected = _isSameDay(day, _selectedDay);
            final isToday = _isSameDay(day, DateTime.now());
            final hasItems = _hasItems(day);
  
            return InkWell(
              onTap: () => setState(() => _selectedDay = day),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                margin: const EdgeInsets.all(1),
                decoration: BoxDecoration(
                  color: isSelected ? AppTheme.primary : isToday ? AppTheme.primary.withOpacity(0.08) : null,
                  borderRadius: BorderRadius.circular(12),
                  border: isToday && !isSelected ? Border.all(color: AppTheme.primary.withOpacity(0.3)) : null,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '$dayNum',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: isToday || isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected ? Colors.white : isToday ? AppTheme.primary : AppTheme.textMain,
                        fontFamily: 'Inter',
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (hasItems)
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isSelected ? Colors.white : AppTheme.accent,
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

  bool _isSameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

  String _monthLabel(DateTime d) {
    const months = ['Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran', 'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık'];
    return '${tr(months[d.month - 1])} ${d.year}';
  }

  String _dayLabel(DateTime d) {
    const days = ['', 'Pazartesi', 'Salı', 'Çarşamba', 'Perşembe', 'Cuma', 'Cumartesi', 'Pazar'];
    const months = ['', 'Oca', 'Şub', 'Mar', 'Nis', 'May', 'Haz', 'Tem', 'Ağu', 'Eyl', 'Eki', 'Kas', 'Ara'];
    return '${tr(days[d.weekday])}, ${d.day} ${tr(months[d.month])}';
  }

  Future<void> _showAddEventDialog() async {
    final titleCtrl = TextEditingController();
    DateTime selectedDate = _selectedDay;
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('Yeni Etkinlik'), style: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            controller: titleCtrl,
            decoration: InputDecoration(labelText: tr('Başlık'), border: const OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          Text('${tr('Tarih')}: ${selectedDate.day}/${selectedDate.month}/${selectedDate.year}',
              style: const TextStyle(fontFamily: 'Inter', color: AppTheme.textSub)),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(tr('İptal'))),
          ElevatedButton(
            onPressed: () async {
              if (titleCtrl.text.isNotEmpty) {
                await SupabaseService.createCalendarEvent({
                  'title': titleCtrl.text.trim(),
                  'event_date': '${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}',
                });
                if (ctx.mounted) Navigator.pop(ctx);
                _load();
              }
            },
            child: Text(tr('Kaydet')),
          ),
        ],
      ),
    );
  }
}

class _CalendarItemCard extends StatelessWidget {
  final Map<String, dynamic> item;
  const _CalendarItemCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final isPlan = item['_type'] == 'plan';
    final color = isPlan ? AppTheme.accent : AppTheme.primary;
    final icon = isPlan ? Icons.engineering : Icons.event;
    final title = isPlan
        ? (item['order']?['title'] ?? item['title'] ?? tr('Operasyon Planı'))
        : (item['title'] ?? tr('Etkinlik'));
    final subtitle = isPlan
        ? '${item['start_time'] ?? ''} – ${item['end_time'] ?? ''} | ${item['order']?['customer']?['name'] ?? ''}'
        : (item['description'] ?? '');

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: color, size: 20),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, fontFamily: 'Inter')),
        subtitle: subtitle.isNotEmpty
            ? Text(subtitle, style: const TextStyle(fontSize: 12, color: AppTheme.textSub, fontFamily: 'Inter'))
            : null,
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
          child: Text(
            isPlan ? tr('Plan') : tr('Etkinlik'),
            style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600, fontFamily: 'Inter'),
          ),
        ),
      ),
    );
  }
}

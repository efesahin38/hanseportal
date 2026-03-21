import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import 'shift_plan_create_screen.dart';

class CompanyDetailScreen extends StatefulWidget {
  final String companyId;
  final String companyName;
  const CompanyDetailScreen({Key? key, required this.companyId, required this.companyName}) : super(key: key);

  @override
  State<CompanyDetailScreen> createState() => _CompanyDetailScreenState();
}

class _CompanyDetailScreenState extends State<CompanyDetailScreen> with SingleTickerProviderStateMixin {
  List<dynamic> _plans = [];
  bool _isLoading = true;
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _loadPlans();
  }

  @override
  void dispose() { _tabCtrl.dispose(); super.dispose(); }

  Future<void> _loadPlans() async {
    setState(() => _isLoading = true);
    final appState = context.read<AppState>();
    try {
      final plans = await appState.apiService.getCompanyPlans(widget.companyId);
      setState(() { _plans = plans; _isLoading = false; });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  List<dynamic> get _pending  => _plans.where((p) => p['status'] == 'pending').toList();
  List<dynamic> get _approved => _plans.where((p) => p['status'] == 'approved').toList();
  List<dynamic> get _rejected => _plans.where((p) => p['status'] == 'rejected').toList();

  Future<void> _deletePlan(String planId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(children: [Icon(Icons.delete, color: Colors.red), SizedBox(width: 8), Text('Planı Sil')]),
        content: const Text('Bu vardiya planını ve tüm atamalarını silmek istediğinizden emin misiniz?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('İptal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Evet, Sil', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final appState = context.read<AppState>();
    try {
      await appState.apiService.deletePlan(planId, appState.currentUser!['id']);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('🗑️ Plan silindi.'), backgroundColor: Colors.red));
      _loadPlans();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: Colors.red));
    }
  }

  // === ÖZELLİK 2: Geriye dönük saat düzenleme ===
  Future<void> _adjustShiftTimes(dynamic assignment, String workDate) async {
    // Mevcut actual_start ve actual_end'i parse et
    DateTime? currentStart, currentEnd;
    if (assignment['actual_start'] != null) currentStart = DateTime.parse(assignment['actual_start']).toLocal();
    if (assignment['actual_end']   != null) currentEnd   = DateTime.parse(assignment['actual_end']).toLocal();

    TimeOfDay startTOD = currentStart != null ? TimeOfDay(hour: currentStart.hour, minute: currentStart.minute) : const TimeOfDay(hour: 8, minute: 0);
    TimeOfDay endTOD   = currentEnd   != null ? TimeOfDay(hour: currentEnd.hour,   minute: currentEnd.minute)   : const TimeOfDay(hour: 17, minute: 0);

    // Dialog ile saat seç
    final result = await showDialog<Map<String, TimeOfDay>>(
      context: context,
      builder: (ctx) {
        TimeOfDay localStart = startTOD;
        TimeOfDay localEnd   = endTOD;
        return StatefulBuilder(
          builder: (ctx2, setSt) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(children: [Icon(Icons.edit_calendar, color: Color(0xFF4F46E5)), SizedBox(width: 8), Text('Saati Düzenle')]),
                const SizedBox(height: 4),
                Text(assignment['worker_name'] ?? '', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.normal, color: Colors.grey)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.play_arrow, color: Colors.green),
                  title: const Text('Başlangıç', style: TextStyle(fontWeight: FontWeight.w600)),
                  trailing: Text('${localStart.hour.toString().padLeft(2,'0')}:${localStart.minute.toString().padLeft(2,'0')}',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF4F46E5))),
                  onTap: () async {
                    final t = await showTimePicker(context: ctx2, initialTime: localStart, builder: (c, child) => MediaQuery(data: MediaQuery.of(c).copyWith(alwaysUse24HourFormat: true), child: child!));
                    if (t != null) setSt(() => localStart = t);
                  },
                ),
                const Divider(),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.stop, color: Colors.red),
                  title: const Text('Bitiş', style: TextStyle(fontWeight: FontWeight.w600)),
                  trailing: Text('${localEnd.hour.toString().padLeft(2,'0')}:${localEnd.minute.toString().padLeft(2,'0')}',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red)),
                  onTap: () async {
                    final t = await showTimePicker(context: ctx2, initialTime: localEnd, builder: (c, child) => MediaQuery(data: MediaQuery.of(c).copyWith(alwaysUse24HourFormat: true), child: child!));
                    if (t != null) setSt(() => localEnd = t);
                  },
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, null), child: const Text('İptal')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4F46E5)),
                onPressed: () => Navigator.pop(ctx, {'start': localStart, 'end': localEnd}),
                child: const Text('Kaydet', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
      },
    );

    if (result == null) return;

    final appState = context.read<AppState>();
    try {
      final base = DateTime.parse(workDate);
      final newStart = DateTime(base.year, base.month, base.day, result['start']!.hour, result['start']!.minute);
      final newEnd   = DateTime(base.year, base.month, base.day, result['end']!.hour,   result['end']!.minute);
      await appState.apiService.adjustShiftTimes(
        assignment['id'] ?? '',
        appState.currentUser!['id'],
        actualStart: newStart.toUtc().toIso8601String(),
        actualEnd:   newEnd.toUtc().toIso8601String(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Saat güncellendi!'), backgroundColor: Colors.green));
      _loadPlans();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.read<AppState>().currentUser;
    final canCreate = user != null && (user['role'] == 'super_admin' || user['role'] == 'manager');

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFF),
      appBar: AppBar(
        backgroundColor: const Color(0xFF4F46E5),
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.companyName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
            const Text('Vardiya Planları', style: TextStyle(fontSize: 11, color: Colors.white70)),
          ],
        ),
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _loadPlans)],
        bottom: TabBar(
          controller: _tabCtrl,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: [
            Tab(text: 'Bekleyen (${_pending.length})'),
            Tab(text: 'Onaylı (${_approved.length})'),
            Tab(text: 'Reddedilen (${_rejected.length})'),
          ],
        ),
      ),
      body: _isLoading
        ? const Center(child: CircularProgressIndicator(color: Color(0xFF4F46E5)))
        : RefreshIndicator(
            onRefresh: _loadPlans,
            child: TabBarView(
              controller: _tabCtrl,
              children: [
                _buildPlanList(_pending, Colors.orange),
                _buildPlanList(_approved, Colors.green),
                _buildPlanList(_rejected, Colors.red),
              ],
            ),
          ),
      floatingActionButton: canCreate
          ? FloatingActionButton.extended(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => ShiftPlanCreateScreen(targetCompanyId: widget.companyId)),
                ).then((_) => _loadPlans());
              },
              backgroundColor: const Color(0xFF4F46E5),
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text('Yeni Plan', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            )
          : null,
    );
  }

  Widget _buildPlanList(List<dynamic> plans, Color accentColor) {
    if (plans.isEmpty) {
      return Center(child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.event_busy, size: 60, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          const Text('Bu kategoride plan yok.', style: TextStyle(color: Colors.grey)),
        ],
      ));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: plans.length,
      itemBuilder: (ctx, i) {
        final plan = plans[i];
        final assignments = List<dynamic>.from(plan['shift_assignments'] ?? []);
        final leader = assignments.firstWhere((a) => a['role_in_shift'] == 'leader', orElse: () => null);
        final workers = assignments.where((a) => a['role_in_shift'] != 'leader').toList();
        final isActive = assignments.any((a) => a['shift_status'] == 'active');
        final isDone = assignments.isNotEmpty && assignments.every((a) => a['shift_status'] == 'completed');
        final user = context.read<AppState>().currentUser;

        return Container(
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: isActive ? Border.all(color: Colors.green, width: 2) : null,
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
          ),
          child: Column(
            children: [
              // Header strip
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.1),
                  borderRadius: const BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.calendar_month, size: 16, color: accentColor),
                    const SizedBox(width: 8),
                    Text(plan['work_date'] ?? '', style: TextStyle(fontWeight: FontWeight.bold, color: accentColor)),
                    const SizedBox(width: 8),
                    Text('${(plan['start_time'] ?? '').substring(0, 5)} - ${(plan['end_time'] ?? '').substring(0, 5)}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    const Spacer(),
                    if (isActive) Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: Colors.green.shade100, borderRadius: BorderRadius.circular(8)),
                      child: Row(children: [
                        Container(width: 7, height: 7, decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle)),
                        const SizedBox(width: 4),
                        const Text('AKTİF', style: TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.bold)),
                      ]),
                    ) else if (isDone) const Icon(Icons.check_circle, color: Colors.green, size: 18),
                  ],
                ),
              ),
              // Body
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (leader != null) ...[
                      Builder(builder: (context) {
                        final canAdjustLeader = (user?['role'] == 'super_admin' || user?['role'] == 'manager') && leader['shift_status'] == 'completed';
                        return Row(
                          children: [
                            const Icon(Icons.star, size: 16, color: Colors.amber),
                            const SizedBox(width: 6),
                            Expanded(child: Text(leader['worker_name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold))),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: Colors.amber.shade100, borderRadius: BorderRadius.circular(6)),
                              child: Text('LİDER', style: TextStyle(fontSize: 10, color: Colors.amber.shade800, fontWeight: FontWeight.bold)),
                            ),
                            const SizedBox(width: 6),
                            _shiftStatusBadge(leader['shift_status']),
                            if (canAdjustLeader) ...[
                              const SizedBox(width: 6),
                              GestureDetector(
                                onTap: () => _adjustShiftTimes(leader, plan['work_date']),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                  decoration: BoxDecoration(color: const Color(0xFF4F46E5).withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                                    Icon(Icons.edit, size: 11, color: Color(0xFF4F46E5)),
                                    SizedBox(width: 3),
                                    Text('Düzenle', style: TextStyle(fontSize: 10, color: Color(0xFF4F46E5), fontWeight: FontWeight.bold)),
                                  ]),
                                ),
                              ),
                            ],
                          ],
                        );
                      }),
                      if (leader['exit_note'] != null && (leader['exit_note'] as String).isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(left: 22, top: 3, bottom: 4),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.orange.shade200)),
                            child: Row(children: [
                              const Icon(Icons.note_alt_outlined, size: 11, color: Colors.orange),
                              const SizedBox(width: 4),
                              Expanded(child: Text(leader['exit_note'], style: const TextStyle(fontSize: 11, color: Colors.orange))),
                            ]),
                          ),
                        ),
                    ],
                    if (workers.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      ...workers.map((w) {
                        final canAdjust = (user?['role'] == 'super_admin' || user?['role'] == 'manager') && w['shift_status'] == 'completed';
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                const Icon(Icons.person, size: 16, color: Colors.grey),
                                const SizedBox(width: 6),
                                Expanded(child: Text(w['worker_name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w500))),
                                _shiftStatusBadge(w['shift_status']),
                                if (canAdjust) ...[
                                  const SizedBox(width: 6),
                                  GestureDetector(
                                    onTap: () => _adjustShiftTimes(w, plan['work_date']),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                      decoration: BoxDecoration(color: const Color(0xFF4F46E5).withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                                      child: const Row(mainAxisSize: MainAxisSize.min, children: [
                                        Icon(Icons.edit, size: 11, color: Color(0xFF4F46E5)),
                                        SizedBox(width: 3),
                                        Text('Düzenle', style: TextStyle(fontSize: 10, color: Color(0xFF4F46E5), fontWeight: FontWeight.bold)),
                                      ]),
                                    ),
                                  ),
                                ],
                              ]),
                              if (w['exit_note'] != null && (w['exit_note'] as String).isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(left: 22, top: 3, bottom: 2),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.orange.shade200)),
                                    child: Row(children: [
                                      const Icon(Icons.note_alt_outlined, size: 11, color: Colors.orange),
                                      const SizedBox(width: 4),
                                      Expanded(child: Text(w['exit_note'], style: const TextStyle(fontSize: 11, color: Colors.orange))),
                                    ]),
                                  ),
                                ),
                            ],
                          ),
                        );
                      }).toList(),
                    ],
                    if (plan['status'] == 'rejected' && plan['rejection_note'] != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(10)),
                        child: Row(children: [
                          const Icon(Icons.info_outline, color: Colors.red, size: 14),
                          const SizedBox(width: 6),
                          Expanded(child: Text(plan['rejection_note'], style: const TextStyle(color: Colors.red, fontSize: 12))),
                        ]),
                      ),
                    ],
                    // Delete button (only non-active plans)
                    if (user?['role'] == 'super_admin' && !isActive) ...[
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: () => _deletePlan(plan['id']),
                          icon: const Icon(Icons.delete_outline, size: 16),
                          label: const Text('Planı Sil', style: TextStyle(fontSize: 12)),
                          style: TextButton.styleFrom(foregroundColor: Colors.red),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _shiftStatusBadge(String? status) {
    Color c; String label;
    switch (status) {
      case 'active': c = Colors.green; label = 'Sahada'; break;
      case 'completed': c = Colors.grey; label = 'Bitti'; break;
      default: c = Colors.blue; label = 'Bekliyor';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: c.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
      child: Text(label, style: TextStyle(color: c, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }
}

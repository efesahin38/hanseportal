import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'dart:typed_data';
import '../theme/app_theme.dart';
import '../theme/web_utils.dart';
import '../providers/app_state.dart';
import '../services/supabase_service.dart';
import '../services/localization_service.dart';
import 'order_detail_screen.dart';

/// Mitarbeiter / Vorarbeiter – kendi görevleri
class FieldMyTasksScreen extends StatefulWidget {
  const FieldMyTasksScreen({super.key});

  @override
  State<FieldMyTasksScreen> createState() => _FieldMyTasksScreenState();
}

class _FieldMyTasksScreenState extends State<FieldMyTasksScreen> {
  List<Map<String, dynamic>> _plans = [];
  Map<String, dynamic>? _activeSession;
  // planId -> completed session (actual_start, actual_end)
  Map<String, Map<String, dynamic>> _completedSessions = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final appState = context.read<AppState>();
    try {
      final now = DateTime.now();
      final plans = await SupabaseService.getOperationPlans(
        userId: appState.userId,
        dateFrom: DateTime(now.year, now.month, now.day),
        dateTo: now.add(const Duration(days: 14)),
      );
      final session = await SupabaseService.getActiveSession(appState.userId);
      // Fetch recent completed sessions for this user (past & future matching plans)
      final completedRaw = await SupabaseService.getRecentCompletedSessions(appState.userId);
      final completedMap = <String, Map<String, dynamic>>{};
      for (final s in completedRaw) {
        final planId = s['operation_plan_id']?.toString();
        if (planId != null) completedMap[planId] = s;
      }
      if (mounted) {
        setState(() {
          _plans = plans;
          _activeSession = session;
          _completedSessions = completedMap;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _startWork(Map<String, dynamic> plan) async {
    final appState = context.read<AppState>();
    
    // Calculate how many minutes late (now vs planned start)
    int delayMinutes = 0;
    final planDate = plan['plan_date']?.toString();
    final startTime = plan['start_time']?.toString();
    if (planDate != null && startTime != null) {
      final planned = DateTime.tryParse('${planDate}T${startTime}');
      if (planned != null) {
        final diff = DateTime.now().difference(planned);
        if (!diff.isNegative) delayMinutes = diff.inMinutes;
      }
    }
    
    try {
      await SupabaseService.startWorkSession(
        orderId: plan['order_id'],
        userId: appState.userId,
        operationPlanId: plan['id'],
        delayMinutes: delayMinutes > 0 ? delayMinutes : null,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('✅ ${tr('İşe başladınız!')}'), backgroundColor: AppTheme.success),
        );
        _load();
      }
    } catch (_) {}
  }

  Future<void> _endWork() async {
    if (_activeSession == null) return;
    final noteCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(tr('İşi Tamamla'), style: const TextStyle(fontFamily: 'Inter')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(tr('İşi tamamladığınızı onaylıyor musunuz?'), style: const TextStyle(fontFamily: 'Inter')),
            const SizedBox(height: 12),
            TextField(
              controller: noteCtrl,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: tr('Saha notu (opsiyonel)...'),
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(tr('Abbrechen'))),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: Text(tr('Tamamla'))),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await SupabaseService.endWorkSession(_activeSession!['id'], note: noteCtrl.text.trim());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('✅ ${tr('Çalışma tamamlandı! Onay bekliyor.')}'), backgroundColor: AppTheme.success),
        );
        _load();
      }
    } catch (_) {}
  }

  String _formatDate(String dateStr) {
    if (dateStr == 'Belirsiz') return dateStr;
    try {
      final dt = DateTime.parse(dateStr);
      final today = DateTime.now();
      final tomorrow = today.add(const Duration(days: 1));
      
      if (dt.year == today.year && dt.month == today.month && dt.day == today.day) {
        return tr('Bugünkü Görevlerim');
      }
      if (dt.year == tomorrow.year && dt.month == tomorrow.month && dt.day == tomorrow.day) {
        return tr('Yarınki Görevlerim');
      }
      return '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year} ${tr('Görevleri')}';
    } catch (_) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();

    // Grouping by date
    final Map<String, List<Map<String, dynamic>>> groupedPlans = {};
    for (var plan in _plans) {
      final date = plan['plan_date'] ?? 'Belirsiz';
      groupedPlans.putIfAbsent(date, () => []).add(plan);
    }

    return WebContentWrapper(
      child: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Aktif Seans ─────────────────────────
                    if (_activeSession != null) ...[
                      _ActiveSessionBanner(session: _activeSession!, onEnd: _endWork),
                      const SizedBox(height: 16),
                    ],
  
                    if (groupedPlans.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppTheme.divider),
                        ),
                        child: Center(child: Column(children: [
                          const Icon(Icons.event_available, size: 48, color: AppTheme.textSub),
                          const SizedBox(height: 8),
                          Text(tr('Planlanmış görev yok'), style: const TextStyle(color: AppTheme.textSub, fontFamily: 'Inter')),
                        ])),
                      )
                    else
                      ...groupedPlans.entries.map((group) {
                        final dateLabel = _formatDate(group.key);
                        final isToday = (group.key != 'Belirsiz' && DateTime.tryParse(group.key)?.day == DateTime.now().day);
                        
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(isToday ? Icons.today : Icons.event, size: 18, color: AppTheme.textSub),
                                const SizedBox(width: 6),
                                Text(dateLabel,
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'Inter')),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(color: AppTheme.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                                  child: Text('${group.value.length}', style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold, fontFamily: 'Inter')),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            ...group.value.map((plan) => _TaskCard(
                              plan: plan,
                              hasActiveSession: _activeSession != null,
                              completedSession: _completedSessions[plan['id']],
                              onStartWork: () => _startWork(plan),
                            )),
                            const SizedBox(height: 8), // Extra space between days
                          ],
                        );
                      }),
                  ],
                ),
              ),
      ),
    );
  }
}

class _ActiveSessionBanner extends StatefulWidget {
  final Map<String, dynamic> session;
  final VoidCallback onEnd;
  const _ActiveSessionBanner({required this.session, required this.onEnd});

  @override
  State<_ActiveSessionBanner> createState() => _ActiveSessionBannerState();
}

class _ActiveSessionBannerState extends State<_ActiveSessionBanner> {
  late final _startTime = _parseUtcSafe(widget.session['actual_start']);
  late final _ticker = Stream.periodic(
    const Duration(seconds: 15), (_) => DateTime.now(),
  ).asBroadcastStream();

  // Parses UTC timestamp safely regardless of whether it has Z suffix
  static DateTime? _parseUtcSafe(dynamic raw) {
    if (raw == null) return null;
    String s = raw.toString();
    // If no timezone info, treat as UTC
    if (!s.endsWith('Z') && !s.contains('+')) s = '${s}Z';
    return DateTime.tryParse(s)?.toLocal();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DateTime>(
      stream: _ticker,
      builder: (context, _) => _buildBanner(context),
    );
  }

  Widget _buildBanner(BuildContext context) {
    final session = widget.session;
    final order = session['order'];
    final op = session['operation_plan'];

    // Elapsed since actual start (always positive, counting up from 0)
    final elapsed = _startTime != null
        ? DateTime.now().difference(_startTime!)
        : Duration.zero;
    final safeElapsed = elapsed.isNegative ? Duration.zero : elapsed;
    final h = safeElapsed.inHours;
    final m = safeElapsed.inMinutes % 60;
    final elapsedText = h > 0 ? '$h ${tr('s')} $m ${tr('dk çalışılıyor')}' : '$m ${tr('dk çalışılıyor')}';

    // Delay at start (saved in DB)
    String? delayText;
    if (session['delay_minutes'] != null) {
      final dm = (session['delay_minutes'] as num).toInt();
      if (dm > 0) {
        final dh = dm ~/ 60;
        final dmin = dm % 60;
        delayText = dh > 0 ? '$dh ${tr('s')} $dmin ${tr('dk geç başlandı')}' : '$dmin ${tr('dk geç başlandı')}';
      }
    } else if (op != null && op['plan_date'] != null && op['start_time'] != null && _startTime != null) {
      final plannedStart = DateTime.tryParse('${op['plan_date']}T${op['start_time']}');
      if (plannedStart != null) {
        final delay = _startTime!.difference(plannedStart);
        if (!delay.isNegative && delay.inMinutes > 0) {
          final dh = delay.inHours;
          final dmin = delay.inMinutes % 60;
          delayText = dh > 0 ? '$dh ${tr('s')} $dmin ${tr('dk geç başlandı')}' : '$dmin ${tr('dk geç başlandı')}';
        }
      }
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [AppTheme.success, Color(0xFF1B5E20)]),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(children: [
            Icon(Icons.play_circle_filled, color: Colors.white, size: 20),
            SizedBox(width: 8),
            Text('Aktif Çalışma', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontFamily: 'Inter')),
          ]),
          const SizedBox(height: 8),
          Text(order?['title'] ?? '', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600, fontFamily: 'Inter')),
          if (order?['site_address'] != null) ...[
            const SizedBox(height: 4),
            Row(children: [
              const Icon(Icons.location_on_outlined, color: Colors.white70, size: 14),
              const SizedBox(width: 4),
              Expanded(child: Text(order!['site_address'], style: const TextStyle(color: Colors.white70, fontSize: 12, fontFamily: 'Inter'), maxLines: 1, overflow: TextOverflow.ellipsis)),
            ]),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(10)),
                    child: Text(elapsedText, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontFamily: 'Inter')),
                  ),
                  if (delayText != null) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: const Color(0xFFFF6B00).withOpacity(0.85), borderRadius: BorderRadius.circular(8)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 13),
                        const SizedBox(width: 4),
                        Text(delayText!, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12, fontFamily: 'Inter')),
                      ]),
                    ),
                  ],
                ],
              ),
              const Spacer(),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppTheme.success,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                onPressed: widget.onEnd,
                icon: const Icon(Icons.stop_circle_outlined, size: 18),
                label: Text(tr('Tamamla'), style: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TaskCard extends StatefulWidget {
  final Map<String, dynamic> plan;
  final bool hasActiveSession;
  final Map<String, dynamic>? completedSession;
  final VoidCallback onStartWork;
  const _TaskCard({
    required this.plan,
    required this.hasActiveSession,
    required this.onStartWork,
    this.completedSession,
  });

  @override
  State<_TaskCard> createState() => _TaskCardState();
}

class _TaskCardState extends State<_TaskCard> {
  final _descCtrl = TextEditingController();
  Uint8List? _photoBytes;
  bool _sending = false;

  @override
  void dispose() {
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final photo = await picker.pickImage(source: ImageSource.camera, imageQuality: 70);
    if (photo != null) {
      final bytes = await photo.readAsBytes();
      final compressed = await FlutterImageCompress.compressWithList(
        bytes,
        minWidth: 1024,
        minHeight: 1024,
        quality: 70,
      );
      setState(() => _photoBytes = compressed);
    }
  }

  Future<void> _sendUpdate() async {
    if (_descCtrl.text.isEmpty && _photoBytes == null) return;
    setState(() => _sending = true);
    try {
      final appState = context.read<AppState>();
      await SupabaseService.uploadSiteUpdate(
        orderId: widget.plan['order_id'],
        planId: widget.plan['id'],
        userId: appState.userId,
        description: _descCtrl.text.trim(),
        photoBytes: _photoBytes,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('✅ ${tr('Rapor başarıyla gönderildi')}'), backgroundColor: AppTheme.success),
        );
        setState(() {
          _descCtrl.clear();
          _photoBytes = null;
          _sending = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${tr('Fehler')}: $e'), backgroundColor: AppTheme.error),
        );
        setState(() => _sending = false);
      }
    }
  }

  // Compute how many minutes late compared to planned start time
  int _computeDelayMinutes(Map<String, dynamic> plan) {
    final planDate = plan['plan_date']?.toString();
    final startTime = plan['start_time']?.toString();
    if (planDate == null || startTime == null) return 0;
    final planned = DateTime.tryParse('${planDate}T${startTime}');
    if (planned == null) return 0;
    final diff = DateTime.now().difference(planned);
    return diff.inMinutes > 0 ? diff.inMinutes : 0;
  }

  @override
  Widget build(BuildContext context) {
    final plan = widget.plan;
    final op = plan['operation_plans'] as Map<String, dynamic>?;
    final order = plan['order'] ?? op?['order'];
    final customer = order?['customer'];
    final start = plan['start_time'] ?? op?['start_time'] ?? '';
    final end = plan['end_time'] ?? op?['end_time'] ?? '';
    final planDate = plan['plan_date']?.toString() ?? op?['plan_date']?.toString();

    // Determine task date status
    final now = DateTime.now();
    final planDt = DateTime.tryParse(planDate ?? '');
    bool isPast = false;
    bool isFuture = false;
    bool isToday = false;
    if (planDt != null) {
      final todayStart = DateTime(now.year, now.month, now.day);
      final pDay = DateTime(planDt.year, planDt.month, planDt.day);
      isToday = pDay.isAtSameMomentAs(todayStart);
      isPast = pDay.isBefore(todayStart);
      isFuture = pDay.isAfter(todayStart);
    } else {
      // If date is unknown, treat as past (safe default — no start button shown)
      isPast = true;
    }
    
    final bool isCompleted = widget.completedSession != null;

    // Compute current delay (only matters for today if not completed)
    int delayMinutes = 0;
    if (isToday && !isCompleted) {
      delayMinutes = _computeDelayMinutes({
        'plan_date': planDate,
        'start_time': start,
      });
    }
    final delayH = delayMinutes ~/ 60;
    final delayM = delayMinutes % 60;
    final delayText = delayMinutes > 0
        ? (delayH > 0 ? '$delayH ${tr('s')} $delayM ${tr('dk gecikti')}' : '$delayM ${tr('dk gecikti')}')
        : null;
    
    // Check if user is the supervisor
    final appState = context.watch<AppState>();
    final isSupervisor = plan['is_supervisor'] == true || 
                        plan['site_supervisor_id'] == appState.userId ||
                        op?['site_supervisor_id'] == appState.userId;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.divider),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)],
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => OrderDetailScreen(orderId: plan['order_id']),
            ),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: AppTheme.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.access_time, size: 14, color: AppTheme.primary),
                          const SizedBox(width: 4),
                          Text('$start${end.isNotEmpty ? ' – $end' : ''}',
                            style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w600, fontSize: 13, fontFamily: 'Inter')),
                        ]),
                      ),
                      if (delayText != null) ...[
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF6B00).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(7),
                            border: Border.all(color: const Color(0xFFFF6B00).withOpacity(0.4)),
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            const Icon(Icons.schedule, size: 12, color: Color(0xFFFF6B00)),
                            const SizedBox(width: 4),
                            Text(delayText!, style: const TextStyle(color: Color(0xFFFF6B00), fontWeight: FontWeight.bold, fontSize: 12, fontFamily: 'Inter')),
                          ]),
                        ),
                      ],
                    ],
                  ),
                  const Spacer(),
                  if (isSupervisor)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: AppTheme.success.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                      child: Text(tr('SAHA LİDERİ'), style: const TextStyle(color: AppTheme.success, fontSize: 10, fontWeight: FontWeight.bold, fontFamily: 'Inter')),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Text(order?['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16, fontFamily: 'Inter')),
              if (customer != null) ...[
                const SizedBox(height: 4),
                Row(children: [
                  const Icon(Icons.business, size: 14, color: AppTheme.textSub),
                  const SizedBox(width: 4),
                  Text(customer['name'] ?? '', style: const TextStyle(fontSize: 13, color: AppTheme.textSub, fontFamily: 'Inter')),
                ]),
              ],

              // ── Tamamlanmış seans: başlangıç & bitiş saati ───
              if (widget.completedSession != null) ...[
                const SizedBox(height: 8),
                Builder(builder: (ctx) {
                  final cs = widget.completedSession!;
                  final fmt = (dynamic raw) {
                    if (raw == null) return '--:--';
                    String s = raw.toString();
                    if (!s.endsWith('Z') && !s.contains('+')) s = '${s}Z';
                    final dt = DateTime.tryParse(s)?.toLocal();
                    if (dt == null) return '--:--';
                    return '${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}';
                  };
                  final actualStart = fmt(cs['actual_start']);
                  final actualEnd   = fmt(cs['actual_end']);
                  // Duration
                  String durText = '';
                  if (cs['actual_start'] != null && cs['actual_end'] != null) {
                    String s1 = cs['actual_start'].toString();
                    String s2 = cs['actual_end'].toString();
                    if (!s1.endsWith('Z') && !s1.contains('+')) s1 = '${s1}Z';
                    if (!s2.endsWith('Z') && !s2.contains('+')) s2 = '${s2}Z';
                    final st = DateTime.tryParse(s1);
                    final en = DateTime.tryParse(s2);
                    if (st != null && en != null) {
                      final dur = en.difference(st);
                      final dh = dur.inHours;
                      final dm = dur.inMinutes % 60;
                      durText = dh > 0 ? ' ($dh ${tr('s')} $dm ${tr('dk')})' : ' ($dm ${tr('dk')})';
                    }
                  }
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppTheme.success.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.success.withOpacity(0.25)),
                    ),
                    child: Row(children: [
                      const Icon(Icons.check_circle_outline, size: 14, color: AppTheme.success),
                      const SizedBox(width: 6),
                      Text(
                        '${tr('Başladı')}: $actualStart  →  ${tr('Bitti')}: $actualEnd$durText',
                        style: const TextStyle(fontSize: 12, color: AppTheme.success, fontWeight: FontWeight.w600, fontFamily: 'Inter'),
                      ),
                    ]),
                  );
                }),
              ],
              
              if (isSupervisor) ...[
                const Divider(height: 24),
                Text('${tr('Lider Paneli')}: ${tr('Saha Durum Bildir')}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, fontFamily: 'Inter')),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onTap: _pickPhoto,
                      child: Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: AppTheme.bg,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppTheme.divider),
                        ),
                        child: _photoBytes != null 
                          ? ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.memory(_photoBytes!, fit: BoxFit.cover))
                          : const Icon(Icons.camera_alt_outlined, color: AppTheme.textSub),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _descCtrl,
                        maxLines: 2,
                        style: const TextStyle(fontSize: 13, fontFamily: 'Inter'),
                        decoration: InputDecoration(
                          hintText: tr('Sahadan not yazın...'),
                          hintStyle: const TextStyle(fontSize: 12),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          suffixIcon: _sending 
                            ? const Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(strokeWidth: 2))
                            : IconButton(
                                icon: const Icon(Icons.send, color: AppTheme.primary, size: 20),
                                onPressed: _sendUpdate,
                              ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 14),
              Builder(
                builder: (context) {
                  // 1) Completed (any day that had a work session finished)
                  if (isCompleted) {
                    return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(color: AppTheme.success.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                      alignment: Alignment.center,
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.check_circle, color: AppTheme.success, size: 20),
                        const SizedBox(width: 8),
                        Text(tr('Tamamlandı'), style: const TextStyle(color: AppTheme.success, fontWeight: FontWeight.w600, fontSize: 15, fontFamily: 'Inter')),
                      ]),
                    );
                  }

                  // 2) Past day without a completed session → Çalışılmadı
                  if (isPast) {
                    return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                      alignment: Alignment.center,
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.cancel, color: Colors.red, size: 20),
                        const SizedBox(width: 8),
                        Text(tr('Çalışılmadı'), style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w600, fontSize: 15, fontFamily: 'Inter')),
                      ]),
                    );
                  }

                  // 3) Future day → plan only, no start button
                  if (isFuture) {
                    return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(color: AppTheme.textSub.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                      alignment: Alignment.center,
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.upcoming, color: AppTheme.textSub, size: 20),
                        const SizedBox(width: 8),
                        Text(tr('Planlanan Görev'), style: const TextStyle(color: AppTheme.textSub, fontWeight: FontWeight.w600, fontSize: 15, fontFamily: 'Inter')),
                      ]),
                    );
                  }

                  // 4) Today & not yet completed → İşe Başla
                  return SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: widget.hasActiveSession ? null : widget.onStartWork,
                      icon: const Icon(Icons.play_arrow, size: 20),
                      label: Text(
                        widget.hasActiveSession ? tr('Başka aktif görev var') : tr('İşe Başla'),
                        style: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600, fontSize: 15),
                      ),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

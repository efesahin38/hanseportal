import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import 'login_screen.dart';

class WorkerDashboardScreen extends StatefulWidget {
  @override
  _WorkerDashboardScreenState createState() => _WorkerDashboardScreenState();
}

String _safeTime(String? time) {
  if (time == null || time.length < 5) return time ?? '--:--';
  return time.substring(0, 5);
}

class _WorkerDashboardScreenState extends State<WorkerDashboardScreen> {
  List<dynamic> _shifts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadShifts();
  }

  Future<void> _loadShifts() async {
    setState(() => _isLoading = true);
    final appState = context.read<AppState>();
    try {
      final shifts = await appState.apiService.getMyShifts(appState.currentUser!['id']);
      setState(() { _shifts = shifts; _isLoading = false; });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  bool _isToday(String dateStr) {
    final today = DateTime.now();
    final d = DateTime.tryParse(dateStr);
    return d != null && d.year == today.year && d.month == today.month && d.day == today.day;
  }

  Future<void> _startShift(String assignmentId) async {
    final appState = context.read<AppState>();
    try {
      await appState.apiService.startShift(assignmentId, appState.currentUser!['id']);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Mesai başlatıldı!'), backgroundColor: Colors.green));
      _loadShifts();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceAll('Exception: ','')), backgroundColor: Colors.red));
    }
  }

  Future<void> _endShift(String assignmentId, String endTimeStr) async {
    // Planlanan bitiş saatini parse et (HH:mm:ss formatı)
    final now = DateTime.now();
    String? exitNote;

    try {
      final parts = endTimeStr.split(':');
      final plannedEnd = DateTime(now.year, now.month, now.day,
        int.parse(parts[0]), int.parse(parts[1]));
      final diffMinutes = now.difference(plannedEnd).inMinutes;
      const threshold = 5;

      if (diffMinutes < -threshold) {
        // ERKEN çıkış - açıklama iste
        final note = await _showExitNoteDialog(
          title: '⚠️ Erken Çıkış',
          subtitle: '${(-diffMinutes)} dakika erken çıkıyorsunuz.\nLütfen neden erken bittiğini açıklayın:',
          accentColor: Colors.orange,
        );
        if (note == null) return; // iptal etti
        exitNote = note;
      } else if (diffMinutes > threshold) {
        // GEÇ çıkış - açıklama iste
        final note = await _showExitNoteDialog(
          title: '⚠️ Geç Çıkış',
          subtitle: '$diffMinutes dakika geç çıkıyorsunuz.\nLütfen neden geç bittiğini açıklayın:',
          accentColor: Colors.red,
        );
        if (note == null) return; // iptal etti
        exitNote = note;
      } else {
        // Normal çıkış - sadece onay
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Row(children: [Icon(Icons.stop_circle, color: Colors.red), SizedBox(width: 10), Text('Mesayi Bitir')]),
            content: const Text('Mesainizi bitirmek istediğinizden emin misiniz?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hayır')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Evet, Bitir', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
        if (confirmed != true) return;
      }
    } catch (_) {
      // Saat parse edilemezse normal devam et
    }

    final appState = context.read<AppState>();
    try {
      await appState.apiService.endShift(assignmentId, appState.currentUser!['id'], exitNote: exitNote);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('🏁 Mesai tamamlandı!'), backgroundColor: Colors.orange));
      _loadShifts();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceAll('Exception: ','')), backgroundColor: Colors.red));
    }
  }

  Future<String?> _showExitNoteDialog({required String title, required String subtitle, required Color accentColor}) async {
    final ctrl = TextEditingController();
    return await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(title, style: TextStyle(color: accentColor, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: accentColor.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
              child: Text(subtitle, style: TextStyle(color: accentColor.withOpacity(0.8), fontSize: 13)),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: ctrl,
              autofocus: true,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Açıklama giriniz...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: accentColor, width: 2)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, null), child: const Text('İptal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: accentColor),
            onPressed: () {
              if (ctrl.text.trim().isEmpty) return;
              Navigator.pop(ctx, ctrl.text.trim());
            },
            child: const Text('Mesayi Bitir', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.read<AppState>().currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFF),
      appBar: AppBar(
        backgroundColor: const Color(0xFF4F46E5),
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Hoşgeldin, ${user?['name'] ?? ''}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const Text('Vardiyalarım', style: TextStyle(fontSize: 11, color: Colors.white70)),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadShifts),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await context.read<AppState>().logout();
              Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => LoginScreen()));
            },
          )
        ],
      ),
      body: _isLoading
        ? const Center(child: CircularProgressIndicator(color: Color(0xFF4F46E5)))
        : RefreshIndicator(
            onRefresh: _loadShifts,
            child: _shifts.isEmpty
              ? const Center(child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.event_busy, size: 72, color: Colors.grey),
                    SizedBox(height: 16),
                    Text('Henüz onaylı vardiya yok.', style: TextStyle(color: Colors.grey, fontSize: 16)),
                    SizedBox(height: 8),
                    Text('Yöneticiniz bir plan oluşturduktan\nsonra burada görünecek.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
                  ],
                ))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _shifts.length,
                  itemBuilder: (ctx, i) {
                    final shift = _shifts[i];
                    final today = _isToday(shift['work_date'] ?? '');
                    final status = shift['shift_status'] ?? 'assigned';
                    final role = shift['role_in_shift'] == 'leader' ? 'LİDER' : 'ÇALIŞAN';
                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(22),
                        border: today ? Border.all(color: const Color(0xFF4F46E5), width: 2) : null,
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]
                      ),
                      child: Column(
                        children: [
                          // Header
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(colors: today ? [const Color(0xFF4F46E5), const Color(0xFF7C3AED)] : [Colors.grey.shade400, Colors.grey.shade500]),
                              borderRadius: const BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.business, color: Colors.white70, size: 16),
                                const SizedBox(width: 6),
                                Expanded(child: Text(shift['company_name'] ?? shift['company_id'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16))),
                                if (today) Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.25), borderRadius: BorderRadius.circular(8)),
                                  child: const Text('BUGÜN', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
                                )
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                                    const SizedBox(width: 6),
                                    Text(shift['work_date'] ?? '', style: const TextStyle(fontWeight: FontWeight.w700)),
                                    const SizedBox(width: 16),
                                    const Icon(Icons.access_time, size: 16, color: Colors.grey),
                                    const SizedBox(width: 6),
                                    Text('${_safeTime(shift['start_time'])} - ${_safeTime(shift['end_time'])}', style: const TextStyle(fontWeight: FontWeight.w700)),
                                  ],
                                ),
                                if (shift['actual_start'] != null || shift['actual_end'] != null) ...[
                                  const SizedBox(height: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(10)),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.history, size: 14, color: Colors.orange),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Gerçekleşen: ${shift['actual_start'] != null ? (shift['actual_start'] as String).substring(11, 16) : '--:--'} - ${shift['actual_end'] != null ? (shift['actual_end'] as String).substring(11, 16) : '--:--'}',
                                          style: TextStyle(fontSize: 12, color: Colors.orange.shade900, fontWeight: FontWeight.bold),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Icon(shift['role_in_shift'] == 'leader' ? Icons.star : Icons.person, size: 16, color: shift['role_in_shift'] == 'leader' ? Colors.amber : Colors.grey),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: shift['role_in_shift'] == 'leader' ? Colors.amber.shade100 : Colors.blue.shade50,
                                        borderRadius: BorderRadius.circular(10)
                                      ),
                                      child: Text(role, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: shift['role_in_shift'] == 'leader' ? Colors.amber.shade800 : Colors.blue.shade700)),
                                    ),
                                    const Spacer(),
                                    _statusBadge(status),
                                  ],
                                ),
                                if (today && status == 'assigned') ...[
                                  const SizedBox(height: 14),
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton.icon(
                                      onPressed: () => _startShift(shift['assignment_id']),
                                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4F46E5), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                                      icon: const Icon(Icons.play_arrow),
                                      label: const Text('MESAİYİ BAŞLAT', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                                    ),
                                  ),
                                ] else if (status == 'active') ...[
                                  const SizedBox(height: 14),
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(12)),
                                    child: const Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.access_time_filled, color: Colors.green, size: 18),
                                        SizedBox(width: 8),
                                        Text('Mesai devam ediyor...', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton.icon(
                                      onPressed: () => _endShift(shift['assignment_id'], shift['end_time'] ?? '23:59'),
                                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                                      icon: const Icon(Icons.stop),
                                      label: const Text('MESAİYİ BİTİR', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5)),
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
                ),
          ),
    );
  }

  Widget _statusBadge(String status) {
    Color c; String label; IconData icon;
    switch (status) {
      case 'active': c = Colors.green; label = 'AKTİF'; icon = Icons.radio_button_checked; break;
      case 'completed': c = Colors.grey; label = 'TAMAMLANDI'; icon = Icons.check_circle; break;
      default: c = Colors.blue; label = 'ATANDI'; icon = Icons.schedule;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: c.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: c, size: 12),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(color: c, fontSize: 11, fontWeight: FontWeight.bold)),
      ]),
    );
  }
}

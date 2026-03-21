import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';

class ShiftPlanCreateScreen extends StatefulWidget {
  final String? targetCompanyId;
  const ShiftPlanCreateScreen({Key? key, this.targetCompanyId}) : super(key: key);
  @override
  _ShiftPlanCreateScreenState createState() => _ShiftPlanCreateScreenState();
}

class _ShiftPlanCreateScreenState extends State<ShiftPlanCreateScreen> {
  DateTime? _selectedDate;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  List<dynamic> _workers = [];
  String? _leaderId;
  String? _leaderName;
  List<Map<String, String>> _helpers = []; // {worker_id, worker_name}
  bool _isLoadingWorkers = false;
  bool _isSaving = false;
  String? _error;

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 60)),
      locale: const Locale('tr', 'TR'),
    );
    if (d != null) {
      setState(() { _selectedDate = d; _leaderId = null; _leaderName = null; _helpers = []; });
      await _loadWorkers(d);
    }
  }

  String _fmtDate(DateTime d) => '${d.day.toString().padLeft(2,'0')}.${d.month.toString().padLeft(2,'0')}.${d.year}';
  String _fmtDateISO(DateTime d) => '${d.year}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}';
  String _fmtTime(TimeOfDay t) => '${t.hour.toString().padLeft(2,'0')}:${t.minute.toString().padLeft(2,'0')}';

  Future<void> _loadWorkers(DateTime date) async {
    setState(() => _isLoadingWorkers = true);
    try {
      final appState = context.read<AppState>();
      final workers = await appState.apiService.getWorkers(date: _fmtDateISO(date));
      setState(() { _workers = workers; _isLoadingWorkers = false; });
    } catch (e) {
      setState(() => _isLoadingWorkers = false);
    }
  }

  Future<void> _pickTime(bool isStart) async {
    final t = await showTimePicker(
      context: context,
      initialTime: isStart ? const TimeOfDay(hour: 8, minute: 0) : const TimeOfDay(hour: 16, minute: 0),
      builder: (ctx, child) => MediaQuery(data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true), child: child!),
    );
    if (t != null) setState(() { if (isStart) _startTime = t; else _endTime = t; });
  }

  bool _isHelperSelected(String wid) => _helpers.any((h) => h['worker_id'] == wid);

  void _toggleHelper(Map<String, dynamic> worker) {
    final wid = worker['id'];
    final wname = worker['name'];
    if (wid == _leaderId) return; // Lider helper olamaz
    setState(() {
      if (_isHelperSelected(wid)) {
        _helpers.removeWhere((h) => h['worker_id'] == wid);
      } else {
        _helpers.add({'worker_id': wid, 'worker_name': wname});
      }
    });
  }

  Future<void> _save() async {
    if (_selectedDate == null || _startTime == null || _endTime == null) {
      setState(() => _error = 'Lütfen tarih ve saat aralığı seçin.'); return;
    }
    if (_leaderId == null) {
      setState(() => _error = 'Bir lider seçmek zorunludur.'); return;
    }

    setState(() { _isSaving = true; _error = null; });
    final appState = context.read<AppState>();

    final assignments = <Map<String, String>>[
      {'worker_id': _leaderId!, 'worker_name': _leaderName!, 'role_in_shift': 'leader'},
      ..._helpers.map((h) => {'worker_id': h['worker_id']!, 'worker_name': h['worker_name']!, 'role_in_shift': 'worker'}),
    ];

    try {
      await appState.apiService.createShiftPlan(
        companyId: widget.targetCompanyId ?? appState.currentUser!['company_id'],
        createdBy: appState.currentUser!['id'],
        workDate: _fmtDateISO(_selectedDate!),
        startTime: _fmtTime(_startTime!),
        endTime: _fmtTime(_endTime!),
        assignments: assignments,
      );
      if (!mounted) return;
      final role = appState.currentUser!['role'];
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(role == 'super_admin' ? '✅ Plan oluşturuldu ve anında onaylandı!' : '✅ Plan oluşturuldu! Ekrem onayı bekleniyor.'), 
          backgroundColor: Colors.green
        )
      );
      Navigator.pop(context);
    } catch (e) {
      setState(() { _error = e.toString().replaceAll('Exception: ', ''); _isSaving = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0FDF4),
      appBar: AppBar(
        backgroundColor: const Color(0xFF16A34A),
        foregroundColor: Colors.white,
        title: const Text('Yeni Vardiya Planı', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date picker
            _sectionTitle('📅 Tarih'),
            _card(
              child: ListTile(
                leading: const Icon(Icons.calendar_today, color: Color(0xFF16A34A)),
                title: Text(_selectedDate == null ? 'Tarih seçin...' : _fmtDate(_selectedDate!), style: TextStyle(fontWeight: FontWeight.bold, color: _selectedDate == null ? Colors.grey : Colors.black)),
                trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                onTap: _pickDate,
              ),
            ),
            const SizedBox(height: 16),

            // Time picker
            _sectionTitle('⏰ Saat Aralığı'),
            Row(
              children: [
                Expanded(child: _card(child: ListTile(
                  dense: true,
                  leading: const Icon(Icons.play_arrow, color: Color(0xFF16A34A)),
                  title: Text(_startTime == null ? 'Başlangıç' : _fmtTime(_startTime!), style: const TextStyle(fontWeight: FontWeight.bold)),
                  onTap: () => _pickTime(true),
                ))),
                const SizedBox(width: 10),
                Expanded(child: _card(child: ListTile(
                  dense: true,
                  leading: const Icon(Icons.stop, color: Colors.red),
                  title: Text(_endTime == null ? 'Bitiş' : _fmtTime(_endTime!), style: const TextStyle(fontWeight: FontWeight.bold)),
                  onTap: () => _pickTime(false),
                ))),
              ],
            ),
            const SizedBox(height: 16),

            // Worker list
            _sectionTitle('👥 Çalışan Seçimi'),
            if (_selectedDate == null)
              const Padding(
                padding: EdgeInsets.all(8),
                child: Text('Önce tarih seçin.', style: TextStyle(color: Colors.grey)),
              )
            else if (_isLoadingWorkers)
              const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator(color: Color(0xFF16A34A))))
            else
              _card(
                child: Column(
                  children: [
                    // Leader pick header
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      color: Colors.amber.shade50,
                      child: const Row(
                        children: [
                          Icon(Icons.star, color: Colors.amber, size: 16),
                          SizedBox(width: 6),
                          Text('Lider Seç (Zorunlu)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: Colors.amber)),
                        ],
                      ),
                    ),
                    ..._workers.map((w) {
                      final busy = w['is_busy'] == true;
                      final isLeader = w['id'] == _leaderId;
                      final isHelper = _isHelperSelected(w['id']);
                      return ListTile(
                        dense: true,
                        enabled: !busy,
                        leading: CircleAvatar(
                          radius: 18,
                          backgroundColor: busy ? Colors.grey.shade200 : isLeader ? Colors.amber.shade100 : isHelper ? Colors.green.shade100 : const Color(0xFF16A34A).withOpacity(0.08),
                          child: Text(
                            (w['name'] as String).substring(0, 1),
                            style: TextStyle(fontWeight: FontWeight.bold, color: busy ? Colors.grey : isLeader ? Colors.amber.shade800 : const Color(0xFF16A34A)),
                          ),
                        ),
                        title: Text(w['name'], style: TextStyle(fontWeight: FontWeight.w600, color: busy ? Colors.grey : Colors.black)),
                        subtitle: Text(busy ? '⚠️ Bu gün başka vardiyada' : 'ID: ${w['id']}', style: TextStyle(fontSize: 11, color: busy ? Colors.orange : Colors.grey)),
                        trailing: busy
                          ? const Icon(Icons.block, color: Colors.grey, size: 20)
                          : Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Helper button
                                GestureDetector(
                                  onTap: () => _toggleHelper(w),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: isHelper ? Colors.green : Colors.green.shade50,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: Colors.green.shade300),
                                    ),
                                    child: Text(isHelper ? '✓ ÇALIŞAN' : 'ÇALIŞAN', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isHelper ? Colors.white : Colors.green.shade700)),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                // Leader button
                                GestureDetector(
                                  onTap: () {
                                    if (!isHelper) {
                                      setState(() {
                                        if (isLeader) { _leaderId = null; _leaderName = null; }
                                        else { _leaderId = w['id']; _leaderName = w['name']; _helpers.removeWhere((h) => h['worker_id'] == w['id']); }
                                      });
                                    }
                                  },
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: isLeader ? Colors.amber : Colors.amber.shade50,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: Colors.amber.shade300),
                                    ),
                                    child: Text(isLeader ? '★ LİDER' : 'LİDER', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isLeader ? Colors.white : Colors.amber.shade800)),
                                  ),
                                ),
                              ],
                            ),
                      );
                    }).toList(),
                  ],
                ),
              ),

            // Summary & error
            if (_error != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.red.shade200)),
                child: Row(children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 18),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_error!, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w600))),
                ]),
              ),
            ],

            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF16A34A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                icon: _isSaving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.send),
                label: Text(_isSaving ? 'GÖNDERİLİYOR...' : 'PLANI ONAYLA VE GÖNDER', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(t, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Color(0xFF15803D))),
  );

  Widget _card({required Widget child}) => Container(
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)]),
    child: child,
  );
}

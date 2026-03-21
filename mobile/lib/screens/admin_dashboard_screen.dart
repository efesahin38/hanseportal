import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import 'login_screen.dart';
import 'company_detail_screen.dart';
import 'daily_tracker_screen.dart';
import 'employee_management_screen.dart';

String _safeTime(String? time) {
  if (time == null || time.length < 5) return time ?? '--:--';
  return time.substring(0, 5);
}

class AdminDashboardScreen extends StatefulWidget {
  @override
  _AdminDashboardScreenState createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  List<dynamic> _companies = [];
  List<dynamic> _pendingPlans = [];
  bool _isLoading = true;
  String _selectedTab = 'pending';

  @override
  void initState() { super.initState(); _loadData(); }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final appState = context.read<AppState>();
    try {
      final companies = await appState.apiService.getCompanies();
      final plans = await appState.apiService.getShiftPlans(status: 'pending');
      setState(() { _companies = companies; _pendingPlans = plans; _isLoading = false; });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _approve(String planId) async {
    final appState = context.read<AppState>();
    try {
      await appState.apiService.approvePlan(planId, appState.currentUser!['id']);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Plan onaylandı!'), backgroundColor: Colors.green));
      _loadData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
    }
  }

  Future<void> _showRejectDialog(String planId) async {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Reddetme Nedeni', style: TextStyle(fontWeight: FontWeight.bold)),
        content: TextField(controller: ctrl, decoration: const InputDecoration(hintText: 'Açıklama giriniz...', border: OutlineInputBorder()), maxLines: 3),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('İptal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              if (!mounted) return;
              final appState = context.read<AppState>();
              try {
                await appState.apiService.rejectPlan(planId, appState.currentUser!['id'], ctrl.text.trim().isEmpty ? 'Açıklama girilmedi.' : ctrl.text.trim());
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('❌ Plan reddedildi.'), backgroundColor: Colors.orange));
                _loadData();
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
              }
            },
            child: const Text('REDDET', style: TextStyle(color: Colors.white)),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.read<AppState>().currentUser;
    return Scaffold(
      backgroundColor: const Color(0xFFEEF2FF),
      appBar: AppBar(
        backgroundColor: const Color(0xFF4F46E5),
        foregroundColor: Colors.white,
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Hoşgeldin, ${user?['name'] ?? ''}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const Text('Süper Admin Paneli', style: TextStyle(fontSize: 11, color: Colors.white70)),
        ]),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await context.read<AppState>().logout();
              if (!mounted) return;
              Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => LoginScreen()));
            },
          )
        ],
      ),
      body: _isLoading
        ? const Center(child: CircularProgressIndicator(color: Color(0xFF4F46E5)))
        : RefreshIndicator(
            onRefresh: _loadData,
            child: Column(children: [
              // Stats banner
              Container(
                color: const Color(0xFF4F46E5),
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Row(children: [
                  _statCard('${_companies.length}', 'Şirket'),
                  const SizedBox(width: 12),
                  _statCard('${_pendingPlans.length}', 'Bekleyen Plan'),
                ]),
              ),

              // Quick Access Buttons (Tracker + Employee Mgmt)
              Container(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                child: Row(children: [
                  _quickBtn(
                    icon: Icons.map_outlined,
                    label: 'Günlük Takip',
                    subtitle: 'Kim nerede sahada',
                    color: Colors.green,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DailyTrackerScreen())),
                  ),
                  const SizedBox(width: 10),
                  _quickBtn(
                    icon: Icons.manage_accounts,
                    label: 'Eleman Yönetimi',
                    subtitle: 'Ekle & Sil',
                    color: Colors.deepOrange,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EmployeeManagementScreen())),
                  ),
                ]),
              ),

              // Tab bar
              Container(
                margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                child: Row(children: [
                  _tabBtn('Bekleyenler (${_pendingPlans.length})', 'pending'),
                  _tabBtn('Şirketler', 'companies'),
                ]),
              ),

              Expanded(child: _selectedTab == 'companies' ? _buildCompanyList() : _buildPendingPlans()),
            ]),
          ),
    );
  }

  Widget _quickBtn({required IconData icon, required String label, required String subtitle, required Color color, required VoidCallback onTap}) =>
    Expanded(child: GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8)],
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            Text(subtitle, style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
          ])),
          Icon(Icons.arrow_forward_ios, size: 12, color: Colors.grey.shade400),
        ]),
      ),
    ));

  Widget _statCard(String value, String label) => Expanded(
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(14)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900)),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
      ]),
    ),
  );

  Widget _tabBtn(String label, String tab) => Expanded(
    child: GestureDetector(
      onTap: () => setState(() => _selectedTab = tab),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: _selectedTab == tab ? const Color(0xFF4F46E5) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(label, textAlign: TextAlign.center, style: TextStyle(color: _selectedTab == tab ? Colors.white : Colors.grey, fontWeight: FontWeight.bold, fontSize: 12)),
      ),
    ),
  );

  Widget _buildPendingPlans() {
    if (_pendingPlans.isEmpty) {
      return const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.check_circle_outline, size: 64, color: Colors.green),
        SizedBox(height: 16),
        Text('Bekleyen plan yok 🎉', style: TextStyle(fontSize: 18, color: Colors.grey)),
      ]));
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      itemCount: _pendingPlans.length,
      itemBuilder: (ctx, i) {
        final plan = _pendingPlans[i];
        final assignments = List<dynamic>.from(plan['shift_assignments'] ?? []);
        return Container(
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)]),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(color: Color(0xFF4F46E5), borderRadius: BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20))),
              child: Row(children: [
                const Icon(Icons.business, color: Colors.white70, size: 18),
                const SizedBox(width: 8),
                Expanded(child: Text(plan['companies']?['name'] ?? plan['company_id'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16))),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: Colors.orange.shade300, borderRadius: BorderRadius.circular(10)),
                  child: const Text('BEKLEMEDE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                )
              ]),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  const Icon(Icons.calendar_today, size: 16, color: Color(0xFF4F46E5)),
                  const SizedBox(width: 6),
                  Text(plan['work_date'] ?? '', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                  const SizedBox(width: 16),
                  const Icon(Icons.access_time, size: 16, color: Color(0xFF4F46E5)),
                  const SizedBox(width: 6),
                  Text('${_safeTime(plan['start_time'])} - ${_safeTime(plan['end_time'])}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                ]),
                const SizedBox(height: 12),
                const Text('Çalışanlar:', style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                ...assignments.map((a) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(children: [
                    Icon(a['role_in_shift'] == 'leader' ? Icons.star : Icons.person, size: 16, color: a['role_in_shift'] == 'leader' ? Colors.amber : Colors.grey),
                    const SizedBox(width: 6),
                    Text(a['worker_name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: a['role_in_shift'] == 'leader' ? Colors.amber.shade100 : Colors.grey.shade100, borderRadius: BorderRadius.circular(6)),
                      child: Text(a['role_in_shift'] == 'leader' ? 'LİDER' : 'ÇALIŞAN', style: TextStyle(fontSize: 10, color: a['role_in_shift'] == 'leader' ? Colors.amber.shade800 : Colors.grey.shade700, fontWeight: FontWeight.bold)),
                    )
                  ]),
                )),
                const SizedBox(height: 16),
                Row(children: [
                  Expanded(child: OutlinedButton.icon(
                    onPressed: () => _showRejectDialog(plan['id']),
                    icon: const Icon(Icons.close, size: 18),
                    label: const Text('REDDET'),
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red)),
                  )),
                  const SizedBox(width: 12),
                  Expanded(child: ElevatedButton.icon(
                    onPressed: () => _approve(plan['id']),
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('ONAYLA'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                  )),
                ]),
              ]),
            ),
          ]),
        );
      },
    );
  }

  Widget _buildCompanyList() => ListView.builder(
    padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
    itemCount: _companies.length,
    itemBuilder: (ctx, i) {
      final c = _companies[i];
      return GestureDetector(
        onTap: () => Navigator.push(context, MaterialPageRoute(
          builder: (_) => CompanyDetailScreen(companyId: c['id'], companyName: c['name'] ?? c['id']),
        )).then((_) => _loadData()),
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8)]),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: const Color(0xFF4F46E5).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.business, color: Color(0xFF4F46E5)),
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(c['name'] ?? c['id'], style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
              const Text('Vardiya planlarını gör & yönet', style: TextStyle(fontSize: 12, color: Colors.grey)),
            ])),
            const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
          ]),
        ),
      );
    },
  );
}

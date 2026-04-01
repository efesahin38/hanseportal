import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../services/supabase_service.dart';

class EmployeeManagementScreen extends StatefulWidget {
  const EmployeeManagementScreen({Key? key}) : super(key: key);
  @override
  State<EmployeeManagementScreen> createState() => _EmployeeManagementScreenState();
}

class _EmployeeManagementScreenState extends State<EmployeeManagementScreen> with SingleTickerProviderStateMixin {
  late TabController _tabs;

  // ADD fields
  final _addIdCtrl   = TextEditingController();
  final _addNameCtrl = TextEditingController();
  final _addPassCtrl = TextEditingController(); // YENİ ŞİFRE ALANI
  final _addPinCtrl  = TextEditingController();
  bool _isAdding = false;
  String? _addError;
  String? _addSuccess;

  // DELETE fields
  final _delIdCtrl   = TextEditingController();
  Map<String, dynamic>? _foundWorker;
  bool _isSearching  = false;
  bool _isDeleting   = false;
  String? _delError;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() { _tabs.dispose(); super.dispose(); }

  Future<void> _addEmployee() async {
    final name = _addNameCtrl.text.trim();
    final pass = _addPassCtrl.text.trim();
    final pin  = _addPinCtrl.text.trim();
    if (name.isEmpty || pass.isEmpty) {
      setState(() { _addError = 'İsim ve Şifre zorunludur.'; _addSuccess = null; }); return;
    }
    setState(() { _isAdding = true; _addError = null; _addSuccess = null; });
    try {
      final appState = context.read<AppState>();
      final parts = name.split(' ');
      final firstName = parts.first;
      final lastName = parts.length > 1 ? parts.sublist(1).join(' ') : '';
      
      await SupabaseService.client.from('users').insert({
        'first_name': firstName,
        'last_name': lastName,
        'email': '${firstName.toLowerCase()}.${lastName.toLowerCase()}@hanse.de',
        'company_id': appState.companyId,
        'role': 'mitarbeiter',
        'password': pass,
        if (pin.isNotEmpty) 'pin_code': pin,
        if (_addIdCtrl.text.trim().isNotEmpty) 'employee_number': _addIdCtrl.text.trim(),
        'status': 'active',
      });

      if (!mounted) return;
      setState(() {
        _isAdding = false;
        _addSuccess = '✅ $name sisteme eklendi!';
        _addIdCtrl.clear(); _addNameCtrl.clear(); _addPinCtrl.clear(); _addPassCtrl.clear();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _isAdding = false; _addError = e.toString().replaceAll('Exception: ', ''); });
    }
  }

  Future<void> _searchWorker() async {
    final id = _delIdCtrl.text.trim();
    if (id.isEmpty) { setState(() => _delError = 'ID boş olamaz.'); return; }
    setState(() { _isSearching = true; _delError = null; _foundWorker = null; });
    try {
      final worker = await SupabaseService.getUserById(id);
      if (!mounted) return;
      if (worker == null) throw Exception('Bulunamadı');
      setState(() { _foundWorker = worker; _isSearching = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _delError = 'Bu ID ile çalışan bulunamadı.'; _isSearching = false; });
    }
  }

  Future<void> _confirmDelete() async {
    if (_foundWorker == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(children: [Icon(Icons.warning_amber, color: Colors.red), SizedBox(width: 8), Text('Emin misiniz?', style: TextStyle(color: Colors.red))]),
        content: RichText(text: TextSpan(style: const TextStyle(fontSize: 15, color: Colors.black), children: [
          const TextSpan(text: ''),
          TextSpan(text: _foundWorker!['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
          const TextSpan(text: ' adlı çalışan sistemden kalıcı olarak silinecek.\nTüm vardiya kayıtları da silinecektir. Bu işlem geri alınamaz!'),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hayır, İptal Et')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Evet, Sil', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _isDeleting = true);
    try {
      // Soft-delete: set status to inactive
      await SupabaseService.client
          .from('users')
          .update({'status': 'inactive'})
          .eq('id', _foundWorker!['id']);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('🗑️ ${_foundWorker!['name']} silindi.'),
        backgroundColor: Colors.red,
      ));
      setState(() { _foundWorker = null; _delIdCtrl.clear(); _isDeleting = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _delError = e.toString().replaceAll('Exception: ', ''); _isDeleting = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFF),
      appBar: AppBar(
        backgroundColor: const Color(0xFF4F46E5),
        foregroundColor: Colors.white,
        title: const Text('Eleman Yönetimi', style: TextStyle(fontWeight: FontWeight.bold)),
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: const [
            Tab(icon: Icon(Icons.person_add), text: 'Eleman Ekle'),
            Tab(icon: Icon(Icons.person_remove), text: 'Eleman Sil'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [_buildAddTab(), _buildDeleteTab()],
      ),
    );
  }

  // ─── ADD TAB ───────────────────────────────────────────────
  Widget _buildAddTab() => SingleChildScrollView(
    padding: const EdgeInsets.all(20),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _sectionHeader('Yeni Çalışan Ekle', Icons.person_add, const Color(0xFF4F46E5)),
      const SizedBox(height: 20),
      _infoBox('ID, isim ve PIN belirleyerek yeni çalışanı sisteme ekleyin. Çalışan bu ID ve PIN ile giriş yapacaktır.', Colors.blue),
      const SizedBox(height: 20),
      _field(controller: _addIdCtrl, label: 'Çalışan ID', hint: 'Örn: 1041', icon: Icons.badge),
      const SizedBox(height: 14),
      _field(controller: _addNameCtrl, label: 'Ad Soyad', hint: 'Örn: Ahmet Yılmaz', icon: Icons.person),
      const SizedBox(height: 14),
      _field(controller: _addPassCtrl, label: 'Giriş Şifresi', hint: 'Örn: ahmet123 (Uygulama Girişi)', icon: Icons.password),
      const SizedBox(height: 14),
      _field(controller: _addPinCtrl, label: 'PIN Şifre', hint: 'Örn: 1234', icon: Icons.lock, isPin: true),
      const SizedBox(height: 20),
      if (_addError != null) _alertBox(_addError!, Colors.red),
      if (_addSuccess != null) _alertBox(_addSuccess!, Colors.green),
      const SizedBox(height: 8),
      SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: _isAdding ? null : _addEmployee,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF4F46E5),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          icon: _isAdding ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.save),
          label: Text(_isAdding ? 'Ekleniyor...' : 'KAYDET VE EKLE', style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5)),
        ),
      ),
    ]),
  );

  // ─── DELETE TAB ────────────────────────────────────────────
  Widget _buildDeleteTab() => SingleChildScrollView(
    padding: const EdgeInsets.all(20),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _sectionHeader('Çalışan Sil', Icons.person_remove, Colors.red),
      const SizedBox(height: 20),
      _infoBox('Silmek istediğiniz çalışanın ID\'sini girin. Doğrulama için isim gösterilecektir.', Colors.orange),
      const SizedBox(height: 20),
      Row(children: [
        Expanded(child: _field(controller: _delIdCtrl, label: 'Çalışan ID', hint: 'Örn: 1005', icon: Icons.search)),
        const SizedBox(width: 10),
        ElevatedButton(
          onPressed: _isSearching ? null : _searchWorker,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF4F46E5),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.all(18),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          child: _isSearching
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : const Icon(Icons.search),
        ),
      ]),
      if (_delError != null) ...[const SizedBox(height: 14), _alertBox(_delError!, Colors.red)],
      if (_foundWorker != null) ...[
        const SizedBox(height: 20),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.red.shade200, width: 2),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 10)],
          ),
          padding: const EdgeInsets.all(20),
          child: Column(children: [
            CircleAvatar(
              radius: 32,
              backgroundColor: Colors.red.shade50,
              child: Text((_foundWorker!['name'] as String).substring(0, 1), style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.red.shade600)),
            ),
            const SizedBox(height: 12),
            Text(_foundWorker!['name'], style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text('ID: ${_foundWorker!['id']}', style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.w600)),
            Text('Rol: ${_foundWorker!['role'] == 'worker' ? 'Çalışan' : _foundWorker!['role']}', style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isDeleting ? null : _confirmDelete,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                icon: _isDeleting ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.delete_forever),
                label: Text(_isDeleting ? 'Siliniyor...' : 'EVET, SİSTEMDEN SİL', style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ]),
        ),
      ],
    ]),
  );

  Widget _sectionHeader(String title, IconData icon, Color color) => Row(children: [
    Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: color)),
    const SizedBox(width: 12),
    Text(title, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: color)),
  ]);

  Widget _infoBox(String text, Color color) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(14), border: Border.all(color: color.withValues(alpha: 0.3))),
    child: Row(children: [
      Icon(Icons.info_outline, color: color, size: 18),
      const SizedBox(width: 10),
      Expanded(child: Text(text, style: TextStyle(color: color.withValues(alpha: 0.9), fontWeight: FontWeight.w500))),
    ]),
  );

  Widget _alertBox(String text, Color color) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withValues(alpha: 0.3))),
    child: Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
  );

  Widget _field({required TextEditingController controller, required String label, required String hint, required IconData icon, bool isPin = false}) => Container(
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)]),
    child: TextField(
      controller: controller,
      obscureText: isPin,
      decoration: InputDecoration(
        labelText: label, hintText: hint,
        prefixIcon: Icon(icon, color: const Color(0xFF4F46E5)),
        border: InputBorder.none,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    ),
  );
}

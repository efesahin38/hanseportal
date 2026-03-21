import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../screens/admin_dashboard_screen.dart';
import '../screens/manager_dashboard_screen.dart';
import '../screens/worker_dashboard_screen.dart';

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _idCtrl = TextEditingController();
  final _pinCtrl = TextEditingController();
  bool _isLoading = false;
  bool _rememberMe = true;
  String? _error;

  Future<void> _login() async {
    final id = _idCtrl.text.trim();
    final pin = _pinCtrl.text.trim();
    if (id.isEmpty || pin.isEmpty) {
      setState(() => _error = 'ID ve PIN boş bırakılamaz.');
      return;
    }
    setState(() { _isLoading = true; _error = null; });

    try {
      final appState = context.read<AppState>();
      await appState.login(id, pin, rememberMe: _rememberMe);
      if (!mounted) return;

      final user = appState.currentUser;
      if (user == null) {
        setState(() { _error = 'Hatalı ID veya PIN.'; _isLoading = false; });
        return;
      }

      final role = user['role'];
      Widget nextScreen;
      if (role == 'super_admin') {
        nextScreen = AdminDashboardScreen();
      } else if (role == 'manager') {
        nextScreen = ManagerDashboardScreen();
      } else {
        nextScreen = WorkerDashboardScreen();
      }
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => nextScreen));
    } catch (e) {
      setState(() { _error = e.toString().replaceAll('Exception: ', ''); _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEEF2FF),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo
                Container(
                  width: 100, height: 100,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)]),
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [BoxShadow(color: const Color(0xFF4F46E5).withOpacity(0.4), blurRadius: 20, offset: const Offset(0, 8))]
                  ),
                  child: const Icon(Icons.business_center, size: 50, color: Colors.white),
                ),
                const SizedBox(height: 28),
                const Text('Ekrem PDKS', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900, color: Color(0xFF1E1B4B), letterSpacing: -0.5)),
                const SizedBox(height: 6),
                const Text('Personel Devam Kontrol Sistemi', style: TextStyle(color: Color(0xFF6366F1), fontSize: 14, fontWeight: FontWeight.w500)),
                const SizedBox(height: 40),

                // ID Field
                _buildField(controller: _idCtrl, label: 'Çalışan ID', icon: Icons.badge_outlined, isNumeric: false),
                const SizedBox(height: 14),
                _buildField(controller: _pinCtrl, label: 'PIN Şifre', icon: Icons.lock_outline, isPassword: true),
                const SizedBox(height: 10),

                if (_error != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.red.shade200)),
                    child: Row(children: [
                      Icon(Icons.error_outline, color: Colors.red.shade600, size: 20),
                      const SizedBox(width: 10),
                      Expanded(child: Text(_error!, style: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.w600))),
                    ]),
                  ),
                const SizedBox(height: 16),
                
                Row(
                  children: [
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: Checkbox(
                        value: _rememberMe,
                        onChanged: (val) => setState(() => _rememberMe = val ?? true),
                        activeColor: const Color(0xFF4F46E5),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Text('Oturumu açık tut', style: TextStyle(color: Color(0xFF1E1B4B), fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 24),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _login,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4F46E5),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    child: _isLoading
                      ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                      : const Text('GİRİŞ YAP', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: 1)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildField({required TextEditingController controller, required String label, required IconData icon, bool isPassword = false, bool isNumeric = false}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))]
      ),
      child: TextField(
        controller: controller,
        obscureText: isPassword,
        keyboardType: isNumeric ? TextInputType.number : TextInputType.text,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: const Color(0xFF4F46E5)),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          labelStyle: const TextStyle(color: Colors.grey),
        ),
      ),
    );
  }
}

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../theme/web_utils.dart';
import '../providers/app_state.dart';
import '../services/localization_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscure = true;
  bool _rememberMe = true;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _error = null);
    final errorMsg = await context.read<AppState>().signIn(
          _emailCtrl.text.trim(),
          _passCtrl.text.trim(),
          rememberMe: _rememberMe,
        );
    if (errorMsg != null && mounted) {
      setState(() => _error = errorMsg);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = context.watch<AppState>().isLoading;

    return Scaffold(
      backgroundColor: AppTheme.primary,
      body: SafeArea(
        child: Center(
          child: WebContentWrapper(
            maxWidth: 480,
            child: SingleChildScrollView(
              child: Column(
                children: [
                  // ── Logo Alanı ─────────────────────────────────
                  const SizedBox(height: 60),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Container(
                      width: 90,
                      height: 90,
                      color: Colors.white,
                      child: Image.asset('assets/icon/hanse.png', fit: BoxFit.cover),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Hanse Kollektiv GmbH',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Inter',
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    tr('Dijital Yönetim Sistemi'),
                    style: const TextStyle(color: Colors.white70, fontSize: 13, fontFamily: 'Inter'),
                  ),
                  const Text('v19.3.8', style: TextStyle(color: Colors.white70, fontSize: 12, fontFamily: 'Inter')),
                  const SizedBox(height: 48),
  
                  // ── Form Kartı ─────────────────────────────────
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 24),
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.12),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'HansePortal v19.3.8',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textMain,
                              fontFamily: 'Poppins',
                            ),
                          ),
                          const SizedBox(height: 24),
  
                          // E-posta
                          TextFormField(
                            controller: _emailCtrl,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            decoration: InputDecoration(
                              labelText: tr('E-posta'),
                              prefixIcon: const Icon(Icons.email_outlined),
                            ),
                            validator: (v) => (v == null || !v.contains('@'))
                                ? tr('Geçerli bir e-posta girin')
                                : null,
                          ),
                          const SizedBox(height: 16),
  
                          // Şifre
                          TextFormField(
                            controller: _passCtrl,
                            obscureText: _obscure,
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (_) => _login(),
                            decoration: InputDecoration(
                              labelText: tr('Şifre'),
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
                                onPressed: () => setState(() => _obscure = !_obscure),
                              ),
                            ),
                            validator: (v) => (v == null || v.length < 4)
                                ? tr('Şifre en az 4 karakter olmalı')
                                : null,
                          ),
  
                          const SizedBox(height: 8),
  
                          // Oturumu Açık Tut
                          Theme(
                            data: Theme.of(context).copyWith(
                              unselectedWidgetColor: AppTheme.textSub,
                            ),
                            child: CheckboxListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(
                                tr('Oturumu Açık Tut'),
                                style: const TextStyle(fontSize: 13, color: AppTheme.textSub, fontFamily: 'Inter'),
                              ),
                              value: _rememberMe,
                              onChanged: (v) => setState(() => _rememberMe = v ?? false),
                              controlAffinity: ListTileControlAffinity.leading,
                              activeColor: AppTheme.primary,
                              dense: true,
                              visualDensity: VisualDensity.compact,
                            ),
                          ),
  
                          // Hata Mesajı
                          if (_error != null) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppTheme.error.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: AppTheme.error.withOpacity(0.3)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.error_outline, color: AppTheme.error, size: 18),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _error!,
                                      style: const TextStyle(color: AppTheme.error, fontSize: 13, fontFamily: 'Inter'),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
  
                          const SizedBox(height: 24),
  
                          // Giriş Butonu
                          SizedBox(
                            height: 52,
                            child: ElevatedButton(
                              onPressed: isLoading ? null : _login,
                              child: isLoading
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                                    )
                                  : Text(tr('Giriş Yap')),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                  const Text(
                    '© 2025 Hanse Kollektiv GmbH',
                    style: TextStyle(color: Colors.white38, fontSize: 11, fontFamily: 'Inter'),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

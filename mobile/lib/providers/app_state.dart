import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;
import '../services/api_service.dart';

class AppState extends ChangeNotifier with WidgetsBindingObserver {
  Map<String, dynamic>? _currentUser;
  bool _isLoading = false;
  bool _isInitialized = false;

  Map<String, dynamic>? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  bool get isInitialized => _isInitialized;

  final ApiService apiService = ApiService(
    baseUrl: 'https://ekrem.onrender.com',
  );

  Future<void> _sendDebugLog(String msg) async {
    try {
      await http.post(
        Uri.parse('https://ekrem.onrender.com/api/debug'),
        body: {'log': msg},
      );
    } catch (_) {}
  }

  AppState() {
    WidgetsBinding.instance.addObserver(this);
    _initFromPrefs();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _updateFcmToken(); // Uygulama öne gelince token'ı tazele
    }
  }

  Future<void> _initFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final userJson = prefs.getString('current_user');
    if (userJson != null) {
      _currentUser = Map<String, dynamic>.from(jsonDecode(userJson));
      _initFcm(); // Giriş yapılmışsa token kontrolü yap
    }
    _isInitialized = true;
    notifyListeners();
  }

  // === PUSH BİLDİRİM SİSTEMİ ===
  Future<void> _initFcm() async {
    if (_currentUser == null) return;

    try {
      final messaging = FirebaseMessaging.instance;
      
      // İzin iste (Özellikle iOS için)
      NotificationSettings settings = await messaging.requestPermission(
        alert: true, badge: true, sound: true,
      );

      // Uygulama açıkken (foreground) bildirimin iOS'ta görünmesi için:
      await messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        print('Ön planda bildirim geldi: ${message.notification?.title}');
      });

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        await _sendDebugLog('Bildirim izni verildi (authorized). Token alınıyor...');
        
        // iOS için APNs token gelmesini bir süre retry ile bekleyelim (Race condition çözümü)
        String? apnsToken;
        int retries = 0;
        while (apnsToken == null && retries < 10) { // 10 saniyeye çıkardık
          apnsToken = await messaging.getAPNSToken();
          if (apnsToken == null) {
            await Future.delayed(const Duration(seconds: 1));
            retries++;
          }
        }
        await _sendDebugLog('APNs Token durumu (${retries} sn bekledi): ${apnsToken != null ? "BASARILI" : "Hala Null!!"}');
        
        // Token al ve kaydet
        await _updateFcmToken();

        // Token değişirse otomatik güncelle (OnTokenRefresh)
        messaging.onTokenRefresh.listen((newToken) async {
          await _sendDebugLog('FCM Token yenilendi, backend guncelleniyor...');
          if (_currentUser != null) {
            await apiService.saveFcmToken(_currentUser!['id'], newToken);
          }
        });
      } else {
        await _sendDebugLog('Kullanici bildirim iznini reddetti: ${settings.authorizationStatus}');
      }
    } catch (e) {
      await _sendDebugLog('FCM Baslatma Hatasi: $e');
    }
  }

  Future<void> _updateFcmToken() async {
    try {
      String? token = await FirebaseMessaging.instance.getToken();
      await _sendDebugLog('FCM Token durumu: ${token != null ? "Alindi" : "Null dondu"}');
      if (token != null && _currentUser != null) {
        await apiService.saveFcmToken(_currentUser!['id'], token);
        await _sendDebugLog('FCM Token basariyla backend\'e iletildi.');
      }
    } catch (e) {
      await _sendDebugLog('Token guncelleme hatasi: $e');
    }
  }

  Future<void> login(String id, String pinCode, {bool rememberMe = true}) async {
    _isLoading = true;
    notifyListeners();
    try {
      final user = await apiService.login(id, pinCode);
      _currentUser = user;
      if (rememberMe) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('current_user', jsonEncode(user));
      }
      _isLoading = false;
      notifyListeners();
      _initFcm(); // Giriş başarılı olunca token al ve kaydet
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> logout() async {
    if (_currentUser != null) {
      try {
        // Çıkış yaparken backend'den bildirim token'ını sil ki bu cihaza artık o kişinin bildirimi gelmesin
        await apiService.saveFcmToken(_currentUser!['id'], '');
      } catch (e) {
        print('Token temizleme hatası: $e');
      }
    }
    _currentUser = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('current_user');
    notifyListeners();
  }
}

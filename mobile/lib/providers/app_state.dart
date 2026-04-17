import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../services/supabase_service.dart';
import '../services/localization_service.dart';

// Backend URL – Render production sunucusu
const String _backendBase = 'https://ekrem.onrender.com/api';

class AppState extends ChangeNotifier {
  Map<String, dynamic>? _currentUser;
  bool _isInitialized = false;
  bool _isLoading = false;
  int _unreadNotifications = 0;

  Map<String, dynamic>? get currentUser => _currentUser;
  bool get isInitialized => _isInitialized;
  bool get isLoading => _isLoading;
  int get unreadNotifications => _unreadNotifications;

  String get role => _currentUser?['role'] ?? '';
  String get userId => _currentUser?['id'] ?? '';
  String get companyId => _currentUser?['company_id'] ?? '';
  String get departmentId => _currentUser?['department_id'] ?? '';
  List<String> get serviceAreaIds {
    final usa = _currentUser?['user_service_areas'] as List?;
    if (usa == null) return [];
    return usa.map((u) => u['service_area_id'].toString()).toList();
  }
  String get fullName => '${_currentUser?['first_name'] ?? ''} ${_currentUser?['last_name'] ?? ''}'.trim();

  bool get isGeschaeftsfuehrer => role.toLowerCase() == 'geschaeftsfuehrer';
  bool get isBetriebsleiter => role.toLowerCase() == 'betriebsleiter';
  bool get isBereichsleiter => role.toLowerCase() == 'bereichsleiter';
  bool get isVorarbeiter => role.toLowerCase() == 'vorarbeiter';
  bool get isMitarbeiter => role.toLowerCase() == 'mitarbeiter';
  bool get isBuchhaltung => role.toLowerCase() == 'buchhaltung';
  bool get isBackoffice => role.toLowerCase() == 'backoffice';
  bool get isSystemAdmin => role.toLowerCase() == 'system_admin';
  bool get isExternalManager => role.toLowerCase() == 'external_manager';

  /// Externer Manager'ın muhattap olduğu customer contact ID'leri
  String get externalManagerEmail => _currentUser?['email'] ?? '';
  String get externalManagerContactRef => _currentUser?['id'] ?? '';

  bool get canManageCompanies => isGeschaeftsfuehrer || isSystemAdmin;
  bool get canManageUsers => isGeschaeftsfuehrer || isBetriebsleiter || isBereichsleiter || isSystemAdmin || isBackoffice;
  bool get canManageCustomers => isGeschaeftsfuehrer || isBetriebsleiter || isBereichsleiter || isBackoffice || isSystemAdmin;
  bool get canManageOrders => isGeschaeftsfuehrer || isBetriebsleiter || isBereichsleiter || isBackoffice || isSystemAdmin;
  bool get canPlanOperations => isGeschaeftsfuehrer || isBetriebsleiter || isBereichsleiter || isSystemAdmin;
  bool get canViewReports => isGeschaeftsfuehrer || isBetriebsleiter || isBuchhaltung || isSystemAdmin;
  bool get canManageInvoices => isGeschaeftsfuehrer || isBuchhaltung || isBetriebsleiter || isSystemAdmin;
  bool get canViewAllOrders => isGeschaeftsfuehrer || isBetriebsleiter || isSystemAdmin;
  bool get canViewAllCustomers => isGeschaeftsfuehrer || isBetriebsleiter || isSystemAdmin;
  bool get canManageDocuments => isGeschaeftsfuehrer || isBetriebsleiter || isBereichsleiter || isBackoffice || isBuchhaltung || isSystemAdmin;
  bool get canManageArchive => isGeschaeftsfuehrer || isBetriebsleiter || isBuchhaltung || isSystemAdmin;
  bool get canManageRoles => isGeschaeftsfuehrer || isSystemAdmin;
  bool get canManageEmployeeDocuments => isGeschaeftsfuehrer || isBetriebsleiter || isBackoffice || isBuchhaltung || isSystemAdmin;
  
  bool get canSeeFinancialDetails => isGeschaeftsfuehrer || isBetriebsleiter || isBuchhaltung || isSystemAdmin;
  bool get canSeeFullCustomerDetails => isGeschaeftsfuehrer || isBetriebsleiter || isBereichsleiter || isBackoffice || isSystemAdmin;
  bool get canViewAllPersonnel => isGeschaeftsfuehrer || isBetriebsleiter || isSystemAdmin;
  bool get canViewAllDepartments => isGeschaeftsfuehrer || isBetriebsleiter || isSystemAdmin;

  /// Returns the IDs of companies the user is authorized to view based on their service areas.
  /// If the user is a GF or Admin, they might see all companies? Actually, following the strict 
  /// "only their company" rule for Bereichsleiter.
  List<String> get authorizedCompanyIds {
    if (isGeschaeftsfuehrer || isSystemAdmin) {
      // GF can see all, but usually we handle it by not filtering.
      // But for some screens, we need the "Main" or current selection.
      return []; 
    }
    final usa = _currentUser?['user_service_areas'] as List?;
    if (usa == null) return [];
    
    final companyIds = usa
        .map((u) => u['service_areas']?['department']?['company_id']?.toString())
        .where((id) => id != null)
        .cast<String>()
        .toSet()
        .toList();
    return companyIds;
  }

  AppState() {
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedUserId = prefs.getString('custom_user_id');
      final stayLoggedIn = prefs.getBool('stay_logged_in') ?? false;
      
      if (stayLoggedIn && savedUserId != null && savedUserId.isNotEmpty) {
        final profile = await SupabaseService.getUserProfileById(savedUserId);
        if (profile != null) {
          _currentUser = profile;
          _unreadNotifications = await SupabaseService.getUnreadNotificationCount(userId);
          // FCM token'i arka planda güncelle
          _registerFcmToken(userId);
        } else {
          await prefs.remove('custom_user_id');
          await prefs.remove('stay_logged_in');
        }
      }
    } catch (e) {
      debugPrint('[AppState.initialize] Error: $e');
    }
    _isInitialized = true;
    notifyListeners();
  }

  /// Custom login: Returns null on success, error message on failure
  Future<String?> signIn(String email, String password, {bool rememberMe = false}) async {
    _isLoading = true;
    notifyListeners();
    try {
      debugPrint('[AUTH] Signing in with: $email (Remember: $rememberMe)');
      final user = await SupabaseService.signIn(email, password);
      if (user == null) {
        debugPrint('[AUTH] Failed: User not found or password incorrect.');
        _isLoading = false;
        notifyListeners();
        return tr('E-posta veya şifre hatalı.');
      }
      
      debugPrint('[AUTH] Success! User ID: ${user['id']}');
      _currentUser = user;
      final prefs = await SharedPreferences.getInstance();
      
      if (rememberMe) {
        await prefs.setString('custom_user_id', user['id']);
        await prefs.setBool('stay_logged_in', true);
      } else {
        await prefs.remove('custom_user_id');
        await prefs.remove('stay_logged_in');
      }
      
      _unreadNotifications = await SupabaseService.getUnreadNotificationCount(userId);
      // FCM token'ı backend'e kaydet (kimin telefonu hangi cihaz)
      _registerFcmToken(user['id']);
      _isLoading = false;
      notifyListeners();
      return null;
    } catch (e) {
      debugPrint('[AUTH] Error during signIn: $e');
      _isLoading = false;
      notifyListeners();
      return '${tr('Bağlantı hatası')}: ${e.toString()}';
    }
  }

  /// FCM token'i al ve backend'e kaydet
  Future<void> _registerFcmToken(String uid) async {
    try {
      // Bildirim izni iste (iOS için zorunlu, Android'de iyi pratik)
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission(
        alert: true, badge: true, sound: true,
      );
      final token = await messaging.getToken();
      if (token != null && token.isNotEmpty) {
        debugPrint('[FCM] Token alındı: ${token.substring(0, 20)}...');
        final url = Uri.parse('$_backendBase/users/$uid/fcm-token');
        await http.post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'fcm_token': token}),
        ).timeout(const Duration(seconds: 10));
        debugPrint('[FCM] Token backend\'e kaydedildi.');
      } else {
        debugPrint('[FCM] Token alınamadı (null/empty).');
      }
    } catch (e) {
      debugPrint('[FCM] Token kayıt hatası: $e');
    }
  }

  Future<void> _loadUserProfile() async {
    if (userId.isEmpty) return;
    _currentUser = await SupabaseService.getUserProfileById(userId);
    if (_currentUser != null) {
      _unreadNotifications = await SupabaseService.getUnreadNotificationCount(userId);
    }
    notifyListeners();
  }

  Future<void> signOut() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('custom_user_id');
    await prefs.remove('stay_logged_in');
    _currentUser = null;
    _unreadNotifications = 0;
    notifyListeners();
  }

  Future<void> refreshProfile() async {
    await _loadUserProfile();
  }

  void decrementUnread() {
    if (_unreadNotifications > 0) {
      _unreadNotifications--;
      notifyListeners();
    }
  }
}

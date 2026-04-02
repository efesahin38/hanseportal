import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/supabase_service.dart';

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
  String get fullName => '${_currentUser?['first_name'] ?? ''} ${_currentUser?['last_name'] ?? ''}'.trim();

  bool get isGeschaeftsfuehrer => role == 'geschaeftsfuehrer';
  bool get isBetriebsleiter => role == 'betriebsleiter';
  bool get isBereichsleiter => role == 'bereichsleiter';
  bool get isVorarbeiter => role == 'vorarbeiter';
  bool get isMitarbeiter => role == 'mitarbeiter';
  bool get isBuchhaltung => role == 'buchhaltung';
  bool get isBackoffice => role == 'backoffice';
  bool get isSystemAdmin => role == 'system_admin';

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
  
  bool get canSeeFinancialDetails => isGeschaeftsfuehrer || isBetriebsleiter || isBuchhaltung || isSystemAdmin;
  bool get canSeeFullCustomerDetails => isGeschaeftsfuehrer || isBetriebsleiter || isBereichsleiter || isBackoffice || isSystemAdmin;
  bool get canViewAllPersonnel => isGeschaeftsfuehrer || isBetriebsleiter || isSystemAdmin;
  bool get canViewAllDepartments => isGeschaeftsfuehrer || isBetriebsleiter || isSystemAdmin;

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
        return 'E-posta veya şifre hatalı.';
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
      _isLoading = false;
      notifyListeners();
      return null;
    } catch (e) {
      debugPrint('[AUTH] Error during signIn: $e');
      _isLoading = false;
      notifyListeners();
      return 'Bağlantı hatası: ${e.toString()}';
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

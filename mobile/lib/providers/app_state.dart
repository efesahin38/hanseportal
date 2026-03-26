import 'package:flutter/material.dart';
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
  bool get canManageUsers => isGeschaeftsfuehrer || isBetriebsleiter || isSystemAdmin;
  bool get canManageCustomers => isGeschaeftsfuehrer || isBetriebsleiter || isBereichsleiter || isBackoffice || isSystemAdmin;
  bool get canManageOrders => isGeschaeftsfuehrer || isBetriebsleiter || isBereichsleiter || isBackoffice || isSystemAdmin;
  bool get canPlanOperations => isGeschaeftsfuehrer || isBetriebsleiter || isBereichsleiter || isSystemAdmin;
  bool get canViewReports => isGeschaeftsfuehrer || isBetriebsleiter || isBereichsleiter || isBuchhaltung || isSystemAdmin;
  bool get canManageInvoices => isGeschaeftsfuehrer || isBuchhaltung || isSystemAdmin;
  bool get canViewAllOrders => isGeschaeftsfuehrer || isBetriebsleiter || isSystemAdmin;

  AppState() {
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      final session = SupabaseService.currentSession;
      if (session != null) {
        await _loadUserProfile();
      }
    } catch (_) {}
    _isInitialized = true;
    notifyListeners();
  }

  Future<bool> signIn(String email, String password) async {
    _isLoading = true;
    notifyListeners();
    try {
      await SupabaseService.signIn(email, password);
      await _loadUserProfile();
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> _loadUserProfile() async {
    _currentUser = await SupabaseService.getCurrentUserProfile();
    if (_currentUser != null) {
      _unreadNotifications = await SupabaseService.getUnreadNotificationCount(userId);
    }
    notifyListeners();
  }

  Future<void> signOut() async {
    await SupabaseService.signOut();
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

import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static final SupabaseClient _client = Supabase.instance.client;
  static SupabaseClient get client => _client;

  // ── Auth ──────────────────────────────────────────────────
  static Future<AuthResponse> signIn(String email, String password) {
    return _client.auth.signInWithPassword(email: email, password: password);
  }

  static Future<void> signOut() => _client.auth.signOut();

  static Session? get currentSession => _client.auth.currentSession;
  static User? get currentAuthUser => _client.auth.currentUser;

  // ── Mevcut Kullanıcı Profili ──────────────────────────────
  static Future<Map<String, dynamic>?> getCurrentUserProfile() async {
    final authUser = currentAuthUser;
    if (authUser == null) return null;
    final data = await _client
        .from('users')
        .select('''
          *,
          company:companies(id, name, short_name),
          department:departments(id, name),
          manager:users!users_manager_id_fkey(id, first_name, last_name)
        ''')
        .eq('auth_id', authUser.id)
        .maybeSingle();
    return data;
  }

  // ── Şirketler ─────────────────────────────────────────────
  static Future<List<Map<String, dynamic>>> getCompanies({String? status}) async {
    final base = _client.from('companies').select();
    final data = await (status != null ? base.eq('status', status).order('name') : base.order('name'));
    return List<Map<String, dynamic>>.from(data);
  }

  static Future<Map<String, dynamic>?> getCompany(String id) async {
    return await _client.from('companies').select().eq('id', id).maybeSingle();
  }

  static Future<void> upsertCompany(Map<String, dynamic> data) async {
    await _client.from('companies').upsert(data);
  }

  // ── Personel ──────────────────────────────────────────────
  static Future<List<Map<String, dynamic>>> getUsers({
    String? companyId,
    String? role,
    String? status,
    String? serviceAreaCode,
  }) async {
    var query = _client.from('users').select('''
      *,
      company:companies(id, name, short_name),
      department:departments(id, name)
    ''');
    if (companyId != null) query = query.eq('company_id', companyId) as dynamic;
    if (role != null) query = query.eq('role', role) as dynamic;
    if (status != null) query = query.eq('status', status) as dynamic;
    final data = await query.order('last_name');
    return List<Map<String, dynamic>>.from(data);
  }

  static Future<Map<String, dynamic>?> getUserById(String id) async {
    return await _client.from('users').select('''
      *,
      company:companies(id, name, short_name),
      department:departments(id, name),
      user_service_areas(service_area_id, service_areas(code, name, color))
    ''').eq('id', id).maybeSingle();
  }

  static Future<void> upsertUser(Map<String, dynamic> data) async {
    await _client.from('users').upsert(data);
  }

  // ── Müşteriler ────────────────────────────────────────────
  static Future<List<Map<String, dynamic>>> getCustomers({
    String? status,
    String? companyId,
  }) async {
    var query = _client.from('customers').select('''
      *,
      company:companies(id, name, short_name),
      customer_contacts(*)
    ''');
    if (status != null) query = query.eq('status', status) as dynamic;
    if (companyId != null) query = query.eq('company_id', companyId) as dynamic;
    final data = await query.order('name');
    return List<Map<String, dynamic>>.from(data);
  }

  static Future<Map<String, dynamic>?> getCustomer(String id) async {
    return await _client.from('customers').select('''
      *,
      company:companies(id, name, short_name),
      customer_contacts(*),
      customer_service_areas(service_area_id, service_areas(code, name, color))
    ''').eq('id', id).maybeSingle();
  }

  static Future<void> upsertCustomer(Map<String, dynamic> data) async {
    await _client.from('customers').upsert(data);
  }

  // ── İşler ─────────────────────────────────────────────────
  static Future<List<Map<String, dynamic>>> getOrders({
    String? status,
    String? companyId,
    String? customerId,
    String? responsibleUserId,
    String? serviceAreaId,
  }) async {
    var query = _client.from('orders').select('''
      *,
      company:companies(id, name, short_name),
      customer:customers(id, name),
      service_area:service_areas(id, code, name, color),
      responsible_user:users!orders_responsible_user_id_fkey(id, first_name, last_name),
      department:departments(id, name)
    ''');
    if (status != null) query = query.eq('status', status) as dynamic;
    if (companyId != null) query = query.eq('company_id', companyId) as dynamic;
    if (customerId != null) query = query.eq('customer_id', customerId) as dynamic;
    if (responsibleUserId != null) query = query.eq('responsible_user_id', responsibleUserId) as dynamic;
    final data = await query.order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(data);
  }

  static Future<Map<String, dynamic>?> getOrder(String id) async {
    return await _client.from('orders').select('''
      *,
      company:companies(id, name, short_name),
      customer:customers(id, name, phone, email),
      customer_contact:customer_contacts(id, name, phone, email),
      service_area:service_areas(id, code, name, color),
      responsible_user:users!orders_responsible_user_id_fkey(id, first_name, last_name),
      department:departments(id, name),
      order_status_history(*),
      documents(*),
      operation_plans(*)
    ''').eq('id', id).maybeSingle();
  }

  static Future<String> createOrder(Map<String, dynamic> data) async {
    final result = await _client.from('orders').insert(data).select().single();
    return result['id'];
  }

  static Future<void> updateOrderStatus(String orderId, String newStatus, String? note, String changedById) async {
    final order = await _client.from('orders').select('status').eq('id', orderId).single();
    await _client.from('order_status_history').insert({
      'order_id': orderId,
      'old_status': order['status'],
      'new_status': newStatus,
      'changed_by': changedById,
      'note': note,
    });
    await _client.from('orders').update({'status': newStatus}).eq('id', orderId);
  }

  // ── Operasyon Planları ────────────────────────────────────
  static Future<List<Map<String, dynamic>>> getOperationPlans({
    String? orderId,
    DateTime? date,
    DateTime? dateFrom,
    DateTime? dateTo,
    String? userId,
  }) async {
    var query = _client.from('operation_plans').select('''
      *,
      order:orders(id, title, order_number, site_address, customer:customers(id, name)),
      site_supervisor:users!operation_plans_site_supervisor_id_fkey(id, first_name, last_name),
      operation_plan_personnel(user_id, is_supervisor, users(id, first_name, last_name, role))
    ''');
    if (orderId != null) query = query.eq('order_id', orderId) as dynamic;
    if (date != null) {
      final dateStr = date.toIso8601String().split('T')[0];
      query = query.eq('plan_date', dateStr) as dynamic;
    }
    if (dateFrom != null) query = query.gte('plan_date', dateFrom.toIso8601String().split('T')[0]) as dynamic;
    if (dateTo != null) query = query.lte('plan_date', dateTo.toIso8601String().split('T')[0]) as dynamic;
    final data = await query.order('plan_date').order('start_time');
    return List<Map<String, dynamic>>.from(data);
  }

  static Future<void> upsertOperationPlan(Map<String, dynamic> data) async {
    await _client.from('operation_plans').upsert(data);
  }

  static Future<void> assignPersonnelToPlan(String planId, List<String> userIds, String assignedBy) async {
    final items = userIds.map((uid) => {
      'operation_plan_id': planId,
      'user_id': uid,
      'assigned_by': assignedBy,
    }).toList();
    await _client.from('operation_plan_personnel').upsert(items);
  }

  // ── Çalışma Seansları ─────────────────────────────────────
  static Future<Map<String, dynamic>?> getActiveSession(String userId) async {
    return await _client
        .from('work_sessions')
        .select('*, order:orders(id, title, order_number, site_address)')
        .eq('user_id', userId)
        .eq('status', 'started')
        .maybeSingle();
  }

  static Future<String> startWorkSession({
    required String orderId,
    required String userId,
    String? operationPlanId,
    double? minimumHours,
    double? lat,
    double? lon,
  }) async {
    final result = await _client.from('work_sessions').insert({
      'order_id': orderId,
      'user_id': userId,
      'operation_plan_id': operationPlanId,
      'actual_start': DateTime.now().toIso8601String(),
      'minimum_hours': minimumHours,
      'status': 'started',
      'start_latitude': lat,
      'start_longitude': lon,
    }).select().single();
    return result['id'];
  }

  static Future<void> endWorkSession(String sessionId, {String? note, double? lat, double? lon}) async {
    await _client.from('work_sessions').update({
      'actual_end': DateTime.now().toIso8601String(),
      'note': note,
      'end_latitude': lat,
      'end_longitude': lon,
    }).eq('id', sessionId);
  }

  static Future<void> adjustWorkSession(
    String sessionId, {
    required String adjustedBy,
    DateTime? actualStart,
    DateTime? actualEnd,
    String? adjustmentReason,
  }) async {
    final updates = <String, dynamic>{
      'is_manually_adjusted': true,
      'adjusted_by': adjustedBy,
      if (adjustmentReason != null) 'adjustment_reason': adjustmentReason,
      if (actualStart != null) 'actual_start': actualStart.toIso8601String(),
      if (actualEnd != null) 'actual_end': actualEnd.toIso8601String(),
    };
    await _client.from('work_sessions').update(updates).eq('id', sessionId);
  }

  static Future<List<Map<String, dynamic>>> getWorkSessionsForOrder(String orderId) async {
    final data = await _client.from('work_sessions').select('''
      *,
      user:users!work_sessions_user_id_fkey(id, first_name, last_name)
    ''').eq('order_id', orderId).order('actual_start');
    return List<Map<String, dynamic>>.from(data);
  }

  // ── Ek İşler ──────────────────────────────────────────────
  static Future<List<Map<String, dynamic>>> getExtraWorks(String orderId) async {
    final data = await _client
        .from('extra_works')
        .select('*, recorded_by_user:users!extra_works_recorded_by_fkey(first_name, last_name)')
        .eq('order_id', orderId)
        .order('work_date', ascending: false);
    return List<Map<String, dynamic>>.from(data);
  }

  static Future<void> createExtraWork(Map<String, dynamic> data) async {
    await _client.from('extra_works').insert(data);
  }

  // ── Bildirimler ───────────────────────────────────────────
  static Future<List<Map<String, dynamic>>> getNotifications(String userId) async {
    final data = await _client
        .from('notifications')
        .select()
        .eq('recipient_id', userId)
        .order('created_at', ascending: false)
        .limit(50);
    return List<Map<String, dynamic>>.from(data);
  }

  static Future<int> getUnreadNotificationCount(String userId) async {
    final data = await _client
        .from('notifications')
        .select('id')
        .eq('recipient_id', userId)
        .eq('is_read', false);
    return (data as List).length;
  }

  static Future<void> markNotificationRead(String notificationId) async {
    await _client.from('notifications').update({
      'is_read': true,
      'read_at': DateTime.now().toIso8601String(),
    }).eq('id', notificationId);
  }

  static Future<void> sendTaskNotification({
    required String recipientId,
    required String title,
    required String body,
    String? orderId,
    String? operationPlanId,
    required String sentBy,
  }) async {
    await _client.from('notifications').insert({
      'recipient_id': recipientId,
      'notification_type': 'task_assignment',
      'title': title,
      'body': body,
      'order_id': orderId,
      'operation_plan_id': operationPlanId,
      'sent_by': sentBy,
    });
  }

  // ── Departmanlar ──────────────────────────────────────────
  static Future<List<Map<String, dynamic>>> getDepartments(String companyId) async {
    final data = await _client
        .from('departments')
        .select()
        .eq('company_id', companyId)
        .eq('is_active', true)
        .order('name');
    return List<Map<String, dynamic>>.from(data);
  }

  // ── Hizmet Alanları ────────────────────────────────────────
  static Future<List<Map<String, dynamic>>> getServiceAreas() async {
    final data = await _client
        .from('service_areas')
        .select()
        .eq('is_active', true)
        .order('name');
    return List<Map<String, dynamic>>.from(data);
  }

  // ── İş Sonu Raporu ────────────────────────────────────────
  static Future<Map<String, dynamic>?> getWorkReport(String orderId) async {
    return await _client
        .from('work_reports')
        .select()
        .eq('order_id', orderId)
        .maybeSingle();
  }

  static Future<void> upsertWorkReport(Map<String, dynamic> data) async {
    await _client.from('work_reports').upsert(data);
  }

  // ── Ön Fatura Taslağı ─────────────────────────────────────
  static Future<List<Map<String, dynamic>>> getInvoiceDrafts({String? status}) async {
    var query = _client.from('invoice_drafts').select('''
      *,
      order:orders(id, title, order_number),
      customer:customers(id, name),
      issuing_company:companies!invoice_drafts_issuing_company_id_fkey(id, name, short_name)
    ''');
    if (status != null) query = query.eq('status', status) as dynamic;
    final data = await query.order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(data);
  }

  static Future<void> upsertInvoiceDraft(Map<String, dynamic> data) async {
    await _client.from('invoice_drafts').upsert(data);
  }

  static Future<void> updateInvoiceDraftStatus(String id, String status, {String? note}) async {
    await _client.from('invoice_drafts').update({
      'status': status,
      if (note != null) 'accounting_note': note,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', id);
  }

  static Future<Map<String, dynamic>?> getInvoiceDraftByOrder(String orderId) async {
    return await _client.from('invoice_drafts').select('''
      *,
      invoice_draft_items(*)
    ''').eq('order_id', orderId).maybeSingle();
  }

  static Future<List<Map<String, dynamic>>> getInvoiceDraftItems(String draftId) async {
    final data = await _client.from('invoice_draft_items')
        .select()
        .eq('invoice_draft_id', draftId)
        .order('sort_order');
    return List<Map<String, dynamic>>.from(data);
  }

  static Future<void> upsertInvoiceDraftItem(Map<String, dynamic> data) async {
    await _client.from('invoice_draft_items').upsert(data);
  }

  static Future<void> deleteInvoiceDraftItem(String itemId) async {
    await _client.from('invoice_draft_items').delete().eq('id', itemId);
  }

  // ── Belgeler ──────────────────────────────────────────────
  static Future<List<Map<String, dynamic>>> getDocuments({
    String? orderId,
    String? customerId,
    String? companyId,
  }) async {
    var query = _client.from('documents').select('''
      *,
      uploaded_by_user:users!documents_uploaded_by_fkey(first_name, last_name)
    ''');
    if (orderId != null) query = query.eq('order_id', orderId) as dynamic;
    if (customerId != null) query = query.eq('customer_id', customerId) as dynamic;
    if (companyId != null) query = query.eq('company_id', companyId) as dynamic;
    final data = await query.order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(data);
  }

  // ── Dashboard İstatistikleri ──────────────────────────────
  static Future<Map<String, int>> getDashboardStats(String companyId) async {
    final activeOrders = await _client
        .from('orders')
        .select('id')
        .eq('company_id', companyId)
        .inFilter('status', ['approved', 'planning', 'in_progress']);

    final todayStr = DateTime.now().toIso8601String().split('T')[0];
    final todayPlans = await _client
        .from('operation_plans')
        .select('id')
        .eq('plan_date', todayStr);

    final activePersonnel = await _client
        .from('users')
        .select('id')
        .eq('company_id', companyId)
        .eq('status', 'active');

    final pendingDrafts = await _client
        .from('invoice_drafts')
        .select('id')
        .inFilter('status', ['auto_generated', 'under_review']);

    return {
      'activeOrders': (activeOrders as List).length,
      'todayPlans': (todayPlans as List).length,
      'activePersonnel': (activePersonnel as List).length,
      'pendingDrafts': (pendingDrafts as List).length,
    };
  }

  // ── Takvim Etkinlikleri ───────────────────────────────────
  static Future<List<Map<String, dynamic>>> getCalendarEvents({
    DateTime? from,
    DateTime? to,
    String? orderId,
  }) async {
    var query = _client.from('calendar_events').select('''
      *,
      order:orders(id, title, order_number),
      responsible_user:users!calendar_events_responsible_user_id_fkey(id, first_name, last_name)
    ''');
    if (orderId != null) query = query.eq('order_id', orderId) as dynamic;
    if (from != null) query = query.gte('event_date', from.toIso8601String().split('T')[0]) as dynamic;
    if (to != null) query = query.lte('event_date', to.toIso8601String().split('T')[0]) as dynamic;
    final data = await query.order('event_date').order('start_time');
    return List<Map<String, dynamic>>.from(data);
  }

  static Future<void> createCalendarEvent(Map<String, dynamic> data) async {
    await _client.from('calendar_events').insert(data);
  }

  static Future<void> deleteCalendarEvent(String id) async {
    await _client.from('calendar_events').delete().eq('id', id);
  }

  // ── Muhasebe Özeti ────────────────────────────────────────
  static Future<Map<String, dynamic>> getAccountingSummary() async {
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1).toIso8601String().split('T')[0];

    final invoiced = await _client.from('invoice_drafts').select('total_amount').eq('status', 'invoiced').gte('created_at', monthStart);
    final pending = await _client.from('invoice_drafts').select('total_amount').inFilter('status', ['auto_generated', 'under_review']).gte('created_at', monthStart);
    final completedOrders = await _client.from('orders').select('id').eq('status', 'completed').gte('updated_at', monthStart);
    final pendingDrafts = await _client.from('invoice_drafts').select('id').inFilter('status', ['auto_generated', 'under_review']);

    double invoicedTotal = 0;
    for (final r in (invoiced as List)) { invoicedTotal += double.tryParse(r['total_amount']?.toString() ?? '0') ?? 0; }
    double pendingTotal = 0;
    for (final r in (pending as List)) { pendingTotal += double.tryParse(r['total_amount']?.toString() ?? '0') ?? 0; }

    return {
      'invoiced_total': invoicedTotal,
      'pending_total': pendingTotal,
      'completed_orders': (completedOrders as List).length,
      'pending_drafts': (pendingDrafts as List).length,
    };
  }

  // ── Personel Görev Listesi (saha çalışanı için) ───────────
  static Future<List<Map<String, dynamic>>> getMyAssignedPlans(String userId) async {
    final data = await _client.from('operation_plan_personnel').select('''
      operation_plan_id, is_supervisor,
      operation_plans(
        id, plan_date, start_time, end_time, status, site_instructions, equipment_notes,
        order:orders(id, title, order_number, site_address, customer:customers(id, name))
      )
    ''').eq('user_id', userId).order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(data);
  }
}

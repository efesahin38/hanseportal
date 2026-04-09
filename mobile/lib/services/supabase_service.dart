import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'localization_service.dart';

// Backend URL – Render production sunucusu
const String _kBackendBase = 'https://ekrem.onrender.com/api';

class SupabaseService {
  static final SupabaseClient _client = Supabase.instance.client;
  static SupabaseClient get client => _client;

  /// Backend notification endpoint'ini sessizce tetikler (hata olursa atlatır)
  static Future<void> _notifyBackend(String path, Map<String, dynamic> body) async {
    try {
      await http.post(
        Uri.parse('$_kBackendBase$path'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 8));
    } catch (e) {
      debugPrint('[Notify] $path hatası: $e');
    }
  }

  // ── Auth (LOKAL SQL KONTROLÜ) ─────────────────────────────
  static Future<Map<String, dynamic>?> signIn(String email, String password) async {
    final data = await _client.from('users').select().eq('email', email.toLowerCase()).eq('password', password).maybeSingle();
    return data;
  }

  static Future<void> signOut() async {
    // Lokal sistemde çıkış için session silmek gerekmez, AppState'ten temizlenir
  }

  static Future<void> deleteOrder(String id) async {
    // SİLME İŞLEMİ: Statüyü 'passive' yapıyoruz. Bu statü tüm sistemden (Arşiv dahil) gizlenir.
    await _client.from('orders').update({'status': 'passive'}).eq('id', id);
  }

  static Future<void> deleteCustomer(String id) async {
    // SİLME İŞLEMİ: Statüyü 'passive' yapıyoruz. Sistemin hiçbir yerinde görünmez hale gelir.
    await _client.from('customers').update({'status': 'passive'}).eq('id', id);
  }

  // ── Mevcut Kullanıcı Profili ──────────────────────────────
  static Future<Map<String, dynamic>?> getUserProfileById(String userId) async {
    final data = await _client
        .from('users')
        .select('''
          *,
          company:companies(id, name, short_name),
          department:departments(id, name)
        ''')
        .eq('id', userId)
        .maybeSingle();
    return data;
  }

  // ── Şirketler ─────────────────────────────────────────────
  static Future<List<Map<String, dynamic>>> getCompanies({String? status, List<String>? serviceAreaIds}) async {
    var query = _client.from('companies').select('''
      *,
      departments(*)
    ''');
    
    if (status != null) {
      query = query.eq('status', status) as dynamic;
    }

    final data = await query.order('name');
    var list = List<Map<String, dynamic>>.from(data);

    // If serviceAreaIds is provided, filter companies that own those service areas
    if (serviceAreaIds != null && serviceAreaIds.isNotEmpty) {
      // First, get the service areas to find their company_ids (via departments)
      final allAreas = await getServiceAreas();
      final authorizedCompanyIds = allAreas
          .where((sa) => serviceAreaIds.contains(sa['id'].toString()))
          .map((sa) => sa['department']?['company_id']?.toString())
          .where((id) => id != null)
          .toSet();
      
      list = list.where((c) => authorizedCompanyIds.contains(c['id'].toString())).toList();
    }

    if (status == null) {
      return list.where((item) => item['status'] != 'passive' && item['status'] != 'archived').toList();
    }
    return list;
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
    String? departmentId,
    String? role,
    String? status,
    String? serviceAreaCode,
    List<String>? serviceAreaIds,
  }) async {
    var query = _client.from('users').select('''
      *,
      company:companies(id, name, short_name),
      department:departments(id, name),
      user_service_areas(service_area_id, service_areas(code, name, color))
    ''');
    if (companyId != null) query = query.eq('company_id', companyId) as dynamic;
    if (departmentId != null) query = query.eq('department_id', departmentId) as dynamic;
    if (role != null) query = query.eq('role', role) as dynamic;
    if (status != null) {
      query = query.eq('status', status) as dynamic;
    }
    
    final data = await query.order('last_name');
    var list = List<Map<String, dynamic>>.from(data);
    
    // Checkbox departman filtreleme
    if (serviceAreaIds != null && serviceAreaIds.isNotEmpty) {
      list = list.where((user) {
        final usa = user['user_service_areas'] as List?;
        if (usa == null || usa.isEmpty) return false;
        return usa.any((u) => serviceAreaIds.contains(u['service_area_id'].toString()));
      }).toList();
    }
    
    // Eğer spesifik bir statü istenmediyse hem 'passive' (silinen) hem 'archived' (arşivlenen) gizlenir.
    if (status == null) {
       return list.where((item) => item['status'] != 'passive' && item['status'] != 'archived').toList();
    }
    return list;
  }

  static Future<Map<String, dynamic>?> getUserById(String id) async {
    return await _client.from('users').select('''
      *,
      company:companies(id, name, short_name),
      department:departments(id, name),
      user_service_areas(service_area_id, service_areas(code, name, color))
    ''').eq('id', id).maybeSingle();
  }

  static Future<Map<String, dynamic>> upsertUser(Map<String, dynamic> data, {List<String>? serviceAreaIds}) async {
    final response = await _client.from('users').upsert(data).select('id').single();
    final String userId = response['id'];
    
    if (serviceAreaIds != null) {
      // First, delete existing ones for this user
      await _client.from('user_service_areas').delete().eq('user_id', userId);
      // Then insert new ones
      if (serviceAreaIds.isNotEmpty) {
        final inserts = serviceAreaIds.map((sid) => {
          'user_id': userId,
          'service_area_id': sid,
          'is_qualified': true
        }).toList();
        await _client.from('user_service_areas').insert(inserts);
      }
    }
    return response;
  }

  // ── Müşteriler ────────────────────────────────────────────
  static Future<List<Map<String, dynamic>>> getCustomers({
    String? status,
    String? companyId,
    String? departmentId,
    String? serviceAreaId,
  }) async {
    // Service Area veya Departman bazlı filtreleme için join kullanıyoruz
    String selectStr = '''
      *,
      company:companies(id, name, short_name),
      customer_contacts(*),
      customer_service_areas!inner(service_area_id)
    ''';
    
    // Eğer bir filtre yoksa !inner kullanmamak gerekebilir (tüm müşterileri getirmek için)
    if (departmentId == null && serviceAreaId == null) {
      selectStr = '''
        *,
        company:companies(id, name, short_name),
        customer_contacts(*),
        customer_service_areas(service_area_id)
      ''';
    }

    var query = _client.from('customers').select(selectStr);
    
    if (status != null) {
      query = query.eq('status', status) as dynamic;
    }

    if (companyId != null) query = query.eq('company_id', companyId) as dynamic;
    
    if (serviceAreaId != null) {
      query = query.eq('customer_service_areas.service_area_id', serviceAreaId) as dynamic;
    } else if (departmentId != null) {
      // 🛡️ NAILED ISOLATION: Sadece bu departmanın service area'larına atanmış müşterileri getir
      final deptSAs = await _client.from('service_areas').select('id').eq('department_id', departmentId);
      final saIds = (deptSAs as List).map((sa) => sa['id'] as String).toList();
      if (saIds.isEmpty) return [];
      query = query.inFilter('customer_service_areas.service_area_id', saIds) as dynamic;
    }

    final data = await query.order('name');
    final list = List<Map<String, dynamic>>.from(data);
    
    if (status == null) {
      return list.where((item) => item['status'] != 'passive' && item['status'] != 'archived').toList();
    }
    return list;
  }

  static Future<Map<String, dynamic>?> getCustomer(String id) async {
    return await _client.from('customers').select('''
      *,
      company:companies(id, name, short_name),
      customer_contacts(*),
      customer_service_areas(service_area_id, service_areas(code, name, color))
    ''').eq('id', id).maybeSingle();
  }

  static Future<void> upsertCustomer(Map<String, dynamic> data, {String? serviceAreaId}) async {
    final result = await _client.from('customers').upsert(data).select('id').single();
    final customerId = result['id'];

    if (serviceAreaId != null) {
      await _client.from('customer_service_areas').delete().eq('customer_id', customerId);
      await _client.from('customer_service_areas').insert({
        'customer_id': customerId,
        'service_area_id': serviceAreaId,
      });
    }
  }

  // ── İşler ─────────────────────────────────────────────────
  static Future<List<Map<String, dynamic>>> getOrders({
    String? status,
    String? companyId,
    String? customerId,
    String? responsibleUserId,
    String? serviceAreaId,
    String? departmentId,
  }) async {
    var query = _client.from('orders').select('''
      *,
      company:companies(id, name, short_name),
      customer:customers(id, name),
      service_area:service_areas(id, code, name, color),
      responsible_user:users!orders_responsible_user_id_fkey(id, first_name, last_name),
      department:departments(id, name)
    ''');
    if (status != null) {
      query = query.eq('status', status) as dynamic;
    }

    if (companyId != null) query = query.eq('company_id', companyId) as dynamic;
    if (customerId != null) query = query.eq('customer_id', customerId) as dynamic;
    if (responsibleUserId != null) query = query.eq('responsible_user_id', responsibleUserId) as dynamic;
    if (serviceAreaId != null) query = query.eq('service_area_id', serviceAreaId) as dynamic;
    
    // Bereichsleiter (Bölüm Sorumlusu) ise sadece kendi departmanını görsün
    // Not: departmentId parametre olarak da gelebilir, zorlayalım.
    if (departmentId != null) query = query.eq('department_id', departmentId) as dynamic;

    final data = await query.order('created_at', ascending: false);
    final list = List<Map<String, dynamic>>.from(data);
    if (status == null) {
      return list.where((item) => item['status'] != 'passive' && item['status'] != 'archived').toList();
    }
    return list;
  }

  static Future<Map<String, dynamic>?> getOrder(String id) async {
    return await _client.from('orders').select('''
      *,
      company:companies(id, name, short_name),
      customer:customers(id, name, phone, email, vat_number, bank_name, iban, bic),
      customer_contact:customer_contacts(id, name, phone, email),
      service_area:service_areas(id, code, name, color),
      responsible_user:users!orders_responsible_user_id_fkey(id, first_name, last_name),
      department:departments(id, name),
      order_status_history(*),
      documents(*),
      operation_plans(
        *,
        site_supervisor:users!operation_plans_site_supervisor_id_fkey(id, first_name, last_name),
        operation_plan_personnel(
          user_id,
          is_supervisor,
          user:users!operation_plan_personnel_user_id_fkey(id, first_name, last_name, role)
        )
      )
    ''').eq('id', id).maybeSingle();
  }

  static Future<String> createOrder(Map<String, dynamic> data) async {
    final result = await _client.from('orders').insert(data).select().single();
    final orderId = result['id'] as String;
    // Yeni iş bildirimi (arka planda, hata olursa atlatır)
    _notifyBackend('/orders/notify-new', {
      'order_id': orderId,
      'created_by': data['created_by'],
    });
    return orderId;
  }

  static Future<void> updateOrderStatus(String orderId, String newStatus, String? note, String changedById) async {
    final order = await _client.from('orders')
        .select('status, title, company_id, customer_id, site_address, planned_start_date, planned_end_date, customer:customers(name, address)')
        .eq('id', orderId).single();
    
    final oldStatus = order['status'];

    await _client.from('order_status_history').insert({
      'order_id': orderId,
      'old_status': oldStatus,
      'new_status': newStatus,
      'changed_by': changedById,
      'note': note,
    });
    
    await _client.from('orders').update({'status': newStatus}).eq('id', orderId);

    // Durum değişikliği bildirimi (arka planda)
    _notifyBackend('/orders/$orderId/notify-status', {
      'new_status': newStatus,
      'changed_by': changedById,
    });

    // Otomatik Taslak Oluşturma (Eğer arka planda trigger çalışmıyorsa yedek)
    if (newStatus == 'completed' && oldStatus != 'completed') {
      try {
        final existing = await _client.from('invoice_drafts').select('id').eq('order_id', orderId).maybeSingle();
        if (existing == null) {
          final customer = order['customer'] ?? {};
          final draftData = {
            'order_id': orderId,
            'issuing_company_id': order['company_id'],
            'customer_id': order['customer_id'],
            'billing_name': customer['name'],
            'billing_address': customer['address'],
            'site_address': order['site_address'],
            'service_date_from': order['planned_start_date'],
            'service_date_to': order['planned_end_date'],
            'status': 'auto_generated',
            'internal_notes': tr('Sistem tarafından otomatik oluşturuldu – lütfen kalemleri düzenleyin.'),
          };
          
          final result = await _client.from('invoice_drafts').insert(draftData).select().single();
          
          await _client.from('invoice_draft_items').insert({
            'invoice_draft_id': result['id'],
            'item_type': 'main',
            'description': order['title'] ?? tr('Hizmet Bedeli'),
            'quantity': 1,
            'unit': 'Pausch.',
          });
        }
      } catch (e) {
        print('Front-end invoice draft creation error: $e');
      }
    }
  }

  static Future<void> markOrderAsInvoiced(String orderId, String changedById) async {
    // 1. Order status güncelle ve logla
    await updateOrderStatus(orderId, 'invoiced', tr('Tahsilat / Fatura süreci başlatıldı'), changedById);

    // 2. Draft faturayı invoiced yap
    final existingDraft = await _client.from('invoice_drafts').select('id, status').eq('order_id', orderId).maybeSingle();
    if (existingDraft != null) {
      if (existingDraft['status'] != 'invoiced') {
        await _client.from('invoice_drafts').update({'status': 'invoiced'}).eq('id', existingDraft['id']);
      }
    } else {
      // Draft yoksa yeni yarat ve invoiced yap
      final order = await getOrder(orderId);
      if (order != null) {
        final customer = order['customer'] ?? {};
        final draftData = {
          'order_id': orderId,
          'issuing_company_id': order['company_id'],
          'customer_id': order['customer_id'],
          'billing_name': customer['name'],
          'billing_address': customer['address'],
          'site_address': order['site_address'],
          'service_date_from': order['planned_start_date'],
          'service_date_to': order['planned_end_date'],
          'status': 'invoiced',
        };
        final result = await _client.from('invoice_drafts').insert(draftData).select().single();
        await _client.from('invoice_draft_items').insert({
          'invoice_draft_id': result['id'],
          'item_type': 'main',
          'description': order['title'] ?? tr('Hizmet Bedeli'),
          'quantity': 1,
          'unit': 'Pausch.',
        });
      }
    }
  }

  // ── Operasyon Planları ────────────────────────────────────
  static Future<List<Map<String, dynamic>>> getOperationPlans({
    String? orderId,
    DateTime? date,
    DateTime? dateFrom,
    DateTime? dateTo,
    String? userId,
    String? departmentId,
  }) async {
    final inner = userId != null ? '!inner' : '';
    final deptInner = departmentId != null ? '!inner' : '';
    var query = _client.from('operation_plans').select('''
      *,
      order:orders$deptInner(id, title, order_number, site_address, department_id, status, customer:customers(id, name)),
      site_supervisor:users!operation_plans_site_supervisor_id_fkey(id, first_name, last_name),
      operation_plan_personnel$inner(user_id, is_supervisor, users!operation_plan_personnel_user_id_fkey(id, first_name, last_name, role))
    ''');
    if (orderId != null) query = query.eq('order_id', orderId) as dynamic;
    if (departmentId != null) query = query.eq('orders.department_id', departmentId) as dynamic;
    if (date != null) {
      final dateStr = date.toIso8601String().split('T')[0];
      query = query.eq('plan_date', dateStr) as dynamic;
    }
    if (dateFrom != null) query = query.gte('plan_date', dateFrom.toIso8601String().split('T')[0]) as dynamic;
    if (dateTo != null) query = query.lte('plan_date', dateTo.toIso8601String().split('T')[0]) as dynamic;
    if (userId != null) query = query.eq('operation_plan_personnel.user_id', userId) as dynamic;
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

    // Personellere yeni görev bildirimi gönder (arka planda)
    _notifyBackend('/operation-plans/notify-new', {
      'plan_id': planId,
      'user_ids': userIds,
    });

    try {
      final plan = await _client.from('operation_plans').select('order_id').eq('id', planId).single();
      final orderId = plan['order_id'];
      if (orderId != null) {
        final order = await _client.from('orders').select('status').eq('id', orderId).single();
        if (order['status'] == 'draft') {
          await updateOrderStatus(orderId, 'planning', tr('Personel atandı, plan oluşturuldu'), assignedBy);
        }
      }
    } catch (e) {
      print('Status change to planning error: $e');
    }
  }

  // ── Çalışma Seansları ─────────────────────────────────────
  static Future<Map<String, dynamic>?> getActiveSession(String userId) async {
    return await _client
        .from('work_sessions')
        .select('''
          *,
          order:orders(id, title, order_number, site_address),
          operation_plan:operation_plans(id, plan_date, start_time, end_time)
        ''')
        .eq('user_id', userId)
        .eq('status', 'started')
        .maybeSingle();
  }

  /// Yakın zamanda tamamlanmış seansları getirir (görev kartında başlangıç/bitiş göstermek için)
  static Future<List<Map<String, dynamic>>> getRecentCompletedSessions(String userId) async {
    final now = DateTime.now();
    final past = now.subtract(const Duration(days: 7)).toIso8601String().split('T')[0];
    final future = now.add(const Duration(days: 14)).toIso8601String().split('T')[0];
    
    final data = await _client
        .from('work_sessions')
        .select('id, operation_plan_id, actual_start, actual_end')
        .eq('user_id', userId)
        .eq('status', 'completed')
        .gte('actual_start', '${past}T00:00:00Z')
        .lte('actual_start', '${future}T23:59:59Z');
    return List<Map<String, dynamic>>.from(data);
  }

  static Future<String> startWorkSession({
    required String orderId,
    required String userId,
    String? operationPlanId,
    double? minimumHours,
    double? lat,
    double? lon,
    int? delayMinutes,
  }) async {
    final result = await _client.from('work_sessions').insert({
      'order_id': orderId,
      'user_id': userId,
      'operation_plan_id': operationPlanId,
      'actual_start': DateTime.now().toUtc().toIso8601String(),
      'minimum_hours': minimumHours,
      'status': 'started',
      'start_latitude': lat,
      'start_longitude': lon,
      if (delayMinutes != null && delayMinutes > 0) 'delay_minutes': delayMinutes,
    }).select().single();
    final sessionId = result['id'] as String;
    // Çalışma başladı bildirimi (saha sorumlusu + yöneticiler)
    _notifyBackend('/work-sessions/notify-start', {'session_id': sessionId});

    return sessionId;
  }

  static Future<void> endWorkSession(String sessionId, {String? note, double? lat, double? lon}) async {
    await _client.from('work_sessions').update({
      'actual_end': DateTime.now().toUtc().toIso8601String(),
      'note': note,
      'end_latitude': lat,
      'end_longitude': lon,
      'status': 'completed',
    }).eq('id', sessionId);
    // Çalışma bitiş bildirimi
    _notifyBackend('/work-sessions/notify-end', {'session_id': sessionId});
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

  static Future<List<Map<String, dynamic>>> getWorkSessionsPendingApproval({String? departmentId}) async {
    var query = _client.from('work_sessions').select('''
      *,
      user:users!work_sessions_user_id_fkey(id, first_name, last_name),
      order:orders(
        id, title, order_number, department_id,
        extra_works:extra_works!extra_works_order_id_fkey(
          *,
          recorded_by_user:users!extra_works_recorded_by_fkey(first_name, last_name)
        )
      ),
      operation_plan:operation_plans(id, estimated_duration_h, start_time, end_time)
    ''').eq('status', 'completed').eq('approval_status', 'pending');
    
    if (departmentId != null) {
      query = query.eq('orders.department_id', departmentId) as dynamic;
    }
    
    final data = await query.order('actual_end', ascending: false);
    return List<Map<String, dynamic>>.from(data);
  }

  static Future<void> approveWorkSession(String sessionId, double approvedHours, String approvedBy) async {
    // 1. Durumu güncelle
    await _client.from('work_sessions').update({
      'approval_status': 'approved',
      'approved_billable_hours': approvedHours,
      'approved_by': approvedBy,
      'approved_at': DateTime.now().toIso8601String(),
    }).eq('id', sessionId);

    // 2. Fatura Taslağına Senkronize et
    await _syncSessionToInvoiceDraft(sessionId);

    // 3. Muhasebeye Bildirim Gönder
    await sendNotificationToAccounting(
      title: tr('Yeni Mesai Onaylandı'),
      body: tr('Bir çalışma seansı onaylandı ve fatura taslağına eklendi.'),
      sentBy: approvedBy,
    );
  }

  static Future<void> _syncSessionToInvoiceDraft(String sessionId) async {
    try {
      // Oturum ve İş bilgilerini getir
      final session = await _client.from('work_sessions').select('''
        *,
        user:users(id, first_name, last_name),
        order:orders(*)
      ''').eq('id', sessionId).single();

      final order = session['order'];
      final user = session['user'];
      final orderId = order['id'];

      // 1. Taslağı bul veya oluştur
      var draft = await _client.from('invoice_drafts').select().eq('order_id', orderId).maybeSingle();
      
      if (draft == null) {
        final data = {
          'order_id': orderId,
          'issuing_company_id': order['company_id'],
          'customer_id': order['customer_id'],
          'billing_name': order['title'] ?? tr('Hizmet Bedeli'),
          'status': 'auto_generated',
          'service_date_from': order['planned_start_date'],
          'service_date_to': order['planned_end_date'],
        };
        draft = await _client.from('invoice_drafts').insert(data).select().single();
      }

      // 2. Kalemi ekle (Eğer zaten eklenmemişse)
      final existingItem = await _client.from('invoice_draft_items')
          .select()
          .eq('invoice_draft_id', draft['id'])
          .eq('work_session_id', sessionId)
          .maybeSingle();

      if (existingItem == null) {
        final start = session['actual_start'] != null ? DateTime.parse(session['actual_start']).toLocal() : DateTime.now();
        final dateStr = DateFormat('dd.MM.yyyy').format(start);
        final description = '${user['first_name']} ${user['last_name']} - $dateStr ${tr('Çalışma Bedeli')}';
        
        await _client.from('invoice_draft_items').insert({
          'invoice_draft_id': draft['id'],
          'work_session_id': sessionId,
          'item_type': 'main',
          'description': description,
          'quantity': session['approved_billable_hours'],
          'unit': 'Std.',
        });
      }
    } catch (e) {
      print('Sync Error: $e');
    }
  }

  static Future<void> rejectWorkSession(String sessionId, String reason, String rejectedBy) async {
    await _client.from('work_sessions').update({
      'approval_status': 'rejected',
      'rejection_reason': reason,
      'approved_by': rejectedBy,
      'approved_at': DateTime.now().toIso8601String(),
    }).eq('id', sessionId);
  }

  static Future<List<Map<String, dynamic>>> getApprovedWorkSessionsForAccounting({List<String>? serviceAreaIds, String? departmentId}) async {
    // Basic query with joins
    // We use inner joins to ensure we only get sessions that have an associated order and customer
    var query = _client.from('work_sessions').select('''
      *,
      order:orders!inner(
        id, title, order_number, service_area_id, department_id, status,
        customer:customers(name),
        invoice_drafts(total_amount, subtotal),
        extra_works(estimated_material_cost, estimated_labor_cost),
        work_reports(total_revenue, estimated_labor_cost, estimated_material_cost)
      ),
      approved_by_user:users!work_sessions_approved_by_fkey(id, first_name, last_name)
    ''').eq('approval_status', 'approved');
    
    if (serviceAreaIds != null && serviceAreaIds.isNotEmpty) {
      query = query.inFilter('order.service_area_id', serviceAreaIds) as dynamic;
    } else if (departmentId != null) {
      query = query.eq('order.department_id', departmentId) as dynamic;
    }
    
    final data = await query.order('approved_at', ascending: false);
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
    final result = await _client.from('extra_works').insert({
      ...data,
      'status': data['status'] ?? 'pending',
    }).select('id').single();
    // Ek iş bildirimi (arka planda)
    _notifyBackend('/extra-works/notify-new', {
      'extra_work_id': result['id'],
      'recorded_by': data['recorded_by'],
    });
  }

  static Future<void> approveExtraWork(String extraWorkId, String approvedBy) async {
    // 1. Durumu güncelle
    await _client.from('extra_works').update({
      'status': 'approved',
      'approved_by': approvedBy,
      'approved_at': DateTime.now().toIso8601String(),
    }).eq('id', extraWorkId);

    // 2. Fatura Taslağına Senkronize et
    final extraWork = await _client.from('extra_works').select('*, order:orders(*)').eq('id', extraWorkId).single();
    await _syncExtraWorkToInvoiceDraft(extraWork);

    // 3. Muhasebeye Bildirim Gönder
    await sendNotificationToAccounting(
      title: tr('Yeni Ek İş Onaylandı'),
      body: '${extraWork['title']} ${tr('başlıklı ek iş onaylandı ve faturaya eklendi.')}',
      sentBy: approvedBy,
    );
  }

  // ── Muhasebeye Bildirim Gönderme Yardımı ───────────────────
  static Future<void> sendNotificationToAccounting({
    required String title,
    required String body,
    required String sentBy,
  }) async {
    try {
      // Muhasebe rolündeki tüm kullanıcıları bul
      final accountingUsers = await _client.from('users').select('id').eq('role', 'buchhaltung');
      
      for (var u in accountingUsers) {
        await sendTaskNotification(
          recipientId: u['id'],
          title: title,
          body: body,
          sentBy: sentBy,
          notificationType: 'invoice_ready',
        );
      }
    } catch (e) {
      print('Notification Error: $e');
    }
  }

  static Future<void> _syncExtraWorkToInvoiceDraft(Map<String, dynamic> extraWork) async {
    try {
      final order = extraWork['order'];
      final orderId = order['id'];

      // 1. Taslağı bul veya oluştur
      var draft = await _client.from('invoice_drafts').select().eq('order_id', orderId).maybeSingle();
      if (draft == null) {
        final data = {
          'order_id': orderId,
          'issuing_company_id': order['company_id'],
          'customer_id': order['customer_id'],
          'billing_name': order['title'] ?? 'Hizmet Bedeli',
          'status': 'auto_generated',
          'service_date_from': order['planned_start_date'],
          'service_date_to': order['planned_end_date'],
        };
        draft = await _client.from('invoice_drafts').insert(data).select().single();
      }

      // 2. Kalemi ekle (Eğer zaten eklenmemişse)
      final existingItem = await _client.from('invoice_draft_items')
          .select()
          .eq('invoice_draft_id', draft['id'])
          .eq('extra_work_id', extraWork['id'])
          .maybeSingle();

      if (existingItem == null) {
        final description = 'Ek İş: ${extraWork['title']} (${extraWork['work_date']})';
        
        await _client.from('invoice_draft_items').insert({
          'invoice_draft_id': draft['id'],
          'extra_work_id': extraWork['id'],
          'item_type': 'extra',
          'description': description,
          'quantity': extraWork['duration_h'] ?? 1,
          'unit': 'Std.',
        });
      }
    } catch (e) {
      print('Extra Work Sync Error: $e');
    }
  }

  static Future<void> rejectExtraWork(String extraWorkId, String reason, String rejectedBy) async {
    await _client.from('extra_works').update({
      'status': 'rejected',
      'rejection_reason': reason,
      'approved_by': rejectedBy,
      'approved_at': DateTime.now().toIso8601String(),
    }).eq('id', extraWorkId);
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
    String notificationType = 'task_assignment',
    required String sentBy,
  }) async {
    await _client.from('notifications').insert({
      'recipient_id': recipientId,
      'notification_type': notificationType,
      'title': title,
      'body': body,
      'order_id': orderId,
      'operation_plan_id': operationPlanId,
      'sent_by': sentBy,
    });
  }

  static Future<void> deleteNotificationsByPlanId(String planId) async {
    await _client.from('notifications').delete().eq('operation_plan_id', planId);
  }

  static Future<List<String>> getPlanPersonnelIds(String planId) async {
    final data = await _client.from('operation_plan_personnel').select('user_id').eq('operation_plan_id', planId);
    return (data as List).map((e) => e['user_id'] as String).toList();
  }

  // ── Departmanlar ──────────────────────────────────────────
  static Future<List<Map<String, dynamic>>> getDepartments({String? companyId}) async {
    var query = _client.from('departments').select().eq('is_active', true);
    if (companyId != null) query = query.eq('company_id', companyId) as dynamic;
    final data = await query.order('name');
    return List<Map<String, dynamic>>.from(data);
  }

  // ── Hizmet Alanları ────────────────────────────────────────
  static Future<List<Map<String, dynamic>>> getServiceAreas({bool activeOnly = true}) async {
    var query = _client
        .from('service_areas')
        .select('*, department:departments(id, name, company_id)');
    
    if (activeOnly) {
      query = query.eq('is_active', true);
    }
    
    final data = await query.order('name');
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
  static Future<List<Map<String, dynamic>>> getInvoiceDrafts({String? status, List<String>? serviceAreaIds, String? departmentId}) async {
    var query = _client.from('invoice_drafts').select('''
      *,
      order:orders!inner(
        id, title, order_number, service_area_id, department_id,
        work_reports(total_revenue, estimated_labor_cost, estimated_material_cost)
      ),
      customer:customers(id, name, email, phone, address, tax_number, vat_number, iban, bic, notes),
      issuing_company:companies!invoice_drafts_issuing_company_id_fkey(id, name, short_name, address, iban, bic, tax_number, vat_number)
    ''');
    if (status != null) {
      query = query.eq('status', status) as dynamic;
    }
    if (serviceAreaIds != null && serviceAreaIds.isNotEmpty) {
      query = query.inFilter('order.service_area_id', serviceAreaIds) as dynamic;
    } else if (departmentId != null) {
      query = query.eq('order.department_id', departmentId) as dynamic;
    }
    final data = await query.order('created_at', ascending: false);
    final list = List<Map<String, dynamic>>.from(data);
    if (status == null) {
      return list.where((item) => item['status'] != 'passive' && item['status'] != 'archived').toList();
    }
    return list;
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

  static Future<List<Map<String, dynamic>>> getDocuments({
    String? orderId,
    String? customerId,
    String? companyId,
    String? documentType,
    String? departmentId,
  }) async {
    final deptInner = departmentId != null ? '!inner' : '';
    var query = _client.from('documents').select('''
      *,
      uploaded_by_user:users!documents_uploaded_by_fkey(first_name, last_name),
      order:orders$deptInner(department_id)
    ''');
    if (orderId != null) query = query.eq('order_id', orderId) as dynamic;
    if (customerId != null) query = query.eq('customer_id', customerId) as dynamic;
    if (companyId != null) query = query.eq('company_id', companyId) as dynamic;
    if (documentType != null) query = query.eq('document_type', documentType) as dynamic;
    if (departmentId != null) query = query.eq('orders.department_id', departmentId) as dynamic;
    final data = await query.order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(data);
  }

  static Future<void> createDocument(Map<String, dynamic> data) async {
    await _client.from('documents').insert(data);
  }

  static Future<void> deleteDocument(String id, String fileUrl) async {
    try {
      // Storage'dan silme denemesi (örn: url .../document/1234.pdf ise)
      if (fileUrl.contains('/document/')) {
        final parts = fileUrl.split('/document/');
        if (parts.length > 1) {
          final path = Uri.decodeFull(parts.last.split('?').first);
          await _client.storage.from('document').remove([path]);
        }
      }
    } catch (e) {
      debugPrint('Storage file remove error: $e');
    }
    
    // Veritabanından sil
    await _client.from('documents').delete().eq('id', id);
  }

  static Future<String> uploadDocument(String fileName, dynamic fileBytes) async {
    try {
      final cleanFileName = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9.]'), '_');
      final path = '${DateTime.now().millisecondsSinceEpoch}_$cleanFileName';
      
      await _client.storage.from('document').uploadBinary(
        path, 
        fileBytes,
        fileOptions: const FileOptions(upsert: true),
      );
      
      final publicUrl = _client.storage.from('document').getPublicUrl(path);
      return publicUrl;
    } catch (e) {
      print('Document upload error: $e');
      throw Exception('Dosya yüklenemedi: $e');
    }
  }

  static Future<List<int>> downloadDocument(String fileUrl) async {
    try {
      debugPrint('[STORAGE] Downloading via Signed URL: $fileUrl');
      final uri = Uri.parse(fileUrl);
      final segments = uri.pathSegments;
      
      String path = segments.last;
      if (segments.contains('document')) {
        final docIdx = segments.indexOf('document');
        if (docIdx != -1 && docIdx < segments.length - 1) {
          path = segments.sublist(docIdx + 1).join('/');
        }
      }

      // 1. 60 saniyelik güvenli bir link oluştur
      final signedUrl = await _client.storage.from('document').createSignedUrl(path, 60);
      debugPrint('[STORAGE] Signed URL received: $signedUrl');

      // 2. Bu özel link üzerinden dosyayı DOĞRUDAN indir (HTTP GET)
      // SDK'nın download(path) metodu RLS'e takılabildiği için 
      // imzalı URL'yi doğrudan çekmek en garanti yöntemdir.
      final response = await http.get(Uri.parse(signedUrl));
      
      if (response.statusCode != 200) {
        throw Exception('Dosya sunucudan çekilemedi (HTTP ${response.statusCode})');
      }

      return response.bodyBytes;
    } catch (e) {
      debugPrint('[STORAGE] Download error: $e');
      throw Exception('Dosya indirilemedi ($e)');
    }
  }

  // ── Arşiv ─────────────────────────────────────────────────
  static Future<List<Map<String, dynamic>>> getArchiveRecords() async {
    final data = await _client.from('archive_records').select('''
      *,
      order:orders(id, title, order_number)
    ''').order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(data);
  }

  static Future<void> upsertArchiveRecord(Map<String, dynamic> data) async {
    await _client.from('archive_records').upsert(data, onConflict: 'order_id');
  }

  // ── Yetki Yönetimi ────────────────────────────────────────
  static Future<void> updateUserRole(String userId, String role) async {
    await _client.from('users').update({'role': role}).eq('id', userId);
  }

  static Future<void> updateUserStatus(String userId, String status) async {
    await _client.from('users').update({'status': status}).eq('id', userId);
  }


  // ── Dashboard İstatistikleri ──────────────────────────────
  static Future<Map<String, int>> getDashboardStats(String companyId, {String? departmentId}) async {
    var ordersQ = _client
        .from('orders')
        .select('id')
        .eq('company_id', companyId)
        .inFilter('status', ['approved', 'planning', 'in_progress']);
    if (departmentId != null) ordersQ = ordersQ.eq('department_id', departmentId);
    final activeOrders = await ordersQ;

    final todayStr = DateTime.now().toIso8601String().split('T')[0];
    var plansQ = _client
        .from('operation_plans')
        .select('id, orders!inner(department_id)')
        .eq('plan_date', todayStr);
    if (departmentId != null) plansQ = plansQ.eq('orders.department_id', departmentId);
    final todayPlans = await plansQ;

    var personnelQ = _client
        .from('users')
        .select('id')
        .eq('company_id', companyId)
        .eq('status', 'active');
    if (departmentId != null) personnelQ = personnelQ.eq('department_id', departmentId);
    final activePersonnel = await personnelQ;

    var draftsQ = _client.from('invoice_drafts')
        .select('id, order:orders!inner(department_id)')
        .inFilter('status', ['auto_generated', 'under_review']);
    if (departmentId != null) draftsQ = draftsQ.eq('order.department_id', departmentId);
    final pendingDrafts = await draftsQ;

    return {
      'active_orders': (activeOrders as List).length,
      'today_plans': (todayPlans as List).length,
      'active_personnel': (activePersonnel as List).length,
      'pending_drafts': (pendingDrafts as List).length,
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
  static Future<Map<String, dynamic>> getAccountingSummary({List<String>? serviceAreaIds, String? departmentId}) async {
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1).toIso8601String().split('T')[0];

    // Draft Queries
    var invoicedQ = _client.from('invoice_drafts').select('total_amount, order!inner(service_area_id, department_id)').eq('status', 'invoiced').gte('created_at', monthStart);
    var pendingQ = _client.from('invoice_drafts').select('total_amount, order!inner(service_area_id, department_id)').inFilter('status', ['auto_generated', 'under_review']).gte('created_at', monthStart);
    var allPendingQ = _client.from('invoice_drafts').select('id, order!inner(service_area_id, department_id)').inFilter('status', ['auto_generated', 'under_review']);
    var completedOrdersQ = _client.from('orders').select('id').eq('status', 'completed').gte('updated_at', monthStart);

    if (serviceAreaIds != null && serviceAreaIds.isNotEmpty) {
      invoicedQ = invoicedQ.inFilter('order.service_area_id', serviceAreaIds) as dynamic;
      pendingQ = pendingQ.inFilter('order.service_area_id', serviceAreaIds) as dynamic;
      allPendingQ = allPendingQ.inFilter('order.service_area_id', serviceAreaIds) as dynamic;
      completedOrdersQ = completedOrdersQ.inFilter('service_area_id', serviceAreaIds) as dynamic;
    } else if (departmentId != null) {
      invoicedQ = invoicedQ.eq('order.department_id', departmentId) as dynamic;
      pendingQ = pendingQ.eq('order.department_id', departmentId) as dynamic;
      allPendingQ = allPendingQ.eq('order.department_id', departmentId) as dynamic;
      completedOrdersQ = completedOrdersQ.eq('department_id', departmentId) as dynamic;
    }

    final invoiced = await invoicedQ;
    final pending = await pendingQ;
    final allPending = await allPendingQ;
    final completedOrders = await completedOrdersQ;

    double invoicedTotal = 0;
    for (final r in (invoiced as List)) { invoicedTotal += double.tryParse(r['total_amount']?.toString() ?? '0') ?? 0; }
    double pendingTotal = 0;
    for (final r in (pending as List)) { pendingTotal += double.tryParse(r['total_amount']?.toString() ?? '0') ?? 0; }

    return {
      'invoiced_total': invoicedTotal,
      'pending_total': pendingTotal,
      'completed_orders': (completedOrders as List).length,
      'pending_drafts': (allPending as List).length,
    };
  }

  // ── Personel Görev Listesi (saha çalışanı için) ───────────
  static Future<List<Map<String, dynamic>>> getMyAssignedPlans(String userId) async {
    final data = await _client.from('operation_plan_personnel').select('''
      operation_plan_id, is_supervisor,
      operation_plans(
        id, plan_date, start_time, end_time, status, site_instructions, equipment_notes,
        order:orders(id, title, order_number, site_address, status, customer:customers(id, name))
      )
    ''').eq('user_id', userId).order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(data);
  }

  // ── Departman Performansı ──────────────────────────────────
  static Future<List<Map<String, dynamic>>> getDepartmentalPerformance({String? departmentId}) async {
    var query = _client.from('departments').select('id, name');
    if (departmentId != null) query = query.eq('id', departmentId) as dynamic;
    
    final depts = await query;
    final List<Map<String, dynamic>> results = [];
    
    for (var d in (depts as List)) {
      final dId = d['id'];
      
      // Completed orders count
      final ordersDone = await _client.from('orders')
          .select('id')
          .eq('department_id', dId)
          .eq('status', 'completed');
          
      // Total hours - using correct alias
      final sessions = await _client.from('work_sessions')
          .select('billable_hours, order:orders!inner(department_id)')
          .eq('order.department_id', dId);
          
      double totalHours = 0;
      for (var s in sessions) {
        totalHours += (s['billable_hours'] as num?)?.toDouble() ?? 0.0;
      }
      
      results.add({
        'id': dId,
        'name': d['name'],
        'completed_orders': (ordersDone as List).length,
        'total_hours': totalHours,
      });
    }
    return results;
  }

  // ── Plan Silme (Bölüm 7) ──────────────────────────────────
  static Future<void> deleteOperationPlan(String planId) async {
    // Önce bağlı personelleri siliyoruz (on delete cascade yoksa diye)
    await _client.from('operation_plan_personnel').delete().eq('plan_id', planId);
    // Sonra planı siliyoruz
    await _client.from('operation_plans').delete().eq('id', planId);
  }

  // ── Saha Güncellemeleri / Fotoğraflı Rapor (Yeni) ──────────
  static Future<void> uploadSiteUpdate({
    required String orderId,
    required String? planId,
    required String userId,
    required String description,
    required Uint8List? photoBytes,
  }) async {
    String? photoUrl;

    if (photoBytes != null) {
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
      final path = 'updates/$orderId/$fileName';
      
      await _client.storage.from('site-updates').uploadBinary(
        path,
        photoBytes,
        fileOptions: const FileOptions(contentType: 'image/jpeg'),
      );
      
      photoUrl = _client.storage.from('site-updates').getPublicUrl(path);
    }

    await _client.from('site_updates').insert({
      'order_id': orderId,
      'operation_plan_id': planId,
      'user_id': userId,
      'description': description,
      'photo_url': photoUrl,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  static Future<List<Map<String, dynamic>>> getSiteUpdates(String orderId) async {
    final data = await _client.from('site_updates').select('''
      *,
      user:users(id, first_name, last_name, role)
    ''').eq('order_id', orderId).order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(data);
  }

  // ── Günlük Finansal Veri (Mevcut tablolardan hesaplanır) ───────
  /// Belirli bir tarih aralığındaki onaylı çalışma seanslarını getirir
  /// ve günlük bazda gruplama yapılmasını sağlar
  static Future<List<Map<String, dynamic>>> getApprovedSessionsByDateRange({
    required String dateFrom,
    required String dateTo,
    List<String>? serviceAreaIds,
    String? departmentId,
  }) async {
    var query = _client.from('work_sessions').select('''
      *,
      user:users!work_sessions_user_id_fkey(id, first_name, last_name, role),
      order:orders(
        id, title, order_number, service_area_id, department_id,
        customer:customers(name),
        invoice_drafts(total_amount, subtotal),
        extra_works(estimated_material_cost, estimated_labor_cost),
        work_reports(total_revenue, estimated_labor_cost, estimated_material_cost)
      )
    ''')
        .eq('approval_status', 'approved')
        .gte('approved_at', '${dateFrom}T00:00:00')
        .lte('approved_at', '${dateTo}T23:59:59');

    if (serviceAreaIds != null && serviceAreaIds.isNotEmpty) {
      query = query.inFilter('order.service_area_id', serviceAreaIds) as dynamic;
    } else if (departmentId != null) {
      query = query.eq('order.department_id', departmentId) as dynamic;
    }

    final data = await query.order('approved_at', ascending: false);
    return List<Map<String, dynamic>>.from(data);
  }

  /// Belirli bir ay için personel saat verilerini getirir
  static Future<List<Map<String, dynamic>>> getPersonnelHoursForMonth(int year, int month) async {
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final dateFrom = '$year-${month.toString().padLeft(2, '0')}-01';
    final dateTo = '$year-${month.toString().padLeft(2, '0')}-${daysInMonth.toString().padLeft(2, '0')}';

    final data = await _client.from('work_sessions').select('''
      id, approved_billable_hours, billable_hours, actual_duration_h, approved_at, actual_start,
      user:users!work_sessions_user_id_fkey(id, first_name, last_name, role)
    ''')
        .eq('approval_status', 'approved')
        .gte('approved_at', '${dateFrom}T00:00:00')
        .lte('approved_at', '${dateTo}T23:59:59')
        .order('approved_at', ascending: false);
    return List<Map<String, dynamic>>.from(data);
  }

  /// Belirli bir tarih aralığındaki fatura taslaklarını getirir
  static Future<List<Map<String, dynamic>>> getInvoiceDraftsByDateRange({
    required String dateFrom,
    required String dateTo,
  }) async {
    final data = await _client.from('invoice_drafts').select('''
      *,
      order:orders(
        id, title, order_number, 
        work_reports(*), 
        extra_works(*), 
        work_sessions(approved_billable_hours)
      ),
      customer:customers(id, name)
    ''')
        .gte('created_at', dateFrom)
        .lte('created_at', '${dateTo} 23:59:59')
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(data);
  }

  /// Belirli bir gün için çalışma seanslarını (kim çalışmış) getirir
  static Future<List<Map<String, dynamic>>> getWorkSessionsByDate(String dateStr) async {
    final data = await _client.from('work_sessions').select('''
      *,
      user:users!work_sessions_user_id_fkey(id, first_name, last_name, role),
      order:orders(id, title, order_number, customer:customers(name))
    ''')
        .gte('actual_start', '${dateStr}T00:00:00')
        .lte('actual_start', '${dateStr}T23:59:59')
        .order('actual_start');
    return List<Map<String, dynamic>>.from(data);
  }

  /// Belirli bir siparişin work_report verilerini getirir (mali analiz için)
  static Future<Map<String, dynamic>?> getWorkReportByOrderId(String orderId) async {
    return await _client
        .from('work_reports')
        .select('total_revenue, estimated_labor_cost, estimated_material_cost')
        .eq('order_id', orderId)
        .maybeSingle();
  }

  /// Tüm aktif kullanıcıları getirir (personel saatleri için)
  static Future<List<Map<String, dynamic>>> getAllActiveUsers() async {
    final data = await _client.from('users').select('id, first_name, last_name, role')
        .eq('status', 'active')
        .order('last_name');
    return List<Map<String, dynamic>>.from(data);
  }

  // ── Mitarbeiter Dokumenten-Verwaltung ─────────────────────

  /// Çalışanın 10 standart klasörünü getirir.
  /// Eğer klasörler yoksa önce oluşturur (lazy init).
  static Future<List<Map<String, dynamic>>> getEmployeeFolders(String employeeId) async {
    // Önce mevcut klasörleri getir
    var data = await _client
        .from('employee_document_folders')
        .select()
        .eq('employee_id', employeeId)
        .order('sort_order');

    var list = List<Map<String, dynamic>>.from(data);

    // Eğer klasörler yoksa SQL fonksiyonunu çağır
    if (list.isEmpty) {
      try {
        await _client.rpc('create_employee_standard_folders', params: {
          'p_employee_id': employeeId,
        });
        // Tekrar getir
        data = await _client
            .from('employee_document_folders')
            .select()
            .eq('employee_id', employeeId)
            .order('sort_order');
        list = List<Map<String, dynamic>>.from(data);
      } catch (e) {
        debugPrint('[EmpFolders] Klasör oluşturma hatası: $e');
      }
    }
    return list;
  }

  /// Belirli bir klasördeki belgeleri getirir (uploader bilgisi dahil)
  static Future<List<Map<String, dynamic>>> getEmployeeDocuments(String folderId) async {
    final data = await _client
        .from('employee_documents')
        .select('''
          *,
          uploaded_by_user:users!employee_documents_uploaded_by_fkey(first_name, last_name)
        ''')
        .eq('folder_id', folderId)
        .order('uploaded_at', ascending: false);
    return List<Map<String, dynamic>>.from(data);
  }

  /// Bir çalışanın her klasöründeki belge sayısını döndürür
  /// { folderId: count } şeklinde map döner
  static Future<Map<String, int>> getEmployeeDocumentCounts(String employeeId) async {
    final data = await _client
        .from('employee_documents')
        .select('folder_id')
        .eq('employee_id', employeeId);

    final Map<String, int> counts = {};
    for (final row in (data as List)) {
      final fId = row['folder_id'].toString();
      counts[fId] = (counts[fId] ?? 0) + 1;
    }
    return counts;
  }

  /// Yeni çalışan belgesi kaydı oluşturur
  static Future<void> createEmployeeDocument(Map<String, dynamic> data) async {
    await _client.from('employee_documents').insert(data);
  }

  /// Çalışan belgesini siler (storage + db)
  static Future<void> deleteEmployeeDocument(String id, String fileUrl) async {
    try {
      if (fileUrl.contains('/employee-documents/')) {
        final parts = fileUrl.split('/employee-documents/');
        if (parts.length > 1) {
          final path = Uri.decodeFull(parts.last.split('?').first);
          await _client.storage.from('employee-documents').remove([path]);
        }
      }
    } catch (e) {
      debugPrint('Employee doc storage remove error: $e');
    }
    await _client.from('employee_documents').delete().eq('id', id);
  }

  /// Çalışan belgesini Supabase Storage'a yükler ve URL döner
  static Future<String> uploadEmployeeDocument(String fileName, dynamic fileBytes) async {
    try {
      final cleanFileName = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
      final path = '${DateTime.now().millisecondsSinceEpoch}_$cleanFileName';

      await _client.storage.from('employee-documents').uploadBinary(
        path,
        fileBytes,
        fileOptions: const FileOptions(upsert: true),
      );

      return _client.storage.from('employee-documents').getPublicUrl(path);
    } catch (e) {
      debugPrint('Employee doc upload error: $e');
      throw Exception('Datei konnte nicht hochgeladen werden: $e');
    }
  }

  // ── Vertragsmanagement ────────────────────────────────────
  static Future<List<Map<String, dynamic>>> getContracts({List<String>? companyIds, String? department}) async {
    var query = _client.from('contracts').select();
    if (companyIds != null && companyIds.isNotEmpty) {
      query = query.inFilter('company_id', companyIds) as dynamic;
    }
    if (department != null) {
      query = query.eq('department', department) as dynamic;
    }
    final data = await query.order('end_date');
    return List<Map<String, dynamic>>.from(data);
  }

  static Future<void> upsertContract(Map<String, dynamic> data) async {
    await _client.from('contracts').upsert(data);
  }

  static Future<void> deleteContract(String id) async {
    await _client.from('contracts').delete().eq('id', id);
  }

  // ── Fuhrpark ──────────────────────────────────────────────
  static Future<List<Map<String, dynamic>>> getVehicles({List<String>? companyIds, String? department}) async {
    var query = _client.from('vehicles').select();
    if (companyIds != null && companyIds.isNotEmpty) {
      query = query.inFilter('company_id', companyIds) as dynamic;
    }
    if (department != null) {
      query = query.eq('department', department) as dynamic;
    }
    final data = await query.order('license_plate');
    final list = List<Map<String, dynamic>>.from(data);
    return list.where((v) => v['status'] != 'deleted').toList();
  }

  static Future<void> upsertVehicle(Map<String, dynamic> data) async {
    await _client.from('vehicles').upsert(data);
  }

  static Future<void> deleteVehicle(String id) async {
    await _client.from('vehicles').update({'status': 'deleted'}).eq('id', id);
  }

  // ── Company Bank Accounts ─────────────────────────────────
  static Future<List<Map<String, dynamic>>> getCompanyBankAccounts(String companyId) async {
    final data = await _client.from('company_bank_accounts').select().eq('company_id', companyId).order('created_at');
    return List<Map<String, dynamic>>.from(data);
  }

  static Future<void> upsertCompanyBankAccount(Map<String, dynamic> data) async {
    await _client.from('company_bank_accounts').upsert(data);
  }

  static Future<void> deleteCompanyBankAccount(String id) async {
    await _client.from('company_bank_accounts').delete().eq('id', id);
  }

  // ── PQ Dokumente ──────────────────────────────────────────
  static Future<List<Map<String, dynamic>>> getPqDocuments({String? companyId, String? category, String? department}) async {
    var query = _client.from('pq_documents').select('*, uploaded_by_user:users!pq_documents_uploaded_by_fkey(first_name, last_name)');
    if (companyId != null) query = query.eq('company_id', companyId) as dynamic;
    if (category != null) query = query.eq('category', category) as dynamic;
    if (department != null) {
      query = query.eq('department', department) as dynamic;
    }
    final data = await query.order('category').order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(data);
  }

  static Future<void> createPqDocument(Map<String, dynamic> data) async {
    await _client.from('pq_documents').insert(data);
  }

  static Future<void> deletePqDocument(String id, String fileUrl) async {
    try {
      if (fileUrl.contains('/pq-documents/')) {
        final parts = fileUrl.split('/pq-documents/');
        if (parts.length > 1) {
          final path = Uri.decodeFull(parts.last.split('?').first);
          await _client.storage.from('pq-documents').remove([path]);
        }
      }
    } catch (e) {
      debugPrint('PQ doc storage remove error: $e');
    }
    await _client.from('pq_documents').delete().eq('id', id);
  }

  static Future<String> uploadPqDocument(String fileName, dynamic fileBytes) async {
    final cleanFileName = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    final path = '${DateTime.now().millisecondsSinceEpoch}_$cleanFileName';
    await _client.storage.from('pq-documents').uploadBinary(path, fileBytes, fileOptions: const FileOptions(upsert: true));
    return _client.storage.from('pq-documents').getPublicUrl(path);
  }

  // ── Service Areas CRUD ────────────────────────────────────
  static Future<void> upsertServiceArea(Map<String, dynamic> data) async {
    await _client.from('service_areas').upsert(data);
  }

  static Future<void> deleteServiceArea(String id) async {
    await _client.from('service_areas').update({'is_active': false}).eq('id', id);
  }

  // ── Chat System ───────────────────────────────────────────
  static Future<List<Map<String, dynamic>>> getChatRooms(String userId, {String? role}) async {
    List<dynamic> data;
    if (role == 'system_admin' || role == 'geschaeftsfuehrer') {
      data = await _client.from('chat_room_members').select('''
        room_id,
        chat_rooms(*, 
          chat_messages(message, created_at, sender_id, is_read),
          members:chat_room_members(user_id, user:users(id, first_name, last_name, role))
        )
      ''').order('joined_at', ascending: false);
    } else {
      data = await _client.from('chat_room_members').select('''
        room_id,
        chat_rooms(*, 
          chat_messages(message, created_at, sender_id, is_read),
          members:chat_room_members(user_id, user:users(id, first_name, last_name, role))
        )
      ''').eq('user_id', userId).order('joined_at', ascending: false);
    }

    final list = List<Map<String, dynamic>>.from(data);
    final uniqueRooms = <String, Map<String, dynamic>>{};
    for (final item in list) {
       final roomId = item['room_id']?.toString() ?? '';
       if (roomId.isNotEmpty && !uniqueRooms.containsKey(roomId)) {
          uniqueRooms[roomId] = item;
       }
    }
    return uniqueRooms.values.toList();
  }

  /// İki kullanıcı arasında zaten bir direkt sohbet odası varsa ID'sini döndürür.
  /// WhatsApp gibi davranış: tekrar yeni oda oluşturma.
  static Future<String?> findExistingDirectChat(String user1Id, String user2Id) async {
    try {
      // user1 üyesi olduğu tüm direct odaları getir
      final rooms1 = await _client
          .from('chat_room_members')
          .select('room_id, chat_rooms!inner(id, room_type)')
          .eq('user_id', user1Id)
          .eq('chat_rooms.room_type', 'direct');

      final roomIds1 = (rooms1 as List)
          .map((r) => r['room_id'].toString())
          .toSet();

      if (roomIds1.isEmpty) return null;

      // Tüm bu odalardaki üyeleri çekelim ve tam olarak 2 üye olan ve birinin user1 diğerinin user2 olduğu odayı bulalım.
      final allMembersData = await _client
          .from('chat_room_members')
          .select('room_id, user_id')
          .inFilter('room_id', roomIds1.toList());

      // Odaya göre üyeleri grupla
      final Map<String, List<String>> roomMembers = {};
      for (var row in (allMembersData as List)) {
        final rId = row['room_id'].toString();
        final uId = row['user_id'].toString();
        roomMembers.putIfAbsent(rId, () => []).add(uId);
      }

      for (var rId in roomIds1) {
        final members = roomMembers[rId] ?? [];
        if (members.length == 2 && members.contains(user1Id) && members.contains(user2Id)) {
          return rId; // Sadece ikisinin olduğu eşleşen tek oda
        }
      }

      return null;
    } catch (e) {
      debugPrint('[Chat] findExistingDirectChat hata: $e');
      return null;
    }
  }

  static Future<String> createChatRoom({
    required String name,
    required String roomType,
    required String createdBy,
    required List<String> memberIds,
    String? orderId,
    String? departmentId,
  }) async {
    final result = await _client.from('chat_rooms').insert({
      'name': name,
      'room_type': roomType,
      'created_by': createdBy,
      if (orderId != null) 'order_id': orderId,
      if (departmentId != null) 'department_id': departmentId,
    }).select('id').single();
    final roomId = result['id'] as String;

    // Add members
    final members = memberIds.map((uid) => {
      'room_id': roomId,
      'user_id': uid,
    }).toList();
    // Also add creator
    members.add({'room_id': roomId, 'user_id': createdBy});
    await _client.from('chat_room_members').upsert(members);
    return roomId;
  }

  static Future<List<Map<String, dynamic>>> getChatMessages(String roomId, {int limit = 50}) async {
    final data = await _client.from('chat_messages').select('''
      *,
      sender:users!chat_messages_sender_id_fkey(id, first_name, last_name)
    ''').eq('room_id', roomId).order('created_at', ascending: false).limit(limit);
    return List<Map<String, dynamic>>.from(data);
  }

  static Future<void> sendChatMessage({
    required String roomId,
    required String senderId,
    String? message,
    String? fileUrl,
    String? fileName,
  }) async {
    await _client.from('chat_messages').insert({
      'room_id': roomId,
      'sender_id': senderId,
      if (message != null) 'message': message,
      if (fileUrl != null) 'file_url': fileUrl,
      if (fileName != null) 'file_name': fileName,
    });

    // MOCK LAYER FOR PUSH NOTIFICATIONS
    // İleride burada bir Edge Function veya veritabanı Trigger'ı (pg_notify + FCM) çağrılabilir.
    // Şimdilik dart seviyesinde logluyoruz.
    debugPrint('Push Notification Tetiklendi: Oda $roomId için $senderId isimli kullanıcıdan yeni mesaj.');
  }

  static Future<void> markChatMessagesRead(String roomId, String userId) async {
    await _client.from('chat_messages')
        .update({'is_read': true})
        .eq('room_id', roomId)
        .neq('sender_id', userId);
  }

  static Future<String> uploadChatFile(String fileName, dynamic fileBytes) async {
    final cleanFileName = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    final path = '${DateTime.now().millisecondsSinceEpoch}_$cleanFileName';
    try {
      await _client.storage.from('chat-files').uploadBinary(
        path,
        fileBytes,
        fileOptions: const FileOptions(upsert: true),
      );
      return _client.storage.from('chat-files').getPublicUrl(path);
    } catch (e) {
      debugPrint('Chat file upload error: $e');
      rethrow;
    }
  }

  static Future<List<Map<String, dynamic>>> getAvailableChatUsers(
      String currentUserId, String role, List<String> serviceAreaIds) async {
    final query = _client.from('users')
        .select('id, first_name, last_name, role, department_id, department:departments(name), user_service_areas(service_area_id, service_areas(name))')
        .eq('status', 'active')
        .neq('id', currentUserId);

    final data = await query.order('last_name');
    final allUsers = List<Map<String, dynamic>>.from(data);

    return allUsers; 
  }

  // ── Formulare (Gebäudedienstleistungen) ───────────────────────────────────

  static Future<List<Map<String, dynamic>>> getOrderForms(String orderId) async {
    final data = await _client
        .from('order_forms')
        .select('''
          *,
          updated_by_user:users!order_forms_updated_by_fkey(first_name, last_name),
          approved_by_user:users!order_forms_approved_by_fkey(first_name, last_name)
        ''')
        .eq('order_id', orderId)
        .order('created_at');
    return List<Map<String, dynamic>>.from(data);
  }

  static Future<void> upsertOrderForm({
    String? id,
    required String orderId,
    required String formType,
    required String status,
    required Map<String, dynamic> data,
    required String userId,
  }) async {
    final payload = <String, dynamic>{
      'order_id':   orderId,
      'form_type':  formType,
      'status':     status,
      'data':       data,
      'updated_by': userId,
    };
    if (id != null) {
      payload['id'] = id;
    } else {
      payload['created_by'] = userId;
    }
    await _client.from('order_forms').upsert(payload, onConflict: 'order_id,form_type');
  }

  static Future<void> approveOrderForm(String formId, String approverId) async {
    await _client.from('order_forms').update({
      'is_approved':  true,
      'approved_by':  approverId,
      'approved_at':  DateTime.now().toUtc().toIso8601String(),
    }).eq('id', formId);
  }

  static Future<void> deleteOrderForm(String formId) async {
    await _client.from('order_forms').delete().eq('id', formId);
  }
}

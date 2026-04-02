import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  final String baseUrl;
  ApiService({required this.baseUrl});

  Map<String, String> get _headers => {'Content-Type': 'application/json'};

  Future<dynamic> _get(String path) async {
    final res = await http.get(Uri.parse('$baseUrl$path'), headers: _headers).timeout(const Duration(seconds: 15));
    final body = jsonDecode(res.body);
    if (res.statusCode != 200) throw Exception(body['error'] ?? 'Sunucu hatası');
    return body;
  }

  Future<dynamic> _post(String path, Map<String, dynamic> data) async {
    final res = await http.post(Uri.parse('$baseUrl$path'), headers: _headers, body: jsonEncode(data)).timeout(const Duration(seconds: 15));
    final body = jsonDecode(res.body);
    if (res.statusCode != 200 && res.statusCode != 201) throw Exception(body['error'] ?? 'Sunucu hatası');
    return body;
  }

  Future<dynamic> _patch(String path, Map<String, dynamic> data) async {
    final res = await http.patch(Uri.parse('$baseUrl$path'), headers: _headers, body: jsonEncode(data)).timeout(const Duration(seconds: 15));
    final body = jsonDecode(res.body);
    if (res.statusCode != 200) throw Exception(body['error'] ?? 'Sunucu hatası');
    return body;
  }

  Future<dynamic> _delete(String path, [Map<String, dynamic>? data]) async {
    final res = await http.delete(
      Uri.parse('$baseUrl$path'),
      headers: _headers,
      body: data != null ? jsonEncode(data) : null,
    ).timeout(const Duration(seconds: 15));
    final body = jsonDecode(res.body);
    if (res.statusCode != 200) throw Exception(body['error'] ?? 'Sunucu hatası');
    return body;
  }

  // ────────── AUTH ───────────────────────────────────────────
  Future<Map<String, dynamic>> login(String id, String pinCode) async {
    final res = await _post('/api/auth/login', {'id': id, 'pin_code': pinCode});
    return Map<String, dynamic>.from(res['user']);
  }

  // ────────── COMPANIES ──────────────────────────────────────
  Future<List<dynamic>> getCompanies() async => await _get('/api/companies');

  Future<List<dynamic>> getCompanyPlans(String companyId, {String? fromDate, String? toDate}) async {
    final params = <String>[];
    if (fromDate != null) params.add('from_date=$fromDate');
    if (toDate != null) params.add('to_date=$toDate');
    final q = params.isNotEmpty ? '?${params.join('&')}' : '';
    return await _get('/api/companies/$companyId/plans$q');
  }

  // ────────── WORKERS ────────────────────────────────────────
  Future<List<dynamic>> getWorkers({required String date}) async =>
    await _get('/api/workers?date=$date');

  Future<Map<String, dynamic>> getWorkerStats(String workerId) async =>
    Map<String, dynamic>.from(await _get('/api/workers/stats/$workerId'));

  // ────────── EMPLOYEE MANAGEMENT (Admin Only) ───────────────
  Future<Map<String, dynamic>> getWorkerById(String id) async =>
    Map<String, dynamic>.from(await _get('/api/admin/workers/$id'));

  Future<dynamic> addEmployee({
    required String id,
    required String name,
    required String pinCode,
    String role = 'worker',
    String? companyId,
  }) async {
    final body = <String, dynamic>{'id': id, 'name': name, 'pin_code': pinCode, 'role': role};
    if (companyId != null) body['company_id'] = companyId;
    return await _post('/api/admin/workers', body);
  }

  Future<dynamic> deleteEmployee(String id) async =>
    await _delete('/api/admin/workers/$id');

  // ────────── DAILY TRACKER ──────────────────────────────────
  Future<List<dynamic>> getTodayActivity({required String date}) async =>
    await _get('/api/today/activity?date=$date');

  // ────────── SHIFT PLANS ────────────────────────────────────
  Future<dynamic> createShiftPlan({
    required String companyId,
    required String createdBy,
    required String workDate,
    required String startTime,
    required String endTime,
    required List<Map<String, String>> assignments,
  }) async => await _post('/api/shift-plans', {
    'company_id': companyId, 'created_by': createdBy,
    'work_date': workDate, 'start_time': startTime, 'end_time': endTime,
    'assignments': assignments,
  });

  Future<List<dynamic>> getShiftPlans({String? companyId, String? status, String? createdBy}) async {
    final p = <String>[];
    if (companyId != null) p.add('company_id=$companyId');
    if (status != null) p.add('status=$status');
    if (createdBy != null) p.add('created_by=$createdBy');
    return await _get('/api/shift-plans${p.isNotEmpty ? '?${p.join('&')}' : ''}');
  }

  Future<dynamic> approvePlan(String planId, String approvedBy) async =>
    await _patch('/api/shift-plans/$planId/approve', {'approved_by': approvedBy});

  Future<dynamic> rejectPlan(String planId, String rejectedBy, String note) async =>
    await _patch('/api/shift-plans/$planId/reject', {'rejected_by': rejectedBy, 'rejection_note': note});

  Future<dynamic> deletePlan(String planId, String deletedBy) async =>
    await _delete('/api/shift-plans/$planId', {'deleted_by': deletedBy});

  Future<dynamic> editPlan(String planId, {String? workDate, String? startTime, String? endTime, String? notes}) async {
    final body = <String, dynamic>{};
    if (workDate != null) body['work_date'] = workDate;
    if (startTime != null) body['start_time'] = startTime;
    if (endTime != null) body['end_time'] = endTime;
    if (notes != null) body['notes'] = notes;
    return await _patch('/api/shift-plans/$planId/edit', body);
  }

  // ────────── WORKER SHIFTS ──────────────────────────────────
  Future<List<dynamic>> getMyShifts(String workerId) async =>
    await _get('/api/my-shifts/$workerId');

  Future<dynamic> startShift(String assignmentId, String workerId) async =>
    await _post('/api/shifts/$assignmentId/start', {'worker_id': workerId});

  Future<dynamic> endShift(String assignmentId, String workerId, {String? exitNote}) async {
    final body = <String, dynamic>{'worker_id': workerId};
    if (exitNote != null && exitNote.trim().isNotEmpty) body['exit_note'] = exitNote.trim();
    return await _post('/api/shifts/$assignmentId/end', body);
  }

  Future<dynamic> adjustShiftTimes(String assignmentId, String adjustedBy, {String? actualStart, String? actualEnd}) async {
    final body = <String, dynamic>{'adjusted_by': adjustedBy};
    if (actualStart != null) body['actual_start'] = actualStart;
    if (actualEnd != null) body['actual_end'] = actualEnd;
    return await _patch('/api/shifts/$assignmentId/adjust', body);
  }

  Future<dynamic> saveFcmToken(String userId, String token) async =>
    await _post('/api/users/$userId/fcm-token', {'fcm_token': token});
}

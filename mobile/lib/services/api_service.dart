import 'dart:convert';
import 'package:http/http.dart' as http;
import 'localization_service.dart';

class ApiService {
  static const String baseUrl = 'http://localhost:3000/api';
  static final Map<String, String> _headers = {'Content-Type': 'application/json'};

  Future<dynamic> _get(String path) async {
    final res = await http.get(Uri.parse('$baseUrl$path'), headers: _headers).timeout(const Duration(seconds: 15));
    final body = jsonDecode(res.body);
    if (res.statusCode != 200) throw Exception(body['error'] ?? tr('Sunucu hatası'));
    return body;
  }

  Future<dynamic> _post(String path, Map<String, dynamic> data) async {
    final res = await http.post(Uri.parse('$baseUrl$path'), headers: _headers, body: jsonEncode(data)).timeout(const Duration(seconds: 15));
    final body = jsonDecode(res.body);
    if (res.statusCode != 200 && res.statusCode != 201) throw Exception(body['error'] ?? tr('Sunucu hatası'));
    return body;
  }

  Future<dynamic> _put(String path, Map<String, dynamic> data) async {
    final res = await http.put(Uri.parse('$baseUrl$path'), headers: _headers, body: jsonEncode(data)).timeout(const Duration(seconds: 15));
    final body = jsonDecode(res.body);
    if (res.statusCode != 200) throw Exception(body['error'] ?? tr('Sunucu hatası'));
    return body;
  }

  Future<dynamic> _delete(String path) async {
    final res = await http.delete(Uri.parse('$baseUrl$path'), headers: _headers).timeout(const Duration(seconds: 15));
    final body = jsonDecode(res.body);
    if (res.statusCode != 200) throw Exception(body['error'] ?? tr('Sunucu hatası'));
    return body;
  }
}

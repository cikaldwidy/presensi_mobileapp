import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';

class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class ApiService {
  static const String _tokenKey = 'auth_token';

  Future<Map<String, dynamic>> get(String endpoint) async {
    final response = await http
        .get(_uri(endpoint), headers: await _headers())
        .timeout(ApiConfig.timeout);

    return _decode(response);
  }

  Future<Map<String, dynamic>> post(
    String endpoint, {
    Map<String, dynamic>? body,
  }) async {
    final response = await http
        .post(
          _uri(endpoint),
          headers: await _headers(),
          body: jsonEncode(body ?? <String, dynamic>{}),
        )
        .timeout(ApiConfig.timeout);

    return _decode(response);
  }

  Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
  }

  Uri _uri(String endpoint) {
    return Uri.parse('${ApiConfig.baseUrl}$endpoint');
  }

  Future<Map<String, String>> _headers() async {
    final token = await getToken();

    return {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  Map<String, dynamic> _decode(http.Response response) {
    final decoded = _decodeBody(response.body);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        _errorMessage(decoded),
        statusCode: response.statusCode,
      );
    }

    return decoded;
  }

  Map<String, dynamic> _decodeBody(String body) {
    if (body.isEmpty) {
      return <String, dynamic>{};
    }

    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }

    return {'data': decoded};
  }

  String _errorMessage(Map<String, dynamic> decoded) {
    final message = decoded['message'];
    if (message is String && message.isNotEmpty) {
      return message;
    }

    final errors = decoded['errors'];
    if (errors is Map<String, dynamic>) {
      final messages = errors.values
          .whereType<List<dynamic>>()
          .expand((items) => items)
          .whereType<String>()
          .toList();

      if (messages.isNotEmpty) {
        return messages.first;
      }
    }

    return 'Terjadi kesalahan.';
  }
}

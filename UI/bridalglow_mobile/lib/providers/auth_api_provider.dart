import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:bridalglow_mobile/models/user.dart';
import 'package:bridalglow_mobile/providers/auth_provider.dart';
import 'package:bridalglow_mobile/providers/base_provider.dart';

class AuthApiProvider {
  static Future<AuthSession> register(Map<String, dynamic> request) async {
    final uri = Uri.parse('${BaseProvider.baseUrl}Auth/register');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(request),
    );
    if (response.statusCode >= 299) {
      throw Exception(_extractError(response.body));
    }
    return AuthSession.fromJson(jsonDecode(response.body));
  }

  static Future<AuthSession?> login(String username, String password) async {
    final uri = Uri.parse('${BaseProvider.baseUrl}Auth/login');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'username': username, 'password': password}),
    );
    if (response.statusCode == 401) return null;
    if (response.statusCode >= 299) {
      throw Exception(_extractError(response.body));
    }
    return AuthSession.fromJson(jsonDecode(response.body));
  }

  static Future<AuthSession?> refresh(String refreshToken) async {
    final uri = Uri.parse('${BaseProvider.baseUrl}Auth/refresh');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'refreshToken': refreshToken}),
    );
    if (response.statusCode == 401) return null;
    if (response.statusCode >= 299) {
      throw Exception(_extractError(response.body));
    }
    return AuthSession.fromJson(jsonDecode(response.body));
  }

  static Future<void> logout() async {
    if (AuthProvider.refreshToken == null) return;
    final uri = Uri.parse('${BaseProvider.baseUrl}Auth/logout');
    await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${AuthProvider.accessToken}',
      },
      body: jsonEncode({'refreshToken': AuthProvider.refreshToken}),
    );
  }

  static String _extractError(String body) {
    try {
      final data = jsonDecode(body);
      if (data['errors'] != null) {
        return data['errors'].values.first.first.toString();
      }
    } catch (_) {}
    return 'Request failed';
  }
}

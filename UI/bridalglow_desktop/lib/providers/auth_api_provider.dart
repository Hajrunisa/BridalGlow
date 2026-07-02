import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:bridalglow_desktop/models/user.dart';
import 'package:bridalglow_desktop/providers/auth_provider.dart';
import 'package:bridalglow_desktop/providers/base_provider.dart';

class AuthApiProvider {
  static Future<AuthSession?> login(String username, String password) async {
    final uri = Uri.parse('${BaseProvider.baseUrl}Auth/login');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'username': username, 'password': password}),
    );
    if (response.statusCode == 401) return null;
    if (response.statusCode >= 299) throw Exception('Login failed');
    return AuthSession.fromJson(jsonDecode(response.body));
  }

  static Future<void> logout() async {
    if (AuthProvider.refreshToken == null) return;
    await http.post(
      Uri.parse('${BaseProvider.baseUrl}Auth/logout'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${AuthProvider.accessToken}',
      },
      body: jsonEncode({'refreshToken': AuthProvider.refreshToken}),
    );
  }
}

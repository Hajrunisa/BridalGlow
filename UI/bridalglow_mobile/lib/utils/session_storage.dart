import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:bridalglow_mobile/models/user.dart';
import 'package:bridalglow_mobile/providers/auth_provider.dart';
import 'package:bridalglow_mobile/providers/user_provider.dart';

class SessionStorage {
  static const _sessionKey = 'auth_session';

  static Future<void> saveSession(AuthSession session) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sessionKey, jsonEncode(session.toJson()));
    AuthProvider.accessToken = session.accessToken;
    AuthProvider.refreshToken = session.refreshToken;
    UserProvider.currentUser = session.user;
  }

  static Future<AuthSession?> loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_sessionKey);
    if (raw == null) return null;
    return AuthSession.fromJson(jsonDecode(raw));
  }

  static Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sessionKey);
    AuthProvider.accessToken = null;
    AuthProvider.refreshToken = null;
    UserProvider.currentUser = null;
  }

  /// Ažurira samo korisnički dio sačuvane sesije, bez mijenjanja tokena.
  static Future<void> updateUser(User user) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_sessionKey);
    if (raw == null) return;
    final data = jsonDecode(raw) as Map<String, dynamic>;
    data['user'] = {
      'id': user.id,
      'firstName': user.firstName,
      'lastName': user.lastName,
      'email': user.email,
      'username': user.username,
      'phone': user.phone,
      'role': user.role,
      'roleName': user.roleName,
      'isActive': user.isActive,
    };
    await prefs.setString(_sessionKey, jsonEncode(data));
  }
}

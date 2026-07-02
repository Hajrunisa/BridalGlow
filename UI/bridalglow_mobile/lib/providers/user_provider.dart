import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:bridalglow_mobile/models/user.dart';
import 'package:bridalglow_mobile/providers/base_provider.dart';

class UserProvider extends BaseProvider<User> {
  UserProvider() : super('Users');

  static User? currentUser;

  @override
  User fromJson(dynamic json) => User.fromJson(json);

  Future<User?> getMyProfile() async {
    final uri = Uri.parse('${BaseProvider.baseUrl}Users/me');
    final response = await http.get(uri, headers: createHeaders());
    if (isValidResponse(response)) {
      currentUser = fromJson(jsonDecode(response.body));
      notifyListeners();
      return currentUser;
    }
    return null;
  }

  Future<User> updateMyProfile(Map<String, dynamic> request) async {
    final uri = Uri.parse('${BaseProvider.baseUrl}Users/me');
    final response = await http.put(
      uri,
      headers: createHeaders(),
      body: jsonEncode(request),
    );
    if (isValidResponse(response)) {
      currentUser = fromJson(jsonDecode(response.body));
      notifyListeners();
      return currentUser!;
    }
    throw Exception('Update failed');
  }

  Future<void> changePassword(String currentPassword, String newPassword) async {
    final uri = Uri.parse('${BaseProvider.baseUrl}Users/me/password');
    final response = await http.put(
      uri,
      headers: createHeaders(),
      body: jsonEncode({
        'currentPassword': currentPassword,
        'newPassword': newPassword,
      }),
    );
    if (response.statusCode >= 299) {
      throw Exception('Password change failed');
    }
  }

  Future<void> activateUser(int id) async {
    final uri = Uri.parse('${BaseProvider.baseUrl}Users/$id/activate');
    final response = await http.put(uri, headers: createHeaders());
    if (response.statusCode >= 299) throw Exception('Activate failed');
  }

  Future<void> deactivateUser(int id) async {
    final uri = Uri.parse('${BaseProvider.baseUrl}Users/$id/deactivate');
    final response = await http.put(uri, headers: createHeaders());
    if (response.statusCode >= 299) throw Exception('Deactivate failed');
  }
}

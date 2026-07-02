import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:bridalglow_desktop/models/user.dart';
import 'package:bridalglow_desktop/providers/base_provider.dart';

class UserProvider extends BaseProvider<User> {
  UserProvider() : super('Users');

  static User? currentUser;

  @override
  User fromJson(dynamic json) => User.fromJson(json);

  Future<User?> getMyProfile() async {
    final response = await http.get(
      Uri.parse('${BaseProvider.baseUrl}Users/me'),
      headers: createHeaders(),
    );
    if (isValidResponse(response)) {
      currentUser = fromJson(jsonDecode(response.body));
      return currentUser;
    }
    return null;
  }

  Future<User> updateMyProfile(Map<String, dynamic> request) async {
    final response = await http.put(
      Uri.parse('${BaseProvider.baseUrl}Users/me'),
      headers: createHeaders(),
      body: jsonEncode(request),
    );
    if (isValidResponse(response)) {
      currentUser = fromJson(jsonDecode(response.body));
      return currentUser!;
    }
    throw Exception('Update failed');
  }

  Future<void> changePassword(String currentPassword, String newPassword) async {
    final response = await http.put(
      Uri.parse('${BaseProvider.baseUrl}Users/me/password'),
      headers: createHeaders(),
      body: jsonEncode({'currentPassword': currentPassword, 'newPassword': newPassword}),
    );
    if (response.statusCode >= 299) throw Exception('Password change failed');
  }

  Future<void> activateUser(int id) async {
    final response = await http.put(
      Uri.parse('${BaseProvider.baseUrl}Users/$id/activate'),
      headers: createHeaders(),
    );
    if (response.statusCode >= 299) throw Exception('Activate failed');
  }

  Future<void> deactivateUser(int id) async {
    final response = await http.put(
      Uri.parse('${BaseProvider.baseUrl}Users/$id/deactivate'),
      headers: createHeaders(),
    );
    if (response.statusCode >= 299) throw Exception('Deactivate failed');
  }

  Future<User> promoteToSalonStaff(int id) async {
    final response = await http.put(
      Uri.parse('${BaseProvider.baseUrl}Users/$id/promote-to-staff'),
      headers: createHeaders(),
    );
    if (isValidResponse(response)) {
      return fromJson(jsonDecode(response.body));
    }
    throw Exception('Promote to SalonStaff failed');
  }
}

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:bridalglow_mobile/models/dress_image.dart';
import 'package:bridalglow_mobile/providers/auth_provider.dart';
import 'package:bridalglow_mobile/providers/base_provider.dart';

class DressImageProvider extends ChangeNotifier {
  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (AuthProvider.accessToken != null)
          'Authorization': 'Bearer ${AuthProvider.accessToken}',
      };

  Future<List<DressImage>> getByDressId(int dressId) async {
    final response = await http.get(
      Uri.parse('${BaseProvider.baseUrl}dress-images?dressId=$dressId'),
      headers: _headers,
    );
    if (response.statusCode < 299) {
      final data = jsonDecode(response.body) as List;
      return data
          .map((e) => DressImage.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    throw Exception('Failed to load images');
  }
}

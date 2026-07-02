import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:bridalglow_desktop/models/dress.dart';
import 'package:bridalglow_desktop/providers/base_provider.dart';

class DressProvider extends BaseProvider<DressListItem> {
  DressProvider() : super('Dress');

  @override
  DressListItem fromJson(dynamic json) =>
      DressListItem.fromJson(json as Map<String, dynamic>);

  /// Loads a single dress with full detail (DressResponse).
  Future<DressDetail> getDressById(int id) async {
    final response = await http.get(
      Uri.parse('${BaseProvider.baseUrl}Dress/$id'),
      headers: createHeaders(),
    );
    if (isValidResponse(response)) {
      return DressDetail.fromJson(
          jsonDecode(response.body) as Map<String, dynamic>);
    }
    throw Exception('Failed to load dress details');
  }

  /// Archives a dress via POST /api/Dress/{id}/archive.
  Future<DressDetail> archiveDress(int id) async {
    final response = await http.post(
      Uri.parse('${BaseProvider.baseUrl}Dress/$id/archive'),
      headers: createHeaders(),
    );
    if (isValidResponse(response)) {
      return DressDetail.fromJson(
          jsonDecode(response.body) as Map<String, dynamic>);
    }
    throw Exception('Failed to archive dress');
  }
}

import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:bridalglow_mobile/models/dress.dart';
import 'package:bridalglow_mobile/providers/base_provider.dart';

class DressProvider extends BaseProvider<DressListItem> {
  DressProvider() : super('Dress');

  @override
  DressListItem fromJson(dynamic json) =>
      DressListItem.fromJson(json as Map<String, dynamic>);

  Future<DressDetail> getDressById(int id) async {
    final uri = Uri.parse('${BaseProvider.baseUrl}Dress/$id');
    final response = await http.get(uri, headers: createHeaders());
    if (isValidResponse(response)) {
      return DressDetail.fromJson(
          jsonDecode(response.body) as Map<String, dynamic>);
    }
    throw Exception('Failed to load dress details');
  }
}

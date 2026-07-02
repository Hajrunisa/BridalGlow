import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:bridalglow_desktop/models/refund.dart';
import 'package:bridalglow_desktop/providers/base_provider.dart';

class RefundProvider extends BaseProvider<Refund> {
  RefundProvider() : super('Finance/refunds');

  @override
  Refund fromJson(dynamic json) =>
      Refund.fromJson(json as Map<String, dynamic>);

  Future<Refund> approve(int id) async => _postAction(id, 'approve');

  Future<Refund> reject(int id, {String? reason}) async =>
      _postAction(id, 'reject', body: {'reason': reason});

  Future<Refund> process(int id) async => _postAction(id, 'process');

  Future<Refund> _postAction(
    int id,
    String action, {
    Map<String, dynamic>? body,
  }) async {
    final uri = Uri.parse('${BaseProvider.baseUrl}Refunds/$id/$action');
    final response = await http.post(
      uri,
      headers: createHeaders(),
      body: jsonEncode(body ?? {}),
    );
    if (isValidResponse(response)) {
      return Refund.fromJson(
          jsonDecode(response.body) as Map<String, dynamic>);
    }
    throw Exception('Action failed');
  }
}

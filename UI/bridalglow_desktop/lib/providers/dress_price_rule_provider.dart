import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:bridalglow_desktop/models/dress_price_rule.dart';
import 'package:bridalglow_desktop/providers/base_provider.dart';

class DressPriceRuleProvider extends BaseProvider<DressPriceRule> {
  DressPriceRuleProvider() : super('DressPriceRules');

  @override
  DressPriceRule fromJson(dynamic json) =>
      DressPriceRule.fromJson(json as Map<String, dynamic>);

  /// Creates a new price rule.
  Future<DressPriceRule> createRule(Map<String, dynamic> request) async {
    final response = await http.post(
      Uri.parse('${BaseProvider.baseUrl}DressPriceRules'),
      headers: createHeaders(),
      body: jsonEncode(request),
    );
    if (isValidResponse(response)) {
      return DressPriceRule.fromJson(
          jsonDecode(response.body) as Map<String, dynamic>);
    }
    throw Exception('Failed to create rule');
  }

  /// Updates an existing price rule.
  Future<DressPriceRule> updateRule(int id, Map<String, dynamic> request) async {
    final response = await http.put(
      Uri.parse('${BaseProvider.baseUrl}DressPriceRules/$id'),
      headers: createHeaders(),
      body: jsonEncode(request),
    );
    if (isValidResponse(response)) {
      return DressPriceRule.fromJson(
          jsonDecode(response.body) as Map<String, dynamic>);
    }
    throw Exception('Failed to update rule');
  }

  /// Deletes a price rule by ID.
  Future<void> deleteRule(int id) async {
    final response = await http.delete(
      Uri.parse('${BaseProvider.baseUrl}DressPriceRules/$id'),
      headers: createHeaders(),
    );
    if (response.statusCode >= 299) {
      _throwApiError(response);
    }
  }

  /// Returns the effective price for a dress in the given period.
  Future<EffectivePrice> getEffectivePrice({
    required int dressId,
    required DateTime startAt,
    required DateTime endAt,
  }) async {
    final uri = Uri.parse(
      '${BaseProvider.baseUrl}DressPriceRules/effective-price'
      '?dressId=$dressId'
      '&startAt=${Uri.encodeComponent(startAt.toUtc().toIso8601String())}'
      '&endAt=${Uri.encodeComponent(endAt.toUtc().toIso8601String())}',
    );
    final response = await http.get(uri, headers: createHeaders());
    if (isValidResponse(response)) {
      return EffectivePrice.fromJson(
          jsonDecode(response.body) as Map<String, dynamic>);
    }
    throw Exception('Failed to load effective price');
  }

  void _throwApiError(http.Response response) {
    String? message;
    if (response.body.isNotEmpty) {
      try {
        final data = jsonDecode(response.body);
        if (data is Map) {
          final errors = data['errors'];
          if (errors is Map && errors.isNotEmpty) {
            message = errors.values
                .expand((v) => v is List ? v : [v])
                .map((e) => e.toString())
                .join('\n');
          }
          message ??=
              data['message']?.toString() ?? data['title']?.toString();
        }
      } catch (_) {}
    }
    throw Exception(message ?? 'Something went wrong, please try again later!');
  }
}

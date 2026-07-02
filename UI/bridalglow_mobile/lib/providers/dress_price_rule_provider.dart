import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:bridalglow_mobile/models/dress_price_rule.dart';
import 'package:bridalglow_mobile/providers/base_provider.dart';

class DressPriceRuleProvider extends BaseProvider<DressPriceRule> {
  DressPriceRuleProvider() : super('DressPriceRules');

  @override
  DressPriceRule fromJson(dynamic json) =>
      DressPriceRule.fromJson(json as Map<String, dynamic>);

  /// Returns the effective price for a dress in the given period.
  /// Used in Korak 3 to display the price during try-on appointment selection.
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
}

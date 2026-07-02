import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:bridalglow_mobile/models/refund.dart';
import 'package:bridalglow_mobile/models/search_result.dart';
import 'package:bridalglow_mobile/providers/auth_provider.dart';
import 'package:bridalglow_mobile/providers/base_provider.dart';

class RefundProvider with ChangeNotifier {
  Map<String, String> _headers() => {
        'Content-Type': 'application/json',
        if (AuthProvider.accessToken != null)
          'Authorization': 'Bearer ${AuthProvider.accessToken}',
      };

  Never _throwFromResponse(http.Response response, String fallback) {
    if (response.statusCode == 401) {
      throw Exception('Please check your credentials and try again.');
    }
    try {
      final body = jsonDecode(response.body);
      if (body is Map<String, dynamic>) {
        final errors = body['errors'] as Map<String, dynamic>?;
        if (errors != null) {
          for (final entry in errors.entries) {
            final msgs = entry.value;
            if (msgs is List && msgs.isNotEmpty) {
              throw Exception(msgs.first.toString());
            }
          }
        }
      }
    } catch (e) {
      if (e is Exception) rethrow;
    }
    throw Exception(fallback);
  }

  Future<SearchResult<Refund>> getMine({
    int? paymentId,
    int page = 0,
    int pageSize = 50,
  }) async {
    final params = <String, String>{
      'Page': '$page',
      'PageSize': '$pageSize',
      'IncludeTotalCount': 'true',
    };
    if (paymentId != null) params['PaymentId'] = '$paymentId';

    final uri = Uri.parse('${BaseProvider.baseUrl}Refunds/mine')
        .replace(queryParameters: params);
    final response = await http.get(uri, headers: _headers());

    if (response.statusCode < 300) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final result = SearchResult<Refund>();
      result.totalCount = data['totalCount'] as int?;
      result.items = (data['items'] as List<dynamic>)
          .map((e) => Refund.fromJson(e as Map<String, dynamic>))
          .toList();
      return result;
    }
    _throwFromResponse(response, 'Failed to load refunds.');
  }

  Future<List<Refund>> getRefundsForReservationPayments(
    List<int> paymentIds,
  ) async {
    final all = <Refund>[];
    for (final paymentId in paymentIds) {
      final result = await getMine(paymentId: paymentId, pageSize: 20);
      all.addAll(result.items);
    }
    all.sort((a, b) => b.requestedAtUtc.compareTo(a.requestedAtUtc));
    return all;
  }

  Future<Refund> requestRefund({
    required int paymentId,
    required int reasonCode,
    String? reasonText,
  }) async {
    final uri = Uri.parse('${BaseProvider.baseUrl}Refunds/request');
    final body = <String, dynamic>{
      'paymentId': paymentId,
      'reasonCode': reasonCode,
      if (reasonText != null && reasonText.trim().isNotEmpty)
        'reasonText': reasonText.trim(),
    };
    final response = await http.post(
      uri,
      headers: _headers(),
      body: jsonEncode(body),
    );
    if (response.statusCode < 300) {
      return Refund.fromJson(
          jsonDecode(response.body) as Map<String, dynamic>);
    }
    _throwFromResponse(response, 'Failed to submit refund request.');
  }
}

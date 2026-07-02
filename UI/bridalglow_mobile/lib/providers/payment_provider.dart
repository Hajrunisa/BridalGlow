import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:bridalglow_mobile/models/payment.dart';
import 'package:bridalglow_mobile/models/search_result.dart';
import 'package:bridalglow_mobile/providers/auth_provider.dart';
import 'package:bridalglow_mobile/providers/base_provider.dart';

class PaymentProvider with ChangeNotifier {
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
        if (body['title'] != null) {
          throw Exception(body['title'].toString());
        }
      }
    } catch (e) {
      if (e is Exception) rethrow;
    }
    throw Exception(fallback);
  }

  Future<PaymentIntentData> createPaymentIntent(int rentalReservationId) async {
    final uri = Uri.parse('${BaseProvider.baseUrl}Payments/create-intent');
    final response = await http.post(
      uri,
      headers: _headers(),
      body: jsonEncode({'rentalReservationId': rentalReservationId}),
    );

    if (response.statusCode < 300) {
      return PaymentIntentData.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    }
    _throwFromResponse(response, 'Failed to create payment intent.');
  }

  Future<SearchResult<Payment>> getMine({
    int? rentalReservationId,
    int? status,
    int page = 0,
    int pageSize = 50,
  }) async {
    final params = <String, String>{
      'Page': '$page',
      'PageSize': '$pageSize',
      'IncludeTotalCount': 'true',
    };
    if (rentalReservationId != null) {
      params['RentalReservationId'] = '$rentalReservationId';
    }
    if (status != null) params['Status'] = '$status';

    final uri = Uri.parse('${BaseProvider.baseUrl}Payments/mine')
        .replace(queryParameters: params);
    final response = await http.get(uri, headers: _headers());

    if (response.statusCode < 300) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final result = SearchResult<Payment>();
      result.totalCount = data['totalCount'] as int?;
      result.items = (data['items'] as List<dynamic>)
          .map((e) => Payment.fromJson(e as Map<String, dynamic>))
          .toList();
      return result;
    }
    _throwFromResponse(response, 'Failed to load payments.');
  }

  Future<Payment?> getById(int id) async {
    final uri = Uri.parse('${BaseProvider.baseUrl}Payments/$id');
    final response = await http.get(uri, headers: _headers());
    if (response.statusCode == 404) return null;
    if (response.statusCode < 300) {
      return Payment.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
    }
    _throwFromResponse(response, 'Failed to load payment.');
  }

  Future<PaymentStatusResult> syncPayment(int paymentId) async {
    final uri = Uri.parse('${BaseProvider.baseUrl}Payments/$paymentId/sync');
    final response = await http.post(uri, headers: _headers());
    if (response.statusCode < 300) {
      return PaymentStatusResult.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    }
    _throwFromResponse(response, 'Failed to sync payment status.');
  }

  Future<Payment?> getPendingPaymentForReservation(int rentalReservationId) async {
    final result = await getMine(
      rentalReservationId: rentalReservationId,
      pageSize: 10,
    );
    for (final payment in result.items) {
      if (payment.isPending) return payment;
    }
    return null;
  }
}

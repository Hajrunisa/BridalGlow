import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:bridalglow_mobile/models/rental_reservation.dart';
import 'package:bridalglow_mobile/providers/base_provider.dart';

class RentalReservationProvider extends BaseProvider<RentalReservation> {
  RentalReservationProvider() : super('RentalReservations');

  @override
  RentalReservation fromJson(dynamic json) =>
      RentalReservation.fromJson(json as Map<String, dynamic>);

  /// Creates a new rental reservation for the current customer.
  Future<RentalReservation> createReservation({
    required int dressId,
    required DateTime startDateUtc,
    required DateTime endDateUtc,
    String? notes,
  }) async {
    final uri = Uri.parse('${BaseProvider.baseUrl}RentalReservations');
    final body = jsonEncode({
      'dressId': dressId,
      'startDateUtc': startDateUtc.toUtc().toIso8601String(),
      'endDateUtc': endDateUtc.toUtc().toIso8601String(),
      if (notes != null && notes.isNotEmpty) 'notes': notes,
    });
    final response = await http.post(uri, headers: createHeaders(), body: body);
    if (isValidResponse(response)) {
      return RentalReservation.fromJson(
          jsonDecode(response.body) as Map<String, dynamic>);
    }
    throw Exception('Failed to create rental reservation');
  }

  /// Returns current customer's rental reservations.
  Future<List<RentalReservation>> getMyReservations({int? status}) async {
    var url =
        '${BaseProvider.baseUrl}RentalReservations/mine?pageSize=100&includeTotalCount=false';
    if (status != null) url += '&status=$status';
    final uri = Uri.parse(url);
    final response = await http.get(uri, headers: createHeaders());
    if (isValidResponse(response)) {
      final data = jsonDecode(response.body);
      final items = data['items'] as List<dynamic>? ?? [];
      return items
          .map((e) => RentalReservation.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  /// Returns a single rental reservation by ID (with full status history).
  @override
  Future<RentalReservation?> getById(int id) async {
    final uri = Uri.parse('${BaseProvider.baseUrl}RentalReservations/$id');
    final response = await http.get(uri, headers: createHeaders());
    if (isValidResponse(response)) {
      if (response.body.isEmpty) return null;
      return RentalReservation.fromJson(
          jsonDecode(response.body) as Map<String, dynamic>);
    }
    return null;
  }

  /// Cancels a pending rental reservation owned by the current customer.
  Future<RentalReservation> cancelReservation(int id, {String? reason}) async {
    final uri =
        Uri.parse('${BaseProvider.baseUrl}RentalReservations/$id/cancel');
    final body = jsonEncode({
      if (reason != null && reason.isNotEmpty) 'reason': reason,
    });
    final response = await http.post(uri, headers: createHeaders(), body: body);
    if (isValidResponse(response)) {
      return RentalReservation.fromJson(
          jsonDecode(response.body) as Map<String, dynamic>);
    }
    throw Exception('Failed to cancel rental reservation');
  }

  /// Returns the full status history timeline in chronological order.
  Future<List<RentalReservationStatusHistory>> getTimeline(int id) async {
    final uri =
        Uri.parse('${BaseProvider.baseUrl}RentalReservations/$id/timeline');
    final response = await http.get(uri, headers: createHeaders());
    if (isValidResponse(response)) {
      final list = jsonDecode(response.body) as List<dynamic>;
      return list
          .map((e) => RentalReservationStatusHistory.fromJson(
              e as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  @override
  bool isValidResponse(http.Response response) {
    if (response.statusCode < 299) return true;
    if (response.statusCode == 401) {
      throw Exception('Please check your credentials and try again.');
    }
    _throwApiError(response);
    return false;
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

import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:bridalglow_mobile/models/try_on_reservation.dart';
import 'package:bridalglow_mobile/providers/base_provider.dart';

class TryOnReservationProvider extends BaseProvider<TryOnReservation> {
  TryOnReservationProvider() : super('TryOnReservations');

  @override
  TryOnReservation fromJson(dynamic json) =>
      TryOnReservation.fromJson(json as Map<String, dynamic>);

  /// Returns current customer's reservations.
  Future<List<TryOnReservation>> getMyReservations({int? status}) async {
    var url = '${BaseProvider.baseUrl}TryOnReservations/mine?pageSize=100&includeTotalCount=false';
    if (status != null) url += '&status=$status';
    final uri = Uri.parse(url);
    final response = await http.get(uri, headers: createHeaders());
    if (isValidResponse(response)) {
      final data = jsonDecode(response.body);
      final items = data['items'] as List<dynamic>? ?? [];
      return items
          .map((e) => TryOnReservation.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  /// Returns a single reservation by ID (with full status history).
  Future<TryOnReservation?> getReservationById(int id) async {
    final uri = Uri.parse('${BaseProvider.baseUrl}TryOnReservations/$id');
    final response = await http.get(uri, headers: createHeaders());
    if (isValidResponse(response)) {
      if (response.body.isEmpty) return null;
      return TryOnReservation.fromJson(
          jsonDecode(response.body) as Map<String, dynamic>);
    }
    return null;
  }

  /// Creates a new try-on reservation.
  ///
  /// [appointmentDate] is the specific date the customer is booking.
  /// When the selected Available slot spans multiple days, this restricts the
  /// TryOnHold to just that day so other days remain bookable.
  Future<TryOnReservation> createReservation({
    required int dressId,
    required int availabilitySlotId,
    DateTime? appointmentDate,
    String? notes,
  }) async {
    final uri = Uri.parse('${BaseProvider.baseUrl}TryOnReservations');
    final body = jsonEncode({
      'dressId': dressId,
      'availabilitySlotId': availabilitySlotId,
      if (appointmentDate != null)
        'appointmentDate': appointmentDate.toUtc().toIso8601String(),
      if (notes != null && notes.isNotEmpty) 'notes': notes,
    });
    final response = await http.post(uri, headers: createHeaders(), body: body);
    if (isValidResponse(response)) {
      return TryOnReservation.fromJson(
          jsonDecode(response.body) as Map<String, dynamic>);
    }
    throw Exception('Failed to create reservation');
  }

  /// Cancels a reservation.
  Future<TryOnReservation> cancelReservation(int id, {String? reason}) async {
    final uri =
        Uri.parse('${BaseProvider.baseUrl}TryOnReservations/$id/cancel');
    final body = jsonEncode({
      if (reason != null && reason.isNotEmpty) 'reason': reason,
    });
    final response = await http.post(uri, headers: createHeaders(), body: body);
    if (isValidResponse(response)) {
      return TryOnReservation.fromJson(
          jsonDecode(response.body) as Map<String, dynamic>);
    }
    throw Exception('Failed to cancel reservation');
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

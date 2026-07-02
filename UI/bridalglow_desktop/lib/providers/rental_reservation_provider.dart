import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:bridalglow_desktop/models/rental_reservation.dart';
import 'package:bridalglow_desktop/providers/base_provider.dart';

class RentalReservationProvider extends BaseProvider<RentalReservation> {
  RentalReservationProvider() : super('RentalReservations');

  @override
  RentalReservation fromJson(dynamic json) =>
      RentalReservation.fromJson(json as Map<String, dynamic>);

  /// Returns a single reservation with full status history.
  Future<RentalReservation?> getReservationById(int id) async {
    final uri = Uri.parse('${BaseProvider.baseUrl}RentalReservations/$id');
    final response = await http.get(uri, headers: createHeaders());
    if (isValidResponse(response)) {
      if (response.body.isEmpty) return null;
      return RentalReservation.fromJson(
          jsonDecode(response.body) as Map<String, dynamic>);
    }
    return null;
  }

  /// Approves a pending rental reservation (Pending → Approved).
  Future<RentalReservation> approve(int id) async =>
      _postAction(id, 'approve');

  /// Rejects a pending rental reservation (Pending → Rejected).
  Future<RentalReservation> reject(int id, {String? reason}) async =>
      _postAction(id, 'reject', body: reason != null ? {'reason': reason} : {});

  /// Marks an approved reservation as ready for customer pickup.
  Future<RentalReservation> markReadyForPickup(int id) async =>
      _postAction(id, 'ready-for-pickup');

  /// Records that the customer has picked up the dress.
  Future<RentalReservation> markPickedUp(int id) async =>
      _postAction(id, 'picked-up');

  /// Records the dress return with optional late and damage fees.
  Future<RentalReservation> markReturned(
    int id, {
    double? lateFeeAmount,
    double? damageFeeAmount,
    String? notes,
  }) async {
    final body = <String, dynamic>{};
    if (lateFeeAmount != null) body['lateFeeAmount'] = lateFeeAmount;
    if (damageFeeAmount != null) body['damageFeeAmount'] = damageFeeAmount;
    if (notes != null && notes.isNotEmpty) body['notes'] = notes;
    return _postAction(id, 'returned', body: body);
  }

  /// Completes the rental lifecycle (Returned → Completed).
  Future<RentalReservation> complete(int id) async =>
      _postAction(id, 'complete');

  /// Cancels a reservation (staff cancellation).
  Future<RentalReservation> cancel(int id, {String? reason}) async =>
      _postAction(id, 'cancel',
          body: reason != null ? {'reason': reason} : {});

  /// Returns the full status history timeline in chronological order.
  Future<List<RentalReservationStatusHistory>> getTimeline(int id) async {
    final uri = Uri.parse(
        '${BaseProvider.baseUrl}RentalReservations/$id/timeline');
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

  // ── Private helpers ───────────────────────────────────────────────────────

  Future<RentalReservation> _postAction(
    int id,
    String action, {
    Map<String, dynamic>? body,
  }) async {
    final uri = Uri.parse(
        '${BaseProvider.baseUrl}RentalReservations/$id/$action');
    final response = await http.post(
      uri,
      headers: createHeaders(),
      body: jsonEncode(body ?? {}),
    );
    if (isValidResponse(response)) {
      return RentalReservation.fromJson(
          jsonDecode(response.body) as Map<String, dynamic>);
    }
    throw Exception('Action failed');
  }
}

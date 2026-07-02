import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:bridalglow_desktop/models/try_on_reservation.dart';
import 'package:bridalglow_desktop/providers/base_provider.dart';

class TryOnReservationProvider extends BaseProvider<TryOnReservation> {
  TryOnReservationProvider() : super('TryOnReservations');

  @override
  TryOnReservation fromJson(dynamic json) =>
      TryOnReservation.fromJson(json as Map<String, dynamic>);

  /// Returns a single reservation with full status history.
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

  /// Confirms a reservation (Pending → Confirmed).
  Future<TryOnReservation> confirm(int id, {String? reason}) async {
    return await _postAction(id, 'confirm', reason: reason);
  }

  /// Marks a reservation as Completed.
  Future<TryOnReservation> complete(int id, {String? reason}) async {
    return await _postAction(id, 'complete', reason: reason);
  }

  /// Marks a reservation as NoShow.
  Future<TryOnReservation> markNoShow(int id, {String? reason}) async {
    return await _postAction(id, 'no-show', reason: reason);
  }

  /// Cancels a reservation (staff cancellation).
  Future<TryOnReservation> cancel(int id, {String? reason}) async {
    return await _postAction(id, 'cancel', reason: reason);
  }

  Future<TryOnReservation> _postAction(
    int id,
    String action, {
    String? reason,
  }) async {
    final uri =
        Uri.parse('${BaseProvider.baseUrl}TryOnReservations/$id/$action');
    final body = reason != null ? jsonEncode({'reason': reason}) : '{}';
    final response = await http.post(uri, headers: createHeaders(), body: body);
    if (isValidResponse(response)) {
      return TryOnReservation.fromJson(
          jsonDecode(response.body) as Map<String, dynamic>);
    }
    throw Exception('Action failed');
  }
}

import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:bridalglow_desktop/models/availability_slot.dart';
import 'package:bridalglow_desktop/providers/base_provider.dart';

class DressAvailabilitySlotProvider extends BaseProvider<AvailabilitySlot> {
  DressAvailabilitySlotProvider() : super('DressAvailabilitySlots');

  @override
  AvailabilitySlot fromJson(dynamic json) =>
      AvailabilitySlot.fromJson(json as Map<String, dynamic>);

  /// Creates a new slot (Available or Blocked).
  Future<AvailabilitySlot> createSlot(Map<String, dynamic> request) async {
    final response = await http.post(
      Uri.parse('${BaseProvider.baseUrl}DressAvailabilitySlots'),
      headers: createHeaders(),
      body: jsonEncode(request),
    );
    if (isValidResponse(response)) {
      return AvailabilitySlot.fromJson(
          jsonDecode(response.body) as Map<String, dynamic>);
    }
    throw Exception('Failed to create slot');
  }

  /// Deletes a slot by ID.
  Future<void> deleteSlot(int id) async {
    final response = await http.delete(
      Uri.parse('${BaseProvider.baseUrl}DressAvailabilitySlots/$id'),
      headers: createHeaders(),
    );
    if (response.statusCode >= 299) {
      _throwApiError(response);
    }
  }

  /// Returns free (Available, non-blocked) slots for a dress on a given date.
  Future<List<AvailabilitySlot>> getFreeSlots(
      int dressId, DateTime date) async {
    final dateStr =
        '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    final uri = Uri.parse(
        '${BaseProvider.baseUrl}DressAvailabilitySlots/free-slots?dressId=$dressId&date=$dateStr');
    final response = await http.get(uri, headers: createHeaders());
    if (isValidResponse(response)) {
      final list = jsonDecode(response.body) as List;
      return list
          .map((e) => AvailabilitySlot.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    return [];
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

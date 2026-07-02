import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:bridalglow_mobile/models/availability_slot.dart';
import 'package:bridalglow_mobile/providers/base_provider.dart';

class DressAvailabilitySlotProvider extends BaseProvider<AvailabilitySlot> {
  DressAvailabilitySlotProvider() : super('DressAvailabilitySlots');

  @override
  AvailabilitySlot fromJson(dynamic json) =>
      AvailabilitySlot.fromJson(json as Map<String, dynamic>);

  /// Returns free (Available, non-blocked) slots for [dressId] on [date].
  /// Used in Try-On booking to let the customer pick a specific time slot.
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

  /// Returns all availability slots (Available + blocking) for [dressId]
  /// within the next year.  Used in Rental booking to highlight available
  /// periods and disable blocked dates in the calendar.
  Future<List<AvailabilitySlot>> getRentalAvailability(int dressId) async {
    final uri = Uri.parse(
        '${BaseProvider.baseUrl}DressAvailabilitySlots/rental-availability?dressId=$dressId');
    final response = await http.get(uri, headers: createHeaders());
    if (isValidResponse(response)) {
      final list = jsonDecode(response.body) as List;
      return list
          .map((e) => AvailabilitySlot.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    return [];
  }
}

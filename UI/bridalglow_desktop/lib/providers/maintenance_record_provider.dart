import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:bridalglow_desktop/models/maintenance_record.dart';
import 'package:bridalglow_desktop/providers/base_provider.dart';

class MaintenanceRecordProvider extends BaseProvider<MaintenanceRecord> {
  MaintenanceRecordProvider() : super('MaintenanceRecords');

  @override
  MaintenanceRecord fromJson(dynamic json) =>
      MaintenanceRecord.fromJson(json as Map<String, dynamic>);

  // ── Status transitions ────────────────────────────────────────────────────

  Future<MaintenanceRecord> start(int id) => _postAction(id, 'start');
  Future<MaintenanceRecord> complete(int id) => _postAction(id, 'complete');
  Future<MaintenanceRecord> cancel(int id) => _postAction(id, 'cancel');

  // ── Summary ───────────────────────────────────────────────────────────────

  Future<MaintenanceSummary> getSummary(
    int dressId, {
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    var url =
        '${BaseProvider.baseUrl}MaintenanceRecords/summary?dressId=$dressId';
    if (fromDate != null) {
      url += '&fromDate=${Uri.encodeComponent(fromDate.toUtc().toIso8601String())}';
    }
    if (toDate != null) {
      url += '&toDate=${Uri.encodeComponent(toDate.toUtc().toIso8601String())}';
    }
    final response = await http.get(Uri.parse(url), headers: createHeaders());
    if (isValidResponse(response)) {
      return MaintenanceSummary.fromJson(
          jsonDecode(response.body) as Map<String, dynamic>);
    }
    throw Exception('Failed to load summary');
  }

  // ── Manual dress condition update ─────────────────────────────────────────

  Future<void> updateDressCondition(int dressId, int condition) async {
    final uri = Uri.parse(
        '${BaseProvider.baseUrl}MaintenanceRecords/dresses/$dressId/condition');
    final response = await http.put(
      uri,
      headers: createHeaders(),
      body: jsonEncode({'condition': condition}),
    );
    if (response.statusCode >= 299) {
      isValidResponse(response);
    }
  }

  // ── Private helpers ───────────────────────────────────────────────────────

  Future<MaintenanceRecord> _postAction(int id, String action) async {
    final uri =
        Uri.parse('${BaseProvider.baseUrl}MaintenanceRecords/$id/$action');
    final response = await http.post(
      uri,
      headers: createHeaders(),
      body: jsonEncode({}),
    );
    if (isValidResponse(response)) {
      return MaintenanceRecord.fromJson(
          jsonDecode(response.body) as Map<String, dynamic>);
    }
    throw Exception('Action failed');
  }
}

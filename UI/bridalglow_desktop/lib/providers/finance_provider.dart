import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:bridalglow_desktop/models/ledger_report.dart';
import 'package:bridalglow_desktop/models/payment.dart';
import 'package:bridalglow_desktop/providers/base_provider.dart';

class FinanceProvider extends BaseProvider<Payment> {
  FinanceProvider() : super('Finance');

  @override
  Payment fromJson(dynamic json) => throw UnimplementedError();

  Future<LedgerReport> getLedger({DateTime? from, DateTime? to}) async {
    var url = '${BaseProvider.baseUrl}Finance/ledger';
    final params = <String, String>{};
    if (from != null) params['from'] = from.toUtc().toIso8601String();
    if (to != null) params['to'] = to.toUtc().toIso8601String();
    if (params.isNotEmpty) {
      url = '$url?${Uri(queryParameters: params).query}';
    }

    final response = await http.get(Uri.parse(url), headers: createHeaders());
    if (isValidResponse(response)) {
      return LedgerReport.fromJson(
          jsonDecode(response.body) as Map<String, dynamic>);
    }
    throw Exception('Unknown error');
  }
}

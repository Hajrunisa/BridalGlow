import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:bridalglow_desktop/models/report_models.dart';
import 'package:bridalglow_desktop/providers/base_provider.dart';
import 'package:bridalglow_desktop/utils/report_pdf_helper.dart';

class ReportsProvider extends BaseProvider<KpiSummary> {
  ReportsProvider() : super('Reports');

  @override
  KpiSummary fromJson(dynamic json) =>
      KpiSummary.fromJson(json as Map<String, dynamic>);

  Future<KpiSummary> getKpiSummary({Map<String, dynamic>? filter}) async {
    return _fetchReport('kpi-summary', KpiSummary.fromJson, filter: filter);
  }

  Future<BusinessPerformanceReport> getBusinessPerformance(
      {Map<String, dynamic>? filter}) async {
    return _fetchReport(
      'business-performance/dataset',
      BusinessPerformanceReport.fromJson,
      filter: filter,
    );
  }

  Future<FinancialReport> getFinancial({Map<String, dynamic>? filter}) async {
    return _fetchReport(
      'financial/dataset',
      FinancialReport.fromJson,
      filter: filter,
    );
  }

  Future<ReportPdfDocument> downloadBusinessPdf(
      {Map<String, dynamic>? filter}) async {
    return _downloadPdf(
      'business-performance/pdf',
      'BridalGlow_BusinessPerformance',
      filter: filter,
    );
  }

  Future<ReportPdfDocument> downloadFinancialPdf(
      {Map<String, dynamic>? filter}) async {
    return _downloadPdf(
      'financial/pdf',
      'BridalGlow_Financial',
      filter: filter,
    );
  }

  Future<T> _fetchReport<T>(
    String path,
    T Function(Map<String, dynamic>) parser, {
    Map<String, dynamic>? filter,
  }) async {
    var url = '${BaseProvider.baseUrl}Reports/$path';
    if (filter != null && filter.isNotEmpty) {
      url = '$url?${getQueryString(filter)}';
    }

    final response = await http.get(Uri.parse(url), headers: createHeaders());
    if (isValidResponse(response)) {
      return parser(jsonDecode(response.body) as Map<String, dynamic>);
    }
    throw Exception('Unknown error');
  }

  Future<ReportPdfDocument> _downloadPdf(
    String path,
    String defaultBaseName, {
    Map<String, dynamic>? filter,
  }) async {
    var url = '${BaseProvider.baseUrl}Reports/$path';
    if (filter != null && filter.isNotEmpty) {
      url = '$url?${getQueryString(filter)}';
    }

    final response = await http.get(Uri.parse(url), headers: createHeaders());
    if (isValidResponse(response)) {
      final fileName =
          _parsePdfFileName(response.headers['content-disposition']) ??
              '${defaultBaseName}_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now().toUtc())}.pdf';

      return ReportPdfDocument(
        bytes: response.bodyBytes,
        fileName: fileName,
      );
    }
    throw Exception('Unknown error');
  }

  String? _parsePdfFileName(String? contentDisposition) {
    if (contentDisposition == null || contentDisposition.isEmpty) {
      return null;
    }

    final utf8Match =
        RegExp(r"filename\*=UTF-8''([^;]+)", caseSensitive: false)
            .firstMatch(contentDisposition);
    if (utf8Match != null) {
      return Uri.decodeComponent(utf8Match.group(1)!);
    }

    final match = RegExp(r'filename="?([^";\n]+)"?', caseSensitive: false)
        .firstMatch(contentDisposition);
    return match?.group(1)?.trim();
  }
}

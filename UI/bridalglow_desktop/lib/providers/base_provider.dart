import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:bridalglow_desktop/models/search_result.dart';
import 'package:bridalglow_desktop/providers/auth_provider.dart';

abstract class BaseProvider<T> with ChangeNotifier {
  /// Single base URL used by all providers and static API helpers.
  /// Initialised once in [main] via [BaseProvider.init] — never null at runtime.
  static String baseUrl = 'http://localhost:5140/api/';
  static String? hubUrlOverride;

  final String endpoint;

  BaseProvider(this.endpoint);

  /// The HTTP origin of the API server (scheme + host + port, no trailing slash).
  /// Used to resolve relative image paths returned by the upload endpoint,
  /// e.g. "/uploads/dresses/5/abc.jpg" → "http://localhost:5140/uploads/…"
  static String get serverOrigin {
    final uri = Uri.tryParse(baseUrl);
    if (uri == null) return '';
    final port = uri.hasPort ? ':${uri.port}' : '';
    return '${uri.scheme}://${uri.host}$port';
  }

  /// Must be called in [main()] after [dotenv.load()], before [runApp()].
  ///
  /// Reads [API_BASE_URL] from the .env file loaded by flutter_dotenv and
  /// normalises it to always end with "/api/".  If the key is absent or the
  /// file is missing the safe development default (localhost:5140) is kept.
  static void init() {
    String? raw;
    try {
      raw = dotenv.env['API_BASE_URL']?.trim();
    } catch (_) {}

    const hubDartDefine = String.fromEnvironment('SIGNALR_HUB_URL');
    if (hubDartDefine.isNotEmpty) {
      hubUrlOverride = hubDartDefine;
    } else {
      try {
        final hubRaw = dotenv.env['SIGNALR_HUB_URL']?.trim();
        if (hubRaw != null && hubRaw.isNotEmpty) {
          hubUrlOverride = hubRaw;
        }
      } catch (_) {}
    }

    if (raw == null || raw.isEmpty) return; // keep the default

    final withSlash = raw.endsWith('/') ? raw : '$raw/';
    baseUrl = withSlash.endsWith('api/') ? withSlash : '${withSlash}api/';
  }

  // ── CRUD helpers ──────────────────────────────────────────────────────────

  Future<T?> getById(int id) async {
    final response = await http.get(
      Uri.parse('$baseUrl$endpoint/$id'),
      headers: createHeaders(),
    );
    if (isValidResponse(response)) {
      if (response.body.isEmpty) return null;
      return fromJson(jsonDecode(response.body));
    }
    return null;
  }

  Future<SearchResult<T>> get({dynamic filter}) async {
    var url = '$baseUrl$endpoint';
    if (filter != null) url = '$url?${getQueryString(filter)}';
    final response = await http.get(Uri.parse(url), headers: createHeaders());
    if (isValidResponse(response)) {
      final data = jsonDecode(response.body);
      final result = SearchResult<T>();
      result.totalCount = data['totalCount'];
      result.items = List<T>.from(
        ((data['items'] as List?) ?? []).map((e) => fromJson(e)),
      );
      return result;
    }
    throw Exception('Unknown error');
  }

  Future<T> insert(dynamic request) async {
    final response = await http.post(
      Uri.parse('$baseUrl$endpoint'),
      headers: createHeaders(),
      body: jsonEncode(request),
    );
    if (isValidResponse(response)) {
      return fromJson(jsonDecode(response.body));
    }
    throw Exception('Unknown error');
  }

  Future<T> update(int id, dynamic request) async {
    final response = await http.put(
      Uri.parse('$baseUrl$endpoint/$id'),
      headers: createHeaders(),
      body: jsonEncode(request),
    );
    if (isValidResponse(response)) {
      return fromJson(jsonDecode(response.body));
    }
    throw Exception('Unknown error');
  }

  /// The BridalGlow API returns 204 No Content on successful delete.
  Future<void> delete(int id) async {
    final response = await http.delete(
      Uri.parse('$baseUrl$endpoint/$id'),
      headers: createHeaders(),
    );
    if (response.statusCode >= 299) {
      _throwApiError(response);
    }
  }

  // ── Subclass contract ─────────────────────────────────────────────────────

  T fromJson(dynamic data);

  // ── Error handling ────────────────────────────────────────────────────────

  bool isValidResponse(http.Response response) {
    if (response.statusCode < 299) return true;
    if (response.statusCode == 401) {
      throw Exception('Please check your credentials and try again.');
    }
    _throwApiError(response);
    return false;
  }

  /// Extracts a meaningful message from BridalGlow API error bodies.
  /// Format: { "errors": { "userError": ["Kategorija već postoji."] } }
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
          message ??= data['message']?.toString() ?? data['title']?.toString();
        }
      } catch (_) {}
    }
    throw Exception(message ?? 'Something went wrong, please try again later!');
  }

  // ── Shared helpers ────────────────────────────────────────────────────────

  Map<String, String> createHeaders() => {
        'Content-Type': 'application/json',
        if (AuthProvider.accessToken != null)
          'Authorization': 'Bearer ${AuthProvider.accessToken}',
      };

  String getQueryString(Map params, {String prefix = '&'}) {
    var query = '';
    params.forEach((key, value) {
      if (value is String || value is int || value is double || value is bool) {
        final encoded = value is String ? Uri.encodeComponent(value) : value;
        query += '$prefix$key=$encoded';
      }
    });
    return query.startsWith('&') ? query.substring(1) : query;
  }
}

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:bridalglow_mobile/models/search_result.dart';
import 'package:bridalglow_mobile/providers/auth_provider.dart';

abstract class BaseProvider<T> with ChangeNotifier {
  /// Single base URL used by all providers and static API helpers.
  /// Initialised once in [main] via [BaseProvider.init] — never null at runtime.
  static String baseUrl = 'http://localhost:5140/api/';
  static String? hubUrlOverride;

  @protected
  final String endpoint;

  BaseProvider(this.endpoint);

  /// HTTP origin (scheme + host + port) used to resolve relative image paths.
  static String get serverOrigin {
    final uri = Uri.tryParse(baseUrl);
    if (uri == null) return '';
    final port = uri.hasPort ? ':${uri.port}' : '';
    return '${uri.scheme}://${uri.host}$port';
  }

  /// Must be called in [main] after [dotenv.load], before [runApp].
  ///
  /// RSII: [API_BASE_URL] se čita putem `--dart-define`, inače iz `.env`.
  /// Normalizuje vrijednost da uvijek završava sa `/api/`.
  static void init() {
    const dartDefine = String.fromEnvironment('API_BASE_URL');
    String? resolved;

    if (dartDefine.isNotEmpty) {
      resolved = dartDefine;
    } else {
      try {
        final fromDotenv = dotenv.env['API_BASE_URL']?.trim();
        if (fromDotenv != null && fromDotenv.isNotEmpty) {
          resolved = fromDotenv;
        }
      } catch (_) {}
    }

    if (resolved == null || resolved.isEmpty) {
      _initHubUrl();
      return;
    }

    _initHubUrl();

    final root = resolved.endsWith('/') ? resolved : '$resolved/';
    baseUrl = root.endsWith('api/') ? root : '${root}api/';
  }

  static void _initHubUrl() {
    const hubDartDefine = String.fromEnvironment('SIGNALR_HUB_URL');
    if (hubDartDefine.isNotEmpty) {
      hubUrlOverride = hubDartDefine;
      return;
    }
    try {
      final hubRaw = dotenv.env['SIGNALR_HUB_URL']?.trim();
      if (hubRaw != null && hubRaw.isNotEmpty) {
        hubUrlOverride = hubRaw;
      }
    } catch (_) {}
  }

  Future<T?> getById(int id) async {
    final uri = Uri.parse('$baseUrl$endpoint/$id');
    final response = await http.get(uri, headers: createHeaders());
    if (isValidResponse(response)) {
      if (response.body.isEmpty) return null;
      return fromJson(jsonDecode(response.body));
    }
    throw Exception('Unknown error');
  }

  Future<SearchResult<T>> get({dynamic filter}) async {
    var url = '$baseUrl$endpoint';
    if (filter != null) {
      url = '$url?${getQueryString(filter)}';
    }
    final uri = Uri.parse(url);
    final response = await http.get(uri, headers: createHeaders());
    if (isValidResponse(response)) {
      final data = jsonDecode(response.body);
      final result = SearchResult<T>();
      result.totalCount = data['totalCount'];
      result.items = List<T>.from(data['items'].map((e) => fromJson(e)));
      return result;
    }
    throw Exception('Unknown error');
  }

  Future<T> insert(dynamic request) async {
    final uri = Uri.parse('$baseUrl$endpoint');
    final response = await http.post(
      uri,
      headers: createHeaders(),
      body: jsonEncode(request),
    );
    if (isValidResponse(response)) {
      return fromJson(jsonDecode(response.body));
    }
    throw Exception('Unknown error');
  }

  Future<T> update(int id, [dynamic request]) async {
    final uri = Uri.parse('$baseUrl$endpoint/$id');
    final response = await http.put(
      uri,
      headers: createHeaders(),
      body: jsonEncode(request),
    );
    if (isValidResponse(response)) {
      return fromJson(jsonDecode(response.body));
    }
    throw Exception('Unknown error');
  }

  T fromJson(dynamic data);

  bool isValidResponse(http.Response response) {
    if (response.statusCode < 299) return true;
    if (response.statusCode == 401) {
      throw Exception('Please check your credentials and try again.');
    }
    throw Exception('Something went wrong, please try again later!');
  }

  Map<String, String> createHeaders() {
    return {
      'Content-Type': 'application/json',
      if (AuthProvider.accessToken != null)
        'Authorization': 'Bearer ${AuthProvider.accessToken}',
    };
  }

  String getQueryString(Map params, {String prefix = '&'}) {
    var query = '';
    params.forEach((key, value) {
      if (value is String || value is int || value is double || value is bool) {
        var encoded = value is String ? Uri.encodeComponent(value) : value;
        query += '$prefix$key=$encoded';
      }
    });
    return query.startsWith('&') ? query.substring(1) : query;
  }
}

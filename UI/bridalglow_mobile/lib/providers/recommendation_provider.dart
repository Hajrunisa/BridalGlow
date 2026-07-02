import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:bridalglow_mobile/models/recommendation.dart';
import 'package:bridalglow_mobile/providers/auth_provider.dart';
import 'package:bridalglow_mobile/providers/base_provider.dart';

class RecommendationProvider extends ChangeNotifier {
  List<RecommendationItem> _forMeItems = [];
  bool _forMeLoading = false;
  String? _forMeError;

  List<RecommendationItem> _coldStartItems = [];
  bool _coldStartLoading = false;
  String? _coldStartError;

  final Map<int, List<SimilarDress>> _similarByDressId = {};
  final Map<int, bool> _similarLoading = {};
  final Map<int, String?> _similarError = {};

  List<RecommendationItem> get forMeItems => _forMeItems;
  bool get forMeLoading => _forMeLoading;
  String? get forMeError => _forMeError;

  List<RecommendationItem> get coldStartItems => _coldStartItems;
  bool get coldStartLoading => _coldStartLoading;
  String? get coldStartError => _coldStartError;

  List<SimilarDress> similarDressesFor(int dressId) =>
      _similarByDressId[dressId] ?? const [];

  bool isSimilarLoading(int dressId) => _similarLoading[dressId] ?? false;

  String? similarErrorFor(int dressId) => _similarError[dressId];

  /// Loads personalized recommendations; server falls back to cold-start when needed.
  Future<void> loadForMe({int? limit, bool force = false}) async {
    if (_forMeLoading) return;
    if (!force && _forMeItems.isNotEmpty && _forMeError == null) return;

    _forMeLoading = true;
    _forMeError = null;
    notifyListeners();

    try {
      final uri = _buildUri('Recommendations/for-me', limit: limit);
      final response = await http.get(uri, headers: _headers());
      _validateResponse(response);
      final data = jsonDecode(response.body) as List<dynamic>;
      _forMeItems = data
          .map((e) => RecommendationItem.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      _forMeError = _messageFrom(e);
      _forMeItems = [];
    } finally {
      _forMeLoading = false;
      notifyListeners();
    }
  }

  /// Loads explicit cold-start recommendations (used when for-me is empty or as fallback).
  Future<void> loadColdStart({int? limit, bool force = false}) async {
    if (_coldStartLoading) return;
    if (!force && _coldStartItems.isNotEmpty && _coldStartError == null) return;

    _coldStartLoading = true;
    _coldStartError = null;
    notifyListeners();

    try {
      final uri = _buildUri('Recommendations/cold-start', limit: limit);
      final response = await http.get(uri, headers: _headers());
      _validateResponse(response);
      final data = jsonDecode(response.body) as List<dynamic>;
      _coldStartItems = data
          .map((e) => RecommendationItem.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      _coldStartError = _messageFrom(e);
      _coldStartItems = [];
    } finally {
      _coldStartLoading = false;
      notifyListeners();
    }
  }

  /// Loads item-based similar dresses for a catalog dress.
  Future<void> loadSimilarDresses(int dressId, {int? limit}) async {
    if (_similarLoading[dressId] == true) return;

    _similarLoading[dressId] = true;
    _similarError[dressId] = null;
    notifyListeners();

    try {
      var url = '${BaseProvider.baseUrl}Dress/$dressId/similar';
      if (limit != null) url += '?limit=$limit';
      final response = await http.get(Uri.parse(url), headers: _headers());
      _validateResponse(response);
      final data = jsonDecode(response.body) as List<dynamic>;
      _similarByDressId[dressId] = data
          .map((e) => SimilarDress.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      _similarError[dressId] = _messageFrom(e);
      _similarByDressId[dressId] = [];
    } finally {
      _similarLoading[dressId] = false;
      notifyListeners();
    }
  }

  Uri _buildUri(String path, {int? limit}) {
    var url = '${BaseProvider.baseUrl}$path';
    if (limit != null) url += '?limit=$limit';
    return Uri.parse(url);
  }

  void _validateResponse(http.Response response) {
    if (response.statusCode < 299) return;
    if (response.statusCode == 401) {
      throw Exception('Please check your credentials and try again.');
    }
    throw Exception('Something went wrong, please try again later!');
  }

  Map<String, String> _headers() {
    return {
      'Content-Type': 'application/json',
      if (AuthProvider.accessToken != null)
        'Authorization': 'Bearer ${AuthProvider.accessToken}',
    };
  }

  String _messageFrom(Object error) {
    final text = error.toString().replaceFirst('Exception: ', '');
    return text.isEmpty ? 'Recommendations are currently unavailable.' : text;
  }
}

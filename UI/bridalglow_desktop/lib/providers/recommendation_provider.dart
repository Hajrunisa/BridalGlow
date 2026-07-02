import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:bridalglow_desktop/models/recommendation.dart';
import 'package:bridalglow_desktop/providers/auth_provider.dart';
import 'package:bridalglow_desktop/providers/base_provider.dart';

class RecommendationProvider extends ChangeNotifier {
  RecommenderStatus? _status;
  RecommenderTrends? _trends;
  bool _loading = false;
  String? _error;

  RecommenderStatus? get status => _status;
  RecommenderTrends? get trends => _trends;
  bool get loading => _loading;
  String? get error => _error;

  Future<void> loadDashboardInsights({int? limit, bool force = false}) async {
    if (_loading) return;
    if (!force && _status != null && _trends != null && _error == null) return;

    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final results = await Future.wait([
        _fetchStatus(),
        _fetchTrends(limit: limit),
      ]);
      _status = results[0] as RecommenderStatus;
      _trends = results[1] as RecommenderTrends;
    } catch (e) {
      _error = _messageFrom(e);
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> loadStatus({bool force = false}) async {
    if (!force && _status != null) return;
    try {
      _status = await _fetchStatus();
      notifyListeners();
    } catch (e) {
      _error = _messageFrom(e);
      notifyListeners();
    }
  }

  Future<void> loadTrends({int? limit, bool force = false}) async {
    if (!force && _trends != null) return;
    try {
      _trends = await _fetchTrends(limit: limit);
      notifyListeners();
    } catch (e) {
      _error = _messageFrom(e);
      notifyListeners();
    }
  }

  Future<RecommenderStatus> _fetchStatus() async {
    final response = await http.get(
      Uri.parse('${BaseProvider.baseUrl}Recommendations/status'),
      headers: _headers(),
    );
    _validateResponse(response);
    return RecommenderStatus.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<RecommenderTrends> _fetchTrends({int? limit}) async {
    var url = '${BaseProvider.baseUrl}Recommendations/trends';
    if (limit != null) url += '?limit=$limit';
    final response = await http.get(Uri.parse(url), headers: _headers());
    _validateResponse(response);
    return RecommenderTrends.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
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
    return text.isEmpty
        ? 'Recommender data is currently unavailable.'
        : text;
  }
}

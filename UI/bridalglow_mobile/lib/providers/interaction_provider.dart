import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:bridalglow_mobile/providers/auth_provider.dart';
import 'package:bridalglow_mobile/providers/base_provider.dart';

class InteractionProvider extends ChangeNotifier {
  static final String _mobileSessionId =
      'mobile-${DateTime.now().toUtc().millisecondsSinceEpoch}';

  final Set<int> _favoritedDressIds = {};

  bool isFavorited(int dressId) => _favoritedDressIds.contains(dressId);

  /// Loads the authenticated customer's favorites from the server.
  Future<void> loadFavorites() async {
    if (AuthProvider.accessToken == null) {
      clearFavorites();
      return;
    }

    final response = await http.get(
      Uri.parse('${BaseProvider.baseUrl}Interactions/favorites'),
      headers: _headers(),
    );
    if (response.statusCode >= 299) {
      throw Exception('Failed to load favorites');
    }

    final dressIds = (jsonDecode(response.body) as List<dynamic>)
        .map((id) => id as int)
        .toSet();

    _favoritedDressIds
      ..clear()
      ..addAll(dressIds);
    notifyListeners();
  }

  void clearFavorites() {
    if (_favoritedDressIds.isEmpty) return;
    _favoritedDressIds.clear();
    notifyListeners();
  }

  /// Records a dress detail view (fire-and-forget; deduplicated server-side).
  Future<void> recordView(int dressId) async {
    final response = await http.post(
      Uri.parse('${BaseProvider.baseUrl}Interactions'),
      headers: _headers(),
      body: jsonEncode({
        'dressId': dressId,
        'interactionType': 'View',
        'sessionId': _mobileSessionId,
      }),
    );
    if (response.statusCode >= 299) {
      throw Exception('Failed to record view');
    }
  }

  Future<void> toggleFavorite(int dressId) async {
    if (_favoritedDressIds.contains(dressId)) {
      await _removeFavorite(dressId);
      _favoritedDressIds.remove(dressId);
    } else {
      await _recordFavorite(dressId);
      _favoritedDressIds.add(dressId);
    }
    notifyListeners();
  }

  Future<void> _recordFavorite(int dressId) async {
    final response = await http.post(
      Uri.parse('${BaseProvider.baseUrl}Interactions'),
      headers: _headers(),
      body: jsonEncode({
        'dressId': dressId,
        'interactionType': 'Favorite',
      }),
    );
    if (response.statusCode >= 299) {
      throw Exception('Failed to record favorite');
    }
  }

  Future<void> _removeFavorite(int dressId) async {
    final response = await http.delete(
      Uri.parse('${BaseProvider.baseUrl}Interactions/favorites/$dressId'),
      headers: _headers(),
    );
    if (response.statusCode >= 299) {
      throw Exception('Failed to remove favorite');
    }
  }

  Map<String, String> _headers() {
    return {
      'Content-Type': 'application/json',
      if (AuthProvider.accessToken != null)
        'Authorization': 'Bearer ${AuthProvider.accessToken}',
    };
  }
}

import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:bridalglow_mobile/models/review.dart';
import 'package:bridalglow_mobile/providers/base_provider.dart';

class ReviewProvider extends BaseProvider<Review> {
  ReviewProvider() : super('Reviews');

  @override
  Review fromJson(dynamic json) =>
      Review.fromJson(json as Map<String, dynamic>);

  // ── Customer endpoints ────────────────────────────────────────────────────

  /// Returns all reviews submitted by the current customer.
  Future<List<Review>> getMyReviews() async {
    final uri = Uri.parse(
        '${BaseProvider.baseUrl}Reviews/mine?pageSize=100&page=0&includeTotalCount=false');
    final response = await http.get(uri, headers: createHeaders());
    if (isValidResponse(response)) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final items = data['items'] as List? ?? [];
      return items
          .map((e) => Review.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  /// Returns published reviews for a specific dress (public endpoint).
  Future<List<Review>> getPublishedByDress(int dressId,
      {int pageSize = 20}) async {
    final uri = Uri.parse(
        '${BaseProvider.baseUrl}Reviews?dressId=$dressId&pageSize=$pageSize&page=0&includeTotalCount=false');
    final response = await http.get(uri, headers: createHeaders());
    if (isValidResponse(response)) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final items = data['items'] as List? ?? [];
      return items
          .map((e) => Review.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  /// Creates a new review for a completed rental reservation.
  Future<Review> createReview(Map<String, dynamic> request) async {
    final response = await http.post(
      Uri.parse('${BaseProvider.baseUrl}Reviews'),
      headers: createHeaders(),
      body: jsonEncode(request),
    );
    if (isValidResponse(response)) {
      return Review.fromJson(
          jsonDecode(response.body) as Map<String, dynamic>);
    }
    throw Exception('Failed to create review');
  }

  /// Updates a pending-moderation review (customer only).
  Future<Review> updateReview(int id, Map<String, dynamic> request) async {
    final response = await http.put(
      Uri.parse('${BaseProvider.baseUrl}Reviews/$id'),
      headers: createHeaders(),
      body: jsonEncode(request),
    );
    if (isValidResponse(response)) {
      return Review.fromJson(
          jsonDecode(response.body) as Map<String, dynamic>);
    }
    throw Exception('Failed to update review');
  }
}

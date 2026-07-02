import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:bridalglow_desktop/models/review.dart';
import 'package:bridalglow_desktop/models/search_result.dart';
import 'package:bridalglow_desktop/providers/base_provider.dart';

class ReviewProvider extends BaseProvider<Review> {
  ReviewProvider() : super('Reviews');

  @override
  Review fromJson(dynamic json) => Review.fromJson(json as Map<String, dynamic>);

  /// Staff/Admin: full listing with all filters.
  Future<SearchResult<Review>> getAll({Map<String, dynamic>? filter}) async {
    var url = '${BaseProvider.baseUrl}Reviews/all';
    if (filter != null && filter.isNotEmpty) {
      url = '$url?${getQueryString(filter)}';
    }
    final response = await http.get(Uri.parse(url), headers: createHeaders());
    if (isValidResponse(response)) {
      final data = jsonDecode(response.body);
      final result = SearchResult<Review>();
      result.totalCount = data['totalCount'];
      result.items = List<Review>.from(
        ((data['items'] as List?) ?? []).map((e) => fromJson(e)),
      );
      return result;
    }
    throw Exception('Failed to load reviews');
  }

  /// Publishes a PendingModeration review.
  Future<Review> publish(int id) => _postAction(id, 'publish');

  /// Hides a Published review.
  Future<Review> hide(int id) => _postAction(id, 'hide');

  /// Rejects a PendingModeration review with an optional moderation note.
  Future<Review> reject(int id, {String? moderationNote}) async {
    final body = <String, dynamic>{};
    if (moderationNote != null && moderationNote.isNotEmpty) {
      body['moderationNote'] = moderationNote;
    }
    return _postAction(id, 'reject', body: body);
  }

  /// Sets or updates the staff reply on a Published review.
  Future<Review> setStaffReply(int id, String reply) async {
    final uri = Uri.parse('${BaseProvider.baseUrl}Reviews/$id/staff-reply');
    final response = await http.put(
      uri,
      headers: createHeaders(),
      body: jsonEncode({'staffReply': reply}),
    );
    if (isValidResponse(response)) {
      return Review.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
    }
    throw Exception('Failed to set staff reply');
  }

  // ── Private helpers ───────────────────────────────────────────────────────

  Future<Review> _postAction(
    int id,
    String action, {
    Map<String, dynamic>? body,
  }) async {
    final uri = Uri.parse('${BaseProvider.baseUrl}Reviews/$id/$action');
    final response = await http.post(
      uri,
      headers: createHeaders(),
      body: jsonEncode(body ?? {}),
    );
    if (isValidResponse(response)) {
      return Review.fromJson(
          jsonDecode(response.body) as Map<String, dynamic>);
    }
    throw Exception('Action failed');
  }
}

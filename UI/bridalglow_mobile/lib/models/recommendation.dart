import 'package:bridalglow_mobile/models/dress.dart';

/// Matches RecommendationItemResponse from the API.
class RecommendationItem {
  final DressListItem dress;
  final double score;
  final int rank;
  final String reason;

  RecommendationItem({
    required this.dress,
    required this.score,
    required this.rank,
    required this.reason,
  });

  factory RecommendationItem.fromJson(Map<String, dynamic> json) {
    return RecommendationItem(
      dress: DressListItem.fromJson(json['dress'] as Map<String, dynamic>),
      score: (json['score'] as num).toDouble(),
      rank: json['rank'] as int,
      reason: json['reason'] as String? ?? '',
    );
  }
}

/// Matches SimilarDressResponse from the API.
class SimilarDress {
  final DressListItem dress;
  final double score;
  final String? reason;

  SimilarDress({
    required this.dress,
    required this.score,
    this.reason,
  });

  factory SimilarDress.fromJson(Map<String, dynamic> json) {
    return SimilarDress(
      dress: DressListItem.fromJson(json['dress'] as Map<String, dynamic>),
      score: (json['score'] as num).toDouble(),
      reason: json['reason'] as String?,
    );
  }
}

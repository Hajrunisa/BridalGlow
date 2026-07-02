import 'package:bridalglow_desktop/models/dress.dart';

class RecommenderStatus {
  final String modelVersion;
  final DateTime? lastSimilarityRunAtUtc;
  final DateTime? lastSnapshotRunAtUtc;
  final int interactionCount;
  final int similarityPairCount;
  final int snapshotCount;

  const RecommenderStatus({
    required this.modelVersion,
    this.lastSimilarityRunAtUtc,
    this.lastSnapshotRunAtUtc,
    required this.interactionCount,
    required this.similarityPairCount,
    required this.snapshotCount,
  });

  factory RecommenderStatus.fromJson(Map<String, dynamic> json) {
    return RecommenderStatus(
      modelVersion: json['modelVersion'] as String? ?? '',
      lastSimilarityRunAtUtc: _parseDate(json['lastSimilarityRunAtUtc']),
      lastSnapshotRunAtUtc: _parseDate(json['lastSnapshotRunAtUtc']),
      interactionCount: json['interactionCount'] as int? ?? 0,
      similarityPairCount: json['similarityPairCount'] as int? ?? 0,
      snapshotCount: json['snapshotCount'] as int? ?? 0,
    );
  }
}

class RecommendationTrendItem {
  final DressListItem dress;
  final int appearanceCount;
  final double totalScore;
  final int rank;

  const RecommendationTrendItem({
    required this.dress,
    required this.appearanceCount,
    required this.totalScore,
    required this.rank,
  });

  factory RecommendationTrendItem.fromJson(Map<String, dynamic> json) {
    return RecommendationTrendItem(
      dress: DressListItem.fromJson(json['dress'] as Map<String, dynamic>),
      appearanceCount: json['appearanceCount'] as int? ?? 0,
      totalScore: (json['totalScore'] as num?)?.toDouble() ?? 0,
      rank: json['rank'] as int? ?? 0,
    );
  }
}

class RecommenderTrends {
  final String modelVersion;
  final DateTime? lastSnapshotRunAtUtc;
  final List<RecommendationTrendItem> items;

  const RecommenderTrends({
    required this.modelVersion,
    this.lastSnapshotRunAtUtc,
    required this.items,
  });

  factory RecommenderTrends.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List<dynamic>? ?? [];
    return RecommenderTrends(
      modelVersion: json['modelVersion'] as String? ?? '',
      lastSnapshotRunAtUtc: _parseDate(json['lastSnapshotRunAtUtc']),
      items: rawItems
          .map((e) =>
              RecommendationTrendItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

DateTime? _parseDate(dynamic value) {
  if (value == null) return null;
  if (value is String && value.isNotEmpty) {
    return DateTime.tryParse(value);
  }
  return null;
}

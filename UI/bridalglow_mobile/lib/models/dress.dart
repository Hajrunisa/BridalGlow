import 'package:bridalglow_mobile/models/dress_tag.dart';

const Map<int, String> kDressStatusLabels = {
  1: 'Draft',
  2: 'Active',
  3: 'Reserved',
  4: 'Out of Service',
  5: 'Archived',
};

const Map<int, String> kDressConditionLabels = {
  1: 'Excellent',
  2: 'Very Good',
  3: 'Good',
  4: 'Needs Repair',
};

const _kStatusByName = {
  'Draft': 1,
  'Active': 2,
  'Reserved': 3,
  'OutOfService': 4,
  'Archived': 5,
};

const _kConditionByName = {
  'Excellent': 1,
  'VeryGood': 2,
  'Good': 3,
  'NeedsRepair': 4,
};

int _parseDressStatus(dynamic v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return _kStatusByName[v] ?? 0;
  return 0;
}

/// Dress statuses that allow rental per backend [RentalReservationService].
const int kDressStatusActive = 2;

int _parseDressCondition(dynamic v) {
  if (v is int) return v;
  if (v is String) return _kConditionByName[v] ?? 0;
  return 0;
}

/// Lightweight model for list view (DressListItemResponse).
class DressListItem {
  final int id;
  final String code;
  final String name;
  final String color;
  final String sizeLabel;
  final double baseRentalPrice;
  final double? tryOnPrice;
  final int status;
  final int condition;
  final bool isFeatured;
  final double averageRating;
  final int ratingCount;
  final int primaryCategoryId;
  final String primaryCategoryName;
  final List<String> tagNames;
  final DateTime createdAtUtc;
  final String? primaryImageUrl;

  DressListItem({
    required this.id,
    required this.code,
    required this.name,
    required this.color,
    required this.sizeLabel,
    required this.baseRentalPrice,
    this.tryOnPrice,
    required this.status,
    required this.condition,
    required this.isFeatured,
    required this.averageRating,
    required this.ratingCount,
    required this.primaryCategoryId,
    required this.primaryCategoryName,
    required this.tagNames,
    required this.createdAtUtc,
    this.primaryImageUrl,
  });

  String get statusLabel => kDressStatusLabels[status] ?? 'Unknown';
  String get conditionLabel => kDressConditionLabels[condition] ?? 'Unknown';

  factory DressListItem.fromJson(Map<String, dynamic> json) {
    List<String> tagNames;
    if (json['tagNames'] != null) {
      tagNames = List<String>.from(json['tagNames'] as List);
    } else if (json['tags'] != null) {
      tagNames = (json['tags'] as List)
          .map((t) => (t as Map<String, dynamic>)['name'] as String)
          .toList();
    } else {
      tagNames = [];
    }

    return DressListItem(
      id: json['id'] as int,
      code: json['code'] as String,
      name: json['name'] as String,
      color: json['color'] as String,
      sizeLabel: json['sizeLabel'] as String,
      baseRentalPrice: (json['baseRentalPrice'] as num).toDouble(),
      tryOnPrice: json['tryOnPrice'] != null
          ? (json['tryOnPrice'] as num).toDouble()
          : null,
      status: _parseDressStatus(json['status']),
      condition: _parseDressCondition(json['condition']),
      isFeatured: json['isFeatured'] as bool,
      averageRating: (json['averageRating'] as num).toDouble(),
      ratingCount: json['ratingCount'] as int,
      primaryCategoryId: json['primaryCategoryId'] as int,
      primaryCategoryName: json['primaryCategoryName'] as String,
      tagNames: tagNames,
      createdAtUtc: DateTime.parse(json['createdAtUtc'] as String),
      primaryImageUrl: json['primaryImageUrl'] as String?,
    );
  }
}

/// Full dress model matching DressResponse from the API.
class DressDetail {
  final int id;
  final String code;
  final String name;
  final String? description;
  final String? brand;
  final String color;
  final String? material;
  final String? silhouette;
  final String? neckline;
  final String? sleeveType;
  final String? trainLength;
  final String sizeLabel;
  final double? bustCm;
  final double? waistCm;
  final double? hipCm;
  final double? lengthCm;
  final int condition;
  final double? acquisitionCost;
  final double? replacementValue;
  final double baseRentalPrice;
  final double? tryOnPrice;
  final double? depositAmount;
  final int status;
  final bool isFeatured;
  final double averageRating;
  final int ratingCount;
  final int primaryCategoryId;
  final String primaryCategoryName;
  final List<DressTag> tags;
  final DateTime createdAtUtc;
  final DateTime? updatedAtUtc;

  DressDetail({
    required this.id,
    required this.code,
    required this.name,
    this.description,
    this.brand,
    required this.color,
    this.material,
    this.silhouette,
    this.neckline,
    this.sleeveType,
    this.trainLength,
    required this.sizeLabel,
    this.bustCm,
    this.waistCm,
    this.hipCm,
    this.lengthCm,
    required this.condition,
    this.acquisitionCost,
    this.replacementValue,
    required this.baseRentalPrice,
    this.tryOnPrice,
    this.depositAmount,
    required this.status,
    required this.isFeatured,
    required this.averageRating,
    required this.ratingCount,
    required this.primaryCategoryId,
    required this.primaryCategoryName,
    required this.tags,
    required this.createdAtUtc,
    this.updatedAtUtc,
  });

  String get statusLabel => kDressStatusLabels[status] ?? 'Unknown';
  String get conditionLabel => kDressConditionLabels[condition] ?? 'Unknown';
  bool get isActiveForRental => status == kDressStatusActive;

  factory DressDetail.fromJson(Map<String, dynamic> json) => DressDetail(
        id: json['id'] as int,
        code: json['code'] as String,
        name: json['name'] as String,
        description: json['description'] as String?,
        brand: json['brand'] as String?,
        color: json['color'] as String,
        material: json['material'] as String?,
        silhouette: json['silhouette'] as String?,
        neckline: json['neckline'] as String?,
        sleeveType: json['sleeveType'] as String?,
        trainLength: json['trainLength'] as String?,
        sizeLabel: json['sizeLabel'] as String,
        bustCm: json['bustCm'] != null
            ? (json['bustCm'] as num).toDouble()
            : null,
        waistCm: json['waistCm'] != null
            ? (json['waistCm'] as num).toDouble()
            : null,
        hipCm: json['hipCm'] != null
            ? (json['hipCm'] as num).toDouble()
            : null,
        lengthCm: json['lengthCm'] != null
            ? (json['lengthCm'] as num).toDouble()
            : null,
        condition: _parseDressCondition(json['condition']),
        acquisitionCost: json['acquisitionCost'] != null
            ? (json['acquisitionCost'] as num).toDouble()
            : null,
        replacementValue: json['replacementValue'] != null
            ? (json['replacementValue'] as num).toDouble()
            : null,
        baseRentalPrice: (json['baseRentalPrice'] as num).toDouble(),
        tryOnPrice: json['tryOnPrice'] != null
            ? (json['tryOnPrice'] as num).toDouble()
            : null,
        depositAmount: json['depositAmount'] != null
            ? (json['depositAmount'] as num).toDouble()
            : null,
        status: _parseDressStatus(json['status']),
        isFeatured: json['isFeatured'] as bool,
        averageRating: (json['averageRating'] as num).toDouble(),
        ratingCount: json['ratingCount'] as int,
        primaryCategoryId: json['primaryCategoryId'] as int,
        primaryCategoryName: json['primaryCategoryName'] as String,
        tags: ((json['tags'] as List?) ?? [])
            .map((t) => DressTag.fromJson(t as Map<String, dynamic>))
            .toList(),
        createdAtUtc: DateTime.parse(json['createdAtUtc'] as String),
        updatedAtUtc: json['updatedAtUtc'] != null
            ? DateTime.parse(json['updatedAtUtc'] as String)
            : null,
      );
}

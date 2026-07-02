const Map<int, String> kPriceRuleTypeLabels = {
  1: 'Seasonal',
  2: 'Weekend',
  3: 'Promotion',
  4: 'Custom',
};

const Map<String, int> kPriceRuleTypeByName = {
  'Seasonal': 1,
  'Weekend': 2,
  'Promotion': 3,
  'Custom': 4,
};

int _parseRuleType(dynamic v) {
  if (v is int) return v;
  if (v is String) return kPriceRuleTypeByName[v] ?? 0;
  return 0;
}

class DressPriceRule {
  final int id;
  final int dressId;
  final String dressName;
  final String dressCode;
  final int ruleType;
  final String ruleTypeLabel;
  final double amount;
  final double? percent;
  final DateTime startDateUtc;
  final DateTime? endDateUtc;
  final int priority;
  final bool isActive;
  final DateTime createdAtUtc;
  final DateTime? updatedAtUtc;

  const DressPriceRule({
    required this.id,
    required this.dressId,
    required this.dressName,
    required this.dressCode,
    required this.ruleType,
    required this.ruleTypeLabel,
    required this.amount,
    this.percent,
    required this.startDateUtc,
    this.endDateUtc,
    required this.priority,
    required this.isActive,
    required this.createdAtUtc,
    this.updatedAtUtc,
  });

  String get ruleTypeName => kPriceRuleTypeLabels[ruleType] ?? 'Unknown';

  factory DressPriceRule.fromJson(Map<String, dynamic> json) {
    return DressPriceRule(
      id: json['id'] as int,
      dressId: json['dressId'] as int,
      dressName: json['dressName'] as String? ?? '',
      dressCode: json['dressCode'] as String? ?? '',
      ruleType: _parseRuleType(json['ruleType']),
      ruleTypeLabel: json['ruleTypeLabel'] as String? ?? '',
      amount: (json['amount'] as num).toDouble(),
      percent: json['percent'] != null ? (json['percent'] as num).toDouble() : null,
      startDateUtc: DateTime.parse(json['startDateUtc'] as String),
      endDateUtc: json['endDateUtc'] != null
          ? DateTime.parse(json['endDateUtc'] as String)
          : null,
      priority: json['priority'] as int,
      isActive: json['isActive'] as bool,
      createdAtUtc: DateTime.parse(json['createdAtUtc'] as String),
      updatedAtUtc: json['updatedAtUtc'] != null
          ? DateTime.parse(json['updatedAtUtc'] as String)
          : null,
    );
  }
}

class EffectivePrice {
  final int dressId;
  final DateTime startAt;
  final DateTime endAt;
  final double baseRentalPrice;
  final double effectivePrice;
  final DressPriceRule? appliedRule;

  const EffectivePrice({
    required this.dressId,
    required this.startAt,
    required this.endAt,
    required this.baseRentalPrice,
    required this.effectivePrice,
    this.appliedRule,
  });

  factory EffectivePrice.fromJson(Map<String, dynamic> json) {
    return EffectivePrice(
      dressId: json['dressId'] as int,
      startAt: DateTime.parse(json['startAt'] as String),
      endAt: DateTime.parse(json['endAt'] as String),
      baseRentalPrice: (json['baseRentalPrice'] as num).toDouble(),
      effectivePrice: (json['effectivePrice'] as num).toDouble(),
      appliedRule: json['appliedRule'] != null
          ? DressPriceRule.fromJson(json['appliedRule'] as Map<String, dynamic>)
          : null,
    );
  }
}

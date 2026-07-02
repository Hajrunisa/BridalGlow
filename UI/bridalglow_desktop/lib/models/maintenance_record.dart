// ── Enum label maps ───────────────────────────────────────────────────────

const Map<int, String> kMaintenanceStatusLabels = {
  1: 'Logged',
  2: 'In Progress',
  3: 'Completed',
  4: 'Cancelled',
};

const Map<String, int> kMaintenanceStatusByName = {
  'Logged': 1,
  'InProgress': 2,
  'Completed': 3,
  'Cancelled': 4,
};

const Map<int, String> kMaintenanceTypeLabels = {
  1: 'Cleaning',
  2: 'Repair',
  3: 'Alteration',
  4: 'Inspection',
  5: 'Preservation',
};

const Map<String, int> kMaintenanceTypeByName = {
  'Cleaning': 1,
  'Repair': 2,
  'Alteration': 3,
  'Inspection': 4,
  'Preservation': 5,
};

const Map<int, String> kMaintenanceDressConditionLabels = {
  1: 'Excellent',
  2: 'Very Good',
  3: 'Good',
  4: 'Needs Repair',
};

const Map<String, int> kMaintenanceDressConditionByName = {
  'Excellent': 1,
  'VeryGood': 2,
  'Good': 3,
  'NeedsRepair': 4,
};

int _parseEnumInt(dynamic v, Map<String, int> nameMap) {
  if (v is int) return v;
  if (v is String) return nameMap[v] ?? 0;
  return 0;
}

// ── Convenience aliases used in UI ────────────────────────────────────────

/// Use [kMaintenanceDressConditionLabels] to avoid collision with dress.dart.
Map<int, String> get kConditionLabelsForMaintenance =>
    kMaintenanceDressConditionLabels;

// ── MaintenanceRecord ─────────────────────────────────────────────────────

class MaintenanceRecord {
  final int id;

  final int dressId;
  final String dressName;
  final String dressCode;

  final int recordedByUserId;
  final String recordedByUserName;

  final int maintenanceType;
  final String maintenanceTypeLabel;

  final int status;
  final String statusLabel;

  final String description;
  final double costAmount;

  final String? vendorName;
  final String? invoiceNumber;

  final int? beforeCondition;
  final String? beforeConditionLabel;

  final int? afterCondition;
  final String? afterConditionLabel;

  final DateTime? outOfServiceFromUtc;
  final DateTime? outOfServiceToUtc;

  final DateTime performedAtUtc;
  final DateTime? nextCheckAtUtc;

  final DateTime createdAtUtc;
  final DateTime? updatedAtUtc;

  const MaintenanceRecord({
    required this.id,
    required this.dressId,
    required this.dressName,
    required this.dressCode,
    required this.recordedByUserId,
    required this.recordedByUserName,
    required this.maintenanceType,
    required this.maintenanceTypeLabel,
    required this.status,
    required this.statusLabel,
    required this.description,
    required this.costAmount,
    this.vendorName,
    this.invoiceNumber,
    this.beforeCondition,
    this.beforeConditionLabel,
    this.afterCondition,
    this.afterConditionLabel,
    this.outOfServiceFromUtc,
    this.outOfServiceToUtc,
    required this.performedAtUtc,
    this.nextCheckAtUtc,
    required this.createdAtUtc,
    this.updatedAtUtc,
  });

  bool get isLogged => status == 1;
  bool get isInProgress => status == 2;
  bool get isCompleted => status == 3;
  bool get isCancelled => status == 4;

  factory MaintenanceRecord.fromJson(Map<String, dynamic> json) {
    return MaintenanceRecord(
      id: json['id'] as int,
      dressId: json['dressId'] as int? ?? 0,
      dressName: json['dressName'] as String? ?? '',
      dressCode: json['dressCode'] as String? ?? '',
      recordedByUserId: json['recordedByUserId'] as int? ?? 0,
      recordedByUserName: json['recordedByUserName'] as String? ?? '',
      maintenanceType:
          _parseEnumInt(json['maintenanceType'], kMaintenanceTypeByName),
      maintenanceTypeLabel: json['maintenanceTypeLabel'] as String? ?? '',
      status: _parseEnumInt(json['status'], kMaintenanceStatusByName),
      statusLabel: json['statusLabel'] as String? ?? '',
      description: json['description'] as String? ?? '',
      costAmount: (json['costAmount'] as num? ?? 0).toDouble(),
      vendorName: json['vendorName'] as String?,
      invoiceNumber: json['invoiceNumber'] as String?,
      beforeCondition: json['beforeCondition'] != null
          ? _parseEnumInt(json['beforeCondition'], kMaintenanceDressConditionByName)
          : null,
      beforeConditionLabel: json['beforeConditionLabel'] as String?,
      afterCondition: json['afterCondition'] != null
          ? _parseEnumInt(json['afterCondition'], kMaintenanceDressConditionByName)
          : null,
      afterConditionLabel: json['afterConditionLabel'] as String?,
      outOfServiceFromUtc: json['outOfServiceFromUtc'] != null
          ? DateTime.parse(json['outOfServiceFromUtc'] as String)
          : null,
      outOfServiceToUtc: json['outOfServiceToUtc'] != null
          ? DateTime.parse(json['outOfServiceToUtc'] as String)
          : null,
      performedAtUtc: DateTime.parse(json['performedAtUtc'] as String),
      nextCheckAtUtc: json['nextCheckAtUtc'] != null
          ? DateTime.parse(json['nextCheckAtUtc'] as String)
          : null,
      createdAtUtc: DateTime.parse(json['createdAtUtc'] as String),
      updatedAtUtc: json['updatedAtUtc'] != null
          ? DateTime.parse(json['updatedAtUtc'] as String)
          : null,
    );
  }
}

// ── MaintenanceSummary ────────────────────────────────────────────────────

class MaintenanceSummary {
  final int dressId;
  final String dressName;
  final String dressCode;
  final DateTime? fromDate;
  final DateTime? toDate;
  final int totalRecordCount;
  final double totalCostAmount;
  final List<MaintenanceTypeSummary> byType;

  const MaintenanceSummary({
    required this.dressId,
    required this.dressName,
    required this.dressCode,
    this.fromDate,
    this.toDate,
    required this.totalRecordCount,
    required this.totalCostAmount,
    required this.byType,
  });

  factory MaintenanceSummary.fromJson(Map<String, dynamic> json) {
    final byTypeJson = json['byType'] as List<dynamic>? ?? [];
    return MaintenanceSummary(
      dressId: json['dressId'] as int,
      dressName: json['dressName'] as String? ?? '',
      dressCode: json['dressCode'] as String? ?? '',
      fromDate: json['fromDate'] != null
          ? DateTime.parse(json['fromDate'] as String)
          : null,
      toDate: json['toDate'] != null
          ? DateTime.parse(json['toDate'] as String)
          : null,
      totalRecordCount: json['totalRecordCount'] as int? ?? 0,
      totalCostAmount: (json['totalCostAmount'] as num? ?? 0).toDouble(),
      byType: byTypeJson
          .map((e) =>
              MaintenanceTypeSummary.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class MaintenanceTypeSummary {
  final int maintenanceType;
  final String maintenanceTypeLabel;
  final int recordCount;
  final double totalCostAmount;

  const MaintenanceTypeSummary({
    required this.maintenanceType,
    required this.maintenanceTypeLabel,
    required this.recordCount,
    required this.totalCostAmount,
  });

  factory MaintenanceTypeSummary.fromJson(Map<String, dynamic> json) {
    return MaintenanceTypeSummary(
      maintenanceType:
          _parseEnumInt(json['maintenanceType'], kMaintenanceTypeByName),
      maintenanceTypeLabel: json['maintenanceTypeLabel'] as String? ?? '',
      recordCount: json['recordCount'] as int? ?? 0,
      totalCostAmount: (json['totalCostAmount'] as num? ?? 0).toDouble(),
    );
  }
}

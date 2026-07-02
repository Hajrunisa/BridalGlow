// ── Enum label maps ───────────────────────────────────────────────────────

const Map<String, int> kSlotTypeByName = {
  'Available': 1,
  'Blocked': 2,
  'TryOnHold': 3,
  'RentalHold': 4,
  'MaintenanceBlock': 5,
};

const Map<int, String> kSlotTypeLabels = {
  1: 'Available',
  2: 'Blocked',
  3: 'Try-On Hold',
  4: 'Rental Hold',
  5: 'Maintenance',
};

int _parseSlotType(dynamic v) {
  if (v is int) return v;
  if (v is String) return kSlotTypeByName[v] ?? 0;
  return 0;
}

// ── AvailabilitySlot model ────────────────────────────────────────────────

class AvailabilitySlot {
  final int id;
  final int dressId;
  final String dressName;
  final String dressCode;
  final DateTime startAtUtc;
  final DateTime endAtUtc;
  final int slotType;
  final String? reason;
  final int? sourceReservationId;
  final DateTime createdAtUtc;

  AvailabilitySlot({
    required this.id,
    required this.dressId,
    required this.dressName,
    required this.dressCode,
    required this.startAtUtc,
    required this.endAtUtc,
    required this.slotType,
    this.reason,
    this.sourceReservationId,
    required this.createdAtUtc,
  });

  String get slotTypeLabel => kSlotTypeLabels[slotType] ?? 'Unknown';
  bool get isAvailable => slotType == 1;

  factory AvailabilitySlot.fromJson(Map<String, dynamic> json) {
    return AvailabilitySlot(
      id: json['id'] as int,
      dressId: json['dressId'] as int,
      dressName: json['dressName'] as String? ?? '',
      dressCode: json['dressCode'] as String? ?? '',
      startAtUtc: DateTime.parse(json['startAtUtc'] as String),
      endAtUtc: DateTime.parse(json['endAtUtc'] as String),
      slotType: _parseSlotType(json['slotType']),
      reason: json['reason'] as String?,
      sourceReservationId: json['sourceReservationId'] as int?,
      createdAtUtc: DateTime.parse(json['createdAtUtc'] as String),
    );
  }
}

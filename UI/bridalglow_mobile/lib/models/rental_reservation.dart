// ── Enum label maps ───────────────────────────────────────────────────────

const Map<int, String> kRentalStatusLabels = {
  1: 'Pending',
  2: 'Approved',
  3: 'Rejected',
  4: 'Awaiting Payment',
  5: 'Paid',
  6: 'Ready for Pickup',
  7: 'Picked Up',
  8: 'Returned',
  9: 'Completed',
  10: 'Cancelled',
  11: 'Refunded',
  12: 'Cancelled by Customer',
  13: 'Cancelled by Staff',
};

const Map<String, int> kRentalStatusByName = {
  'Pending': 1,
  'Approved': 2,
  'Rejected': 3,
  'AwaitingPayment': 4,
  'Paid': 5,
  'ReadyForPickup': 6,
  'PickedUp': 7,
  'Returned': 8,
  'Completed': 9,
  'Cancelled': 10,
  'Refunded': 11,
  'CancelledByCustomer': 12,
  'CancelledByStaff': 13,
};

int _parseStatus(dynamic v) {
  if (v is int) return v;
  if (v is String) return kRentalStatusByName[v] ?? 0;
  return 0;
}

// ── RentalReservationStatusHistory ────────────────────────────────────────

class RentalReservationStatusHistory {
  final int id;
  final int fromStatus;
  final String fromStatusLabel;
  final int toStatus;
  final String toStatusLabel;
  final int changedByUserId;
  final String changedByUserName;
  final DateTime changedAtUtc;
  final String? reason;

  const RentalReservationStatusHistory({
    required this.id,
    required this.fromStatus,
    required this.fromStatusLabel,
    required this.toStatus,
    required this.toStatusLabel,
    required this.changedByUserId,
    required this.changedByUserName,
    required this.changedAtUtc,
    this.reason,
  });

  factory RentalReservationStatusHistory.fromJson(Map<String, dynamic> json) {
    return RentalReservationStatusHistory(
      id: json['id'] as int,
      fromStatus: _parseStatus(json['fromStatus']),
      fromStatusLabel: json['fromStatusLabel'] as String? ?? '',
      toStatus: _parseStatus(json['toStatus']),
      toStatusLabel: json['toStatusLabel'] as String? ?? '',
      changedByUserId: json['changedByUserId'] as int? ?? 0,
      changedByUserName: json['changedByUserName'] as String? ?? '',
      changedAtUtc: DateTime.parse(json['changedAtUtc'] as String),
      reason: json['reason'] as String?,
    );
  }
}

// ── RentalReservation ─────────────────────────────────────────────────────

class RentalReservation {
  final int id;
  final String reservationNumber;

  final int dressId;
  final String dressName;
  final String dressCode;

  final int customerUserId;
  final String customerName;
  final String customerEmail;

  final DateTime startDateUtc;
  final DateTime endDateUtc;

  final int status;
  final String statusLabel;

  final double baseAmount;
  final double discountAmount;
  final double depositAmount;
  final double lateFeeAmount;
  final double damageFeeAmount;
  final double totalAmount;
  final String currency;

  final String? notes;
  final String? cancellationReason;

  final DateTime? cancelledAtUtc;
  final DateTime? approvedAtUtc;
  final DateTime? pickedUpAtUtc;
  final DateTime? returnedAtUtc;
  final DateTime? completedAtUtc;

  final DateTime createdAtUtc;
  final DateTime? updatedAtUtc;

  final List<RentalReservationStatusHistory> statusHistory;

  const RentalReservation({
    required this.id,
    required this.reservationNumber,
    required this.dressId,
    required this.dressName,
    required this.dressCode,
    required this.customerUserId,
    required this.customerName,
    required this.customerEmail,
    required this.startDateUtc,
    required this.endDateUtc,
    required this.status,
    required this.statusLabel,
    required this.baseAmount,
    required this.discountAmount,
    required this.depositAmount,
    required this.lateFeeAmount,
    required this.damageFeeAmount,
    required this.totalAmount,
    required this.currency,
    this.notes,
    this.cancellationReason,
    this.cancelledAtUtc,
    this.approvedAtUtc,
    this.pickedUpAtUtc,
    this.returnedAtUtc,
    this.completedAtUtc,
    required this.createdAtUtc,
    this.updatedAtUtc,
    this.statusHistory = const [],
  });

  bool get isPending => status == 1;
  bool get isApproved => status == 2;
  bool get isRejected => status == 3;
  bool get isAwaitingPayment => status == 4;
  bool get isPaid => status == 5;
  bool get isRefunded => status == 11;
  bool get isReadyForPickup => status == 6;
  bool get isPickedUp => status == 7;
  bool get isReturned => status == 8;
  bool get isCompleted => status == 9;
  bool get isCancelled => status == 10 || status == 12 || status == 13;

  bool get canPay => isApproved || isAwaitingPayment;

  bool get isActive =>
      status == 1 ||
      status == 2 ||
      status == 4 ||
      status == 5 ||
      status == 6 ||
      status == 7 ||
      status == 8;

  bool get canCancel => isPending;

  factory RentalReservation.fromJson(Map<String, dynamic> json) {
    final historyJson = json['statusHistory'] as List<dynamic>? ?? [];
    return RentalReservation(
      id: json['id'] as int,
      reservationNumber: json['reservationNumber'] as String? ?? '',
      dressId: json['dressId'] as int,
      dressName: json['dressName'] as String? ?? '',
      dressCode: json['dressCode'] as String? ?? '',
      customerUserId: json['customerUserId'] as int,
      customerName: json['customerName'] as String? ?? '',
      customerEmail: json['customerEmail'] as String? ?? '',
      startDateUtc: DateTime.parse(json['startDateUtc'] as String),
      endDateUtc: DateTime.parse(json['endDateUtc'] as String),
      status: _parseStatus(json['status']),
      statusLabel: json['statusLabel'] as String? ?? '',
      baseAmount: (json['baseAmount'] as num? ?? 0).toDouble(),
      discountAmount: (json['discountAmount'] as num? ?? 0).toDouble(),
      depositAmount: (json['depositAmount'] as num? ?? 0).toDouble(),
      lateFeeAmount: (json['lateFeeAmount'] as num? ?? 0).toDouble(),
      damageFeeAmount: (json['damageFeeAmount'] as num? ?? 0).toDouble(),
      totalAmount: (json['totalAmount'] as num? ?? 0).toDouble(),
      currency: json['currency'] as String? ?? 'EUR',
      notes: json['notes'] as String?,
      cancellationReason: json['cancellationReason'] as String?,
      cancelledAtUtc: json['cancelledAtUtc'] != null
          ? DateTime.parse(json['cancelledAtUtc'] as String)
          : null,
      approvedAtUtc: json['approvedAtUtc'] != null
          ? DateTime.parse(json['approvedAtUtc'] as String)
          : null,
      pickedUpAtUtc: json['pickedUpAtUtc'] != null
          ? DateTime.parse(json['pickedUpAtUtc'] as String)
          : null,
      returnedAtUtc: json['returnedAtUtc'] != null
          ? DateTime.parse(json['returnedAtUtc'] as String)
          : null,
      completedAtUtc: json['completedAtUtc'] != null
          ? DateTime.parse(json['completedAtUtc'] as String)
          : null,
      createdAtUtc: DateTime.parse(json['createdAtUtc'] as String),
      updatedAtUtc: json['updatedAtUtc'] != null
          ? DateTime.parse(json['updatedAtUtc'] as String)
          : null,
      statusHistory: historyJson
          .map((e) => RentalReservationStatusHistory.fromJson(
              e as Map<String, dynamic>))
          .toList(),
    );
  }
}

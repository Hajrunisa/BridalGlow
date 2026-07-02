// ── Enum label maps ───────────────────────────────────────────────────────

const Map<int, String> kReservationStatusLabels = {
  1: 'Pending',
  2: 'Confirmed',
  3: 'Checked In',
  4: 'Completed',
  5: 'Cancelled by Customer',
  6: 'Cancelled by Staff',
  7: 'No Show',
};

const Map<String, int> kReservationStatusByName = {
  'Pending': 1,
  'Confirmed': 2,
  'CheckedIn': 3,
  'Completed': 4,
  'CancelledByCustomer': 5,
  'CancelledByStaff': 6,
  'NoShow': 7,
};

int _parseStatus(dynamic v) {
  if (v is int) return v;
  if (v is String) return kReservationStatusByName[v] ?? 0;
  return 0;
}

// ── TryOnReservationStatusHistory ─────────────────────────────────────────

class TryOnReservationStatusHistory {
  final int id;
  final int fromStatus;
  final String fromStatusLabel;
  final int toStatus;
  final String toStatusLabel;
  final int changedByUserId;
  final String changedByUserName;
  final DateTime changedAtUtc;
  final String? reason;

  const TryOnReservationStatusHistory({
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

  factory TryOnReservationStatusHistory.fromJson(Map<String, dynamic> json) {
    return TryOnReservationStatusHistory(
      id: json['id'] as int,
      fromStatus: _parseStatus(json['fromStatus']),
      fromStatusLabel: json['fromStatusLabel'] as String? ?? '',
      toStatus: _parseStatus(json['toStatus']),
      toStatusLabel: json['toStatusLabel'] as String? ?? '',
      changedByUserId: json['changedByUserId'] as int,
      changedByUserName: json['changedByUserName'] as String? ?? '',
      changedAtUtc: DateTime.parse(json['changedAtUtc'] as String),
      reason: json['reason'] as String?,
    );
  }
}

// ── TryOnReservation ──────────────────────────────────────────────────────

class TryOnReservation {
  final int id;
  final String reservationNumber;
  final int dressId;
  final String dressName;
  final String dressCode;
  final int customerUserId;
  final String customerName;
  final String customerEmail;
  final DateTime startAtUtc;
  final DateTime endAtUtc;
  final int status;
  final String statusLabel;
  final double priceAmount;
  final double? depositAmount;
  final String? notes;
  final String? cancellationReason;
  final DateTime? cancelledAtUtc;
  final DateTime? confirmedAtUtc;
  final DateTime? completedAtUtc;
  final DateTime? noShowAtUtc;
  final DateTime createdAtUtc;
  final DateTime? updatedAtUtc;
  final List<TryOnReservationStatusHistory> statusHistory;

  const TryOnReservation({
    required this.id,
    required this.reservationNumber,
    required this.dressId,
    required this.dressName,
    required this.dressCode,
    required this.customerUserId,
    required this.customerName,
    required this.customerEmail,
    required this.startAtUtc,
    required this.endAtUtc,
    required this.status,
    required this.statusLabel,
    required this.priceAmount,
    this.depositAmount,
    this.notes,
    this.cancellationReason,
    this.cancelledAtUtc,
    this.confirmedAtUtc,
    this.completedAtUtc,
    this.noShowAtUtc,
    required this.createdAtUtc,
    this.updatedAtUtc,
    this.statusHistory = const [],
  });

  bool get isPending => status == 1;
  bool get isConfirmed => status == 2;
  bool get isCheckedIn => status == 3;
  bool get isCompleted => status == 4;
  bool get isCancelled => status == 5 || status == 6;
  bool get isNoShow => status == 7;
  bool get isActive => status == 1 || status == 2 || status == 3;

  factory TryOnReservation.fromJson(Map<String, dynamic> json) {
    final historyJson = json['statusHistory'] as List<dynamic>? ?? [];
    return TryOnReservation(
      id: json['id'] as int,
      reservationNumber: json['reservationNumber'] as String? ?? '',
      dressId: json['dressId'] as int,
      dressName: json['dressName'] as String? ?? '',
      dressCode: json['dressCode'] as String? ?? '',
      customerUserId: json['customerUserId'] as int,
      customerName: json['customerName'] as String? ?? '',
      customerEmail: json['customerEmail'] as String? ?? '',
      startAtUtc: DateTime.parse(json['startAtUtc'] as String),
      endAtUtc: DateTime.parse(json['endAtUtc'] as String),
      status: _parseStatus(json['status']),
      statusLabel: json['statusLabel'] as String? ?? '',
      priceAmount: (json['priceAmount'] as num).toDouble(),
      depositAmount: json['depositAmount'] != null
          ? (json['depositAmount'] as num).toDouble()
          : null,
      notes: json['notes'] as String?,
      cancellationReason: json['cancellationReason'] as String?,
      cancelledAtUtc: json['cancelledAtUtc'] != null
          ? DateTime.parse(json['cancelledAtUtc'] as String)
          : null,
      confirmedAtUtc: json['confirmedAtUtc'] != null
          ? DateTime.parse(json['confirmedAtUtc'] as String)
          : null,
      completedAtUtc: json['completedAtUtc'] != null
          ? DateTime.parse(json['completedAtUtc'] as String)
          : null,
      noShowAtUtc: json['noShowAtUtc'] != null
          ? DateTime.parse(json['noShowAtUtc'] as String)
          : null,
      createdAtUtc: DateTime.parse(json['createdAtUtc'] as String),
      updatedAtUtc: json['updatedAtUtc'] != null
          ? DateTime.parse(json['updatedAtUtc'] as String)
          : null,
      statusHistory: historyJson
          .map((e) => TryOnReservationStatusHistory.fromJson(
              e as Map<String, dynamic>))
          .toList(),
    );
  }
}

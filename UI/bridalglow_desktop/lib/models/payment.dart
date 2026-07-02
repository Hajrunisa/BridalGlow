const Map<int, String> kPaymentStatusLabels = {
  1: 'Created',
  2: 'Requires Action',
  3: 'Processing',
  4: 'Succeeded',
  5: 'Failed',
  6: 'Cancelled',
  7: 'Expired',
};

const Map<String, int> kPaymentStatusByName = {
  'Created': 1,
  'RequiresAction': 2,
  'Processing': 3,
  'Succeeded': 4,
  'Failed': 5,
  'Cancelled': 6,
  'Expired': 7,
};

int _parsePaymentStatus(dynamic v) {
  if (v is int) return v;
  if (v is String) return kPaymentStatusByName[v] ?? 0;
  return 0;
}

class Payment {
  final int id;
  final int? rentalReservationId;
  final int customerUserId;
  final String customerName;
  final String customerEmail;
  final int status;
  final String statusLabel;
  final String? providerPaymentIntentId;
  final String? providerChargeId;
  final double amount;
  final String currency;
  final double capturedAmount;
  final String? failedReason;
  final DateTime? paidAtUtc;
  final String? reservationNumber;
  final String? dressName;
  final DateTime createdAtUtc;

  const Payment({
    required this.id,
    this.rentalReservationId,
    required this.customerUserId,
    required this.customerName,
    required this.customerEmail,
    required this.status,
    required this.statusLabel,
    this.providerPaymentIntentId,
    this.providerChargeId,
    required this.amount,
    required this.currency,
    required this.capturedAmount,
    this.failedReason,
    this.paidAtUtc,
    this.reservationNumber,
    this.dressName,
    required this.createdAtUtc,
  });

  factory Payment.fromJson(Map<String, dynamic> json) {
    return Payment(
      id: json['id'] as int,
      rentalReservationId: json['rentalReservationId'] as int?,
      customerUserId: json['customerUserId'] as int,
      customerName: json['customerName'] as String? ?? '',
      customerEmail: json['customerEmail'] as String? ?? '',
      status: _parsePaymentStatus(json['status']),
      statusLabel: json['statusLabel'] as String? ?? '',
      providerPaymentIntentId: json['providerPaymentIntentId'] as String?,
      providerChargeId: json['providerChargeId'] as String?,
      amount: (json['amount'] as num).toDouble(),
      currency: json['currency'] as String? ?? 'EUR',
      capturedAmount: (json['capturedAmount'] as num?)?.toDouble() ?? 0,
      failedReason: json['failedReason'] as String?,
      paidAtUtc: json['paidAtUtc'] != null
          ? DateTime.parse(json['paidAtUtc'] as String)
          : null,
      reservationNumber: json['reservationNumber'] as String?,
      dressName: json['dressName'] as String?,
      createdAtUtc: DateTime.parse(json['createdAtUtc'] as String),
    );
  }
}

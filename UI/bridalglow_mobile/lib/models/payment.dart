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

int parsePaymentStatus(dynamic v) {
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

  bool get isSucceeded => status == 4;
  bool get isPending => status == 1 || status == 2 || status == 3;
  bool get isFailed => status == 5 || status == 6 || status == 7;

  factory Payment.fromJson(Map<String, dynamic> json) {
    return Payment(
      id: json['id'] as int,
      rentalReservationId: json['rentalReservationId'] as int?,
      customerUserId: json['customerUserId'] as int,
      customerName: json['customerName'] as String? ?? '',
      customerEmail: json['customerEmail'] as String? ?? '',
      status: parsePaymentStatus(json['status']),
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

class PaymentIntentData {
  final int paymentId;
  final String clientSecret;
  final String ephemeralKey;
  final String customerId;

  const PaymentIntentData({
    required this.paymentId,
    required this.clientSecret,
    required this.ephemeralKey,
    required this.customerId,
  });

  factory PaymentIntentData.fromJson(Map<String, dynamic> json) {
    return PaymentIntentData(
      paymentId: json['paymentId'] as int,
      clientSecret: json['clientSecret'] as String,
      ephemeralKey: json['ephemeralKey'] as String,
      customerId: json['customerId'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
        'paymentId': paymentId,
        'clientSecret': clientSecret,
        'ephemeralKey': ephemeralKey,
        'customerId': customerId,
      };
}

class PaymentStatusResult {
  final int paymentId;
  final int localStatus;
  final String localStatusLabel;
  final int? rentalReservationStatus;
  final String? rentalReservationStatusLabel;
  final bool syncApplied;

  const PaymentStatusResult({
    required this.paymentId,
    required this.localStatus,
    required this.localStatusLabel,
    this.rentalReservationStatus,
    this.rentalReservationStatusLabel,
    required this.syncApplied,
  });

  bool get isPaymentSucceeded => localStatus == 4;
  bool get isRentalPaid => rentalReservationStatus == 5;

  factory PaymentStatusResult.fromJson(Map<String, dynamic> json) {
    final rentalStatus = json['rentalReservationStatus'];
    return PaymentStatusResult(
      paymentId: json['paymentId'] as int,
      localStatus: parsePaymentStatus(json['localStatus']),
      localStatusLabel: json['localStatusLabel'] as String? ?? '',
      rentalReservationStatus:
          rentalStatus is int ? rentalStatus : parsePaymentStatus(rentalStatus),
      rentalReservationStatusLabel:
          json['rentalReservationStatusLabel'] as String?,
      syncApplied: json['syncApplied'] as bool? ?? false,
    );
  }
}

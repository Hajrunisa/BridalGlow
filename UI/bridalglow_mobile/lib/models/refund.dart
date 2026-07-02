const Map<int, String> kRefundStatusLabels = {
  1: 'Requested',
  2: 'Approved',
  3: 'Processing',
  4: 'Succeeded',
  5: 'Rejected',
  6: 'Failed',
};

const Map<String, int> kRefundStatusByName = {
  'Requested': 1,
  'Approved': 2,
  'Processing': 3,
  'Succeeded': 4,
  'Rejected': 5,
  'Failed': 6,
};

int parseRefundStatus(dynamic v) {
  if (v is int) return v;
  if (v is String) return kRefundStatusByName[v] ?? 0;
  return 0;
}

class Refund {
  final int id;
  final int paymentId;
  final int requestedByUserId;
  final int? approvedByUserId;
  final int status;
  final String statusLabel;
  final int reasonCode;
  final String reasonCodeLabel;
  final String? reasonText;
  final double amount;
  final String currency;
  final String? providerRefundId;
  final DateTime requestedAtUtc;
  final DateTime? approvedAtUtc;
  final DateTime? processedAtUtc;
  final DateTime? rejectedAtUtc;
  final String? failureReason;
  final DateTime createdAtUtc;

  const Refund({
    required this.id,
    required this.paymentId,
    required this.requestedByUserId,
    this.approvedByUserId,
    required this.status,
    required this.statusLabel,
    required this.reasonCode,
    required this.reasonCodeLabel,
    this.reasonText,
    required this.amount,
    required this.currency,
    this.providerRefundId,
    required this.requestedAtUtc,
    this.approvedAtUtc,
    this.processedAtUtc,
    this.rejectedAtUtc,
    this.failureReason,
    required this.createdAtUtc,
  });

  factory Refund.fromJson(Map<String, dynamic> json) {
    return Refund(
      id: json['id'] as int,
      paymentId: json['paymentId'] as int,
      requestedByUserId: json['requestedByUserId'] as int,
      approvedByUserId: json['approvedByUserId'] as int?,
      status: parseRefundStatus(json['status']),
      statusLabel: json['statusLabel'] as String? ?? '',
      reasonCode: json['reasonCode'] is int ? json['reasonCode'] as int : 0,
      reasonCodeLabel: json['reasonCodeLabel'] as String? ?? '',
      reasonText: json['reasonText'] as String?,
      amount: (json['amount'] as num).toDouble(),
      currency: json['currency'] as String? ?? 'EUR',
      providerRefundId: json['providerRefundId'] as String?,
      requestedAtUtc: DateTime.parse(json['requestedAtUtc'] as String),
      approvedAtUtc: json['approvedAtUtc'] != null
          ? DateTime.parse(json['approvedAtUtc'] as String)
          : null,
      processedAtUtc: json['processedAtUtc'] != null
          ? DateTime.parse(json['processedAtUtc'] as String)
          : null,
      rejectedAtUtc: json['rejectedAtUtc'] != null
          ? DateTime.parse(json['rejectedAtUtc'] as String)
          : null,
      failureReason: json['failureReason'] as String?,
      createdAtUtc: DateTime.parse(json['createdAtUtc'] as String),
    );
  }
}

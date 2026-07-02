const Map<String, int> kLedgerEntryTypeByName = {
  'PaymentCapture': 1,
  'Refund': 2,
  'Adjustment': 3,
  'Fee': 4,
};

const Map<String, int> kLedgerDirectionByName = {
  'Debit': 1,
  'Credit': 2,
};

int _parseLedgerEntryType(dynamic v) {
  if (v is int) return v;
  if (v is String) return kLedgerEntryTypeByName[v] ?? 0;
  return 0;
}

int _parseLedgerDirection(dynamic v) {
  if (v is int) return v;
  if (v is String) return kLedgerDirectionByName[v] ?? 0;
  return 0;
}

class LedgerPeriodSummary {
  final double totalReceivedAmount;
  final int transactionCount;
  final String currency;

  const LedgerPeriodSummary({
    required this.totalReceivedAmount,
    required this.transactionCount,
    required this.currency,
  });

  factory LedgerPeriodSummary.fromJson(Map<String, dynamic> json) {
    return LedgerPeriodSummary(
      totalReceivedAmount: (json['totalReceivedAmount'] as num?)?.toDouble() ?? 0,
      transactionCount: json['transactionCount'] as int? ?? 0,
      currency: json['currency'] as String? ?? 'EUR',
    );
  }
}

class TransactionLedgerEntry {
  final int id;
  final int? paymentId;
  final int? refundId;
  final int? rentalReservationId;
  final int entryType;
  final String entryTypeLabel;
  final int direction;
  final String directionLabel;
  final double amount;
  final String currency;
  final DateTime occurredAtUtc;
  final String description;
  final String? externalReference;
  final String? reservationNumber;
  final String? customerName;

  const TransactionLedgerEntry({
    required this.id,
    this.paymentId,
    this.refundId,
    this.rentalReservationId,
    required this.entryType,
    required this.entryTypeLabel,
    required this.direction,
    required this.directionLabel,
    required this.amount,
    required this.currency,
    required this.occurredAtUtc,
    required this.description,
    this.externalReference,
    this.reservationNumber,
    this.customerName,
  });

  factory TransactionLedgerEntry.fromJson(Map<String, dynamic> json) {
    return TransactionLedgerEntry(
      id: json['id'] as int,
      paymentId: json['paymentId'] as int?,
      refundId: json['refundId'] as int?,
      rentalReservationId: json['rentalReservationId'] as int?,
      entryType: _parseLedgerEntryType(json['entryType']),
      entryTypeLabel: json['entryTypeLabel'] as String? ?? '',
      direction: _parseLedgerDirection(json['direction']),
      directionLabel: json['directionLabel'] as String? ?? '',
      amount: (json['amount'] as num).toDouble(),
      currency: json['currency'] as String? ?? 'EUR',
      occurredAtUtc: DateTime.parse(json['occurredAtUtc'] as String),
      description: json['description'] as String? ?? '',
      externalReference: json['externalReference'] as String?,
      reservationNumber: json['reservationNumber'] as String?,
      customerName: json['customerName'] as String?,
    );
  }

  bool get isCredit => direction == 2;
  bool get isDebit => direction == 1;
}

class LedgerReport {
  final DateTime? fromUtc;
  final DateTime? toUtc;
  final LedgerPeriodSummary summary;
  final List<TransactionLedgerEntry> entries;

  const LedgerReport({
    this.fromUtc,
    this.toUtc,
    required this.summary,
    required this.entries,
  });

  factory LedgerReport.fromJson(Map<String, dynamic> json) {
    final entriesJson = json['entries'] as List<dynamic>? ?? [];
    return LedgerReport(
      fromUtc: json['fromUtc'] != null
          ? DateTime.parse(json['fromUtc'] as String)
          : null,
      toUtc: json['toUtc'] != null
          ? DateTime.parse(json['toUtc'] as String)
          : null,
      summary: LedgerPeriodSummary.fromJson(
          json['summary'] as Map<String, dynamic>? ?? {}),
      entries: entriesJson
          .map((e) =>
              TransactionLedgerEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

const Map<int, String> kNotificationTypeLabels = {
  1: 'Reservation Status Changed',
  2: 'Payment Succeeded',
  3: 'Payment Failed',
  4: 'Refund Processed',
  5: 'Try-On Reminder',
  6: 'Review Moderation',
  7: 'System',
  8: 'Rental Approved',
  9: 'Rental Rejected',
  10: 'Rental Ready For Pickup',
  11: 'Rental Completed',
};

class NotificationModel {
  final int id;
  final int userId;
  final int type;
  final String typeLabel;
  final int channel;
  final String title;
  final String body;
  final int status;
  final String statusLabel;
  final bool isRead;
  final DateTime? readAtUtc;
  final String? relatedEntityType;
  final int? relatedEntityId;
  final DateTime createdAtUtc;

  const NotificationModel({
    required this.id,
    required this.userId,
    required this.type,
    required this.typeLabel,
    required this.channel,
    required this.title,
    required this.body,
    required this.status,
    required this.statusLabel,
    required this.isRead,
    this.readAtUtc,
    this.relatedEntityType,
    this.relatedEntityId,
    required this.createdAtUtc,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: _parseInt(json['id'] ?? json['Id']),
      userId: _parseInt(json['userId'] ?? json['UserId']),
      type: _parseInt(json['type'] ?? json['Type']),
      typeLabel: (json['typeLabel'] ?? json['TypeLabel']) as String? ?? '',
      channel: _parseInt(json['channel'] ?? json['Channel']),
      title: (json['title'] ?? json['Title']) as String? ?? '',
      body: (json['body'] ?? json['Body']) as String? ?? '',
      status: _parseInt(json['status'] ?? json['Status']),
      statusLabel: (json['statusLabel'] ?? json['StatusLabel']) as String? ?? '',
      isRead: (json['isRead'] ?? json['IsRead']) as bool? ?? false,
      readAtUtc: _parseDateTime(json['readAtUtc'] ?? json['ReadAtUtc']),
      relatedEntityType:
          (json['relatedEntityType'] ?? json['RelatedEntityType']) as String?,
      relatedEntityId: _parseNullableInt(
          json['relatedEntityId'] ?? json['RelatedEntityId']),
      createdAtUtc: _parseDateTime(json['createdAtUtc'] ?? json['CreatedAtUtc']) ??
          DateTime.now().toUtc(),
    );
  }

  static int _parseInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  static int? _parseNullableInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String && value.isNotEmpty) return DateTime.parse(value);
    return null;
  }
}

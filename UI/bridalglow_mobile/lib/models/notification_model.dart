// ── Notification model ────────────────────────────────────────────────────

const Map<int, String> kNotificationTypeLabels = {
  1: 'Reservation Status Changed',
  2: 'Payment Succeeded',
  3: 'Payment Failed',
  4: 'Refund Processed',
  5: 'Try-On Reminder',
  6: 'Review Moderation',
  7: 'System',
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
      id: json['id'] as int,
      userId: json['userId'] as int,
      type: _parseInt(json['type']),
      typeLabel: json['typeLabel'] as String? ?? '',
      channel: _parseInt(json['channel']),
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      status: _parseInt(json['status']),
      statusLabel: json['statusLabel'] as String? ?? '',
      isRead: json['isRead'] as bool? ?? false,
      readAtUtc: json['readAtUtc'] != null
          ? DateTime.parse(json['readAtUtc'] as String)
          : null,
      relatedEntityType: json['relatedEntityType'] as String?,
      relatedEntityId: json['relatedEntityId'] as int?,
      createdAtUtc: DateTime.parse(json['createdAtUtc'] as String),
    );
  }

  static int _parseInt(dynamic value) {
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }
}

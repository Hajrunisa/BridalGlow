// ── Enum label maps ───────────────────────────────────────────────────────

const Map<int, String> kReviewStatusLabels = {
  1: 'Pending Moderation',
  2: 'Published',
  3: 'Hidden',
  4: 'Rejected',
};

const Map<String, int> kReviewStatusByName = {
  'PendingModeration': 1,
  'Published': 2,
  'Hidden': 3,
  'Rejected': 4,
};

int _parseStatus(dynamic v) {
  if (v is int) return v;
  if (v is String) return kReviewStatusByName[v] ?? 0;
  return 0;
}

// ── Review model ──────────────────────────────────────────────────────────

class Review {
  final int id;

  final int dressId;
  final String dressName;
  final String dressCode;

  final int customerUserId;
  final String customerName;

  final int? rentalReservationId;

  final int rating;
  final String? title;
  final String? comment;

  final int status;
  final String statusLabel;

  final String? moderationNote;
  final String? staffReply;

  final DateTime? publishedAtUtc;
  final DateTime? hiddenAtUtc;

  final DateTime createdAtUtc;
  final DateTime? updatedAtUtc;

  const Review({
    required this.id,
    required this.dressId,
    required this.dressName,
    required this.dressCode,
    required this.customerUserId,
    required this.customerName,
    this.rentalReservationId,
    required this.rating,
    this.title,
    this.comment,
    required this.status,
    required this.statusLabel,
    this.moderationNote,
    this.staffReply,
    this.publishedAtUtc,
    this.hiddenAtUtc,
    required this.createdAtUtc,
    this.updatedAtUtc,
  });

  bool get isPendingModeration => status == 1;
  bool get isPublished => status == 2;
  bool get isHidden => status == 3;
  bool get isRejected => status == 4;

  factory Review.fromJson(Map<String, dynamic> json) {
    return Review(
      id: json['id'] as int,
      dressId: json['dressId'] as int? ?? 0,
      dressName: json['dressName'] as String? ?? '',
      dressCode: json['dressCode'] as String? ?? '',
      customerUserId: json['customerUserId'] as int? ?? 0,
      customerName: json['customerName'] as String? ?? '',
      rentalReservationId: json['rentalReservationId'] as int?,
      rating: json['rating'] as int? ?? 0,
      title: json['title'] as String?,
      comment: json['comment'] as String?,
      status: _parseStatus(json['status']),
      statusLabel: json['statusLabel'] as String? ?? '',
      moderationNote: json['moderationNote'] as String?,
      staffReply: json['staffReply'] as String?,
      publishedAtUtc: json['publishedAtUtc'] != null
          ? DateTime.parse(json['publishedAtUtc'] as String)
          : null,
      hiddenAtUtc: json['hiddenAtUtc'] != null
          ? DateTime.parse(json['hiddenAtUtc'] as String)
          : null,
      createdAtUtc: DateTime.parse(json['createdAtUtc'] as String),
      updatedAtUtc: json['updatedAtUtc'] != null
          ? DateTime.parse(json['updatedAtUtc'] as String)
          : null,
    );
  }
}

class DressImage {
  final int id;
  final int dressId;
  final String url;
  final String? altText;
  final int sortOrder;
  final bool isPrimary;
  final String? mimeType;
  final int? fileSizeBytes;
  final DateTime createdAtUtc;

  DressImage({
    required this.id,
    required this.dressId,
    required this.url,
    this.altText,
    required this.sortOrder,
    required this.isPrimary,
    this.mimeType,
    this.fileSizeBytes,
    required this.createdAtUtc,
  });

  factory DressImage.fromJson(Map<String, dynamic> json) => DressImage(
        id: json['id'] as int,
        dressId: json['dressId'] as int,
        url: json['url'] as String,
        altText: json['altText'] as String?,
        sortOrder: json['sortOrder'] as int,
        isPrimary: json['isPrimary'] as bool,
        mimeType: json['mimeType'] as String?,
        fileSizeBytes: json['fileSizeBytes'] != null
            ? (json['fileSizeBytes'] as num).toInt()
            : null,
        createdAtUtc: DateTime.parse(json['createdAtUtc'] as String),
      );
}

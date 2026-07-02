class DressTag {
  final int id;
  final String name;
  final DateTime createdAtUtc;

  DressTag({
    required this.id,
    required this.name,
    required this.createdAtUtc,
  });

  factory DressTag.fromJson(Map<String, dynamic> json) => DressTag(
        id: json['id'] as int,
        name: json['name'] as String,
        createdAtUtc: DateTime.parse(json['createdAtUtc'] as String),
      );
}

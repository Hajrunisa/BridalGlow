class DressCategory {
  final int id;
  final String name;
  final String? description;
  final DateTime createdAtUtc;

  DressCategory({
    required this.id,
    required this.name,
    this.description,
    required this.createdAtUtc,
  });

  factory DressCategory.fromJson(Map<String, dynamic> json) => DressCategory(
        id: json['id'] as int,
        name: json['name'] as String,
        description: json['description'] as String?,
        createdAtUtc: DateTime.parse(json['createdAtUtc'] as String),
      );
}

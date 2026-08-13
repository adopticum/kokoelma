class Group {
  final String id;
  final String name;
  final String description;
  final DateTime createdAt;

  Group({
    required this.id,
    required this.name,
    required this.description,
    required this.createdAt,
  });

  factory Group.fromJson(Map<String, dynamic> json) {
    return Group(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime(1970, 1, 1),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'created_at': createdAt.toIso8601String(),
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Group &&
        other.id == id &&
        other.name == name &&
        other.description == description &&
        other.createdAt == createdAt;
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    description,
    createdAt,
  );

  /// Compares two lists of groups for equality, ignoring order.
  static bool areEqualLists(List<Group> a, List<Group> b) {
    if (a.length != b.length) return false;
    for (final group in a) {
      if (!b.contains(group)) {
        return false;
      }
    }
    return true;
  }

}

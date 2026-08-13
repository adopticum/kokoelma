class UserProfile {
  final String id;
  final String nickname;
  final String firstName;
  final String lastName;
  final DateTime? createdAt;
  // Fields joined from other tables:
  final bool isAdmin; // from privileges.is_group_admin

  UserProfile({
    required this.id,
    this.firstName = '',
    this.lastName = '',
    this.nickname = '',
    this.createdAt,
    this.isAdmin = false,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    final privileges = json['privileges'] as Map<String, dynamic>?;

    return UserProfile(
      id: json['id'] as String,
      nickname: json['nickname'] as String,
      firstName: json['firstname'] as String,
      lastName: json['lastname'] as String,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      isAdmin: privileges?['is_group_admin'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nickname': nickname,
      'firstname': firstName,
      'lastname': lastName,
      'created_at': createdAt?.toIso8601String(),
      // We do not write isAdmin.
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserProfile &&
        other.id == id &&
        other.nickname == nickname &&
        other.firstName == firstName &&
        other.lastName == lastName &&
        other.createdAt == createdAt &&
        other.isAdmin == isAdmin;
  }

  @override
  int get hashCode => Object.hash(
    id,
    nickname,
    firstName,
    lastName,
    createdAt,
    isAdmin,
  );
}

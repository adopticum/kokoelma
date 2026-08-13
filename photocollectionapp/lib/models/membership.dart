class Membership {
  final String id;
  final DateTime joinedAt;
  final String userid;
  final String groupid;

  Membership({
    required this.id,
    required this.joinedAt,
    required this.userid,
    required this.groupid,
  });

  factory Membership.fromJson(Map<String, dynamic> json) {
    return Membership(
      id: json['id'] as String,
      joinedAt: json['joined_at'] != null
          ? DateTime.parse(json['joined_at'] as String)
          : DateTime(1970, 1, 1),
      userid: json['userid'] as String,
      groupid: json['groupid'] as String,
    );
  }

  static Membership? tryParseMembership(Map<String, dynamic> record) {
    final id = record['id'];
    final userId = record['userid'];
    final groupId = record['groupid'];

    if (id is! String || userId is! String || groupId is! String) {
      return null;
    }
    return Membership.fromJson(record);
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'joined_at': joinedAt.toIso8601String(),
      'userid': userid,
      'groupid': groupid,
    };
  }
}
